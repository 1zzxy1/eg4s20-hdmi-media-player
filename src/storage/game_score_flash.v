// User SPI Flash only. Two reserved 4 KiB sectors form a commit-last journal.
// Page format: FGR1, sequence LE32, 10x96-bit records, CRC32 LE32,
// erased padding, commit 0xa5 at offset 255. CRC covers bytes [0,127].
// Both complete sectors must be blank or carry our magic before any erase.
module game_score_flash #(
    parameter integer CLK_DIV=12,
    parameter WRITE_ENABLE=1,
    parameter [23:0] SECTOR0=24'h600000, SECTOR1=24'h601000,
    parameter integer POLL_LIMIT=65535
)(input wire clk,rst,save_req,
    output wire [3:0] query_index, input wire [95:0] query_record,
    output reg load_valid, output reg [3:0] load_index, output reg [95:0] load_record,
    output wire busy, output reg ready,error, output wire persist_available,
    output wire flash_cs_n,flash_sck,flash_mosi, input wire flash_miso);
    localparam MAGIC=32'h31524746;
    reg [5:0] state;
    reg start,use_address;
    reg [7:0] opcode;
    reg [23:0] address;
    reg [12:0] length;
    wire done,rx_valid;
    wire [11:0] tx_index,rx_index;
    wire [7:0] rx_byte;
    reg [7:0] tx_byte;
    reg [23:0] jedec;
    reg id_ok,owned0,owned1,valid0,have_active,active,target,scan_sector;
    reg [31:0] seq0,current_seq,new_seq,scan_seq,magic,crc,stored_crc;
    reg blank;
    reg [7:0] commit,status_byte;
    reg [95:0] load_shift;
    reg [7:0] crc_index;
    reg [31:0] write_crc;
    reg [16:0] polls;
    reg [1:0] poll_next;
    reg [3:0] tx_record_number,tx_record_byte,rx_record_number,rx_record_byte;
    wire payload_next;
    wire [11:0] data_index=(state==20)?{4'd0,crc_index}:tx_index;
    assign query_index=tx_record_number;
    assign busy=(state!=10);
    assign persist_available=id_ok && owned0 && owned1 && WRITE_ENABLE;
    function [31:0] crc32_byte;
        input [31:0] c; input [7:0] b;
        reg [31:0] v; integer n;
        begin v=c^{24'd0,b}; for(n=0;n<8;n=n+1) v=v[0]?(v>>1)^32'hedb88320:(v>>1); crc32_byte=v; end
    endfunction
    always @* begin
        if(data_index<4) tx_byte=MAGIC>>(data_index[1:0]*8);
        else if(data_index<8) tx_byte=new_seq>>(data_index[1:0]*8);
        else if(data_index<128) tx_byte=query_record>>(tx_record_byte*8);
        else if(data_index<132) tx_byte=write_crc>>(data_index[1:0]*8);
        else tx_byte=8'hff;
        if(state==35 || state==36) tx_byte=8'ha5;
    end
    game_flash_transaction #(.CLK_DIV(CLK_DIV)) spi(
        .clk(clk),.rst(rst),.start(start),.opcode(opcode),.use_address(use_address),
        .address(address),.length(length),.tx_byte(tx_byte),.tx_index(tx_index),
        .done(done),.rx_valid(rx_valid),.rx_index(rx_index),.rx_byte(rx_byte),.payload_next(payload_next),
        .cs_n(flash_cs_n),.sck(flash_sck),.mosi(flash_mosi),.miso(flash_miso));
    task transaction;
        input [7:0] cmd; input addr_en; input [23:0] addr; input [12:0] count;
        begin opcode<=cmd;use_address<=addr_en;address<=addr;length<=count;start<=1;end
    endtask
    task reset_scan;
        begin crc<=32'hffffffff;stored_crc<=0;magic<=0;scan_seq<=0;blank<=1;commit<=0;end
    endtask
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=0; start<=0; opcode<=0; use_address<=0; address<=0; length<=0;
            ready<=0;error<=0;id_ok<=0;jedec<=0;owned0<=0;owned1<=0;valid0<=0;
            have_active<=0;active<=0;target<=0;scan_sector<=0;seq0<=0;current_seq<=0;new_seq<=0;
            scan_seq<=0;magic<=0;crc<=0;stored_crc<=0;blank<=1;commit<=0;
            load_valid<=0;load_index<=0;load_record<=0;load_shift<=0;
            crc_index<=0;write_crc<=0;status_byte<=0;polls<=0;poll_next<=0;
            tx_record_number<=0;tx_record_byte<=0;rx_record_number<=0;rx_record_byte<=0;
        end else begin
            start<=0;load_valid<=0;
            // Sequential byte cursors replace division/modulo by 12 in both
            // the CRC pass and SPI payload. Advance only after byte capture.
            if((state==20 && crc_index>=8) ||
               (state==28 && payload_next && tx_index>=8 && tx_index<128))begin
                if(tx_record_byte==11)begin tx_record_byte<=0;tx_record_number<=tx_record_number+1'b1;end
                else tx_record_byte<=tx_record_byte+1'b1;
            end
            case(state)
                0: begin transaction(8'h9f,0,0,3);state<=1;end
                1: begin
                    if(rx_valid) jedec<={jedec[15:0],rx_byte};
                    if(done) state<=2;
                end
                2: begin
                    if(jedec==24'hef4017 || jedec==24'hef3017) begin id_ok<=1;state<=3;end
                    else begin error<=1;ready<=1;state<=10;end
                end
                3: begin reset_scan;transaction(8'h03,1,scan_sector?SECTOR1:SECTOR0,4096);state<=4;end
                4,30: begin
                    if(rx_valid) begin
                        if(rx_byte!=8'hff) blank<=0;
                        if(rx_index<128) crc<=crc32_byte(crc,rx_byte);
                        if(rx_index<4) magic[rx_index[1:0]*8+:8]<=rx_byte;
                        if(rx_index>=4 && rx_index<8) scan_seq[rx_index[1:0]*8+:8]<=rx_byte;
                        if(rx_index>=128 && rx_index<132) stored_crc[rx_index[1:0]*8+:8]<=rx_byte;
                        if(rx_index==255) commit<=rx_byte;
                    end
                    if(done) state<=(state==4)?5:31;
                end
                5: begin
                    if(magic==MAGIC && commit==8'ha5 && stored_crc!=~crc) error<=1;
                    if(!scan_sector) begin
                        owned0<=blank || magic==MAGIC;
                        valid0<=(magic==MAGIC && commit==8'ha5 && stored_crc==~crc);
                        seq0<=scan_seq;scan_sector<=1;state<=3;
                    end else begin
                        owned1<=blank || magic==MAGIC;
                        if(!(blank || magic==MAGIC) || !owned0) error<=1;
                        if(magic==MAGIC && commit==8'ha5 && stored_crc==~crc &&
                           (!valid0 || $signed(scan_seq-seq0)>0)) begin
                            active<=1;have_active<=1;current_seq<=scan_seq;state<=6;
                        end else if(valid0) begin active<=0;have_active<=1;current_seq<=seq0;state<=6;end
                        else begin ready<=1;state<=10;end
                    end
                end
                6: begin
                    rx_record_number<=0;rx_record_byte<=0;
                    transaction(8'h03,1,active?SECTOR1:SECTOR0,128);state<=7;
                end
                7: begin
                    if(rx_valid && rx_index>=8 && rx_index<128) begin
                        load_shift<={rx_byte,load_shift[95:8]};
                        if(rx_record_byte==11) begin
                            load_valid<=1;load_index<=rx_record_number;
                            load_record<={rx_byte,load_shift[95:8]};
                            rx_record_byte<=0;rx_record_number<=rx_record_number+1'b1;
                        end else rx_record_byte<=rx_record_byte+1'b1;
                    end
                    if(done) state<=8;
                end
                8: begin ready<=1;state<=10;end
                10: if(save_req) begin
                    if(persist_available) begin
                        target<=have_active?!active:0;new_seq<=current_seq+1'b1;
                        crc<=32'hffffffff;crc_index<=0;state<=20;error<=0;
                        tx_record_number<=0;tx_record_byte<=0;
                    end else error<=1;
                end
                20: begin
                    crc<=crc32_byte(crc,tx_byte);
                    if(crc_index==127) begin write_crc<=~crc32_byte(crc,tx_byte);state<=21;end
                    else crc_index<=crc_index+1'b1;
                end
                21: begin transaction(8'h06,0,0,0);state<=22;end
                22: if(done) state<=23;
                23: begin transaction(8'h20,1,target?SECTOR1:SECTOR0,0);state<=24;end
                24: if(done) begin polls<=0;poll_next<=0;state<=40;end
                25: begin transaction(8'h06,0,0,0);state<=26;end
                26: if(done) state<=27;
                27: begin
                    tx_record_number<=0;tx_record_byte<=0;
                    transaction(8'h02,1,target?SECTOR1:SECTOR0,132);state<=28;
                end
                28: if(done) begin polls<=0;poll_next<=1;state<=40;end
                29: begin reset_scan;transaction(8'h03,1,target?SECTOR1:SECTOR0,132);state<=30;end
                31: begin
                    if(magic==MAGIC && scan_seq==new_seq && stored_crc==~crc && stored_crc==write_crc) state<=33;
                    else begin error<=1;state<=10;end
                end
                33: begin transaction(8'h06,0,0,0);state<=34;end
                34: if(done) state<=35;
                35: begin transaction(8'h02,1,(target?SECTOR1:SECTOR0)+24'd255,1);state<=36;end
                36: if(done) begin polls<=0;poll_next<=2;state<=40;end
                37: begin transaction(8'h03,1,(target?SECTOR1:SECTOR0)+24'd255,1);state<=38;end
                38: begin if(rx_valid) commit<=rx_byte;if(done) state<=39;end
                39: begin
                    if(commit==8'ha5) begin active<=target;have_active<=1;current_seq<=new_seq;end
                    else error<=1;
                    state<=10;
                end
                40: begin transaction(8'h05,0,0,1);state<=41;end
                41: begin if(rx_valid) status_byte<=rx_byte;if(done) state<=42;end
                42: begin
                    if(!status_byte[0]) begin
                        case(poll_next) 0:state<=25;1:state<=29;default:state<=37;endcase
                    end else if(polls>=POLL_LIMIT) begin error<=1;state<=10;end
                    else begin polls<=polls+1'b1;state<=40;end
                end
                default:begin error<=1;state<=10;end
            endcase
        end
    end
endmodule

// SPI mode 0 transaction engine. Header then payload, with one-cycle read strobes.
module game_flash_transaction #(parameter integer CLK_DIV=12)(
    input wire clk,rst,start,input wire [7:0] opcode,input wire use_address,
    input wire [23:0] address,input wire [12:0] length,input wire [7:0] tx_byte,
    output wire [11:0] tx_index,output reg done,rx_valid,output wire payload_next,
    output reg [11:0] rx_index,output reg [7:0] rx_byte,
    output reg cs_n,sck,output wire mosi,input wire miso);
    reg [12:0] byte_number,total;
    reg [2:0] bit_number;
    reg [15:0] divider;
    reg [7:0] tx_shift,rx_shift;
    reg [2:0] header;
    reg pending_byte;
    assign tx_index=byte_number-header;
    assign payload_next=!cs_n && pending_byte && byte_number>=header;
    assign mosi=tx_shift[7];
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            cs_n<=1;sck<=0;done<=0;rx_valid<=0;rx_index<=0;rx_byte<=0;
            byte_number<=0;total<=0;bit_number<=7;divider<=0;tx_shift<=0;rx_shift<=0;header<=1;pending_byte<=0;
        end else begin
            done<=0;rx_valid<=0;
            if(start && cs_n) begin
                cs_n<=0;sck<=0;header<=use_address?4:1;total<=length+(use_address?4:1);
                byte_number<=0;bit_number<=7;divider<=0;tx_shift<=opcode;rx_shift<=0;pending_byte<=0;
            end else if(!cs_n) begin
                if(pending_byte) begin
                    pending_byte<=0;
                    if(byte_number<header) begin
                        case(byte_number) 1:tx_shift<=address[23:16];2:tx_shift<=address[15:8];default:tx_shift<=address[7:0];endcase
                    end else tx_shift<=tx_byte;
                end else if(divider==CLK_DIV-1) begin
                    divider<=0;
                    if(!sck) begin sck<=1;rx_shift<={rx_shift[6:0],miso};end
                    else begin
                        sck<=0;tx_shift<={tx_shift[6:0],1'b0};
                        if(bit_number==0) begin
                            if(byte_number>=header) begin rx_valid<=1;rx_index<=byte_number-header;rx_byte<=rx_shift;end
                            if(byte_number==total-1) begin cs_n<=1;done<=1;end
                            else begin byte_number<=byte_number+1'b1;bit_number<=7;pending_byte<=1;end
                        end else bit_number<=bit_number-1'b1;
                    end
                end else divider<=divider+1'b1;
            end
        end
    end
endmodule

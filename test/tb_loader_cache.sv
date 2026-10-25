`timescale 1ns/1ps
// Real scanner/scaler/controller. The endpoint replaces only SD SPI; output
// geometry is reduced for this scheduling test (full-size pixels are tested
// independently by tb_loader_recovery and the frame-path/golden regressions).
module tb_loader_cache;
    reg clk=0,rst=1,key_next=1,finished=0,ack=0,allow_ack=1;
    always #10 clk=~clk;
    wire [3:0] state;
    wire valid,commit,wreq,we;
    wire [1:0] wb,db;
    wire [31:0] data;
    wire [6:0] index,count;
    wire [2:0] cached;
    integer pixels=0,finish_delay=0,ack_delay=0,loads=0;
    reg wreq_prev=0,have_front=0;
    reg [1:0] front;
    reg [3:0] complete=0;
    reg [7:0] slot_id[0:3];
    sd_card_bmp #(.CLK_FREQ_HZ(1000),.SCAN_START_SECTOR(2048),.SCAN_MAX_SECTOR(2200)) dut(
        .clk(clk),.rst(rst),.key_next(key_next),.key_auto(1'b1),.state_code(state),
        .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(valid),
        .write_finish_toggle(finished),.display_ack_toggle(ack),.display_commit_toggle(commit),
        .write_buf_idx(wb),.disp_buf_idx(db),.write_req(wreq),.write_req_ack(wreq),
        .write_ready(1'b1),.write_en(we),.write_data(data),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
        .cache_count(cached),.image_index(index),.image_count(count));
    defparam dut.bmp_read_m0.OUT_WIDTH=8;
    defparam dut.bmp_read_m0.OUT_HEIGHT=4;

    always @(posedge clk) if(!rst) begin
        wreq_prev<=wreq;
        if(wreq && !wreq_prev) begin
            if(have_front && wb==front) $fatal(1,"write request to active slot");
            pixels=0;complete[wb]=0;loads=loads+1;
        end
        if(we) begin
            if(have_front && wb==front) $fatal(1,"pixel write to active slot");
            if(data[23:0]!==24'h201000) $fatal(1,"pixel ordering/scaling changed");
            if(pixels==0) slot_id[wb]=data[31:24];
            else if(slot_id[wb]!=data[31:24]) $fatal(1,"mixed image in slot");
            pixels=pixels+1;
            if(pixels==32) finish_delay=40;
        end
        if(finish_delay>0) begin
            finish_delay=finish_delay-1;
            if(finish_delay==0) begin finished<=!finished;complete[wb]=1;end
        end
        if(commit!=ack) begin
            if(!complete[db] || slot_id[db]==3) $fatal(1,"partial/bad frame committed");
            ack_delay=ack_delay+1;
            if(allow_ack && ack_delay>=12) begin ack<=commit;front<=db;have_front<=1;end
        end else ack_delay=0;
    end
    task tick;begin @(negedge clk);end endtask
    task press;begin key_next=0;repeat(26)tick();key_next=1;repeat(26)tick();end endtask
    task await_index(input integer expected);
        integer timeout;
        begin
            timeout=0;
            while(index!=expected && timeout<50000) begin tick();timeout=timeout+1;end
            if(index!=expected) $fatal(1,"display index %0d expected %0d",index,expected);
            if(slot_id[front]!=expected) $fatal(1,"displayed slot has wrong source");
        end
    endtask
    task await_full;
        integer timeout;
        begin
            timeout=0;
            while(cached!=4 && timeout<50000) begin tick();timeout=timeout+1;end
            if(cached!=4) $fatal(1,"prefetch did not fill cache");
        end
    endtask
    integer before_requests;
    initial begin
        repeat(5)tick();rst=0;await_index(1);await_full();
        if(count!=6) $fatal(1,"scanner must catalog more than four images");
        before_requests=dut.internal_card.sd_card_top_m0.served;
        allow_ack=0;press();repeat(80)tick();
        if(index!=1 || commit==ack || dut.internal_card.sd_card_top_m0.served!=before_requests)
            $fatal(1,"ready switch read SD or recycled old slot before ack");
        allow_ack=1;await_index(2);await_full();
        press();await_index(4);await_full();
        press();await_index(5);await_full();
        press();await_index(6);await_full();
        press();await_index(1);await_full();
        press();await_index(2);await_full();
        $display("PASS loader cache: six-image scan/marker, partial corrupt image skip, cached switch without SD read, ack-gated refill, wrap");
        $finish;
    end
    initial begin #20000000;$fatal(1,"loader cache timeout index=%0d cache=%0d",index,cached);end
endmodule

module sd_card_top(input wire clk,rst,output wire SD_nCS,SD_DCLK,SD_MOSI,input wire SD_MISO,
    output wire sd_init_done,input wire sd_sec_read,input wire [31:0] sd_sec_read_addr,
    output reg [7:0] sd_sec_read_data,output reg sd_sec_read_data_valid,sd_sec_read_end,
    input wire sd_sec_write,input wire [31:0] sd_sec_write_addr,input wire [7:0] sd_sec_write_data,
    output wire sd_sec_write_data_req,sd_sec_write_end);
    assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=0;assign sd_init_done=!rst;
    assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
    localparam [127:0] END_TAG="FPGA_BMP_END_V1!";
    integer served=0,j,id,part,filepos;
    function [7:0] byte_at(input integer p,input integer image);
        begin
            byte_at=0;
            case(p)
                0:byte_at="B";1:byte_at="M";2:byte_at=54;3:byte_at=3;10:byte_at=54;
                14:byte_at=40;18:byte_at=8;22:byte_at=32;26:byte_at=1;28:byte_at=24;
                default: if(p>=54 && p<822) case((p-54)%3)
                    0:byte_at=16;1:byte_at=32;2:byte_at=image;
                endcase
            endcase
        end
    endfunction
    initial begin
        sd_sec_read_data=0;sd_sec_read_data_valid=0;sd_sec_read_end=0;
        forever begin
            wait(sd_sec_read&&!rst);served=served+1;
            if(sd_sec_read_addr<2048 || sd_sec_read_addr>2060)
                $fatal(1,"scan passed exact end marker");
            id=(sd_sec_read_addr-2048)/2+1;part=(sd_sec_read_addr-2048)%2;
            for(j=0;j<((id==3 && part==1)?511:512);j=j+1) begin
                @(negedge clk);
                if(sd_sec_read_addr==2060)
                    sd_sec_read_data=j<16 ? END_TAG[(15-j)*8 +: 8] : 0;
                else sd_sec_read_data=byte_at(part*512+j,id);
                sd_sec_read_data_valid=1;
                @(negedge clk);sd_sec_read_data_valid=0;
            end
            sd_sec_read_end=1;@(negedge clk);sd_sec_read_end=0;wait(!sd_sec_read);
        end
    end
endmodule

`timescale 1ns/1ps
// MODEL-ONLY: memory array is a controller App-interface model, not encrypted RTL.
// Real course asynchronous FIFO RTL, DMA, video timing and video_delay are used.
module tb_frame_path #(
    parameter integer DISPLAY_SLOT = 2,
    parameter integer ALIGN_OFFSET = -1,
    parameter integer FREE_RASTER = 0,
    parameter integer BANKS = 4
);
    localparam integer FRAME_WORDS = 307200;
    localparam integer BACKGROUND_SLOT = (DISPLAY_SLOT + 1) % BANKS;
    localparam BANK_BITS=BANKS>4?3:2;
    reg mc=0,wc=0,pc=0,rst=1,vrst=1;
    always #12.5 mc=~mc;always #10 wc=~wc;always #20 pc=~pc;
    wire wa,wfinish,wready,re,ra,rfinish,app_r,app_w,read_en;
    wire busy,refresh,initialized,returned;wire [31:0] returned_data;
    reg [BANK_BITS-1:0] write_bank_select=DISPLAY_SLOT;
    wire [BANK_BITS-1:0] read_bank_select=DISPLAY_SLOT;
    integer concurrent_writes=0;
`ifdef BMP_SOURCE
    wire wreq,we;wire [31:0] wd;
    reg bmp_start=0;
    wire bmp_ready,bmp_done,sector_req;wire [31:0] sector_addr;
    wire [23:0] loaded_rgb;wire [3:0] bmp_error;
    reg [7:0] sector_data=0;reg sector_valid=0,sector_end=0;
    bmp_sector_player source(.clk(wc),.rst(rst),.sd_init_done(initialized),
        .scan_start(1'b0),.scan_start_sector(32'd0),.scan_max_sector(32'd0),.scan_target_count(3'd1),
        .scan_done(),.scan_found_valid(),.scan_found_sector(),.scan_found_total(),
        .load_start(bmp_start),.load_sector(32'd2048),.ready(bmp_ready),.state_code(),
        .write_req(wreq),.write_req_ack(wa),.pixel_ready(wready),.bmp_data_wr_en(we),.bmp_data(loaded_rgb),
        .load_done(bmp_done),.error_code(bmp_error),.sd_sec_read(sector_req),.sd_sec_read_addr(sector_addr),
        .sd_sec_read_data(sector_data),.sd_sec_read_data_valid(sector_valid),.sd_sec_read_end(sector_end));
    assign wd={loaded_rgb,8'd0};
    function [7:0] file_byte(input integer p);
        begin
            file_byte=0;
            case(p)
                0:file_byte="B";1:file_byte="M";2:file_byte=70;10:file_byte=54;
                14:file_byte=40;18:file_byte=2;22:file_byte=2;26:file_byte=1;28:file_byte=24;
                54,57,58,59,64,66:file_byte=255;
            endcase
        end
    endfunction
    integer sb;
    initial forever begin
        wait(sector_req);if(sector_addr!=2048) $fatal(1,"unexpected tiny BMP sector");
        for(sb=0;sb<512;sb=sb+1) begin
            @(negedge wc);sector_data=file_byte(sb);sector_valid=1;
            @(negedge wc);sector_valid=0;
        end
        sector_end=1;@(negedge wc);sector_end=0;wait(!sector_req);
    end
`else
    reg wreq=0,we=0;reg [31:0] wd=0;
`endif
    wire [20:0] raddr,waddr;wire [31:0] app_data,read_data;wire [3:0] mask;
    wire hs,vs,de,ho,vo,dout;wire [23:0] pixel;
    reg [31:0] memory[0:BANKS*FRAME_WORDS-1];
    reg [3:0] latency=0;reg [31:0] pipe[0:3];
    reg [1:0] ack_sync=0;
    reg read_started=0;
    reg re_d=0,read_pending=0;
    wire dma_request=FREE_RASTER?read_pending:re;
    wire [9:0] offset_value=ALIGN_OFFSET<0?0:ALIGN_OFFSET;
    always @(posedge pc)begin
        if(vrst)begin re_d<=0;read_pending<=0;end
        else begin
            re_d<=re;
            if(re&&!re_d)read_pending<=1;
            else if(ack_sync[1])read_pending<=0;
        end
    end
    integer memcycles=0,writes=0,reads=0,pixels=0,i,j,cy=0,expected;
`ifdef REAL_SDRAM
    reg shifted=0;
    initial begin #12;forever #12.5 shifted=~shifted;end
    sdram memory_ip(.Clk(mc),.Clk_sft(shifted),.Rst(rst),.Sdr_init_done(initialized),
        .Sdr_init_ref_vld(refresh),.Sdr_busy(busy),.App_wr_en(app_w),.App_wr_addr(waddr),
        .App_wr_dm(mask),.App_wr_din(app_data),.App_rd_en(app_r),.App_rd_addr(raddr),
        .Sdr_rd_en(returned),.Sdr_rd_dout(returned_data));
`else
    assign busy=(memcycles%337)<5;
    assign refresh=busy;assign initialized=!rst;
    assign returned=latency[3];assign returned_data=pipe[3];
`endif
    frame_read_write #(.BURST_SIZE(128),.ALIGNMENT(ALIGN_OFFSET>=0),.BANK_BITS(BANK_BITS)) dut(.rst(rst),.mem_clk(mc),.Sdr_init_done(initialized),
        .Sdr_init_ref_vld(refresh),.Sdr_busy(busy),.App_rd_en(app_r),.App_rd_addr(raddr),
        .Sdr_rd_en(returned),.Sdr_rd_dout(returned_data),.read_clk(pc),.read_req(dma_request),.read_req_ack(ra),
        .read_finish(rfinish),.read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd614400),.read_addr_3(21'd921600),
        .read_addr_4(21'd1228800),.read_addr_5(21'd1536000),
        .read_addr_index(read_bank_select),.read_len(21'd307200),.read_en(read_en),.read_data(read_data),
        .App_wr_en(app_w),.App_wr_addr(waddr),.App_wr_din(app_data),.App_wr_dm(mask),
        .write_clk(wc),.write_req(wreq),.write_req_ack(wa),.write_finish(wfinish),
        .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd614400),.write_addr_3(21'd921600),
        .write_addr_4(21'd1228800),.write_addr_5(21'd1536000),
        .write_addr_index(write_bank_select),.write_len(21'd307200),.write_en(we),.write_data(wd),.write_ready(wready),
        .alignment_offset(offset_value));
    always @(posedge pc) begin
        if(vrst) begin ack_sync<=0;read_started<=0;end
        else begin ack_sync<={ack_sync[0],ra};if(ack_sync[1]) read_started<=1;end
    end
    video_timing_data timing(pc,vrst,re,FREE_RASTER?re:ack_sync[1],hs,vs,de);
    video_delay delay(pc,vrst,read_en,read_data[31:8],hs,vs,de,ho,vo,dout,pixel);
    always @(posedge mc) begin
        memcycles=memcycles+1;
        latency<={latency[2:0],app_r};pipe[1]<=pipe[0];pipe[2]<=pipe[1];pipe[3]<=pipe[2];
        if(!rst && app_w) begin
            if(mask!==0 || waddr<write_bank_select*FRAME_WORDS ||
                waddr>=(write_bank_select+1)*FRAME_WORDS) $fatal(1,"bank or mask violation slot=%0d addr=%0d",write_bank_select,waddr);
            if(write_bank_select==BACKGROUND_SLOT) concurrent_writes=concurrent_writes+1;
            memory[waddr]<=app_data;writes=writes+1;
        end
        if(!rst && app_r) begin
            if(raddr<read_bank_select*FRAME_WORDS ||
                raddr>=(read_bank_select+1)*FRAME_WORDS) $fatal(1,"read bank bounds slot=%0d addr=%0d",read_bank_select,raddr);
            pipe[0]<=memory[raddr];reads=reads+1;
        end
        if(app_r&&app_w) $fatal(1,"simultaneous read and write");
    end
    always @(posedge pc) begin
        #1;
        if(!vrst && read_started && dout) begin
`ifdef BMP_SOURCE
            expected=pixels/640<240 ? ((pixels%640+offset_value)%640<320?24'hff0000:24'h00ff00) :
                ((pixels%640+offset_value)%640<320?24'h0000ff:24'hffffff);
`else
            expected=((479-pixels/640)*640+(pixels%640+offset_value)%640)^24'h567890^(24'h010101*DISPLAY_SLOT);
`endif
            if(pixel!==expected[23:0]) $fatal(1,"FIFO/video pixel %0d got %h expected %h",pixels,pixel,expected[23:0]);
            pixels=pixels+1;
            if(pixels==307200) begin
                if(writes<307200||reads!=307200||concurrent_writes<10000)
                    $fatal(1,"DMA count/overlap %0d %0d %0d",writes,reads,concurrent_writes);
`ifdef REAL_SDRAM
                $display("PASS frame path with vendor encrypted SDRAM controller; display slot=%0d background slot=%0d concurrent writes=%0d",DISPLAY_SLOT,BACKGROUND_SLOT,concurrent_writes);
`else
                $display("PASS frame path: real async FIFOs, clocks 50/40/25MHz, full frame, display slot=%0d background slot=%0d, VFLIP, concurrent writes=%0d",DISPLAY_SLOT,BACKGROUND_SLOT,concurrent_writes);
`endif
                $finish;
            end
        end
    end
    initial begin
        if(DISPLAY_SLOT<0 || DISPLAY_SLOT>=BANKS) $fatal(1,"DISPLAY_SLOT out of range");
`ifdef BMP_SOURCE
        repeat(8)@(negedge wc);rst=0;wait(initialized);repeat(4)@(negedge wc);
        bmp_start=1;@(negedge wc);bmp_start=0;
        wait(bmp_done);if(bmp_error) $fatal(1,"BMP error");
        wait(wfinish);repeat(10)@(negedge pc);vrst=0;
        wait(read_started);@(negedge wc);write_bank_select=BACKGROUND_SLOT;bmp_start=1;
        @(negedge wc);bmp_start=0;
`else
        repeat(8)@(negedge wc);rst=0;wreq=1;
        wait(wa);repeat(3)@(negedge wc);wreq=0;
        // Wait for asynchronous FIFO clear and synchronous release.
        wait(!wa);repeat(12)@(negedge wc);
        i=0;
        while(i<307200) begin
            @(negedge wc);cy=cy+1;
            we=wready&&(cy%17>3);
            wd={(24'(i)^24'h567890^(24'h010101*DISPLAY_SLOT)),8'd0};
            if(we) i=i+1;
        end
        @(negedge wc);we=0;wait(wfinish);repeat(10)@(negedge pc);vrst=0;
        wait(read_started);@(negedge wc);write_bank_select=BACKGROUND_SLOT;wreq=1;
        wait(wa);repeat(3)@(negedge wc);wreq=0;wait(!wa);repeat(12)@(negedge wc);
        i=0;
        while(i<307200) begin
            repeat(13)@(negedge wc);
            we=wready;wd={(24'(i)^24'habcdef),8'd0};
            if(we) i=i+1;
            @(negedge wc);we=0;
        end
`endif
    end
    initial begin #300000000;$fatal(1,"frame path timeout pixels=%0d writes=%0d reads=%0d",pixels,writes,reads);end
endmodule

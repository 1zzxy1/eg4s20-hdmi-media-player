`timescale 1ns/1ps
module tb_scaled_bmp;
    parameter W=640,H=480,FILE_BYTES=1024,SCALING=1,ZOOM=0;
    reg clk=0,rst=1,start=0,ack=0,pready=0,dvalid=0,dend=0;
    reg [7:0] din=0;
    always #10 clk=~clk;
    wire ready,wreq,req,pvalid,done;wire [3:0] error,state;wire [31:0] addr;
    wire [23:0] rgb;
    reg [7:0] image[0:FILE_BYTES-1];
    reg [23:0] golden[0:W*H-1];
    string image_path,golden_path;
    integer bad=0,short_sector=0,no_reply=0,negative=0,pixels=0,cycles=0,j,base,served=0;
    bmp_sector_player #(.ENABLE_SCALE(SCALING),.OUT_WIDTH(W),.OUT_HEIGHT(H),.TIMEOUT_CYCLES(20000)) dut(
        .clk(clk),.rst(rst),.sd_init_done(1'b1),.view_zoom(ZOOM!=0),.scan_start(1'b0),.scan_start_sector(32'd2048),
        .scan_max_sector(32'd2048),.scan_target_count(3'd1),.scan_done(),.scan_found_valid(),
        .scan_found_sector(),.scan_found_total(),.load_start(start),.load_sector(32'd2048),
        .ready(ready),.state_code(state),.write_req(wreq),.write_req_ack(ack),.pixel_ready(pready),
        .bmp_data_wr_en(pvalid),.bmp_data(rgb),.load_done(done),.error_code(error),
        .sd_sec_read(req),.sd_sec_read_addr(addr),.sd_sec_read_data(din),
        .sd_sec_read_data_valid(dvalid),.sd_sec_read_end(dend));
    always @(negedge clk) begin
        cycles=cycles+1;ack=wreq;
        // Bursty consumer, long periodic stalls, and jittery sectors are independent.
        pready=(cycles%113)>40 && (cycles%17)!=0;
    end
    always @(posedge clk) if(!rst && pvalid) begin
        if(!pready || pixels>=W*H) $fatal(1,"unexpected pixel count/handshake");
        if(rgb!==golden[pixels]) $fatal(1,"pixel %0d got %h expected %h",pixels,rgb,golden[pixels]);
        pixels=pixels+1;
    end
    initial begin
        if(!$value$plusargs("IMAGE=%s",image_path)||!$value$plusargs("GOLDEN=%s",golden_path)) $fatal;
        if($value$plusargs("BAD=%d",bad)) begin end
        if($value$plusargs("SHORT=%d",short_sector)) begin end
        if($value$plusargs("SILENT=%d",no_reply)) begin end
        if($value$plusargs("NEGATIVE=%d",negative)) begin end
        $readmemh(image_path,image);$readmemh(golden_path,golden);
        if(negative) golden[W*H/2]=golden[W*H/2]^24'h010000;
        repeat(5)@(negedge clk);rst=0;start=1;@(negedge clk);start=0;
        if(bad||short_sector||no_reply) begin
            wait(error!=0);
            if(short_sector==2) begin
                if(pixels<=0||pixels>=W*H) $fatal(1,"midstream fault did not exercise partial frame");
            end else if(pixels!=0) $fatal(1,"bad file emitted pixels");
            if(!ready) $fatal(1,"error did not recover to idle");
        end else begin
            wait(done);@(negedge clk);
            if(pixels!=W*H || error!=0) $fatal(1,"completion mismatch");
        end
        $display("PASS scaled BMP pixels=%0d sectors=%0d error=%0d",pixels,served,error);$finish;
    end
    initial forever begin
        wait(req && !rst);base=(addr-2048)*512;
        if(no_reply) wait(rst);
        else begin
            if(base<0 || base+511>=FILE_BYTES) $fatal(1,"out of range sector %0d",addr);
            served=served+1;
            repeat(3) @(negedge clk);
            for(j=0;j<((short_sector==1 || (short_sector==2 && served>=2))?511:512);j=j+1) begin
                din=image[base+j];dvalid=1;@(negedge clk);dvalid=0;
                repeat(1+j%3) @(negedge clk);
            end
            dend=1;@(negedge clk);dend=0;
            wait(!req);@(negedge clk);
        end
    end
    initial begin #2000000000;$fatal(1,"watchdog");end
endmodule

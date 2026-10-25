`timescale 1ns/1ps
// Decode the actual vendor serializer pins while running the real PLL model.
module tb_video_svga;
    parameter CORRUPT=0;
    reg clk=0;always #10 clk=~clk;
    reg [3:0] keys=15,sw=0;
    wire [3:0] led;wire hc,h0,h1,h2,scl,sn,sc,sm,fn,fc,fm,fw,fh;tri1 sda;
    video_svga_top dut(clk,keys,sw,led,hc,h0,h1,h2,scl,sda,
        sn,sc,sm,1'b1,fn,fc,fm,1'b1,fw,fh);
    wire [31:0] serial_words;
    hdmi_serial_capture #(.LAST_CYCLE(2100000)) serial_check(
        dut.pix_clk,dut.serial_clk,dut.path_rst,dut.c0,dut.c1,dut.c2,10'b1111100000,
        h0,h1,h2,hc,serial_words);
    reg [23:0] golden[0:479999];
    reg [1023:0] golden_file,ppm_file;
    integer image_file;
    real last_pixel=0,last_serial=0;
    always @(posedge dut.pix_clk)begin
        if(!dut.path_rst&&last_pixel!=0&&($realtime-last_pixel<24.99||$realtime-last_pixel>25.01))
            $fatal(1,"pixel clock is not 40MHz");
        last_pixel=$realtime;
    end
    always @(posedge dut.serial_clk)begin
        if(!dut.path_rst&&last_serial!=0&&($realtime-last_serial<4.99||$realtime-last_serial>5.01))
            $fatal(1,"serial clock is not 200MHz");
        last_serial=$realtime;
    end
    always @(posedge clk)
        if({sn,sc,sm,fn,fc,fm,fw,fh,scl,sda}!==10'b1011011111)
            $fatal(1,"storage/DDC pins not idle");
    initial begin
        if(!$value$plusargs("GOLDEN=%s",golden_file))$fatal(1,"missing golden");
        if(!$value$plusargs("PPM=%s",ppm_file))$fatal(1,"missing image path");
        $readmemh(golden_file,golden);
        image_file=$fopen(ppm_file,"wb");$fwrite(image_file,"P6\n800 600\n255\n");
        // As in the A/B bench, functional PLL startup requires a reset pulse.
        force dut.u_vid.reset=1'b1;#200;release dut.u_vid.reset;
        if(CORRUPT)force dut.blue.video_data=8'h42;
        wait(dut.path_rst===1'b0);
    end
    function [7:0] decode(input [9:0] code);
        reg [7:0] q;integer k;
        begin q=code[9]?~code[7:0]:code[7:0];decode[0]=q[0];
            for(k=1;k<8;k=k+1)decode[k]=code[8]?(q[k]^q[k-1]):~(q[k]^q[k-1]);end
    endfunction
    localparam [9:0] C00=10'h354,C01=10'h0ab,C10=10'h154,C11=10'h2ab;
    reg [9:0] c0,c1,c2;
    reg control,hs,vs,old_hs=0,old_vs=0,seen=0,synced=0,in_row=0;
    reg [23:0] got;
    integer cycles=0,xx=0,yy=0,frames=0,pixels=0;
    integer hs_start=0,hs_end=0,vs_start=0,frame_end=0,row_start=0;
    reg frames_done=0;
    always @(serial_words)if(serial_words>0&&!frames_done)begin
        cycles=cycles+1;
        c0=serial_check.recovered[9:0];c1=serial_check.recovered[19:10];c2=serial_check.recovered[29:20];
        if(^{c0,c1,c2}===1'bx)$fatal(1,"unknown TMDS symbol");
        control=c1==C00&&c2==C00&&(c0==C00||c0==C01||c0==C10||c0==C11);
        if(control)begin
            if(in_row)begin
                // The pin receiver can acquire mid-row after reset. Require
                // complete rows only after observing a physical VS boundary.
                if(synced&&xx!=800)$fatal(1,"SVGA row width %0d",xx);
                in_row=0;xx=0;if(synced)yy=yy+1;
            end
            case(c0)
                C00:begin hs=0;vs=0;end C01:begin hs=1;vs=0;end
                C10:begin hs=0;vs=1;end C11:begin hs=1;vs=1;end
            endcase
            if(seen&&!old_hs&&hs)begin
                if(hs_start!=0&&cycles-hs_start!=1056)$fatal(1,"line period");
                hs_start=cycles;
            end
            if(seen&&old_hs&&!hs)begin
                if(cycles-hs_start!=128)$fatal(1,"HS width");hs_end=cycles;
            end
            if(seen&&!old_vs&&vs)vs_start=cycles;
            if(seen&&old_vs&&!vs)begin
                if(cycles-vs_start!=4*1056)$fatal(1,"VS width");
                if(synced)begin
                    if(cycles-frame_end!=1056*628||yy!=600)$fatal(1,"SVGA frame size/period");
                    if(frames==0)$fclose(image_file);
                    frames=frames+1;
                end
                synced=1;yy=0;frame_end=cycles;
                if(frames==2)frames_done=1;
            end
            seen=1;old_hs=hs;old_vs=vs;
        end else begin
            if(!in_row)begin
                if(synced&&cycles-hs_end!=88)$fatal(1,"SVGA back porch");
                if(synced&&yy>0&&cycles-row_start!=1056)$fatal(1,"active row period");
                in_row=1;xx=0;row_start=cycles;
            end
            if(xx>=800)$fatal(1,"SVGA row too long");
            if(synced)begin
                got={decode(c2),decode(c1),decode(c0)};
                if(yy>=600||got!==golden[yy*800+xx])
                    $fatal(1,"SVGA pixel mismatch x=%0d y=%0d got=%h expected=%h",xx,yy,got,golden[yy*800+xx]);
                if(frames==0)$fwrite(image_file,"%c%c%c",got[23:16],got[15:8],got[7:0]);
                pixels=pixels+1;
            end
            xx=xx+1;
        end
    end
    initial begin
        wait(frames_done);
        if(pixels!=960000||serial_words<1900000)$fatal(1,"incomplete SVGA frames");
        @(negedge dut.pix_clk);keys[3]=0;
        repeat(10)@(negedge dut.pix_clk);
        if(!dut.path_rst)$fatal(1,"KEY4 must assert reset");
        keys[3]=1;wait(dut.path_rst===1'b0);
        repeat(20)@(negedge dut.pix_clk);
        $display("PASS SVGA: pin-decoded pixels=%0d frames=%0d words=%0d 40/200MHz HS128 BP88 line1056 frame628 KEY4 storage idle",pixels,frames,serial_words);
        $finish;
    end
    initial begin #100_000_000;$fatal(1,"SVGA timeout");end
endmodule

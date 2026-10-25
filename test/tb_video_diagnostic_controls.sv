`timescale 1ns/1ps
module tb_video_diagnostic_controls;
    reg clk=0;always #10 clk=~clk;
    reg [3:0] keys=15,sw=0;wire [3:0] led;
    wire hc,h0,h1,h2,scl,sn,sc,sm,fn,fc,fm,fw,fh;tri1 sda;
    video_diagnostic_top dut(clk,keys,sw,led,hc,h0,h1,h2,scl,sda,
        sn,sc,sm,1'b1,fn,fc,fm,1'b1,fw,fh);
    always @(posedge clk)begin
        if({sn,sc,sm,fn,fc,fm,fw,fh}!==8'b10110111)$fatal(1,"storage pins not idle");
    end
    task select_mode(input bit mode);
        begin
            @(negedge dut.pix_clk);sw[0]=mode;
            wait(dut.dvi_mode===mode);wait(dut.path_rst===1'b0);
            repeat(20)@(negedge dut.pix_clk);
            if(dut.dvi_mode!==mode||dut.path_rst)$fatal(1,"path selection/reset");
        end
    endtask
    initial begin
        // The functional PLL model needs an explicit startup pulse; hardware
        // power-on initialization is not represented by a constant reset pin.
        force dut.u_vid.reset=1'b1;#200;release dut.u_vid.reset;
        wait(dut.path_rst===1'b0);
        if(dut.dvi_mode!==0)$fatal(1,"boot must select HDMI");
        select_mode(1);select_mode(0);
        @(negedge dut.pix_clk);keys[3]=0;
        repeat(10)@(negedge dut.pix_clk);
        if(!dut.path_rst)$fatal(1,"KEY4 must hold video in reset");
        keys[3]=1;wait(dut.path_rst===1'b0);
        repeat(20)@(negedge dut.pix_clk);
        if(dut.dvi_mode!==0)$fatal(1,"KEY4 changed selected path");
        $display("PASS diagnostic board controls: functional PLL boot, HDMI-DVI-HDMI, KEY4 reset, no SD/Flash access");
        $finish;
    end
    initial begin #80_000_000;$fatal(1,"diagnostic controls timeout");end
endmodule

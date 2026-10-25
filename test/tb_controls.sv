`timescale 1ns/1ps
module tb_controls;
    reg clk=0,rst=1,frame=0,key=1,overlay=0,wave=0;reg [1:0] sw=0;
    wire [1:0] brightness,contrast,mode;wire o,w;wire [15:0] time_bcd;
    always #20 clk=~clk;
    video_controls #(.CLOCK_HZ(100),.DEBOUNCE(3),.LONG_PRESS(20)) dut(
        clk,rst,frame,key,sw,overlay,wave,brightness,contrast,o,w,mode,time_bcd,2'd0,2'd0);
    task tick(input integer n);begin repeat(n)@(negedge clk);end endtask
    task publish;begin frame=1;tick(1);frame=0;end endtask
    integer i;
    initial begin
        tick(3);rst=0;sw=2;overlay=1;wave=1;tick(8);
        if(brightness||o||w) $fatal(1,"mid-frame controls changed");
        publish();if(brightness!=2||!o||!w) $fatal(1,"switch snapshot");
        key=0;tick(1);key=1;tick(5);publish();if(contrast) $fatal(1,"bounce");
        key=0;tick(9);key=1;tick(8);
        if(contrast) $fatal(1,"contrast changed outside frame");
        publish();if(contrast!=1) $fatal(1,"short press");
        key=0;tick(40);key=1;tick(8);publish();
        if(mode!=1||contrast!=1) $fatal(1,"long press duplicated short");
        key=0;tick(40);key=1;tick(8);publish();
        if(mode!=2) $fatal(1,"WIPE missing");
        key=0;tick(40);key=1;tick(8);publish();
        if(mode!=0) $fatal(1,"CUT cycle missing");
        // Reset to align the exact clock count; 6000 clocks is precisely 01:00.
        rst=1;tick(2);rst=0;tick(5999);publish();
        if(time_bcd!==16'h0059) $fatal(1,"early minute rollover %h",time_bcd);
        publish();if(time_bcd!==16'h0100) $fatal(1,"minute rollover %h",time_bcd);
        $display("PASS controls: debounce, short/long press, frame atomicity, exact BCD minute");$finish;
    end
endmodule

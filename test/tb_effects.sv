`timescale 1ns/1ps
module tb_effects;
    reg clk=0,rst=1,hs=0,vs=0,de=0,overlay=0,valid=1;
    reg [23:0] rgb=24'h10f080;
    reg [1:0] sw=0;
    wire ho,vo,dout;wire [23:0] result;
    always #20 clk=~clk;
    video_effects dut(clk,rst,hs,vs,de,rgb,sw,overlay,valid,ho,vo,dout,result);
    task tick;begin @(negedge clk);end endtask
    task frame;begin de=0;vs=0;repeat(5)tick();vs=1;tick();vs=0;tick();de=1;tick();end endtask
    integer mode;
    initial begin
        repeat(4)tick();rst=0;frame();
        if(result!==24'h10f080) $fatal(1,"normal RGB");
        sw=1;repeat(8)tick();
        if(result!==24'h10f080) $fatal(1,"setting changed mid-frame");
        frame(); if(result!==24'h30ffa0) $fatal(1,"+32 saturation");
        sw=2;frame();if(result!==24'h50ffc0) $fatal(1,"+64 saturation");
        sw=3;frame();if(result!==24'h00d060) $fatal(1,"-32 saturation");
        valid=0;tick();if(result!==0) $fatal(1,"invalid frame must black");
        de=0;tick();if(dout!==0 || result!==0) $fatal(1,"blanking");
        $display("PASS effects: saturating RGB888, frame-boundary settings, blanking");$finish;
    end
endmodule

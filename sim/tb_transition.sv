`timescale 1ns/1ps
module tb_transition;
    reg clk=0,rst=1,req=0,frame=0;reg [1:0] bank=0;
    always #20 clk=~clk;
    wire valid,ack,hold;wire [1:0] active;wire [4:0] gain;
    transition_control ctl(clk,rst,frame,valid,req,ack,hold,gain);
    frame_commit_bridge bridge(clk,rst,req,bank,frame,hold,active,valid,ack);
    task boundary; begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(8)@(negedge clk);end endtask
    integer i;reg [4:0] prev;
    initial begin
        repeat(4)@(negedge clk);rst=0;req=1;repeat(8)@(negedge clk);boundary();
        if(!valid||active!=0||!ack||gain!=16) $fatal(1,"initial commit");
        bank=1;req=0;repeat(8)@(negedge clk);
        for(i=0;i<16;i=i+1) begin
            prev=gain;boundary();
            if(gain!=prev-1 || active!=0 || !ack) $fatal(1,"fade-out or early bank reuse");
        end
        boundary();if(active!=1||ack||gain!=0) $fatal(1,"black boundary commit");
        for(i=0;i<17;i=i+1) boundary();
        if(gain!=16||hold) $fatal(1,"fade-in incomplete");
        rst=1;@(negedge clk);if(valid||ack) $fatal(1,"reset");
        $display("PASS transition: monotonic 16-step fade, black-only swap, startup and reset");$finish;
    end
    initial begin #1000000;$fatal(1,"timeout");end
endmodule

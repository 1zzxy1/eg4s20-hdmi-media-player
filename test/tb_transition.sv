`timescale 1ns/1ps
module tb_transition;
    reg clk=0,rst=1,req=0,frame=0,reader_ack=0;reg [1:0] bank=0,mode=0;
    always #20 clk=~clk;
    wire valid,ack,hold;wire [1:0] active,effect;wire [4:0] gain;
    transition_control ctl(clk,rst,frame,valid,req,ack,hold,gain,mode,effect);
    frame_commit_bridge bridge(clk,rst,req,bank,frame,hold,active,valid,ack,reader_ack);
    task boundary; begin
        @(negedge clk);reader_ack=0;frame=1;
        @(negedge clk);frame=0;repeat(4)@(negedge clk);
        reader_ack=1;repeat(4)@(negedge clk);
    end endtask
    integer i;reg [4:0] prev;
    initial begin
        repeat(4)@(negedge clk);rst=0;req=1;repeat(8)@(negedge clk);boundary();
        if(!valid||active!=0||!ack||gain!=16) $fatal(1,"initial commit");
        bank=1;req=0;repeat(8)@(negedge clk);boundary();
        if(active!=1||ack||gain!=16||effect!=0) $fatal(1,"CUT not immediate");
        mode=1;bank=2;req=1;repeat(8)@(negedge clk);
        for(i=0;i<16;i=i+1) begin
            prev=gain;boundary();
            if(gain!=prev-1 || active!=1 || ack) $fatal(1,"fade-out or early bank reuse");
            mode=0;
            if(effect!=1) $fatal(1,"transition mode not latched");
        end
        boundary();if(active!=2||!ack||gain!=0) $fatal(1,"black boundary commit");
        // A second commit may reach the pixel domain after the previous ack
        // but before the next frame tick. It must not hide the first fade-in.
        mode=1;bank=3;req=0;repeat(8)@(negedge clk);
        for(i=0;i<16;i=i+1) begin
            prev=gain;boundary();
            if(gain!=prev+1 || active!=2 || !ack || !hold || effect!=1)
                $fatal(1,"queued request swallowed first fade-in at step %0d",i);
        end
        boundary();
        if(active!=2 || !ack || gain!=16) $fatal(1,"queued swap before complete fade-in");
        for(i=0;i<16;i=i+1) begin
            prev=gain;boundary();
            if(gain!=prev-1 || active!=2 || !ack || effect!=1)
                $fatal(1,"second transaction skipped fade-out at step %0d",i);
            mode=2;
        end
        boundary();if(active!=3||ack||gain!=0||effect!=1) $fatal(1,"second black boundary commit");
        for(i=0;i<16;i=i+1) begin
            prev=gain;boundary();
            if(gain!=prev+1 || active!=3 || ack || effect!=1)
                $fatal(1,"second fade-in incomplete at step %0d",i);
        end
        boundary();
        if(gain!=16||hold) $fatal(1,"fade-in incomplete");
        mode=0;bank=0;req=1;repeat(8)@(negedge clk);boundary();
        if(active!=0||!ack||gain!=16||effect!=0) $fatal(1,"CUT after fade");
        rst=1;@(negedge clk);if(valid||ack) $fatal(1,"reset");
        $display("PASS transition: CUT, latched modes, queued commits preserve complete fade-in/out, black-only swap, startup/reset");$finish;
    end
    initial begin #1000000;$fatal(1,"timeout");end
endmodule

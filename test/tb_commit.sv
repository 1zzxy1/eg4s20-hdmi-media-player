`timescale 1ns/1ps
module tb_commit;
    reg clk=0,rst=1,toggle=0,frame=0,reader_ack=0; reg [1:0] bank=0;
    always #20 clk=~clk;
    wire [1:0] active;wire valid,ack;
    frame_commit_bridge dut(clk,rst,toggle,bank,frame,1'b0,active,valid,ack,reader_ack);
    task tick;begin @(negedge clk);end endtask
    initial begin
        repeat(4) tick();rst=0;tick();bank=1;toggle=1;
        repeat(10) tick();
        if(valid||ack) $fatal(1,"committed outside frame boundary");
        reader_ack=1;frame=1;repeat(3) tick();
        if(!valid||ack||active!=1) $fatal(1,"stale reader ack released slot");
        reader_ack=0;repeat(4) tick();
        if(ack) $fatal(1,"slot freed before DMA accept");
        reader_ack=1;repeat(3) tick();
        if(!ack) $fatal(1,"reader acceptance not acknowledged");
        bank=0;toggle=0;repeat(10) tick();
        if(active!=1||!ack) $fatal(1,"mid-frame switch");
        frame=0;reader_ack=0;repeat(3) tick();frame=1;repeat(3) tick();
        if(active!=0||!ack) $fatal(1,"second capture missing/early release");
        reader_ack=1;repeat(3) tick();
        if(ack) $fatal(1,"second DMA acceptance missing");
        rst=1;tick();if(valid||ack) $fatal(1,"reset");
        $display("PASS commit: frame-only capture, delayed DMA acceptance, stale-ack rejection, reset");$finish;
    end
endmodule

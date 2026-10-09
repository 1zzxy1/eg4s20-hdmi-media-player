`timescale 1ns/1ps
module tb_audio;
    reg clk=0, rst=1;
    always #20 clk=~clk;
    wire valid, av; wire [23:0] l,r; wire [19:0] n,cts;
    pcm48_tone dut(clk,rst,valid,l,r,av,n,cts);
    integer i, samples=0, acrs=0, last=0, flips=0;
    reg sign_prev;
    initial begin
        repeat(5) @(negedge clk); rst=0;
        sign_prev=0;
        for(i=1;i<=250000;i=i+1) begin
            @(negedge clk);
            if(valid) begin
                samples=samples+1;
                if(last!=0 && i-last!=520 && i-last!=521) $fatal(1,"sample spacing");
                last=i;
                if(l!==r || (l!==24'h100000 && l!==24'hf00000)) $fatal(1,"PCM sample");
                if(samples>1 && l[23]!=sign_prev) flips=flips+1;
                sign_prev=l[23];
            end
            if(av) begin
                acrs=acrs+1;
                if(!valid || n!=6144 || cts!=25000) $fatal(1,"ACR");
            end
        end
        if(samples!=480 || acrs!=10 || flips!=19) $fatal(1,"counts %d %d %d",samples,acrs,flips);
        $display("PASS audio: 480 samples/10 ms, 1 kHz, ACR N/CTS"); $finish;
    end
endmodule

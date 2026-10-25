`timescale 1ns/1ps
module tb_scope;
    reg clk=0,rst=1,frame=0,pvalid=0;reg signed [23:0] pcm=0;
    reg [5:0] index=0;wire signed [7:0] sample;wire [7:0] peak;wire valid;
    always #20 clk=~clk;
    audio_scope dut(clk,rst,frame,pvalid,pcm,index,sample,peak,valid);
    integer i;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        for(i=0;i<64;i=i+1) begin pvalid=1;pcm=(i-32)*65536;@(negedge clk);end
        pvalid=0;if(valid) $fatal(1,"snapshot before frame boundary");
        frame=1;@(negedge clk);frame=0;
        if(!valid||peak!=32) $fatal(1,"peak");
        for(i=0;i<64;i=i+1) begin
            index=i;pcm=-24'sh800000;pvalid=1;@(negedge clk);
            if(sample!==i-32) $fatal(1,"display changed during capture");
        end
        pvalid=0;frame=1;@(negedge clk);frame=0;
        if(peak!=128||sample!=-128) $fatal(1,"signed minimum peak");
        $display("PASS scope: signed PCM, full-window atomic swap, stable capture/display, peak -128");$finish;
    end
endmodule

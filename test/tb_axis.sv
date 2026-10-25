`timescale 1ns/1ps
module tb_axis;
    reg clk=0,rst=1,vs=0,de=0; reg [23:0] rgb=0;
    always #20 clk=~clk;
    wire user,valid,last; wire [23:0] data;
    video_rgb_to_axis_640x480 dut(clk,rst,vs,de,rgb,user,valid,last,data);
    integer frame,line,x,vc=0,lc=0,uc=0;
    task step(input bit d,input [23:0] value);
        begin
            @(negedge clk); de=d;rgb=value;
            @(posedge clk); #1;
            if(valid!==d || (d && data!==value)) $fatal(1,"data alignment");
            if(valid) begin
                vc=vc+1;
                if(last !== (x==639)) $fatal(1,"TLAST pixel %0d",x);
                if(user !== (line==0 && x==0)) $fatal(1,"SOF pixel %0d line %0d",x,line);
            end
            if(last) lc=lc+1;
            if(user) uc=uc+1;
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst=0;
        for(frame=0;frame<2;frame=frame+1) begin
            vs=1;step(0,0);step(0,0);vs=0;step(0,0);
            for(line=0;line<480;line=line+1) begin
                for(x=0;x<640;x=x+1) step(1,(line<<10)|x);
                repeat(4) step(0,0);
            end
        end
        if(vc!=614400 || lc!=960 || uc!=2) $fatal(1,"frame counts");
        $display("PASS AXIS: two 640x480 frames; RGB/SOF/TLAST aligned");$finish;
    end
endmodule

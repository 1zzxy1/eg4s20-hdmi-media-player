`timescale 1ns/1ps
module tb_video_golden;
    reg clk=0,rst=1,hs=0,vs=0,de=0,overlay=0,wave=0,key=1,pcm_valid=0;
    reg [23:0] rgb=0;reg [1:0] bright=0;
    reg [4:0] gain=16;
    always #20 clk=~clk;
    wire ho,vo,dout,mode,valid,user,last;wire [23:0] result,axis;
    integer f,xx,yy,px,py,count=0,style=0;
    reg [23:0] expected[0:614399];string path;
    advanced_video #(.DEBOUNCE(3),.LONG_PRESS(20)) dut(clk,rst,hs,vs,de,rgb,1'b1,key,overlay,wave,bright,gain,pcm_valid,24'sh100000,
        ho,vo,dout,result,mode);
    video_rgb_to_axis_640x480 adapter(clk,rst,vo,dout,result,user,valid,last,axis);
    always @(posedge clk) begin
        #1;
        if(!rst && valid) begin
            if(count>=614400) $fatal(1,"extra pixel");
            if(axis!==expected[count]) $fatal(1,"video style=%0d pixel=%0d got=%h expected=%h",style,count,axis,expected[count]);
            if(user!==(count%307200==0)||last!==(count%640==639)) $fatal(1,"SOF/TLAST alignment %0d",count);
            count=count+1;
        end
        if(!rst && !dout && result!==0) $fatal(1,"non-black blanking");
    end
    initial begin
        if(!$value$plusargs("GOLDEN=%s",path)) $fatal;
        if($value$plusargs("STYLE=%d",style)) begin end
        $readmemh(path,expected);
        repeat(4)@(negedge clk);rst=0;
        if(style==1) overlay=1;
        if(style==2) begin bright=1;gain=8;end
        if(style==3) wave=1;
        if(style==4) begin overlay=1;wave=1;bright=2;gain=12;end
        if(style==5) begin
            gain=8;key=0;repeat(40)@(negedge clk);key=1;repeat(8)@(negedge clk);
        end
        if(style==6) begin
            // Three short presses select contrast x2 without internal force.
            repeat(3) begin key=0;repeat(9)@(negedge clk);key=1;repeat(8)@(negedge clk);end
            bright=3;
        end
        if(style==7||style==8) begin
            repeat(style-6) begin key=0;repeat(9)@(negedge clk);key=1;repeat(8)@(negedge clk);end
            bright=style-6;
        end
        repeat(8)@(negedge clk);
        for(f=0;f<2;f=f+1) begin
            for(yy=0;yy<525;yy=yy+1)
                for(xx=0;xx<800;xx=xx+1) begin
                    vs=yy<2;hs=xx<96;de=xx>=160&&yy>=45;
                    pcm_valid=style==4;
                    px=xx-160;py=yy-45;
                    rgb={8'((px*19+py*5)%256),8'((px*3+py*17)%256),8'((px*7+py*11)%256)};
                    // Changes during frame0 only become effective in frame1.
                    if(style==1 && f==0 && yy==200 && xx==0) overlay=0;
                    @(negedge clk);
                end
        end
        de=0;vs=0;repeat(8)@(negedge clk);
        if(count!=614400) $fatal(1,"pixel count %0d",count);
        $display("PASS video golden: style=%0d, two full frames, exact RGB/SOF/TLAST, blanking",style);$finish;
    end
    initial begin #40000000;$fatal(1,"video timeout");end
endmodule

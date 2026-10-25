`timescale 1ns/1ps
module tb_video_diagnostic;
    parameter DVI=0,CORRUPT=0;
    reg clk=0,serial_clk=0,rst=1;
    always #20 clk=~clk;
    always #4 serial_clk=~serial_clk;
    wire [9:0] c0,c1,c2,cc;wire overflow,locked,scl;tri1 sda;
    video_diagnostic dut(clk,rst,DVI!=0,c0,c1,c2,cc,overflow,locked,scl,sda);
    wire sd0,sd1,sd2,sck;wire [31:0] serial_words;
    hdmi_phy_wrapper #(.DEVICE("EG")) phy(clk,serial_clk,rst,c0,c1,c2,cc,sd0,sd1,sd2,sck);
    hdmi_serial_capture serial_check(clk,serial_clk,rst,c0,c1,c2,cc,sd0,sd1,sd2,sck,serial_words);
    reg [23:0] golden[0:307199];
    reg [1023:0] golden_file,ppm_file;
    integer image_file;
    initial begin
        if(!$value$plusargs("GOLDEN=%s",golden_file))$fatal(1,"missing independent golden");
        if(!$value$plusargs("PPM=%s",ppm_file))$fatal(1,"missing image path");
        $readmemh(golden_file,golden);
        image_file=$fopen(ppm_file,"wb");$fwrite(image_file,"P6\n640 480\n255\n");
        if(CORRUPT)force dut.hdmi.core.I_axis_s_data=24'h123456;
        repeat(10)@(negedge clk);rst=0;
    end
    function [7:0] decode(input [9:0] code);
        reg [7:0] q;integer k;
        begin q=code[9]?~code[7:0]:code[7:0];decode[0]=q[0];
            for(k=1;k<8;k=k+1)decode[k]=code[8]?(q[k]^q[k-1]):~(q[k]^q[k-1]);end
    endfunction
    function [3:0] un_terc(input [9:0] code);
        case(code)
            10'h29c:un_terc=0;10'h263:un_terc=1;10'h2e4:un_terc=2;10'h2e2:un_terc=3;
            10'h171:un_terc=4;10'h11e:un_terc=5;10'h18e:un_terc=6;10'h13c:un_terc=7;
            10'h2cc:un_terc=8;10'h139:un_terc=9;10'h19c:un_terc=10;10'h2c6:un_terc=11;
            10'h28e:un_terc=12;10'h271:un_terc=13;10'h163:un_terc=14;10'h2c3:un_terc=15;
            default:un_terc=4'bxxxx;
        endcase
    endfunction
    localparam [9:0] C00=10'b1101010100,C01=10'b0010101011,C10=10'b0101010100,C11=10'b1010101011;
    wire guard=c0==10'b1011001100&&c1==10'b0100110011&&c2==10'b1011001100;
    wire control=c1==C00&&c2==C00&&(c0==C00||c0==C01||c0==C10||c0==C11);
    integer cycles=0,xx=0,yy=0,frames=0,pixels=0,rows=0,guards=0;
    integer line_start=0,hs_fall=0,hs_rise=0,pre_count=0,island_cycles=0;
    reg in_video=0,synced=0,after_video=0,seen=0,out_vs=1,out_hs=1;
    reg island_active=0,trailing=0,sync_valid,pixel_valid;
    reg [1:0] sync_bits;reg [3:0] nibble;reg [23:0] got;
    always @(posedge clk)begin
        #1;cycles=cycles+1;
        if(!rst&&locked)begin
            if(overflow)$fatal(1,"diagnostic HDMI backpressure");
            if(^{c0,c1,c2,cc}===1'bx)$fatal(1,"unknown output");
            sync_valid=0;pixel_valid=0;
            if(DVI)begin
                pixel_valid=!control;
                if(!pixel_valid&&in_video)$fatal(1,"short DVI row");
            end else begin
                pixel_valid=in_video;
                if(after_video&&!control)$fatal(1,"long HDMI row");
                after_video=0;
            end
            if(pixel_valid)begin
                if(!in_video)begin
                    if(synced&&cycles-hs_rise!=48)$fatal(1,"DVI back porch %0d",cycles-hs_rise);
                    if(synced&&yy>0&&cycles-line_start!=800)$fatal(1,"DVI line period");
                    line_start=cycles;in_video=1;
                end
                if(synced)begin
                    got={decode(c2),decode(c1),decode(c0)};
                    if(yy>=480||got!==golden[yy*640+xx])
                        $fatal(1,"diagnostic pixel mismatch x=%0d y=%0d got=%h expected=%h",xx,yy,got,golden[yy*640+xx]);
                    if(frames==0)$fwrite(image_file,"%c%c%c",got[23:16],got[15:8],got[7:0]);
                    pixels=pixels+1;
                end
                if(xx==639)begin in_video=0;xx=0;after_video=!DVI;if(synced)begin yy=yy+1;rows=rows+1;end end
                else xx=xx+1;
            end else if(!DVI&&guard)begin
                guards=guards+1;
                if(guards==2)begin
                    if(synced&&cycles-hs_rise!=47)$fatal(1,"HDMI back porch %0d",cycles-hs_rise+1);
                    if(synced&&yy>0&&cycles+1-line_start!=800)$fatal(1,"HDMI line period");
                    line_start=cycles+1;in_video=1;xx=0;guards=0;
                end
            end else begin
                guards=0;
                if(!DVI)begin
                    if(c1==C01&&c2==C01)pre_count=pre_count+1;
                    else begin
                        if(pre_count==8)begin island_active=1;island_cycles=0;trailing=0;end
                        pre_count=0;
                    end
                end
                if(island_active)begin
                    nibble=un_terc(c0);if(^nibble===1'bx)$fatal(1,"bad island symbol");
                    sync_bits=nibble[1:0];sync_valid=1;
                    if(trailing)island_active=0;
                    else if(island_cycles>=2&&c1==10'h133&&c2==10'h133)trailing=1;
                    island_cycles=island_cycles+1;
                end else case(c0)
                    C00:begin sync_bits=0;sync_valid=1;end C01:begin sync_bits=1;sync_valid=1;end
                    C10:begin sync_bits=2;sync_valid=1;end C11:begin sync_bits=3;sync_valid=1;end
                endcase
                if(sync_valid)begin
                    if(seen&&out_hs&&!sync_bits[0])hs_fall=cycles;
                    if(seen&&!out_hs&&sync_bits[0])begin
                        if(synced&&cycles-hs_fall!=96)$fatal(1,"HS width");hs_rise=cycles;
                    end
                    if(seen&&!out_vs&&sync_bits[1])begin
                        if(synced)begin
                            if(yy!=480)$fatal(1,"frame height %0d",yy);
                            if(frames==0)$fclose(image_file);
                            frames=frames+1;
                        end
                        synced=1;yy=0;
                    end
                    seen=1;out_hs=sync_bits[0];out_vs=sync_bits[1];
                end
            end
        end
        if(cycles==420000*4)begin
            if(frames<2||pixels<640*480*2||serial_words<1679900)$fatal(1,"incomplete diagnostic");
            $display("PASS video diagnostic DVI=%0d frames=%0d rows=%0d pixels=%0d serial=%0d",DVI,frames,rows,pixels,serial_words);
            $finish;
        end
    end
endmodule

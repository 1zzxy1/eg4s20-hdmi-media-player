`timescale 1ns/1ps
// Actual encrypted HDMI RTL. Test digital TMDS video symbols, input handshake,
// clock and audio/ACR stimulation. Does not model PHY analog eye or sink EDID.
module tb_hdmi_vendor;
    reg clk=0,rst=1;
    always #20 clk=~clk;
    wire hs,vs,de,req;wire [23:0] pixel;
    wire user,valid,last,ready,locked;
    wire [23:0] axis,left,right;
    wire av,acr;wire [19:0] n,cts;
    wire [9:0] c0,c1,c2,cc;wire scl;tri1 sda;
    wire oh,ov,od,wipe;wire [23:0] out_pixel;
    video_timing_data timing(clk,rst,req,req,hs,vs,de);
    advanced_video effects(clk,rst,hs,vs,de,24'h804020,1'b1,1'b1,1'b1,1'b1,
        2'b00,5'd16,av,left,oh,ov,od,out_pixel,wipe);
    video_rgb_to_axis_640x480 axis_pack(clk,rst,ov,od,out_pixel,user,valid,last,axis);
    pcm48_tone audio(clk,rst,av,left,right,acr,n,cts);
    hdmi_1_4b_transmitter_core_wrapper #(.DEVICE("EG"),.HTOTAL(800),.HSA(96),.HFP(16),.HBP(48),.HACTIVE(640),
        .VTOTAL(525),.VSA(2),.VFP(10),.VBP(33),.VACTIVE(480),.VIDEO_VIC(1),.VIDEO_TPG("Disable"),
        .VIDEO_FORMAT("RGB"),.AUDIO_SAMPLE_RATE("48K"),.IIC_SCL_DIV(250)) dut(
        .I_pixel_clk(clk),.I_rst(rst),.I_edid_read_trig(1'b0),.O_edid_read_valid(),.O_edid_read_data(),
        .I_axis_s_user(user),.I_axis_s_valid(valid),.I_axis_s_last(last),.I_axis_s_data(axis),.O_axis_s_ready(ready),
        .I_audio_valid(av),.I_audio_left_data(left),.I_audio_right_data(right),.I_acr_valid(acr),.I_acr_cts(cts),.I_acr_n(n),
        .O_video_locked(locked),.O_ddc_scl(scl),.IO_ddc_sda(sda),
        .O_ch0_tmds_data(c0),.O_ch1_tmds_data(c1),.O_ch2_tmds_data(c2),.O_clk_tmds_data(cc));
    function [7:0] decode(input [9:0] code);
        reg [7:0] q;integer k;
        begin q=code[9]?~code[7:0]:code[7:0];decode[0]=q[0];
            for(k=1;k<8;k=k+1) decode[k]=code[8]?(q[k]^q[k-1]):~(q[k]^q[k-1]);end
    endfunction
    integer clock_count=0,locked_cycles=0,base_pixels=0,audio_count=0;
    always @(posedge clk) begin
        #1;clock_count=clock_count+1;
        if(!rst && av) audio_count=audio_count+1;
        if(!rst && locked) begin
            locked_cycles=locked_cycles+1;
            if(valid && !ready) $fatal(1,"HDMI backpressure while locked");
            if(^{c0,c1,c2,cc}===1'bx) $fatal(1,"unknown TMDS outputs while locked");
            if(decode(c2)==8'h80&&decode(c1)==8'h40&&decode(c0)==8'h20) base_pixels=base_pixels+1;
        end
        if(clock_count==420000*5) begin
            if(locked_cycles<420000||base_pixels<307200||audio_count<3000) $fatal(1,"HDMI no valid output lock=%0d base=%0d audio=%0d",locked_cycles,base_pixels,audio_count);
            $display("PASS vendor HDMI: locked=%0d cycles, base RGB decoded=%0d, PCM samples=%0d, no backpressure/X",locked_cycles,base_pixels,audio_count);$finish;
        end
    end
    initial begin repeat(10)@(negedge clk);rst=0;end
endmodule

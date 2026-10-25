// Board comparison backend: vendor HDMI packetizer and raster generator.
// Keep the complete 640-pixel rows; SOF/TLAST are generated from final DE.
// This isolates receiver compatibility without shifting game coordinates.
module game_hdmi_output #(
    parameter READ_EDID=0
)(
    input wire clk,rst,hs,vs,de,input wire [23:0] rgb,
    input wire sample_valid,input wire [23:0] sample_left,sample_right,
    input wire acr_valid,
    output wire [9:0] c0,c1,c2,cc,
    output reg overflow,
    output wire locked,
    output wire ddc_scl,inout wire ddc_sda
);
    wire user,valid,last,ready;
    wire [23:0] data;
    wire edid_trigger;
    startup_pulse #(.CNT_MAX(20'd100000)) startup(
        .I_clk(clk),.I_rst(rst),.O_pulse(edid_trigger));
    video_rgb_to_axis_640x480 pack(
        .I_clk(clk),.I_rst(rst),.I_vs(vs),.I_de(de),.I_rgb(rgb),
        .O_video_user(user),.O_video_valid(valid),.O_video_last(last),.O_video_data(data));
    always @(posedge clk or posedge rst)
        if(rst)overflow<=0;
        else if(locked&&valid&&!ready)overflow<=1;
    hdmi_1_4b_transmitter_core_wrapper #(
        .DEVICE("EG"),.HTOTAL(800),.HSA(96),.HFP(16),.HBP(48),.HACTIVE(640),
        .VTOTAL(525),.VSA(2),.VFP(10),.VBP(33),.VACTIVE(480),.VIDEO_VIC(1),
        .VIDEO_TPG("Disable"),.VIDEO_FORMAT("RGB"),.AUDIO_SAMPLE_RATE("48K"),
        .IIC_SCL_DIV(250)) core(
        .I_pixel_clk(clk),.I_rst(rst),.I_edid_read_trig(READ_EDID?edid_trigger:1'b0),
        .O_edid_read_valid(),.O_edid_read_data(),
        .I_axis_s_user(user),.I_axis_s_valid(valid),.I_axis_s_last(last),
        .I_axis_s_data(data),.O_axis_s_ready(ready),
        .I_audio_valid(sample_valid),.I_audio_left_data(sample_left),
        .I_audio_right_data(sample_right),.I_acr_valid(acr_valid),
        .I_acr_cts(20'd25000),.I_acr_n(20'd6144),.O_video_locked(locked),
        .O_ddc_scl(ddc_scl),.IO_ddc_sda(ddc_sda),
        .O_ch0_tmds_data(c0),.O_ch1_tmds_data(c1),.O_ch2_tmds_data(c2),
        .O_clk_tmds_data(cc));
endmodule

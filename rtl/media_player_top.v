`include "feature_config.vh"
module media_player_top(
    input wire clk, input wire rst_n, input wire key_next, input wire key_auto,
    input wire [1:0] brightness_sw, input wire overlay_sw,
    input wire key_menu, input wire wave_sw,
    output wire [3:0] led,
    output wire HDMI_CLK_P, HDMI_D0_P, HDMI_D1_P, HDMI_D2_P,
    output wire HDMI_DDC_SCL, inout wire HDMI_DDC_SDA,
    output wire sd_ncs, sd_dclk, sd_mosi, input wire sd_miso
);
    wire sd_clk;
    EG_LOGIC_BUFG u_control_clock(.i(clk),.o(sd_clk));
    wire mem_clk, mem_clk_shift, pix_clk, serial_clk;
    wire sys_lock, video_lock, rst_sd, rst_mem, rst_pix;
    wire arst = !rst_n || !sys_lock || !video_lock;
    sys_pll u_sys_pll(.refclk(clk), .reset(1'b0), .locked(sys_lock),
        .clk0_out(), .clk1_out(mem_clk), .clk2_out(mem_clk_shift));
    video_pll u_video_pll(.refclk(clk), .reset(1'b0), .locked(video_lock),
        .clk0_out(pix_clk), .clk1_out(serial_clk));
    reset_sync u_sd_reset(sd_clk, arst, rst_sd);
    reset_sync u_mem_reset(mem_clk, arst, rst_mem);
    reset_sync u_pix_reset(pix_clk, arst, rst_pix);

    wire init_done, refreshing, busy;
    wire app_rd, app_wr, mem_valid;
    wire [20:0] rd_addr, wr_addr;
    wire [31:0] mem_data, wr_data;
    wire [3:0] wr_mask;
    wire write_req, write_ack, write_en, write_finish, write_ready;
    wire [31:0] write_data, read_data;
    wire [1:0] write_bank, pending_bank, active_bank;
    wire commit_toggle, ack_toggle, active_valid;
    wire [3:0] state_code;
    wire read_req, read_ack, read_en;
    (* ASYNC_REG = "TRUE" *) reg [1:0] read_ack_sync, write_ack_sync;
    always @(posedge pix_clk or posedge rst_pix)
        if (rst_pix) read_ack_sync <= 0;
        else read_ack_sync <= {read_ack_sync[0], read_ack};
    always @(posedge sd_clk or posedge rst_sd)
        if (rst_sd) write_ack_sync <= 0;
        else write_ack_sync <= {write_ack_sync[0], write_ack};
    reg write_toggle;
    always @(posedge mem_clk or posedge rst_mem)
        if (rst_mem) write_toggle <= 0;
        else if (write_finish) write_toggle <= ~write_toggle;

    sd_card_bmp #(.CLK_FREQ_HZ(50_000_000), .ENABLE_SCALE(`FEATURE_SCALE), .SCAN_START_SECTOR(32'd2048), .SCAN_MAX_SECTOR(32'd131071)) u_loader(
        .clk(sd_clk), .rst(rst_sd), .key_next(key_next), .key_auto(key_auto),
        .state_code(state_code), .bmp_width(16'd640), .bmp_height(16'd480),
        .display_valid(), .write_finish_toggle(write_toggle),
        .display_commit_toggle(commit_toggle), .display_ack_toggle(ack_toggle),
        .write_buf_idx(write_bank), .disp_buf_idx(pending_bank),
        .write_req(write_req), .write_req_ack(write_ack_sync[1]), .write_en(write_en), .write_ready(write_ready),
        .write_data(write_data), .SD_nCS(sd_ncs), .SD_DCLK(sd_dclk),
        .SD_MOSI(sd_mosi), .SD_MISO(sd_miso));

    wire commit_hold;
    wire [4:0] fade_gain;
    reg read_req_prev;
    always @(posedge pix_clk or posedge rst_pix)
        if(rst_pix) read_req_prev<=0;else read_req_prev<=read_req;
    transition_control #(.ENABLE(`FEATURE_TRANSITION)) u_transition(pix_clk,rst_pix,
        read_req&&!read_req_prev,active_valid,commit_toggle,ack_toggle,commit_hold,fade_gain);
    frame_commit_bridge u_commit(.clk(pix_clk), .rst(rst_pix), .commit_hold(commit_hold),
        .commit_toggle(commit_toggle), .pending_bank(pending_bank),
        .frame_request(read_req), .active_bank(active_bank),
        .active_valid(active_valid), .ack_toggle(ack_toggle));
    wire hs0, vs0, de0, hs, vs, de;
    wire [23:0] rgb;
    video_timing_data u_timing(.video_clk(pix_clk), .rst(rst_pix),
        .read_req(read_req), .read_req_ack(read_ack_sync[1]), .hs(hs0), .vs(vs0), .de(de0));
    video_delay u_delay(.video_clk(pix_clk), .rst(rst_pix),
        .read_en(read_en), .read_data(read_data[31:8]), .hs(hs0), .vs(vs0), .de(de0),
        .hs_r(hs), .vs_r(vs), .de_r(de), .vout_data(rgb));
    frame_read_write #(.BURST_SIZE(128), .WRITE_V_FLIP(1)) u_frame(
        .rst(rst_mem), .mem_clk(mem_clk), .Sdr_init_done(init_done),
        .Sdr_init_ref_vld(refreshing), .Sdr_busy(busy),
        .App_rd_en(app_rd), .App_rd_addr(rd_addr), .Sdr_rd_en(mem_valid), .Sdr_rd_dout(mem_data),
        .read_clk(pix_clk), .read_req(read_req), .read_req_ack(read_ack), .read_finish(),
        .read_addr_0(21'd0), .read_addr_1(21'd307200), .read_addr_2(21'd0), .read_addr_3(21'd0),
        .read_addr_index(active_bank), .read_len(21'd307200), .read_en(read_en), .read_data(read_data),
        .App_wr_en(app_wr), .App_wr_addr(wr_addr), .App_wr_din(wr_data), .App_wr_dm(wr_mask),
        .write_clk(sd_clk), .write_req(write_req), .write_req_ack(write_ack), .write_finish(write_finish),
        .write_addr_0(21'd0), .write_addr_1(21'd307200), .write_addr_2(21'd0), .write_addr_3(21'd0),
        .write_addr_index(write_bank), .write_len(21'd307200), .write_en(write_en), .write_data(write_data), .write_ready(write_ready));
    sdram u_sdram(.Clk(mem_clk), .Clk_sft(mem_clk_shift), .Rst(rst_mem),
        .Sdr_init_done(init_done), .Sdr_init_ref_vld(refreshing), .Sdr_busy(busy),
        .App_wr_en(app_wr), .App_wr_addr(wr_addr), .App_wr_dm(wr_mask), .App_wr_din(wr_data),
        .App_rd_en(app_rd), .App_rd_addr(rd_addr), .Sdr_rd_en(mem_valid), .Sdr_rd_dout(mem_data));

    wire fx_hs, fx_vs, fx_de;
    wire [23:0] fx_rgb;
    wire audio_valid, acr_valid;
    wire [23:0] audio_left, audio_right;
    advanced_video #(.TEXT(`FEATURE_TEXT), .COLOR(`FEATURE_COLOR), .SCOPE(`FEATURE_SCOPE),
        .TRANSITION(`FEATURE_TRANSITION)) u_effects(.clk(pix_clk), .rst(rst_pix), .hs(hs), .vs(vs), .de(de), .rgb(rgb),
        .brightness_sw(brightness_sw), .overlay_sw(overlay_sw), .image_valid(active_valid),
        .key_menu(key_menu), .wave_sw(wave_sw), .fade_gain(fade_gain), .wipe_mode(),
        .pcm_valid(audio_valid), .pcm(audio_left),
        .hs_o(fx_hs), .vs_o(fx_vs), .de_o(fx_de), .rgb_o(fx_rgb));
    wire axis_user, axis_valid, axis_last, axis_ready;
    wire [23:0] axis_data;
    video_rgb_to_axis_640x480 u_axis(.I_clk(pix_clk), .I_rst(rst_pix),
        .I_vs(fx_vs), .I_de(fx_de), .I_rgb(fx_rgb), .O_video_user(axis_user),
        .O_video_valid(axis_valid), .O_video_last(axis_last), .O_video_data(axis_data));
    wire [19:0] acr_n, acr_cts;
    pcm48_tone u_audio(.clk(pix_clk), .rst(rst_pix), .valid(audio_valid),
        .left(audio_left), .right(audio_right), .acr_valid(acr_valid), .acr_n(acr_n), .acr_cts(acr_cts));
    wire edid_trigger, hdmi_locked;
    wire [9:0] ch0, ch1, ch2, chclk;
    startup_pulse #(.CNT_MAX(20'd100000)) u_start(.I_clk(pix_clk), .I_rst(rst_pix), .O_pulse(edid_trigger));
    hdmi_1_4b_transmitter_core_wrapper #(
        .DEVICE("EG"), .HTOTAL(800), .HSA(96), .HFP(16), .HBP(48), .HACTIVE(640),
        .VTOTAL(525), .VSA(2), .VFP(10), .VBP(33), .VACTIVE(480),
        .VIDEO_VIC(1), .VIDEO_TPG("Disable"), .VIDEO_FORMAT("RGB"),
        .AUDIO_SAMPLE_RATE("48K"), .IIC_SCL_DIV(250)) u_hdmi(
        .I_pixel_clk(pix_clk), .I_rst(rst_pix), .I_edid_read_trig(edid_trigger),
        .O_edid_read_valid(), .O_edid_read_data(),
        .I_axis_s_user(axis_user), .I_axis_s_valid(axis_valid), .I_axis_s_last(axis_last),
        .I_axis_s_data(axis_data), .O_axis_s_ready(axis_ready),
        .I_audio_valid(audio_valid), .I_audio_left_data(audio_left), .I_audio_right_data(audio_right),
        .I_acr_valid(acr_valid), .I_acr_cts(acr_cts), .I_acr_n(acr_n),
        .O_video_locked(hdmi_locked), .O_ddc_scl(HDMI_DDC_SCL), .IO_ddc_sda(HDMI_DDC_SDA),
        .O_ch0_tmds_data(ch0), .O_ch1_tmds_data(ch1), .O_ch2_tmds_data(ch2), .O_clk_tmds_data(chclk));
    hdmi_phy_wrapper #(.DEVICE("EG")) u_phy(
        .I_pixel_clk(pix_clk), .I_serial_clk(serial_clk), .I_rst(rst_pix),
        .I_tmds_channel_0(ch0), .I_tmds_channel_1(ch1), .I_tmds_channel_2(ch2), .I_tmds_channel_clk(chclk),
        .O_tmds_ch0_p(HDMI_D0_P), .O_tmds_ch1_p(HDMI_D1_P), .O_tmds_ch2_p(HDMI_D2_P), .O_tmds_clk_p(HDMI_CLK_P));
    reg axis_overrun;
    always @(posedge pix_clk or posedge rst_pix)
        if (rst_pix) axis_overrun <= 0;
        else if (axis_valid && !axis_ready && hdmi_locked) axis_overrun <= 1;
    assign led = ~{axis_overrun, hdmi_locked, active_valid, init_done};
endmodule

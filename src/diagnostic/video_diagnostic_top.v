// Standalone board image. SD/Flash chip selects remain inactive throughout.
module video_diagnostic_top(
    input wire clk,input wire [3:0] keys_n,input wire [3:0] switches,
    output wire [3:0] led,
    output wire HDMI_CLK_P,HDMI_D0_P,HDMI_D1_P,HDMI_D2_P,HDMI_DDC_SCL,inout wire HDMI_DDC_SDA,
    output wire sd_ncs,sd_dclk,sd_mosi,input wire sd_miso,
    output wire flash_cs_n,flash_sck,flash_mosi,input wire flash_miso,output wire flash_wp_n,flash_hold_n
);
    wire pix_clk,serial_clk,video_lock,arst,boot_rst;
    video_pll u_vid(.refclk(clk),.reset(1'b0),.locked(video_lock),.clk0_out(pix_clk),.clk1_out(serial_clk));
    game_boot_reset boot(.clk(clk),.locked(video_lock),.arst(arst));
    reset_sync reset_pixel(pix_clk,arst,boot_rst);
    (* ASYNC_REG="TRUE" *) reg [4:0] input_meta,input_sync;
    reg dvi_mode,path_rst;
    reg [17:0] sample_count;
    reg [15:0] reset_count;
    always @(posedge pix_clk or posedge boot_rst)
        if(boot_rst)begin
            input_meta<=5'b01111;input_sync<=5'b01111;
            dvi_mode<=0;path_rst<=1;sample_count<=0;reset_count<=0;
        end else begin
            input_meta<={switches[0],keys_n};input_sync<=input_meta;
            sample_count<=sample_count+1'b1;
            if(!input_sync[3]||(&sample_count&&dvi_mode!=input_sync[4]))begin
                dvi_mode<=input_sync[4];path_rst<=1;reset_count<=0;
            end else if(!(&reset_count))reset_count<=reset_count+1'b1;
            else path_rst<=0;
        end
    wire [9:0] c0,c1,c2,cc;
    wire overflow,locked;
    video_diagnostic diagnostic(pix_clk,path_rst,dvi_mode,c0,c1,c2,cc,overflow,locked,HDMI_DDC_SCL,HDMI_DDC_SDA);
    hdmi_phy_wrapper #(.DEVICE("EG")) phy(
        .I_pixel_clk(pix_clk),.I_serial_clk(serial_clk),.I_rst(path_rst),
        .I_tmds_channel_0(c0),.I_tmds_channel_1(c1),.I_tmds_channel_2(c2),.I_tmds_channel_clk(cc),
        .O_tmds_ch0_p(HDMI_D0_P),.O_tmds_ch1_p(HDMI_D1_P),.O_tmds_ch2_p(HDMI_D2_P),.O_tmds_clk_p(HDMI_CLK_P));
    assign sd_ncs=1'b1,sd_dclk=1'b0,sd_mosi=1'b1;
    assign flash_cs_n=1'b1,flash_sck=1'b0,flash_mosi=1'b1,flash_wp_n=1'b1,flash_hold_n=1'b1;
    // LED1 observes spare pins only; LED2/3/4 are lock/path/overflow.
    assign led={overflow,dvi_mode,locked,^{input_sync[2:0],switches[3:1],sd_miso,flash_miso}};
endmodule

// Independent fixed-mode compatibility probe. Only KEY4 resets video.
module video_svga_top(
    input wire clk,input wire [3:0] keys_n,input wire [3:0] switches,
    output wire [3:0] led,
    output wire HDMI_CLK_P,HDMI_D0_P,HDMI_D1_P,HDMI_D2_P,HDMI_DDC_SCL,inout wire HDMI_DDC_SDA,
    output wire sd_ncs,sd_dclk,sd_mosi,input wire sd_miso,
    output wire flash_cs_n,flash_sck,flash_mosi,input wire flash_miso,output wire flash_wp_n,flash_hold_n
);
    wire pix_clk,serial_clk,video_lock,arst,boot_rst;
    video_svga_pll u_vid(clk,1'b0,video_lock,pix_clk,serial_clk);
    game_boot_reset boot(clk,video_lock,arst);
    reset_sync reset_pixel(pix_clk,arst,boot_rst);
    (* ASYNC_REG="TRUE" *) reg key_meta,key_sync;
    reg path_rst;
    reg [15:0] reset_count;
    always @(posedge pix_clk or posedge boot_rst)
        if(boot_rst)begin key_meta<=1;key_sync<=1;path_rst<=1;reset_count<=0;end
        else begin
            key_meta<=keys_n[3];key_sync<=key_meta;
            if(!key_sync)begin path_rst<=1;reset_count<=0;end
            else if(!(&reset_count))reset_count<=reset_count+1'b1;
            else path_rst<=0;
        end
    wire hs,vs,de;wire [23:0] rgb;wire [10:0] x;wire [9:0] y;
    video_svga_pattern pattern(pix_clk,path_rst,hs,vs,de,rgb,x,y);
    // Register color and all timing signals together before TMDS encoding.
    // This separates font/raster logic from the encoder's disparity arithmetic.
    reg hs_q,vs_q,de_q;reg [23:0] rgb_q;
    always @(posedge pix_clk or posedge path_rst)
        if(path_rst)begin hs_q<=0;vs_q<=0;de_q<=0;rgb_q<=0;end
        else begin hs_q<=hs;vs_q<=vs;de_q<=de;rgb_q<=rgb;end
    wire [9:0] c0,c1,c2;
    game_hdmi_channel #(.CHANNEL(0)) blue(pix_clk,!path_rst,de_q?3'd1:3'd0,rgb_q[7:0],4'd0,{vs_q,hs_q},c0);
    game_hdmi_channel #(.CHANNEL(1)) green(pix_clk,!path_rst,de_q?3'd1:3'd0,rgb_q[15:8],4'd0,2'b0,c1);
    game_hdmi_channel #(.CHANNEL(2)) red(pix_clk,!path_rst,de_q?3'd1:3'd0,rgb_q[23:16],4'd0,2'b0,c2);
    hdmi_phy_wrapper #(.DEVICE("EG")) phy(
        .I_pixel_clk(pix_clk),.I_serial_clk(serial_clk),.I_rst(path_rst),
        .I_tmds_channel_0(c0),.I_tmds_channel_1(c1),.I_tmds_channel_2(c2),.I_tmds_channel_clk(10'b1111100000),
        .O_tmds_ch0_p(HDMI_D0_P),.O_tmds_ch1_p(HDMI_D1_P),.O_tmds_ch2_p(HDMI_D2_P),.O_tmds_clk_p(HDMI_CLK_P));
    assign HDMI_DDC_SCL=1'b1,HDMI_DDC_SDA=1'bz;
    assign sd_ncs=1'b1,sd_dclk=1'b0,sd_mosi=1'b1;
    assign flash_cs_n=1'b1,flash_sck=1'b0,flash_mosi=1'b1,flash_wp_n=1'b1,flash_hold_n=1'b1;
    assign led={1'b0,1'b1,!path_rst,^{keys_n[2:0],switches,sd_miso,flash_miso}};
endmodule

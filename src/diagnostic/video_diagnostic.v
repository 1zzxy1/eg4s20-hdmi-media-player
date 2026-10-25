// Compare the deployed HDMI transport with DVI on identical pixels/clocks.
module video_diagnostic(
    input wire clk,rst,dvi_mode,
    output wire [9:0] c0,c1,c2,cc,
    output wire overflow,locked,
    output wire ddc_scl,inout wire ddc_sda
);
    wire hs,vs,de;wire [23:0] rgb;wire [9:0] x,y;
    video_diagnostic_pattern pattern(clk,rst,dvi_mode,hs,vs,de,rgb,x,y);
    wire [9:0] h0,h1,h2,hc,d0,d1,d2;
    wire vendor_overflow,vendor_locked;
    game_hdmi_output #(.READ_EDID(1)) hdmi(
        .clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.rgb(rgb),
        .sample_valid(1'b0),.sample_left(24'd0),.sample_right(24'd0),.acr_valid(1'b0),
        .c0(h0),.c1(h1),.c2(h2),.cc(hc),.overflow(vendor_overflow),.locked(vendor_locked),
        .ddc_scl(ddc_scl),.ddc_sda(ddc_sda));
    // Pure DVI: no AXIS FIFO, preambles, guards, InfoFrames or audio islands.
    game_hdmi_channel #(.CHANNEL(0)) blue(clk,!rst,de?3'd1:3'd0,rgb[7:0],4'd0,{vs,hs},d0);
    game_hdmi_channel #(.CHANNEL(1)) green(clk,!rst,de?3'd1:3'd0,rgb[15:8],4'd0,2'b0,d1);
    game_hdmi_channel #(.CHANNEL(2)) red(clk,!rst,de?3'd1:3'd0,rgb[23:16],4'd0,2'b0,d2);
    assign c0=dvi_mode?d0:h0,c1=dvi_mode?d1:h1,c2=dvi_mode?d2:h2;
    assign cc=dvi_mode?10'b1111100000:hc;
    assign overflow=!dvi_mode&&vendor_overflow;
    assign locked=dvi_mode?!rst:vendor_locked;
endmodule

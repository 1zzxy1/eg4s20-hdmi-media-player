// RGB888 saturating brightness and a compact status panel, no DSP or frame RAM.
// Switches are synchronized and committed only in vertical blanking.
module video_effects(
    input wire clk, input wire rst,
    input wire hs, input wire vs, input wire de,
    input wire [23:0] rgb,
    input wire [1:0] brightness_sw,
    input wire overlay_sw,
    input wire image_valid,
    output reg hs_o, output reg vs_o, output reg de_o,
    output reg [23:0] rgb_o
);
    (* ASYNC_REG = "TRUE" *) reg [2:0] sw1, sw2;
    reg [2:0] settings;
    reg de_prev, vs_prev;
    reg [9:0] x, y;
    wire [9:0] px = de_prev ? x : 10'd0;
    function [7:0] adjust;
        input [7:0] c;
        input [1:0] mode;
        begin
            case(mode)
                0: adjust = c;
                1: adjust = (c > 223) ? 255 : c + 8'd32;
                2: adjust = (c > 191) ? 255 : c + 8'd64;
                3: adjust = (c < 32) ? 0 : c - 8'd32;
            endcase
        end
    endfunction
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sw1 <= 0; sw2 <= 0; settings <= 0;
            x <= 0; y <= 0; de_prev <= 0; vs_prev <= 0;
            hs_o <= 0; vs_o <= 0; de_o <= 0; rgb_o <= 0;
        end else begin
            sw1 <= {overlay_sw, brightness_sw}; sw2 <= sw1;
            de_prev <= de; vs_prev <= vs;
            if (vs && !vs_prev) begin y <= 0; settings <= sw2; end
            else if (de_prev && !de) y <= y + 1'b1;
            if (de) x <= px + 1'b1;
            else x <= 0;
            hs_o <= hs; vs_o <= vs; de_o <= de;
            rgb_o <= de && image_valid ?
                {adjust(rgb[23:16], settings[1:0]), adjust(rgb[15:8], settings[1:0]),
                 adjust(rgb[7:0], settings[1:0])} : 24'd0;
            // Green: committed frame; amber: waiting for a frame.
            // Four bars encode brightness mode; screen content stays static per frame.
            if (de && settings[2] && y >= 8 && y < 24 && px >= 8 && px < 88)
                if (px < 24) rgb_o <= image_valid ? 24'h00c040 : 24'hff8000;
                else if (px[3:0] < 12)
                    rgb_o <= ((px - 24) >> 4) <= settings[1:0] ? 24'hffffff : 24'h303030;
                else rgb_o <= 24'h101010;
        end
    end
endmodule

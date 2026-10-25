// Exact average 48 kHz from 25 MHz: intervals of 520/521 pixel clocks.
// PCM and ACR stay in the pixel domain; no audio PLL or I2S round trip.
module pcm48_tone(
    input wire clk, input wire rst,
    output reg valid, output reg [23:0] left, output reg [23:0] right,
    output reg acr_valid, output wire [19:0] acr_n, output wire [19:0] acr_cts
);
    reg [24:0] sample_acc;
    reg [5:0] sample_number;
    reg [5:0] acr_count;
    wire [25:0] next_acc = {1'b0, sample_acc} + 26'd48000;
    assign acr_n = 20'd6144;
    assign acr_cts = 20'd25000; // 25 MHz * 6144 / (128 * 48 kHz)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sample_acc <= 0; sample_number <= 0; acr_count <= 0;
            valid <= 0; left <= 0; right <= 0; acr_valid <= 0;
        end else begin
            valid <= 0; acr_valid <= 0;
            if (next_acc >= 26'd25000000) begin
                sample_acc <= next_acc - 26'd25000000;
                valid <= 1;
                // 1 kHz stereo square wave, -18 dBFS approximately.
                left <= (sample_number < 24) ? 24'h100000 : 24'hf00000;
                right <= (sample_number < 24) ? 24'h100000 : 24'hf00000;
                sample_number <= (sample_number == 47) ? 0 : sample_number + 1'b1;
                if (acr_count == 47) begin acr_count <= 0; acr_valid <= 1; end
                else acr_count <= acr_count + 1'b1;
            end else sample_acc <= next_acc[24:0];
        end
    end
endmodule

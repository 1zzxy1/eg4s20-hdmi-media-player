// Two complete sample windows; never read the bank being captured.
module audio_scope # (parameter SAMPLES=64)(
    input wire clk,rst,frame_tick,pcm_valid,
    input wire signed [23:0] pcm,
    input wire [5:0] sample_index,
    output wire signed [7:0] sample,
    output reg [7:0] peak, output reg valid
);
    reg signed [7:0] samples[0:2*SAMPLES-1];
    reg display_bank, full;
    reg [5:0] count;
    reg [7:0] collecting_peak;
    wire signed [7:0] value=pcm[23:16];
    wire [7:0] magnitude=value[7] ? (~value+8'd1) : value;
    // Separate memory write process, no bulk reset (BRAM/distributed RAM inference).
    always @(posedge clk) if(!rst && pcm_valid && !full)
        samples[{!display_bank,count}]<=value;
    assign sample=valid ? samples[{display_bank,sample_index}] : 8'sd0;
    always @(posedge clk or posedge rst) begin
        if(rst) begin display_bank<=0;full<=0;count<=0;collecting_peak<=0;peak<=0;valid<=0;end
        else if(full && frame_tick) begin
            display_bank<=!display_bank;peak<=collecting_peak;valid<=1;
            full<=0;count<=0;collecting_peak<=0;
        end else if(pcm_valid && !full) begin
            if(magnitude>collecting_peak) collecting_peak<=magnitude;
            if(count==SAMPLES-1) full<=1;else count<=count+1'b1;
        end
    end
endmodule

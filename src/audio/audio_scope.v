// Two complete sample windows; never read the bank being captured.
module audio_scope # (parameter SAMPLES=64, REGISTERED_READ=0)(
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
    generate if(REGISTERED_READ)begin:registered_read
        // The video caller supplies the address one pixel stage early, so a
        // synchronous RAM port saves logic without shifting the plotted trace.
        reg signed [7:0] sample_q;
        always @(posedge clk)sample_q<=samples[{display_bank,sample_index}];
        assign sample=valid?sample_q:8'sd0;
    end else begin:combinational_read
        assign sample=valid?samples[{display_bank,sample_index}]:8'sd0;
    end endgenerate
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

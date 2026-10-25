// Stretch menu transactions for the legacy 20 ms debouncers and CDC.
module menu_media_controls #(
    parameter integer CLOCK_HZ=25_000_000,
    parameter integer SHORT_CYCLES=CLOCK_HZ/40,
    parameter integer LONG_CYCLES=CLOCK_HZ+CLOCK_HZ/10
)(input wire clk,rst,auto_action,next_action,previous_action,effect_action,contrast_action,
  output wire auto_key_n,next_key_n,previous_key_n,effect_key_n);
    localparam W=$clog2(LONG_CYCLES+1);
    reg [W-1:0] ca,cn,cp,ce;
    assign auto_key_n=ca==0;
    assign next_key_n=cn==0;
    assign previous_key_n=cp==0;
    assign effect_key_n=ce==0;
    always @(posedge clk or posedge rst)
        if(rst) begin ca<=0;cn<=0;cp<=0;ce<=0;end
        else begin
            if(ca!=0) ca<=ca-1'b1;
            if(cn!=0) cn<=cn-1'b1;
            if(cp!=0) cp<=cp-1'b1;
            if(ce!=0) ce<=ce-1'b1;
            if(auto_action&&ca==0) ca<=SHORT_CYCLES;
            if(next_action&&cn==0) cn<=SHORT_CYCLES;
            if(previous_action&&cp==0) cp<=SHORT_CYCLES;
            if(ce==0) begin
                if(effect_action) ce<=LONG_CYCLES;
                else if(contrast_action) ce<=SHORT_CYCLES;
            end
        end
endmodule

// KEY3: short release requests autoplay; long release toggles HDMI sound.
// The active-low pulse feeds the existing SD-domain debouncer (>20 ms).
module audio_controls #(
    parameter CLOCK_HZ=25_000_000,
    parameter DEBOUNCE=CLOCK_HZ/50,
    parameter LONG_PRESS=CLOCK_HZ,
    parameter AUTO_PULSE=CLOCK_HZ/40
)(
    input wire clk,rst,key_auto,
    output wire auto_key_n,
    output reg audio_enabled
);
    (* ASYNC_REG="TRUE" *) reg [1:0] sync_key;
    reg stable;
    reg [$clog2(DEBOUNCE+1)-1:0] debounce;
    reg [$clog2(LONG_PRESS+1)-1:0] duration;
    reg [$clog2(AUTO_PULSE+1)-1:0] pulse_left;
    assign auto_key_n=(pulse_left==0);
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            sync_key<=2'b11;stable<=1;debounce<=0;duration<=0;
            pulse_left<=0;audio_enabled<=0;
        end else begin
            sync_key<={sync_key[0],key_auto};
            if(pulse_left!=0) pulse_left<=pulse_left-1'b1;
            if(!stable && duration<LONG_PRESS) duration<=duration+1'b1;
            if(sync_key[1]==stable) debounce<=0;
            else if(debounce==DEBOUNCE-1) begin
                debounce<=0;stable<=sync_key[1];
                if(!sync_key[1]) duration<=0;
                else if(duration>=LONG_PRESS) audio_enabled<=!audio_enabled;
                else pulse_left<=AUTO_PULSE;
            end else debounce<=debounce+1'b1;
        end
    end
endmodule

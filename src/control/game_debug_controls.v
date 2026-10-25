// Debug gestures are queued between frames. Legacy controls receive complete
// active-low presses; no pulse crosses into the SD domain without stretching.
module game_debug_controls #(
    parameter integer CLOCK_HZ=25000000,
    parameter integer SHORT_CYCLES=CLOCK_HZ/40,
    parameter integer LONG_CYCLES=CLOCK_HZ+CLOCK_HZ/10
)(input wire clk,rst,frame_tick,debug_mode,
    input wire back_press,left_press,right_press,jump_short,jump_long,
    input wire held_left,held_right,
    output reg media_fullscreen,test_tone,
    output reg [1:0] brightness,
    output wire auto_key_n,effect_key_n,next_key_n,previous_key_n);
    localparam CW=$clog2(LONG_CYCLES+1);
    reg [CW-1:0] auto_count,effect_count,next_count,previous_count;
    reg both_d;
    reg p_back,p_tone,p_bright,p_auto,p_effect_long,p_contrast;
    wire both=held_left&&held_right;
    wire tone_edge=both&&!both_d;
    assign auto_key_n=(auto_count==0);
    assign effect_key_n=(effect_count==0);
    assign next_key_n=(next_count==0);
    assign previous_key_n=(previous_count==0);
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            media_fullscreen<=1;test_tone<=0;brightness<=0;
            auto_count<=0;effect_count<=0;both_d<=0;
            next_count<=0;previous_count<=0;
            p_back<=0;p_tone<=0;p_bright<=0;p_auto<=0;p_effect_long<=0;p_contrast<=0;
        end else begin
            both_d<=both;
            if(auto_count!=0)auto_count<=auto_count-1'b1;
            if(effect_count!=0)effect_count<=effect_count-1'b1;
            if(next_count!=0)next_count<=next_count-1'b1;
            if(previous_count!=0)previous_count<=previous_count-1'b1;
            if(debug_mode&&!both) begin
                if(right_press) next_count<=SHORT_CYCLES;
                if(left_press) previous_count<=SHORT_CYCLES;
            end
            if(!debug_mode) begin
                test_tone<=0;auto_count<=0;effect_count<=0;next_count<=0;previous_count<=0;
                p_back<=0;p_tone<=0;p_bright<=0;p_auto<=0;p_effect_long<=0;p_contrast<=0;
            end else if(frame_tick) begin
                p_back<=0;p_tone<=0;p_bright<=0;p_auto<=0;p_effect_long<=0;p_contrast<=0;
                if(p_back||back_press)media_fullscreen<=!media_fullscreen;
                if(p_tone||tone_edge)test_tone<=!test_tone;
                if(p_bright||(jump_short&&both))brightness<=brightness+1'b1;
                if((p_auto||(jump_short&&!both)) && auto_count==0)auto_count<=SHORT_CYCLES;
                if(effect_count==0) begin
                    if(p_effect_long||(jump_long&&!both))effect_count<=LONG_CYCLES;
                    else if(p_contrast||(jump_long&&both))effect_count<=SHORT_CYCLES;
                end
            end else begin
                if(back_press)p_back<=1;
                if(tone_edge)p_tone<=1;
                if(jump_short)begin if(both)p_bright<=1;else p_auto<=1;end
                if(jump_long)begin if(both)p_contrast<=1;else p_effect_long<=1;end
            end
        end
    end
endmodule

module video_controls #(parameter CLOCK_HZ=25_000_000, DEBOUNCE=500_000, LONG_PRESS=25_000_000, DIRECT=0)(
    input wire clk,rst,frame_tick,key_menu,
    input wire [1:0] brightness_sw,input wire overlay_sw,wave_sw,
    output reg [1:0] brightness,contrast,
    output reg overlay,wave,
    output reg [1:0] transition_mode,
    output reg [15:0] timestamp,
    input wire [1:0] control_contrast,control_transition
);
    (* ASYNC_REG="TRUE" *) reg [4:0] s1,s2;
    reg key_stable;
    reg [$clog2(DEBOUNCE+1)-1:0] debounce;
    reg [$clog2(LONG_PRESS+1)-1:0] duration;
    reg [1:0] contrast_next;
    reg [1:0] mode_next;
    reg [$clog2(CLOCK_HZ+1)-1:0] seconds;
    reg [15:0] bcd;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            s1<=5'b10000;s2<=5'b10000;key_stable<=1;debounce<=0;duration<=0;
            contrast_next<=0;mode_next<=0;brightness<=0;contrast<=0;
            overlay<=0;wave<=0;transition_mode<=0;seconds<=0;bcd<=0;timestamp<=0;
        end else begin
            s1<={key_menu,wave_sw,overlay_sw,brightness_sw};s2<=s1;
            if(!DIRECT && !key_stable && duration<LONG_PRESS) duration<=duration+1'b1;
            if(DIRECT || s2[4]==key_stable) debounce<=0;
            else if(debounce==DEBOUNCE-1) begin
                debounce<=0;key_stable<=s2[4];
                if(!s2[4]) duration<=0;
                else if(duration>=LONG_PRESS) mode_next<=mode_next==2 ? 0 : mode_next+1'b1;
                else contrast_next<=contrast_next+1'b1;
            end else debounce<=debounce+1'b1;
            if(seconds==CLOCK_HZ-1) begin
                seconds<=0;
                if(bcd[3:0]!=9) bcd[3:0]<=bcd[3:0]+1'b1;
                else begin bcd[3:0]<=0;
                    if(bcd[7:4]!=5) bcd[7:4]<=bcd[7:4]+1'b1;
                    else begin bcd[7:4]<=0;
                        if(bcd[11:8]!=9) bcd[11:8]<=bcd[11:8]+1'b1;
                        else begin bcd[11:8]<=0;
                            if(bcd[15:12]!=9) bcd[15:12]<=bcd[15:12]+1'b1;
                            else bcd[15:12]<=0;
                        end
                    end
                end
            end else seconds<=seconds+1'b1;
            if(frame_tick) begin
                brightness<=s2[1:0];overlay<=s2[2];wave<=s2[3];
                contrast<=DIRECT?control_contrast:contrast_next;
                transition_mode<=DIRECT?control_transition:mode_next;timestamp<=bcd;
            end
        end
    end
endmodule

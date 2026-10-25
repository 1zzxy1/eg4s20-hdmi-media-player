// Debounced board inputs. KEY3/KEY1 move, KEY2 jumps, SW4 runs/fires.
module game_inputs #(
    parameter integer CLOCK_HZ=25_000_000,
    parameter integer DEBOUNCE=CLOCK_HZ/200,
    parameter integer LONG_PRESS=CLOCK_HZ
)(
    input wire clk,rst,frame_tick,
    input wire [3:0] keys_n,switches,
    input wire gameplay_active,debug_mode,
    output wire held_left,held_right,jump_hold,held_run,held_down,
    output reg left_press,right_press,jump_press,jump_short,jump_long,
    output reg back_press,reset_game,sound_toggle,
    output reg [3:0] frame_switches,
    output wire key_left_held,key_right_held,
    output reg switches_armed
);
    (* ASYNC_REG="TRUE" *) reg [7:0] sync0,sync1;
    reg [7:0] stable;
    localparam DBW=(DEBOUNCE<2)?1:$clog2(DEBOUNCE+1);
    localparam LPW=(LONG_PRESS<2)?1:$clog2(LONG_PRESS+1);
    reg [DBW-1:0] debounce[0:7];
    reg [LPW-1:0] confirm_count;
    reg confirm_used,mode_d,jump_d;
    reg [3:0] blocked;
    wire in_game=(gameplay_active===1'b1)&&!(debug_mode===1'b1);
    wire [3:0] key_stable=stable[3:0];
    wire [3:0] sw_stable=stable[7:4];
    wire enabled=in_game&&switches_armed;
    assign key_left_held=!key_stable[1]&&!blocked[1];
    assign key_right_held=!key_stable[2]&&!blocked[2];
    assign held_left=in_game ? enabled&&!key_stable[2]&&!blocked[2] : key_left_held;
    assign held_right=in_game ? enabled&&!key_stable[0]&&!blocked[0] : key_right_held;
    assign jump_hold=enabled&&!key_stable[1]&&!blocked[1];
    assign held_run=enabled&&frame_switches[3];
    assign held_down=held_left&&held_right&&in_game;
    integer i;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            sync0<=8'h0f;sync1<=8'h0f;stable<=8'h0f;
            for(i=0;i<8;i=i+1) debounce[i]<=0;
            frame_switches<=0;switches_armed<=0;mode_d<=0;jump_d<=0;blocked<=0;
            confirm_count<=0;confirm_used<=1;
            left_press<=0;right_press<=0;jump_press<=0;jump_short<=0;jump_long<=0;
            back_press<=0;reset_game<=0;sound_toggle<=0;
        end else begin
            sync0<={switches,keys_n};sync1<=sync0;
            left_press<=0;right_press<=0;jump_press<=0;jump_short<=0;jump_long<=0;
            back_press<=0;reset_game<=0;sound_toggle<=0;mode_d<=in_game;
            if(!in_game || mode_d!=in_game) begin
                switches_armed<=0;jump_d<=0;
            end else if(frame_tick) begin
                // Debug switches may remain on. Only released action keys arm play.
                if(!switches_armed && key_stable[2:0]==3'b111) switches_armed<=1;
                jump_d<=jump_hold;
                if(jump_hold&&!jump_d) jump_press<=1;
            end
            if(frame_tick) frame_switches<=sw_stable;
            if(mode_d!=in_game) begin blocked<=blocked|~key_stable;confirm_used<=1;end
            if(!key_stable[3]&&!confirm_used&&!blocked[3]) begin
                if(confirm_count>=LONG_PRESS-1) begin jump_long<=1;confirm_used<=1;end
                else confirm_count<=confirm_count+1'b1;
            end
            for(i=0;i<8;i=i+1) begin
                if(sync1[i]==stable[i]) debounce[i]<=0;
                else if(debounce[i]>=DEBOUNCE-1) begin
                    stable[i]<=sync1[i];debounce[i]<=0;
                    if(i<4) begin
                        if(sync1[i]) begin
                            blocked[i]<=0;
                            if(!blocked[i]&&mode_d==in_game) begin
                                if(i==0&&!in_game) back_press<=1;
                                if(i==3&&!confirm_used) jump_short<=1;
                            end
                        end else if(!blocked[i]&&mode_d==in_game) begin
                            case(i)
                                1:if(!in_game) left_press<=1;
                                2:if(!in_game) right_press<=1;
                                3:begin
                                    confirm_count<=0;confirm_used<=0;
                                    if(!in_game) jump_press<=1;
                                end
                            endcase
                        end
                    end
                end else debounce[i]<=debounce[i]+1'b1;
            end
        end
    end
endmodule

// Frame-boundary controls for a sink that cyclically shifts active columns.
// No timing, audio, framebuffer, or persistent Flash state is changed.
module game_display_alignment #(
    parameter [9:0] DEFAULT_OFFSET=10'd128
)(
    input wire clk,rst,frame_tick,
    input wire [3:0] keys_n,switches,
    output reg active,
    output wire block_controls,
    output reg [9:0] offset
);
    (* ASYNC_REG="TRUE" *) reg [4:0] sync0,sync1;
    reg [4:0] previous,stable;
    reg [3:0] old_keys;
    reg armed;
    reg [4:0] repeat_count;
    wire [3:0] pressed=old_keys&~stable[3:0];
    wire left_down=!stable[2],right_down=!stable[0];
    wire [9:0] step=stable[1]?10'd1:10'd16;
    wire [10:0] sum={1'b0,offset}+step;
    assign block_controls=active||!armed;
    always @(posedge clk or posedge rst) begin
        if(rst)begin
            sync0<=5'b01111;sync1<=5'b01111;previous<=5'b01111;stable<=5'b01111;
            old_keys<=4'hf;active<=0;armed<=0;repeat_count<=0;offset<=DEFAULT_OFFSET;
        end else begin
            sync0<={switches[2],keys_n};sync1<=sync0;
            if(frame_tick)begin
                previous<=sync1;
                if(previous==sync1)stable<=sync1;
                active<=stable[4];old_keys<=stable[3:0];
                if(stable[4]!=active)begin armed<=0;repeat_count<=0;end
                else if(!armed)begin
                    // A key held across either mode transition must be released.
                    if(stable[3:0]==4'hf&&sync1[3:0]==4'hf)armed<=1;
                end else if(active)begin
                    if(pressed[3])begin offset<=0;repeat_count<=0;end
                    else if(left_down!=right_down)begin
                        if(pressed[2]||pressed[0]||repeat_count==1)begin
                            // Increasing source X moves the displayed image left.
                            if(left_down)offset<=sum>=640?sum-11'd640:sum[9:0];
                            else offset<=offset<step?offset+10'd640-step:offset-step;
                            repeat_count<=(pressed[2]||pressed[0])?5'd18:5'd3;
                        end else if(repeat_count!=0)repeat_count<=repeat_count-1'b1;
                    end else repeat_count<=0;
                end
            end
        end
    end
endmodule

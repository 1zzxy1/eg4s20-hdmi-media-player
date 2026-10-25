// Two bounded world-space reward slots; no extra texture or font memory.
module game_reward_fx(
    input wire clk,rst,frame_tick,paused,clear,
    input wire reward_valid,input wire [3:0] reward_kind,
    input wire [11:0] reward_x,input wire [8:0] reward_y,
    input wire [11:0] world_x,input wire [8:0] world_y,
    output reg coin_on,output reg [3:0] coin_u,coin_v,
    output reg text_on,output reg [7:0] text_char,
    output reg [2:0] text_row,text_col
);
    // kind: 0 coin then 200, 1 200, 2 1000, 3 1UP, 4 50,
    //       5 100, 6 400, 7 800, 8 2000, 9 5000.
    reg [5:0] age [0:1];
    reg [8:0] origin_y [0:1];
    reg [11:0] draw_x [0:1];
    reg [8:0] draw_y [0:1];
    reg [31:0] label [0:1];
    reg [1:0] last_char [0:1];
    reg [1:0] is_coin,update_pending;
    reg [1:0] active;
    reg replace_slot;
    wire insert_slot=!active[0]?1'b0:!active[1]?1'b1:replace_slot;
    integer slot;
    wire update_slot=!update_pending[0];
    wire [5:0] next_age=age[update_slot]+1'b1;
    wire [5:0] next_lift=is_coin[update_slot]?
        (next_age<24?coin_lift(next_age[4:0]):6'd32+((next_age-6'd24)>>1)):
        6'd8+(next_age>>1);
    wire [3:0] label_inset=(reward_kind==2||reward_kind>=8)?8:reward_kind==4?0:4;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            active<=0;replace_slot<=0;is_coin<=0;update_pending<=0;
            for(integer n=0;n<2;n=n+1) begin
                age[n]<=0;origin_y[n]<=0;draw_x[n]<=0;draw_y[n]<=0;
                label[n]<=0;last_char[n]<=0;
            end
        end else if(clear) begin
            active<=0;replace_slot<=0;update_pending<=0;
        end else begin
            // Share the trajectory arithmetic across the two slots during
            // vertical blanking, rather than duplicating it in the pixel path.
            if(frame_tick&&!paused) begin
                update_pending<=active;
            end else if(update_pending!=0) begin
                update_pending[update_slot]<=0;
                if(age[update_slot]==(is_coin[update_slot]?6'd47:6'd39))active[update_slot]<=0;
                else begin
                    age[update_slot]<=next_age;
                    draw_y[update_slot]<=origin_y[update_slot]>next_lift?
                        origin_y[update_slot]-next_lift:9'd0;
                    if(is_coin[update_slot]&&next_age==24)
                        draw_x[update_slot]<=draw_x[update_slot]>4?draw_x[update_slot]-12'd4:12'd0;
                end
            end
            // Pulses arrive after the frame's serial physics. Insertion wins
            // over expiry on the same clock, and does not depend on frame_tick.
            if(reward_valid===1'b1) begin
                active[insert_slot]<=1;age[insert_slot]<=0;
                update_pending[insert_slot]<=0;
                is_coin[insert_slot]<=reward_kind==0;
                origin_y[insert_slot]<=reward_y;
                draw_x[insert_slot]<=reward_kind==0?reward_x:
                    reward_x>label_inset?reward_x-label_inset:12'd0;
                draw_y[insert_slot]<=reward_kind==0?
                    (reward_y>16?reward_y-9'd16:9'd0):(reward_y>8?reward_y-9'd8:9'd0);
                last_char[insert_slot]<=(reward_kind==2||reward_kind>=8)?3:reward_kind==4?1:2;
                case(reward_kind)
                    0,1:label[insert_slot]<="200 ";
                    2:label[insert_slot]<="1000";
                    3:label[insert_slot]<="1UP ";
                    4:label[insert_slot]<="50  ";
                    5:label[insert_slot]<="100 ";
                    6:label[insert_slot]<="400 ";
                    7:label[insert_slot]<="800 ";
                    8:label[insert_slot]<="2000";
                    default:label[insert_slot]<="5000";
                endcase
                replace_slot<=!insert_slot;
            end
        end
    end
    function [5:0] coin_lift(input [4:0] t);
        begin case(t)
            0:coin_lift=16;1:coin_lift=20;2:coin_lift=24;3:coin_lift=28;
            4:coin_lift=31;5:coin_lift=34;6:coin_lift=37;7:coin_lift=39;
            8:coin_lift=41;9:coin_lift=42;10:coin_lift=43;
            11,12:coin_lift=44;13:coin_lift=43;14:coin_lift=42;
            15:coin_lift=41;16:coin_lift=39;17:coin_lift=37;18:coin_lift=34;
            19:coin_lift=31;20:coin_lift=28;21:coin_lift=24;
            22:coin_lift=20;default:coin_lift=16;
        endcase end
    endfunction
    reg slot_coin;
    reg [12:0] dx;
    reg [9:0] dy;
    always @* begin
        coin_on=0;coin_u=0;coin_v=0;
        text_on=0;text_char=" ";text_row=0;text_col=0;
        dx=0;dy=0;slot_coin=0;
        for(slot=0;slot<2;slot=slot+1) if(active[slot]) begin
            slot_coin=0;
            dx={1'b0,world_x}-{1'b0,draw_x[slot]};
            dy={1'b0,world_y}-{1'b0,draw_y[slot]};
            if(is_coin[slot]&&age[slot]<24) begin
                if(dx[12:4]==0&&dy[9:4]==0) begin
                    case(age[slot][2:1])
                        0:begin slot_coin=1;coin_u=dx[3:0];end
                        1,3:if(dx[3:0]>=4&&dx[3:0]<12)begin slot_coin=1;coin_u=(dx[3:0]-4'd4)<<1;end
                        2:if(dx[3:0]>=6&&dx[3:0]<10)begin slot_coin=1;coin_u=(dx[3:0]-4'd6)<<2;end
                    endcase
                    if(slot_coin)begin coin_on=1;coin_v=dy[3:0];end
                end
            end else begin
                if(dx[12:5]==0&&dx[4:3]<=last_char[slot]&&dy[9:3]==0) begin
                    text_on=1;
                    case(dx[4:3])
                        0:text_char=label[slot][31:24];1:text_char=label[slot][23:16];
                        2:text_char=label[slot][15:8];3:text_char=label[slot][7:0];
                    endcase
                    text_col=dx[2:0];text_row=dy[2:0];
                end
            end
        end
    end
endmodule

// Share one binary-to-BCD datapath among five slowly changing HUD fields.
// A full round takes 125 clocks, less than the left raster margin of the
// leaderboard score field. Each result is published atomically.
module game_hud_decimal(input wire clk,rst,
    input wire [23:0] score,rank_score,input wire [8:0] seconds_left,
    input wire [7:0] coins_count,input wire [15:0] rank_time,
    output reg [23:0] score_bcd,rank_score_bcd,
    output reg [11:0] seconds_bcd,output reg [7:0] coins_bcd,
    output reg [19:0] rank_time_bcd);
    reg [23:0] bits,work,adjusted;
    reg [4:0] remaining;
    reg [2:0] field;
    wire [23:0] shifted={adjusted[22:0],bits[23]};
    integer i;
    always @* begin
        adjusted=work;
        for(i=0;i<6;i=i+1)
            if(work[i*4+:4]>=5)adjusted[i*4+:4]=work[i*4+:4]+4'd3;
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            bits<=0;work<=0;remaining<=0;field<=0;
            score_bcd<=0;rank_score_bcd<=0;seconds_bcd<=0;coins_bcd<=0;rank_time_bcd<=0;
        end else if(remaining==0)begin
            case(field)
                0:bits<=score;1:bits<=rank_score;2:bits<={15'd0,seconds_left};
                3:bits<={16'd0,coins_count};default:bits<={8'd0,rank_time};
            endcase
            work<=0;remaining<=24;
        end else begin
            work<=shifted;bits<={bits[22:0],1'b0};remaining<=remaining-1'b1;
            if(remaining==1)begin
                case(field)
                    0:score_bcd<=shifted;1:rank_score_bcd<=shifted;
                    2:seconds_bcd<=shifted[11:0];3:coins_bcd<=shifted[7:0];
                    default:rank_time_bcd<=shifted[19:0];
                endcase
                field<=field==4?0:field+1'b1;
            end
        end
    end
endmodule

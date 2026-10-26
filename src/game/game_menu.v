// Boot lobby only: switches select labs; KEY1 changes, KEY2/3 select.
// KEY4 always leaves the lobby for name/avatar entry, even with switches on.
module game_menu(input wire clk,rst,frame_tick,
    input wire [2:0] game_state,
    input wire [3:0] switches,
    input wire back_press,left_press,right_press,confirm,confirm_long,
    output wire active,debug_mode,
    output wire [2:0] page,output reg [2:0] selection,
    output reg view_narrow,palette_mode,output wire osd_enable,calibration,
    output reg audio_enabled,test_tone,
    output reg [1:0] brightness,master_volume,bgm_volume,sfx_volume,
    output reg [1:0] contrast,transition_mode,
    output wire media_fullscreen,
    output reg auto_action,next_action,previous_action,effect_action,contrast_action,
    output wire reset_game,output reg profile_request,output wire scores_request,
    output reg audition,output reg [4:0] audition_id);
    reg pb,pl,pr,pc;
    reg [2:0] page_d;
    reg pattern;
    wire b=pb||back_press,l=pl||left_press,r=pr||right_press,c=pc||confirm;
    wire lobby=game_state==0;
    assign active=lobby&&(|switches);
    assign page=switches[3]?3'd3:switches[2]?3'd2:3'd1;
    assign debug_mode=active;
    assign osd_enable=(lobby||game_state==2||game_state==6||game_state==7)&&switches[1];
    assign calibration=lobby&&pattern;
    assign media_fullscreen=debug_mode;
    assign reset_game=1'b0;
    assign scores_request=1'b0;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            selection<=0;page_d<=1;pb<=0;pl<=0;pr<=0;pc<=0;
            view_narrow<=0;palette_mode<=0;pattern<=0;
            audio_enabled<=1;test_tone<=0;brightness<=0;contrast<=0;transition_mode<=0;master_volume<=3;bgm_volume<=2;sfx_volume<=3;
            audition_id<=1;profile_request<=0;audition<=0;
            auto_action<=0;next_action<=0;previous_action<=0;effect_action<=0;contrast_action<=0;
        end else begin
            auto_action<=0;next_action<=0;previous_action<=0;effect_action<=0;contrast_action<=0;
            profile_request<=0;audition<=0;
            if(!lobby) begin pb<=0;pl<=0;pr<=0;pc<=0;pattern<=0;test_tone<=0;end
            else if(frame_tick) begin
                pb<=0;pl<=0;pr<=0;pc<=0;page_d<=page;
                if(c) begin profile_request<=1;pattern<=0;test_tone<=0;end
                else if(page!=page_d) selection<=0;
                else if(active) begin
                    if(page==1) begin
                        if(switches[0]) begin
                            if(l) previous_action<=1;
                            if(r) next_action<=1;
                            if(b) auto_action<=1;
                        end
                    end else begin
                        if(l) selection<=selection==0?3'd6:selection-1'b1;
                        else if(r) selection<=selection==6?3'd0:selection+1'b1;
                        if(b) begin
                            if(page==2) case(selection)
                                0:view_narrow<=!view_narrow;
                                1:palette_mode<=!palette_mode;
                                2:pattern<=!pattern;
                                3:brightness<=brightness+1'b1;
                                4:begin contrast<=contrast+1'b1;contrast_action<=1;end
                                5:begin transition_mode<=transition_mode==2?0:transition_mode+1'b1;effect_action<=1;end
                                6:begin view_narrow<=0;palette_mode<=0;brightness<=0;pattern<=0;contrast<=0;transition_mode<=0;end
                            endcase
                            else case(selection)
                                0:audio_enabled<=!audio_enabled;
                                1:master_volume<=master_volume+1'b1;
                                2:bgm_volume<=bgm_volume+1'b1;
                                3:sfx_volume<=sfx_volume+1'b1;
                                4:audition_id<=audition_id==23?1:audition_id+1'b1;
                                5:audition<=1;
                                6:begin test_tone<=!test_tone;audio_enabled<=1;end
                            endcase
                        end
                    end
                end
            end else begin
                if(back_press)pb<=1;if(left_press)pl<=1;if(right_press)pr<=1;if(confirm)pc<=1;
            end
        end
    end
endmodule

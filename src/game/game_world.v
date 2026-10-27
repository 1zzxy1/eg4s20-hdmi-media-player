// Frame-stepped 1-1 ground course. Map probes share one synchronous RAM port.
module game_world(
    input wire clk,rst,frame_tick,assets_loaded,
    input wire held_left,held_right,jump_press,jump_hold,back_press,
    input wire held_run,held_down,debug_mode,view_narrow,
    input wire profile_request,scores_request,
    input wire quick_start,
    input wire map_ready,input wire [7:0] map_data,
    output reg map_reload,output reg [11:0] map_addr,
    output reg map_we,output reg [7:0] map_wdata,
    output reg [2:0] state,
    output wire [11:0] player_x,output wire [8:0] player_y,
    output reg [11:0] camera_x,output reg facing_left,
    output reg [1:0] anim,
    output wire [11:0] enemy0_x,enemy1_x,
    output wire [1:0] enemy_alive,
    output reg [47:0] enemy_x,
    output reg [35:0] enemy_y,
    output reg [7:0] enemy_kind,
    output reg [3:0] enemy_active,
    output reg [7:0] coin_mask,output reg [23:0] score,
    output reg [8:0] seconds_left,output reg [3:0] lives,
    output reg [7:0] coins_count,
    output reg [47:0] player_name,output reg [2:0] avatar,profile_cursor,
    output reg submit,output reg [15:0] elapsed_seconds,
    output reg [3:0] event_code,output reg event_valid,
    output wire playing,paused,death_active,
    output wire powerup_active,output wire [11:0] powerup_x,
    output wire [8:0] powerup_y,output wire [1:0] powerup_kind,
    output wire super_mario,output reg player_crouch,
    output reg fire_mario,output reg [1:0] fireball_active,
    output reg [23:0] fireball_x,output reg [17:0] fireball_y,
    output reg [1:0] flag_phase,output reg [8:0] flag_y,
    output reg [11:0] block_fx_addr,output reg [4:0] block_fx_frames,
    output reg [1:0] block_fx_kind,
    output wire player_blink,player_star,output reg [4:0] transform_frames,
    output reg reward_valid,output reg [3:0] reward_kind,
    output reg [11:0] reward_x,output reg [8:0] reward_y
);
    localparam TITLE=0,PROFILE=1,PLAY=2,DEAD=3,CLEAR=4,LEADERBOARD=5,
               FLAG=6,CASTLE=7;
    localparam AIR=0,GROUND=1,BRICK=2,Q_COIN=3,Q_POWER=4,USED=5,
               STONE=6,PIPE_TL=7,PIPE_TR=8,PIPE_BL=9,PIPE_BR=10,
               HIDDEN_1UP=11,BRICK_COIN=12,BRICK_STAR=13,BRICK_POWER=14;
    localparam IDLE=0,H_ADDR=1,H_WAIT=2,H_WAIT2=3,H_USE=4,V_ADDR=5,V_WAIT=6,V_WAIT2=7,
               V_USE=8,ENTITY_ADDR=9,ENTITY_WAIT=10,ENTITY_WAIT2=11,ENTITY_USE=12,
               COMMIT=13,WAIT_MAP=14,CONTACT=15,
               STAND_ADDR=16,STAND_WAIT=17,STAND_WAIT2=18,STAND_USE=19,
               PICKUP=20,FIRE_STEP=21,FINISH=22;
    localparam [11:0] FLAG_X=12'd3168,CASTLE_X=12'd3264;

    reg [4:0] phase;
    reg [15:0] xq;
    reg signed [13:0] yq;
    reg signed [8:0] vx,vy,next_vx,next_vy;
    reg signed [16:0] next_xq;
    reg signed [14:0] next_yq;
    reg grounded,super_state,star_state;
    reg [7:0] hurt_frames;
    reg [9:0] star_frames;
    reg [4:0] timer_frames;
    reg [7:0] multicoin_frames;
    reg multicoin_started;
    reg [5:0] second_frames,animation_frames;
    reg [8:0] flag_frames;
    reg [6:0] death_frames;
    reg [1:0] probe;
    reg head_effect;
    reg [7:0] head_tile;
    reg [11:0] head_addr;
    reg pending_jump,pending_back,pending_left,pending_right,pending_quick,left_d,right_d;
    reg powerup_live;
    reg [1:0] powerup_type;
    reg [11:0] powerup_px;
    reg [8:0] powerup_py;
    reg powerup_dir;
    reg [4:0] emerge_frames;
    reg [4:0] spawn_index;
    reg [3:0] enemy_dir;
    reg [2:0] entity_index;
    reg entity_floor,entity_live,entity_left;
    reg [2:0] entity_speed;
    reg [8:0] entity_height;
    reg signed [4:0] powerup_vy;
    reg [9:0] fireball_vy;
    reg [1:0] fireball_dir;
    reg [4:0] fire_cooldown;
    reg [11:0] entity_probe_x;
    reg [8:0] entity_probe_y;
    reg [11:0] ex;
    reg [8:0] ey;
    reg [7:0] tile;
    reg [11:0] tile_x;
    reg [8:0] tile_y;
    reg [5:0] body_height;
    integer k,j;
    reg projectile_hit;
    reg menu_return;
    reg [2:0] return_state;
    reg [4:0] return_phase;
    reg pickup_pending,grow_pending,fire_pending;

    wire jp=pending_jump||jump_press;
    wire bp=pending_back||back_press;
    wire lp=pending_left||(held_left&&!left_d);
    wire rp=pending_right||(held_right&&!right_d);
    wire qp=pending_quick||(quick_start===1'b1);
    assign player_x=xq[15:4];
    assign player_y=yq[12:4];
    assign playing=(state==PLAY||state==FLAG||state==CASTLE);
    assign paused=debug_mode||!playing;
    assign death_active=state==DEAD&&death_frames<7'd120;
    assign powerup_active=powerup_live;
    assign powerup_x=powerup_px;
    assign powerup_y=powerup_py;
    assign powerup_kind=powerup_type;
    assign super_mario=super_state;
    assign player_blink=hurt_frames!=0&&hurt_frames[2];
    assign player_star=star_state;
    assign enemy0_x=enemy_x[11:0];
    assign enemy1_x=enemy_x[23:12];
    assign enemy_alive=enemy_active[1:0];

    function solid;
        input [7:0] value;
        begin solid=(value!=AIR && value!=HIDDEN_1UP);end
    endfunction
    `include "game_enemy_spawns.vh"
    function [7:0] next_char;
        input [7:0] c;input forward;
        begin
            if(forward) next_char=c=="Z"?"0":c=="9"?" ":c==" "?"A":c+1'b1;
            else next_char=c=="A"?" ":c==" "?"9":c=="0"?"Z":c-1'b1;
        end
    endfunction

    // Map address is changed in *_ADDR and consumed two clocks later.
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            pickup_pending<=0;grow_pending<=0;fire_pending<=0;
            reward_valid<=0;reward_kind<=0;reward_x<=0;reward_y<=0;
            menu_return<=0;return_state<=TITLE;return_phase<=IDLE;
            block_fx_addr<=0;block_fx_frames<=0;block_fx_kind<=0;transform_frames<=0;
            state<=TITLE;phase<=IDLE;map_addr<=0;map_we<=0;map_wdata<=0;map_reload<=0;
            xq<=16'd512;yq<=14'd3072;vx<=0;vy<=0;next_vx<=0;next_vy<=0;
            next_xq<=0;next_yq<=0;grounded<=1;super_state<=0;star_state<=0;
            player_crouch<=0;hurt_frames<=0;star_frames<=0;camera_x<=0;
            facing_left<=0;anim<=0;enemy_x<=0;enemy_y<=0;enemy_kind<=0;
            enemy_active<=0;enemy_dir<=0;spawn_index<=0;entity_index<=0;
            coin_mask<=0;score<=0;seconds_left<=400;lives<=3;coins_count<=0;
            player_name<="AAA   ";avatar<=0;profile_cursor<=0;submit<=0;
            elapsed_seconds<=0;event_code<=0;event_valid<=0;second_frames<=0;
            animation_frames<=0;flag_phase<=0;flag_y<=9'd48;flag_frames<=0;death_frames<=0;
            pending_jump<=0;pending_back<=0;pending_left<=0;pending_right<=0;
            pending_quick<=0;
            left_d<=0;right_d<=0;powerup_live<=0;powerup_type<=0;
            powerup_px<=0;powerup_py<=0;powerup_dir<=0;emerge_frames<=0;
            probe<=0;head_effect<=0;head_tile<=0;head_addr<=0;
            entity_probe_x<=0;entity_probe_y<=0;ex<=0;ey<=0;
            tile<=0;tile_x<=0;tile_y<=0;body_height<=16;
            timer_frames<=0;multicoin_frames<=0;multicoin_started<=0;
            entity_floor<=0;entity_live<=0;entity_left<=0;entity_speed<=0;
            entity_height<=16;powerup_vy<=0;fireball_vy<=0;fireball_dir<=0;
            fire_mario<=0;fireball_active<=0;fireball_x<=0;fireball_y<=0;fire_cooldown<=0;
        end else begin
            reward_valid<=0;
            submit<=0;event_valid<=0;map_we<=0;map_reload<=0;
            left_d<=held_left;right_d<=held_right;
            if(jump_press) pending_jump<=1;
            if(back_press) pending_back<=1;
            if(held_left&&!left_d) pending_left<=1;
            if(held_right&&!right_d) pending_right<=1;
            // The long-press pulse is asynchronous to the frame enable.
            // Retain a start request while the TF atlas is still loading.
            if(state!=PROFILE || (frame_tick&&assets_loaded)) pending_quick<=0;
            else if(quick_start===1'b1) pending_quick<=1;
            if(frame_tick||debug_mode) begin
                pending_jump<=0;pending_back<=0;pending_left<=0;pending_right<=0;
            end
            if((profile_request===1'b1)||(scores_request===1'b1)) begin
                menu_return<=state!=TITLE;return_state<=state;return_phase<=phase;
                state<=(profile_request===1'b1)?PROFILE:LEADERBOARD;
                profile_cursor<=0;phase<=IDLE;
                pending_jump<=0;pending_back<=0;pending_left<=0;pending_right<=0;
            end else if(!debug_mode) begin
                case(phase)
                WAIT_MAP:if(map_ready) phase<=IDLE;
                IDLE:if(frame_tick) begin
                    case(state)
                    TITLE:begin
                        if(jp&&assets_loaded) begin state<=PROFILE;profile_cursor<=0;end
                        else if(lp||rp) state<=LEADERBOARD;
                    end
                    PROFILE:begin
                        if(bp) begin
                            if(profile_cursor==0) begin
                                state<=menu_return?return_state:TITLE;
                                if(menu_return) phase<=return_phase;
                                menu_return<=0;
                            end
                            else profile_cursor<=profile_cursor-1'b1;
                        end else if(jp || qp) begin
                            if(profile_cursor==6&&menu_return) begin
                                state<=return_state;phase<=return_phase;menu_return<=0;
                            end else if((profile_cursor==6 || qp) && assets_loaded) begin
                                state<=PLAY;phase<=WAIT_MAP;map_reload<=1;
                                xq<=16'd512;yq<=14'd3072;vx<=0;vy<=0;grounded<=1;
                                camera_x<=0;score<=0;coins_count<=0;lives<=3;
                                seconds_left<=400;elapsed_seconds<=0;second_frames<=0;
                                timer_frames<=0;multicoin_frames<=0;multicoin_started<=0;
                                enemy_active<=0;spawn_index<=0;coin_mask<=0;
                                powerup_live<=0;super_state<=0;star_state<=0;
                                fire_mario<=0;fireball_active<=0;fire_cooldown<=0;
                                hurt_frames<=0;player_crouch<=0;flag_phase<=0;
                                block_fx_frames<=0;transform_frames<=0;death_frames<=0;
                                flag_y<=48;event_valid<=1;event_code<=5;
                            end else if(profile_cursor<6 && !qp) profile_cursor<=profile_cursor+1'b1;
                        end else if(lp||rp) begin
                            if(profile_cursor==6) avatar<=rp?avatar+1'b1:avatar-1'b1;
                            else player_name[47-profile_cursor*8 -: 8]<=
                                next_char(player_name[47-profile_cursor*8 -: 8],rp);
                        end
                    end
                    PLAY:begin
                        if(bp) state<=TITLE;
                        else if(map_ready) begin
                            next_vx<=vx;
                            if(held_right&&!held_left) begin
                                facing_left<=0;
                                if(vx<(held_run?9'sd64:9'sd36))
                                    next_vx<=vx+9'sd4;
                            end else if(held_left&&!held_right) begin
                                facing_left<=1;
                                if(vx>(held_run?-9'sd64:-9'sd36))
                                    next_vx<=vx-9'sd4;
                            end else if($signed(vx)>0) next_vx<= (vx>9'sd4) ? (vx-9'sd4) : 0;
                            else if($signed(vx)<0) next_vx<= (vx< -9'sd4) ? (vx+9'sd4) : 0;
                            next_vy<= (vy<9'sd112) ? (vy+9'sd5) : vy;
                            if(jp&&grounded) begin
                                next_vy<=held_run?-9'sd120:-9'sd112;
                                grounded<=0;
                                event_valid<=1;event_code<=1;
                            end else if(!jump_hold&&vy< -9'sd40) next_vy<=-9'sd40;
                            // Crouch keeps the feet fixed; standing is checked by
                            // the vertical map probes on the following frame.
                            if(super_state&&grounded&&held_down) begin
                                if(!player_crouch) yq<=yq+14'd256;
                                player_crouch<=1;
                            end else if(player_crouch) begin
                                // Check headroom through the map port before
                                // raising the top of the collision box.
                                phase<=STAND_ADDR;
                            end
                            probe<=0;head_effect<=0;phase<=H_ADDR;
                            if(player_crouch&&!held_down) phase<=STAND_ADDR;
                        end
                    end
                    DEAD:begin
                        if(bp) state<=TITLE;
                        else if(death_active) begin
                            death_frames<=death_frames+1'b1;
                            // Hold the death pose before the ballistic fall.
                            // The signed coordinate allows clipping above y=0;
                            // clamp below the viewport to prevent 9-bit wrap.
                            if(death_frames>=7'd24) begin
                                if($signed(yq)+$signed(vy)>=14'sd4096)yq<=14'sd4096;
                                else yq<=yq+vy;
                                if(vy<9'sd107)vy<=vy+9'sd5;
                                else vy<=9'sd112;
                            end
                        end
                        else if(jp) begin
                            if(lives==0) state<=LEADERBOARD;
                            else begin
                                state<=PLAY;phase<=WAIT_MAP;map_reload<=1;
                                xq<=16'd512;yq<=14'd3072;vx<=0;vy<=0;
                                grounded<=1;camera_x<=0;seconds_left<=400;
                                second_frames<=0;enemy_active<=0;spawn_index<=0;
                                timer_frames<=0;multicoin_frames<=0;multicoin_started<=0;
                                coin_mask<=0;powerup_live<=0;super_state<=0;
                                fire_mario<=0;fireball_active<=0;fire_cooldown<=0;
                                star_state<=0;hurt_frames<=60;player_crouch<=0;
                                flag_phase<=0;flag_y<=48;death_frames<=0;
                            end
                        end
                    end
                    FLAG:begin
                        if(flag_y<9'd176) flag_y<=flag_y+9'd4;
                        if(yq[12:4]<(super_state?9'd176:9'd192)) begin
                            if(yq[12:4]+4>=(super_state?9'd176:9'd192))
                                yq<=super_state?14'd2816:14'd3072;
                            else yq<=yq+14'd64;
                        end
                        if(flag_y>=9'd176&&yq[12:4]>=(super_state?9'd176:9'd192)) begin
                            state<=CASTLE;flag_phase<=2;flag_frames<=0;
                            facing_left<=0;anim<=1;
                            event_valid<=1;event_code<=6;
                        end
                    end
                    CASTLE:begin
                        // Keep the course visible for the 7.81 s clear track.
                        // Reuse the walk animation counter and clamp to the door.
                        if(flag_frames<9'd480)flag_frames<=flag_frames+1'b1;
                        if(xq[15:4]<CASTLE_X) begin
                            animation_frames<=animation_frames+1'b1;
                            anim<=animation_frames[3]?2:1;
                            if(xq+16'd24>=CASTLE_X*16)begin
                                xq<=CASTLE_X*16;flag_phase<=3;anim<=0;
                            end else xq<=xq+16'd24;
                        end
                        else if(seconds_left!=0) begin
                            flag_phase<=3;anim<=0;
                            seconds_left<=seconds_left-1'b1;score<=score+24'd50;
                        end else if(flag_frames>=9'd480) begin
                            state<=CLEAR;flag_phase<=3;submit<=1;
                        end
                    end
                    CLEAR:if(jp) state<=LEADERBOARD;else if(bp) state<=TITLE;
                    LEADERBOARD:if(jp||bp) begin
                        state<=menu_return?return_state:TITLE;
                        if(menu_return) phase<=return_phase;
                        menu_return<=0;
                    end
                    default:state<=TITLE;
                    endcase
                end
                STAND_ADDR:begin
                    tile_x=player_x+(probe==0?2:13);
                    tile_y=player_y-9'd16;
                    map_addr<={tile_y[7:4],tile_x[11:4]};phase<=STAND_WAIT;
                end
                STAND_WAIT:phase<=STAND_WAIT2;
                STAND_WAIT2:phase<=STAND_USE;
                STAND_USE:begin
                    if(solid(map_data)) begin probe<=0;phase<=H_ADDR;end
                    else if(probe==0) begin probe<=1;phase<=STAND_ADDR;end
                    else begin
                        yq<=yq-14'd256;player_crouch<=0;probe<=0;phase<=H_ADDR;
                    end
                end
                H_ADDR:begin
                    if(probe==0) begin
                        next_xq<=$signed({1'b0,xq})+next_vx;
                        if(($signed({1'b0,xq})+next_vx)<$signed({1'b0,camera_x,4'd0}))
                            next_xq<=$signed({1'b0,camera_x,4'd0});
                        else if(($signed({1'b0,xq})+next_vx)>17'sd53120)
                            next_xq<=17'sd53120;
                        tile_x=(($signed({1'b0,xq})+next_vx+
                                 ($signed(next_vx)>=0?17'sd208:17'sd0))>>>4);
                    end else tile_x=((next_xq+($signed(next_vx)>=0?17'sd208:17'sd0))>>>4);
                    body_height<=super_state&&!player_crouch?32:16;
                    tile_y=(yq+(probe==0?14'sd224:probe==1?14'sd0:
                                    (super_state&&!player_crouch?14'sd480:14'sd224)))>>>4;
                    map_addr<={tile_y[7:4],tile_x[11:4]};
                    phase<=H_WAIT;
                end
                H_WAIT:phase<=H_WAIT2;
                H_WAIT2:phase<=H_USE;
                H_USE:begin
                    if(solid(map_data)) begin
                        next_xq<=xq;next_vx<=0;
                    end
                    if(probe==2) begin probe<=0;phase<=V_ADDR;end
                    else begin probe<=probe+1'b1;phase<=H_ADDR;end
                end
                V_ADDR:begin
                    if(probe==0) begin
                        next_yq<=$signed(yq)+next_vy;
                        if(($signed(yq)+next_vy)<0) next_yq<=0;
                        tile_y=(($signed(yq)+next_vy+
                                 ($signed(next_vy)>=0?$signed({5'd0,body_height,4'd0}):15'sd0))>>>4);
                    end else tile_y=((next_yq+
                                      ($signed(next_vy)>=0?$signed({5'd0,body_height,4'd0}):15'sd0))>>>4);
                    tile_x=((next_xq+(probe==0?17'sd32:17'sd208))>>>4);
                    map_addr<={tile_y[7:4],tile_x[11:4]};
                    phase<=V_WAIT;
                end
                // The level RAM registers data on the address edge; keep one
                // complete wait state so V_USE observes that registered value.
                V_WAIT:phase<=V_WAIT2;
                V_WAIT2:phase<=V_USE;
                V_USE:begin
                    if(solid(map_data) || (map_data==HIDDEN_1UP&&$signed(next_vy)<0)) begin
                        if($signed(next_vy)>=0) begin
                            next_yq<=$signed({3'd0,map_addr[11:8],8'd0})-
                                      $signed({5'd0,body_height,4'd0});
                            next_vy<=0;grounded<=1;
                        end else begin
                            next_yq<=$signed({3'd0,map_addr[11:8],8'd0})+15'sd256;
                            next_vy<=0;
                            if(!head_effect) begin
                                head_effect<=1;head_tile<=map_data;
                                head_addr<=map_addr;
                            end
                        end
                    end else if($signed(next_vy)>=0 && probe==0) grounded<=0;
                    // A resolved contact changes velocity to zero. Do not use
                    // that new direction to probe the opposite edge this frame.
                    if(probe==1 || solid(map_data) ||
                       (map_data==HIDDEN_1UP && $signed(next_vy)<0)) begin
                        probe<=0;entity_index<=0;entity_floor<=0;phase<=ENTITY_ADDR;
                    end else begin probe<=1;phase<=V_ADDR;end
                end
                ENTITY_ADDR:begin
                    if(!entity_floor) begin
                        entity_height=16;
                        if(entity_index<4) begin
                            entity_live=enemy_active[entity_index];
                            ex=enemy_x[entity_index*12 +: 12];
                            ey=enemy_y[entity_index*9 +: 9];
                            entity_left=enemy_dir[entity_index];
                            entity_speed=enemy_kind[entity_index*2 +: 2]==2?0:
                                         enemy_kind[entity_index*2 +: 2]==3?4:1;
                            entity_probe_y=ey+9'd3;
                        end else if(entity_index==4) begin
                            entity_live=powerup_live && emerge_frames==0;
                            ex=powerup_px;ey=powerup_py;entity_left=powerup_dir;
                            entity_speed=powerup_type==3?0:1;
                            entity_probe_y=powerup_type==3?ey:
                                $signed({1'b0,ey})+$signed(powerup_vy);
                        end else begin
                            entity_live=fireball_active[entity_index-5];
                            ex=fireball_x[(entity_index-5)*12 +: 12];
                            ey=fireball_y[(entity_index-5)*9 +: 9];
                            entity_left=fireball_dir[entity_index-5];
                            entity_speed=4;entity_height=8;
                            entity_probe_y=$signed({1'b0,ey})+
                                $signed(fireball_vy[(entity_index-5)*5 +: 5]);
                        end
                        entity_probe_x=entity_left?ex-entity_speed:ex+entity_speed;
                        tile_x=entity_probe_x+(entity_left?0:entity_height-1'b1);
                        tile_y=ey+(entity_height>>1);
                    end else begin
                        tile_x=entity_probe_x+(entity_height>>1);
                        tile_y=entity_probe_y+entity_height;
                    end
                    map_addr<={tile_y[7:4],tile_x[11:4]};
                    phase<=ENTITY_WAIT;
                end
                ENTITY_WAIT:phase<=ENTITY_WAIT2;
                ENTITY_WAIT2:phase<=ENTITY_USE;
                ENTITY_USE:begin
                    if(!entity_floor) begin
                        if(entity_live && solid(map_data)) begin
                            entity_probe_x=ex;
                            if(entity_index<4) enemy_dir[entity_index]<=!entity_left;
                            else if(entity_index==4) powerup_dir<=!entity_left;
                            else begin
                                fireball_active[entity_index-5]<=0;entity_live=0;
                            end
                        end
                        entity_floor<=1;phase<=ENTITY_ADDR;
                    end else begin
                        if(entity_live) begin
                            if(solid(map_data) && entity_probe_y>=ey)
                                entity_probe_y={1'b0,map_addr[11:8],4'd0}-entity_height;
                            if(entity_index<4) begin
                                enemy_x[entity_index*12 +: 12]<=entity_probe_x;
                                enemy_y[entity_index*9 +: 9]<=entity_probe_y;
                                if(entity_probe_y>=240 || entity_probe_x+12'd32<camera_x ||
                                   entity_probe_x>12'd3392) enemy_active[entity_index]<=0;
                            end else if(entity_index==4) begin
                                powerup_px<=entity_probe_x;powerup_py<=entity_probe_y;
                                if(solid(map_data) && entity_probe_y>=ey)
                                    powerup_vy<=powerup_type==2?-5'sd6:5'sd0;
                                else if(powerup_vy<5'sd5) powerup_vy<=powerup_vy+5'sd1;
                                if(entity_probe_y>=240 || entity_probe_x+12'd32<camera_x ||
                                   entity_probe_x>12'd3392) powerup_live<=0;
                            end else begin
                                fireball_x[(entity_index-5)*12 +: 12]<=entity_probe_x;
                                fireball_y[(entity_index-5)*9 +: 9]<=entity_probe_y;
                                if(solid(map_data) && entity_probe_y>=ey)
                                    fireball_vy[(entity_index-5)*5 +: 5]<=-5'sd4;
                                else if($signed(fireball_vy[(entity_index-5)*5 +: 5])<5'sd5)
                                    fireball_vy[(entity_index-5)*5 +: 5]<=
                                        fireball_vy[(entity_index-5)*5 +: 5]+5'd1;
                                if(entity_probe_y>=240 || entity_probe_x+12'd8<camera_x ||
                                   entity_probe_x>camera_x+12'd320) fireball_active[entity_index-5]<=0;
                            end
                        end
                        if(entity_index==6) begin entity_index<=0;phase<=CONTACT;end
                        else begin entity_index<=entity_index+1'b1;entity_floor<=0;phase<=ENTITY_ADDR;end
                    end
                end
                CONTACT:begin
                    k=entity_index;projectile_hit=0;
                    ex=enemy_x[k*12 +: 12];ey=enemy_y[k*9 +: 9];
                    if(enemy_active[k] && state==PLAY) begin
                        for(j=0;j<2;j=j+1) begin
                            if(fireball_active[j] && fireball_x[j*12 +: 12]+8>ex &&
                               fireball_x[j*12 +: 12]<ex+16 && fireball_y[j*9 +: 9]+8>ey &&
                               fireball_y[j*9 +: 9]<ey+16) begin
                                projectile_hit=1;fireball_active[j]<=0;
                            end
                        end
                        for(j=0;j<4;j=j+1) begin
                            if(j!=k && enemy_active[j] && enemy_kind[j*2 +: 2]==3 &&
                               enemy_x[j*12 +: 12]+16>ex && enemy_x[j*12 +: 12]<ex+16 &&
                               enemy_y[j*9 +: 9]+16>ey && enemy_y[j*9 +: 9]<ey+16)
                                projectile_hit=1;
                        end
                        if(projectile_hit) begin
                            enemy_active[k]<=0;score<=score+24'd200;
                            reward_valid<=1;reward_kind<=1;reward_x<=ex;reward_y<=ey;
                            event_valid<=1;event_code<=3;
                        end else if(next_xq[16:4]+14>ex && next_xq[16:4]<ex+16 &&
                           next_yq[14:4]+body_height>ey && next_yq[14:4]<ey+16) begin
                            if(star_state || ($signed(next_vy)>=0 &&
                               yq[12:4]+body_height<=ey+4)) begin
                                if(star_state || enemy_kind[k*2 +: 2]==0) enemy_active[k]<=0;
                                else if(enemy_kind[k*2 +: 2]==2) begin
                                    enemy_kind[k*2 +: 2]<=3;
                                    enemy_dir[k]<=facing_left;
                                end else enemy_kind[k*2 +: 2]<=2;
                                if(!star_state) begin next_vy<=-9'sd64;grounded<=0;end
                                score<=score+24'd200;event_valid<=1;event_code<=3;
                                reward_valid<=1;reward_kind<=1;reward_x<=ex;reward_y<=ey;
                            end else if(enemy_kind[k*2 +: 2]==2) begin
                                enemy_kind[k*2 +: 2]<=3;enemy_dir[k]<=next_xq[16:4]>ex;
                                enemy_x[k*12 +: 12]<=next_xq[16:4]>ex?ex-12'd8:ex+12'd8;
                            end else if(hurt_frames==0) begin
                                if(super_state) begin
                                    super_state<=0;player_crouch<=0;fire_mario<=0;
                                    if(!player_crouch) next_yq<=next_yq+15'sd256;
                                    hurt_frames<=90;event_valid<=1;event_code<=9;
                                end else begin
                                    state<=DEAD;lives<=lives-1'b1;
                                    event_valid<=1;event_code<=4;
                                    if(lives==1) submit<=1;
                                end
                            end
                        end
                    end
                    if(entity_index==3) phase<=COMMIT;
                    else entity_index<=entity_index+1'b1;
                end
                COMMIT:begin
                    // Death has priority over rewards and the finish line. A
                    // CONTACT death must not be charged again by the timer.
                    if(state!=PLAY || next_yq>15'sd3840 || seconds_left==0) begin
                        xq<=next_xq[15:0];yq<=next_yq[13:0];
                        vx<=next_vx;vy<=next_vy;phase<=IDLE;
                        if(state==PLAY||state==DEAD)begin
                            death_frames<=0;vx<=0;
                            // Pit deaths continue downward, never re-entering
                            // the playfield. Contact/timeout use the death hop.
                            vy<=(next_yq>15'sd3840) ? 9'sd112 : -9'sd96;
                        end
                        if(state==PLAY) begin
                            state<=DEAD;lives<=lives-1'b1;
                            event_valid<=1;event_code<=4;
                            if(lives==1) submit<=1;
                        end
                    end else begin
                    // Snapshot contacts before block spawning/emergence and
                    // before a newly collected flower changes fire_mario.
                    pickup_pending<=powerup_live && emerge_frames==0 &&
                        next_xq[16:4]+16>powerup_px && next_xq[16:4]<powerup_px+16 &&
                        next_yq[14:4]+body_height>powerup_py && next_yq[14:4]<powerup_py+16;
                    grow_pending<=0;
                    fire_pending<=fire_mario && held_run && fire_cooldown==0 && fireball_active!=2'b11;
                    if(hurt_frames!=0) hurt_frames<=hurt_frames-1'b1;
                    if(block_fx_frames!=0) block_fx_frames<=block_fx_frames-1'b1;
                    if(transform_frames!=0) transform_frames<=transform_frames-1'b1;
                    if(star_frames!=0) star_frames<=star_frames-1'b1;
                    else star_state<=0;
                    if(multicoin_frames!=0) multicoin_frames<=multicoin_frames-1'b1;
                    if(head_effect) begin
                        block_fx_addr<=head_addr;block_fx_frames<=16;block_fx_kind<=1;
                        event_valid<=1;event_code<=8;
                        case(head_tile)
                        Q_COIN,BRICK_COIN:begin
                            map_we<=1;map_addr<=head_addr;
                            map_wdata<=head_tile==Q_COIN?USED:
                                (multicoin_started && multicoin_frames==0)?USED:BRICK_COIN;
                            if(head_tile==BRICK_COIN && !multicoin_started) begin
                                multicoin_started<=1;multicoin_frames<=231;
                            end
                            score<=score+24'd200;
                            reward_valid<=1;reward_kind<=0;
                            reward_x<={head_addr[7:0],4'b0};reward_y<={1'b0,head_addr[11:8],4'b0};
                            coins_count<=coins_count==99?0:coins_count+1'b1;
                            if(coins_count==99 && lives!=15) lives<=lives+1'b1;
                            event_valid<=1;event_code<=2;
                            block_fx_kind<=head_tile==Q_COIN ||
                                (multicoin_started && multicoin_frames==0)?3:1;
                        end
                        Q_POWER,BRICK_POWER,HIDDEN_1UP,BRICK_STAR:begin
                            map_we<=1;map_addr<=head_addr;
                            map_wdata<=USED;
                            if(!powerup_live) begin
                                powerup_live<=1;powerup_px<={head_addr[7:0],4'b0};
                                powerup_py<={head_addr[11:8],4'b0};
                                powerup_type<=head_tile==HIDDEN_1UP?1:
                                    head_tile==BRICK_STAR?2:super_state?3:0;
                                emerge_frames<=16;powerup_dir<=0;powerup_vy<=0;
                            end
                            event_valid<=1;event_code<=14;block_fx_kind<=3;
                        end
                        BRICK:if(super_state) begin
                            map_we<=1;map_addr<=head_addr;map_wdata<=AIR;
                            score<=score+24'd50;event_valid<=1;event_code<=15;
                            reward_valid<=1;reward_kind<=4;
                            reward_x<={head_addr[7:0],4'b0};reward_y<={1'b0,head_addr[11:8],4'b0};
                            block_fx_frames<=20;block_fx_kind<=2;
                        end
                        default:begin end
                        endcase
                    end
                    if(powerup_live) begin
                        if(emerge_frames!=0) begin
                            emerge_frames<=emerge_frames-1'b1;
                            powerup_py<=powerup_py-1'b1;
                        end
                    end
                    phase<=PICKUP;
                    end
                end
                // Serialize awards instead of adding multiple score/life
                // assignments on the same edge. Each event reaches both the
                // audio queue and the reward renderer on its own clock.
                PICKUP:begin
                    if(pickup_pending) begin
                        powerup_live<=0;event_valid<=1;event_code<=7;
                        reward_valid<=1;reward_kind<=powerup_type==1?3:2;
                        reward_x<=powerup_px;reward_y<=powerup_py;
                        case(powerup_type)
                        0:begin
                            if(!super_state) begin
                                super_state<=1;
                                transform_frames<=24;
                                grow_pending<=1;
                            end
                            score<=score+24'd1000;
                        end
                        1:begin if(lives!=15) lives<=lives+1'b1;score<=score+24'd1000;event_code<=11;end
                        2:begin star_state<=1;star_frames<=720;
                                score<=score+24'd1000;event_code<=13;end
                        3:begin fire_mario<=1;transform_frames<=24;score<=score+24'd1000;end
                        endcase
                    end
                    phase<=FIRE_STEP;
                end
                FIRE_STEP:begin
                    if(fire_cooldown!=0) fire_cooldown<=fire_cooldown-1'b1;
                    if(fire_pending) begin
                        if(!fireball_active[0]) begin
                            fireball_active[0]<=1;fireball_x[11:0]<=player_x+(facing_left?0:12);
                            fireball_y[8:0]<=player_y+12;fireball_dir[0]<=facing_left;
                            fireball_vy[4:0]<=5'd2;
                        end else begin
                            fireball_active[1]<=1;fireball_x[23:12]<=player_x+(facing_left?0:12);
                            fireball_y[17:9]<=player_y+12;fireball_dir[1]<=facing_left;
                            fireball_vy[9:5]<=5'd2;
                        end
                        fire_cooldown<=20;event_valid<=1;event_code<=12;
                    end
                    if(spawn_index<`GAME_ENEMY_COUNT && spawn_x(spawn_index)<=camera_x+12'd320) begin
                        if(!enemy_active[0]) begin
                            enemy_active[0]<=1; enemy_x[11:0]<=spawn_x(spawn_index);
                            enemy_y[8:0]<=spawn_y(spawn_index); enemy_kind[1:0]<=spawn_kind(spawn_index);
                            enemy_dir[0]<=1; spawn_index<=spawn_index+1'b1;
                        end else if(!enemy_active[1]) begin
                            enemy_active[1]<=1; enemy_x[23:12]<=spawn_x(spawn_index);
                            enemy_y[17:9]<=spawn_y(spawn_index); enemy_kind[3:2]<=spawn_kind(spawn_index);
                            enemy_dir[1]<=1; spawn_index<=spawn_index+1'b1;
                        end else if(!enemy_active[2]) begin
                            enemy_active[2]<=1; enemy_x[35:24]<=spawn_x(spawn_index);
                            enemy_y[26:18]<=spawn_y(spawn_index); enemy_kind[5:4]<=spawn_kind(spawn_index);
                            enemy_dir[2]<=1; spawn_index<=spawn_index+1'b1;
                        end else if(!enemy_active[3]) begin
                            enemy_active[3]<=1; enemy_x[47:36]<=spawn_x(spawn_index);
                            enemy_y[35:27]<=spawn_y(spawn_index); enemy_kind[7:6]<=spawn_kind(spawn_index);
                            enemy_dir[3]<=1; spawn_index<=spawn_index+1'b1;
                        end
                    end
                    if(second_frames==59) begin
                        second_frames<=0;
                        elapsed_seconds<=elapsed_seconds+1'b1;
                    end else second_frames<=second_frames+1'b1;
                    if(timer_frames==23) begin
                        timer_frames<=0;
                        if(seconds_left!=0) seconds_left<=seconds_left-1'b1;
                    end else timer_frames<=timer_frames+1'b1;
                    phase<=FINISH;
                end
                FINISH:begin
                    xq<=next_xq[15:0];
                    yq<=grow_pending?next_yq[13:0]-14'd256:next_yq[13:0];
                    vx<=next_vx;vy<=next_vy;
                    animation_frames<=animation_frames+1'b1;
                    anim<=!grounded?3:next_vx==0?0:animation_frames[3]?2:1;
                    if(next_xq[16:4]>128 && next_xq[16:4]-128>camera_x)
                        camera_x<=next_xq[16:4]-128>3136?3136:
                                  next_xq[16:4]-128;
                    if(next_xq[16:4]+16>=FLAG_X) begin
                        state<=FLAG;flag_phase<=1;flag_y<=48;
                        score<=score+(player_y<34?24'd5000:player_y<80?24'd2000:
                                      player_y<104?24'd800:player_y<144?24'd400:24'd100);
                        reward_valid<=1;reward_kind<=player_y<34?9:player_y<80?8:
                            player_y<104?7:player_y<144?6:5;
                        reward_x<=FLAG_X;reward_y<=player_y;
                        event_valid<=1;event_code<=10;
                        player_crouch<=0;
                        xq<=FLAG_X*16-16;vx<=0;vy<=0;
                    end
                    phase<=IDLE;
                end
                default:phase<=IDLE;
                endcase
            end
        end
    end
endmodule

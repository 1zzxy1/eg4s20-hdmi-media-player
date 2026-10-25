`include "game_assets.vh"
// One background and one foreground texel per output pixel; two-cycle raster path.
module game_video #(
    parameter ALIGNMENT=0
)(
    input wire clk,rst,hs,vs,de,input wire [23:0] media_rgb,
    input wire [9:0] alignment_offset,input wire alignment_active,
    input wire media_valid,debug_mode,media_fullscreen,osd_enable,view_narrow,palette_mode,assets_loaded,
    input wire [2:0] state,input wire [11:0] player_x,camera_x,enemy0_x,enemy1_x,
    input wire powerup_active,input wire [11:0] powerup_x,input wire [8:0] powerup_y,
    input wire [1:0] powerup_kind,
    output reg [11:0] map_addr,input wire [7:0] map_data,
    input wire [47:0] enemy_x,input wire [35:0] enemy_y,input wire [7:0] enemy_kind,
    input wire [3:0] enemy_active,input wire [7:0] coins_count,input wire player_crouch,
    input wire [1:0] flag_phase,input wire [8:0] flag_y,
    input wire super_mario,
    input wire [8:0] player_y,input wire facing_left,input wire [1:0] anim,enemy_alive,
    input wire [7:0] coin_mask,input wire [8:0] seconds_left,input wire [23:0] score,
    input wire [3:0] lives,input wire [47:0] player_name,input wire [2:0] avatar,profile_cursor,
    input wire fire_mario,input wire [1:0] fireball_active,
    input wire [23:0] fireball_x,input wire [17:0] fireball_y,
    input wire [3:0] event_code,
    input wire [11:0] block_fx_addr,input wire [4:0] block_fx_frames,transform_frames,
    input wire [1:0] block_fx_kind,input wire player_blink,player_star,death_active,
    input wire effects_paused,reward_valid,input wire [3:0] reward_kind,
    input wire [11:0] reward_x,input wire [8:0] reward_y,
    input wire save_busy,save_error,save_available,audio_enabled,
    output reg [14:0] bg_addr,sprite_addr,input wire [3:0] bg_index,sprite_index,
    output wire [3:0] rank_index,input wire rank_valid,input wire [47:0] rank_name,
    input wire [23:0] rank_score,input wire [15:0] rank_time,input wire [2:0] rank_avatar,
    output reg hs_o,vs_o,de_o,output reg [23:0] rgb_o,output wire frame_tick
);
    reg vs_d,de_d;reg [9:0] scan_x,scan_y;
    reg [9:0] px,y;
    reg [9:0] lx;
    reg [7:0] scale_x;
    reg [2:0] scale_fraction;
    reg hs0,vs0,de0;
    wire [9:0] raster_x=de_d?scan_x:10'd0;
    wire [10:0] aligned_sum={1'b0,raster_x}+{1'b0,alignment_offset};
    wire [9:0] request_px=ALIGNMENT?
        (aligned_sum>=640?aligned_sum-11'd640:aligned_sum[9:0]):raster_x;
    // floor(x*256/640), using a 2/5 phase accumulator, with no divider.
    // Both logical view widths fill all 640 output columns.
    wire [9:0] request_lx=view_narrow?
        (ALIGNMENT?({1'b0,request_px}*11'd2)/11'd5:{2'b0,scale_x}):request_px>>1;
    wire [8:0] request_ly=scan_y>>1;
    wire [11:0] request_wx=camera_x+request_lx;
    wire death_scene=state==3&&(death_active===1'b1);
    wire player_visible=!death_scene&&!(state==7&&flag_phase==3);
    wire world_visible=state==2||state==6||state==7||death_scene;
    reg [4:0] request_message,request_column;
    wire [7:0] static_char;
    // Fetch fixed text alongside the synchronous map, without another RGB
    // stage. Dynamic names, scores and reward labels still use the next stage.
    always @* begin
        request_message=25;request_column=(request_px-10'd192)>>3;
        if(scan_y>=32&&scan_y<48&&request_px>=64&&request_px<576)begin
            request_message=0;request_column=(request_px-10'd64)>>4;
        end
        if(!world_visible||!assets_loaded)begin
            if(scan_y>=128&&scan_y<136)begin
                if(!assets_loaded)request_message=1;
                else case(state)
                    0:request_message=2;1:request_message=3;
                    3:request_message=lives==0?4:5;4:request_message=6;
                    5:request_message=7;default:request_message=2;
                endcase
            end
            if(scan_y>=352&&scan_y<360)request_message=state==1?(!assets_loaded?1:8):state==0?9:10;
            if(scan_y>=336&&scan_y<344&&state!=1)
                request_message=save_busy?11:save_error?12:save_available?13:14;
            if(scan_y>=248&&scan_y<256&&state==1)request_message=profile_cursor==6?15:16;
            if(state==0&&((scan_y>=192&&scan_y<200)||(scan_y>=224&&scan_y<232)||
               (scan_y>=256&&scan_y<264)))request_message=scan_y<208?17:scan_y<240?18:19;
        end else if(osd_enable&&player_x>=400&&player_x<640&&scan_y>=88&&scan_y<96)begin
            request_message=20;request_column=(request_px-10'd160)>>3;
        end else if(osd_enable&&player_x>=1100&&scan_y>=88&&scan_y<96)begin
            request_message=21;request_column=(request_px-10'd160)>>3;
        end
        if(debug_mode&&scan_y>=104&&scan_y<112)begin
            request_message=22;request_column=(request_px-10'd160)>>3;
        end
        if(debug_mode&&osd_enable&&scan_y>=368&&scan_y<376)begin
            request_message=26;request_column=(request_px-10'd160)>>3;
        end
        if(!debug_mode&&osd_enable&&scan_y>=72&&scan_y<80)begin
            request_message=audio_enabled?23:24;request_column=(request_px-10'd80)>>3;
        end
    end
    game_scene_text scene_text(.clk(clk),.message_id(request_message),
        .column(request_column),.character(static_char));
    assign frame_tick=vs&&!vs_d;
    always @(posedge clk or posedge rst) begin
        if(rst) begin scan_x<=0;scan_y<=0;vs_d<=0;de_d<=0;px<=0;y<=0;lx<=0;scale_x<=0;scale_fraction<=0;hs0<=0;vs0<=0;de0<=0;end
        else begin
            vs_d<=vs;de_d<=de;
            if(frame_tick) scan_y<=0;else if(de_d&&!de) scan_y<=scan_y+1'b1;
            scan_x<=de?raster_x+1'b1:10'd0;
            if(!de)begin scale_x<=0;scale_fraction<=0;end
            else if(scale_fraction>=3)begin scale_fraction<=scale_fraction-3'd3;scale_x<=scale_x+1'b1;end
            else scale_fraction<=scale_fraction+3'd2;
            px<=request_px;y<=scan_y;lx<=request_lx;hs0<=hs;vs0<=vs;de0<=de;
        end
    end
    wire inside_view=1'b1;
    wire [8:0] ly=y>>1;
    wire [11:0] wx=camera_x+lx;
    wire reward_coin,reward_text;
    wire [3:0] reward_u,reward_v;
    wire [7:0] reward_char;
    wire [2:0] reward_row,reward_col;
    wire [8:0] death_dy=ly-player_y;
    game_reward_fx rewards(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .paused(effects_paused===1'b1||!world_visible),
        .clear(state==0||state==3||state==4||!assets_loaded),
        .reward_valid(reward_valid),.reward_kind(reward_kind),.reward_x(reward_x),.reward_y(reward_y),
        .world_x(wx),.world_y(ly),.coin_on(reward_coin),.coin_u(reward_u),.coin_v(reward_v),
        .text_on(reward_text),.text_char(reward_char),.text_row(reward_row),.text_col(reward_col));
    wire [8:0] decor_x=wx[8:0];
    always @* map_addr={request_ly[7:4],request_wx[11:4]};
    assign rank_index=(state==5&&y>=160&&y<320)?(y-160)>>4:0;
    wire [23:0] score_bcd,rank_score_bcd;
    wire [11:0] seconds_bcd;
    wire [7:0] coins_bcd;
    wire [19:0] rank_time_bcd;
    game_hud_decimal decimal_fields(.clk(clk),.rst(rst),.score(score),.rank_score(rank_score),
        .seconds_left(seconds_left),.coins_count(coins_count),.rank_time(rank_time),
        .score_bcd(score_bcd),.rank_score_bcd(rank_score_bcd),.seconds_bcd(seconds_bcd),
        .coins_bcd(coins_bcd),.rank_time_bcd(rank_time_bcd));
    reg [6:0] tile,stile,decor_tile;
    reg [3:0] u,v;
    reg sprite_on,decor_on,player_sprite;
    reg [11:0] player_top;
    reg [11:0] ex4;
    reg [8:0] ey4;
    reg [1:0] ek4;
    reg [11:0] fx;
    reg [8:0] fy;
    reg [11:0] piece_x;
    reg [8:0] piece_y;
    wire fx_active=(block_fx_frames!=0);
    wire [4:0] fx_age=5'd20-block_fx_frames;
    wire [3:0] bump_height=block_fx_frames>8?16-block_fx_frames:block_fx_frames;
    wire [11:0] block_x={block_fx_addr[7:0],4'b0};
    wire [8:0] block_y={1'b0,block_fx_addr[11:8],4'b0};
    wire [8:0] bump_y=block_y-{5'd0,bump_height};
    function [8:0] debris_y(input [4:0] age);
        begin case(age)
            0:debris_y=0;1:debris_y=-3;2:debris_y=-6;3:debris_y=-8;
            4:debris_y=-10;5,6,7:debris_y=-11;8:debris_y=-10;
            9:debris_y=-8;10:debris_y=-6;11:debris_y=-3;12:debris_y=0;
            13:debris_y=4;14:debris_y=9;15:debris_y=14;16:debris_y=20;
            17:debris_y=27;18:debris_y=34;default:debris_y=42;
        endcase end
    endfunction
    integer i;
    function [6:0] terrain_tile;
        input [7:0] map_code;
        begin
            case(map_code)
                1:terrain_tile=`GAME_TILE_GROUND;
                2,12,13,14:terrain_tile=`GAME_TILE_BRICK;
                3,4:terrain_tile=`GAME_TILE_QUESTION;
                5:terrain_tile=`GAME_TILE_USED;
                6:terrain_tile=`GAME_TILE_STONE;
                7:terrain_tile=`GAME_TILE_PIPE_TL;
                8:terrain_tile=`GAME_TILE_PIPE_TR;
                9:terrain_tile=`GAME_TILE_PIPE_BL;
                10:terrain_tile=`GAME_TILE_PIPE_BR;
                default:terrain_tile=`GAME_TILE_EMPTY;
            endcase
        end
    endfunction
    always @* begin
        tile=inside_view?terrain_tile(map_data):0;
        if(fx_active&&block_fx_kind!=2&&{ly[7:4],wx[11:4]}==block_fx_addr)tile=0;
        decor_tile=0;decor_on=0;
        // Decorations are drawn only behind air.  They share the same
        // ground-line alignment as the source course.
        if(inside_view && tile==`GAME_TILE_EMPTY) begin
            if(wx>=12'd3232 && wx<12'd3312 && ly>=9'd128 && ly<9'd208) begin
                decor_tile=`GAME_TILE_CASTLE_00 + (((ly-9'd128)>>4)*5) + ((wx-12'd3232)>>4);
                decor_on=1;
            end else if(decor_x>=9'd96&&decor_x<9'd128&&ly>=9'd32&&ly<9'd64) begin
                decor_tile=`GAME_TILE_CLOUD_00+(((ly-9'd32)>>4)*2)+((decor_x-9'd96)>>4);
                decor_on=1;
            end else if(decor_x>=9'd288&&decor_x<9'd352&&ly>=9'd176&&ly<9'd208) begin
                decor_tile=`GAME_TILE_HILL_00+(((ly-9'd176)>>4)*4)+((decor_x-9'd288)>>4);
                decor_on=1;
            end else if(decor_x>=9'd432&&decor_x<9'd464&&ly>=9'd192&&ly<9'd208) begin
                decor_tile=`GAME_TILE_BUSH_L+((decor_x-9'd432)>>4);
                decor_on=1;
            end
        end
        bg_addr={(decor_on?decor_tile:tile),ly[3:0],wx[3:0]};
        stile=0;u=0;v=0;sprite_on=0;player_sprite=0;ex4=0;ey4=0;ek4=0;fx=0;fy=0;
        piece_x=0;piece_y=0;
        player_top=player_crouch?player_y-12'd16:{3'd0,player_y};
        if(inside_view) begin
            // Flag cloth and pole use the dedicated narrow source frames.
            if(wx>=12'd3152&&wx<12'd3168&&ly>=flag_y&&ly<flag_y+9'd16) begin
                stile=`GAME_TILE_FLAG;u=wx-12'd3152;v=ly-flag_y;sprite_on=1;
            end
            if(wx>=12'd3168&&wx<12'd3176&&ly>=9'd32&&ly<9'd192) begin
                if(ly<9'd48) begin
                    stile=`GAME_TILE_FLAG_POLE_TOP;u=wx-12'd3168;v=ly-9'd32;
                end else begin
                    stile=`GAME_TILE_FLAG_POLE_BODY;u=wx-12'd3168;v=8+((ly-9'd48)&7);
                end
                sprite_on=1;
            end
            // Four independent enemy slots.  Koopa occupies 24 logical
            // pixels; the bottom 8 pixels are aligned to the bottom of its
            // 16x16 cache tile and therefore retain transparent padding.
            for(i=0;i<4;i=i+1) begin
                ex4=enemy_x[i*12 +: 12];
                ey4=enemy_y[i*9 +: 9];
                ek4=enemy_kind[i*2 +: 2];
                if(enemy_active[i] && wx>=ex4 && wx<ex4+12'd16 &&
                   ly+(ek4==2'd1 ? 9'd8 : 9'd0)>=ey4 && ((ek4==2'd1 && ly<ey4+16) ||
                               (ek4!=2'd1 && ly<ey4+16))) begin
                    u=wx-ex4;
                    if(ek4==2'd1) begin
                        if(ly+9'd8-ey4<16) begin stile=`GAME_TILE_KOOPA_TOP;v=ly+9'd8-ey4;end
                        else begin stile=`GAME_TILE_KOOPA_BOTTOM;v=8+(ly-ey4-8);end
                    end else if(ek4==2'd2 || ek4==2'd3) begin
                        stile=`GAME_TILE_SHELL;v=ly-ey4;
                    end else begin
                        stile=(i[0]^anim[0])?`GAME_TILE_ENEMY1:`GAME_TILE_ENEMY0;
                        v=ly-ey4;
                    end
                    sprite_on=1;
                end
            end
            if((powerup_active===1'b1)&&wx>=powerup_x&&wx<powerup_x+16&&
               ly>=powerup_y&&ly<powerup_y+16) begin
                case(powerup_kind)
                    2'd1:stile=`GAME_TILE_ONEUP;
                    2'd2:stile=`GAME_TILE_STAR;
                    2'd3:stile=`GAME_TILE_FLOWER;
                    default:stile=`GAME_TILE_MUSHROOM;
                endcase
                u=wx-powerup_x;v=ly-powerup_y;sprite_on=1;
            end
            for(i=0;i<2;i=i+1) begin
                fx=fireball_x[i*12 +: 12];fy=fireball_y[i*9 +: 9];
                if(fireball_active[i]===1'b1 && wx+12'd4>=fx&&wx<fx+12'd12 &&
                   ly+9'd4>=fy&&ly<fy+9'd12) begin
                    stile=`GAME_TILE_FIREBALL;u=wx+12'd4-fx;v=ly+9'd4-fy;sprite_on=1;
                end
            end
            if(world_visible&&reward_coin)begin
                stile=`GAME_TILE_COIN;u=reward_u;v=reward_v;sprite_on=1;
            end
            if(player_visible&&super_mario===1'b1 && wx>=player_x&&wx<player_x+16&&
               ly>=player_top&&ly<player_top+32) begin
                case(anim)
                    2'd1: begin
                        stile=player_crouch?`GAME_TILE_BIG_CROUCH_TOP:`GAME_TILE_BIG_RUN0_TOP;
                    end
                    2'd2: begin
                        stile=player_crouch?`GAME_TILE_BIG_CROUCH_TOP:`GAME_TILE_BIG_RUN1_TOP;
                    end
                    2'd3: stile=player_crouch?`GAME_TILE_BIG_CROUCH_TOP:`GAME_TILE_BIG_JUMP_TOP;
                    default:stile=player_crouch?`GAME_TILE_BIG_CROUCH_TOP:`GAME_TILE_BIG_IDLE_TOP;
                endcase
                if(ly-player_top>=16) begin
                    case(anim)
                        2'd1:stile=player_crouch?`GAME_TILE_BIG_CROUCH_BOTTOM:`GAME_TILE_BIG_RUN0_BOTTOM;
                        2'd2:stile=player_crouch?`GAME_TILE_BIG_CROUCH_BOTTOM:`GAME_TILE_BIG_RUN1_BOTTOM;
                        2'd3:stile=player_crouch?`GAME_TILE_BIG_CROUCH_BOTTOM:`GAME_TILE_BIG_JUMP_BOTTOM;
                        default:stile=player_crouch?`GAME_TILE_BIG_CROUCH_BOTTOM:`GAME_TILE_BIG_IDLE_BOTTOM;
                    endcase
                    v=ly-player_top-16;
                end else v=ly-player_top;
                u=facing_left?15-(wx-player_x):wx-player_x;sprite_on=1;player_sprite=1;
            end else if(player_visible&&wx>=player_x&&wx<player_x+16&&ly>=player_y&&ly<player_y+16) begin
                stile=`GAME_TILE_PLAYER_IDLE+anim;u=facing_left?15-(wx-player_x):wx-player_x;v=ly-player_y;sprite_on=1;player_sprite=1;
            end
            if(player_sprite&&(player_blink===1'b1))sprite_on=0;
            if(fx_active)begin
                if(block_fx_kind==2)begin
                    for(i=0;i<4;i=i+1)begin
                        piece_x=i[0]?block_x+8+{7'd0,fx_age}:block_x-{7'd0,fx_age};
                        piece_y=block_y+debris_y(fx_age)+(i[1]?9'd10:9'd0);
                        if(wx>=piece_x&&wx<piece_x+8&&ly>=piece_y&&ly<piece_y+8)begin
                            stile=`GAME_TILE_BRICK;u=(wx-piece_x)+(i[0]?8:0);
                            v=(ly-piece_y)+(i[1]?8:0);sprite_on=1;player_sprite=0;
                        end
                    end
                end else if(wx>=block_x&&wx<block_x+16&&ly>=bump_y&&ly<bump_y+9'd16)begin
                    stile=block_fx_kind==3?`GAME_TILE_USED:`GAME_TILE_BRICK;
                    u=wx-block_x;v=ly-bump_y;sprite_on=1;player_sprite=0;
                end
            end
            // Reuse the original small-Mario death frame in the avatar atlas.
            // Modular dy clips negative y without wrapping the sprite on-screen.
            // Draw after terrain effects so the body falls through the ground.
            if(death_scene&&wx>=player_x&&wx<player_x+16&&death_dy<9'd16)begin
                stile=`GAME_TILE_AVATAR6;u=wx-player_x;v=death_dy;
                sprite_on=1;player_sprite=0;
            end
        end
        // Profile avatar is an actual texture from the SD atlas.
        if(osd_enable&&px>=32&&px<64&&y>=16&&y<48) begin stile=`GAME_TILE_AVATAR0+avatar;u=(px-32)>>1;v=(y-16)>>1;sprite_on=1;end
        if(state==1&&px>=288&&px<352&&y>=272&&y<336) begin stile=`GAME_TILE_AVATAR0+avatar;u=(px-288)>>2;v=(y-272)>>2;sprite_on=1;end
        if(state==5&&rank_valid&&px>=168&&px<184&&y>=160&&y<320) begin
            stile=`GAME_TILE_AVATAR0+rank_avatar;u=px-168;v=y[3:0];sprite_on=1;
        end
        sprite_addr={stile,v,u};
    end
    function [23:0] palette;
        input [3:0] n;
        begin case(n)
        0:palette=`GAME_PAL_0;1:palette=`GAME_PAL_1;2:palette=`GAME_PAL_2;3:palette=`GAME_PAL_3;
        4:palette=`GAME_PAL_4;5:palette=`GAME_PAL_5;6:palette=`GAME_PAL_6;7:palette=`GAME_PAL_7;
        8:palette=`GAME_PAL_8;9:palette=`GAME_PAL_9;10:palette=`GAME_PAL_10;11:palette=`GAME_PAL_11;
        12:palette=`GAME_PAL_12;13:palette=`GAME_PAL_13;14:palette=`GAME_PAL_14;default:palette=`GAME_PAL_15;
        endcase end
    endfunction
    function [7:0] hexchar;
        input [3:0] n;begin hexchar=n<10?"0"+n:"A"+n-10;end
    endfunction
    function [7:0] name_character(input [47:0] name,input [2:0] column);
        begin case(column)
            0:name_character=name[47:40];1:name_character=name[39:32];
            2:name_character=name[31:24];3:name_character=name[23:16];
            4:name_character=name[15:8];5:name_character=name[7:0];
            default:name_character=" ";
        endcase end
    endfunction
    reg [7:0] ch;
    reg text_area,panel;
    reg [5:0] char_col;
    reg [2:0] glyph_row,glyph_col;
    // Default play HUD follows the source game's four-field arrangement.
    always @* begin
        ch=32;text_area=0;panel=0;char_col=0;glyph_row=y[2:0];glyph_col=px[2:0];
        if(world_visible&&inside_view&&reward_text)begin
            text_area=1;ch=reward_char;glyph_row=reward_row;glyph_col=reward_col;
        end
        if(y>=32&&y<48&&px>=64&&px<576) begin
            text_area=1;char_col=(px-64)>>4;
            glyph_row=(y-32)>>1;glyph_col=(px-64)>>1;
            ch=static_char;
        end
        if(y>=48&&y<64&&px>=64&&px<576) begin
            text_area=1;char_col=(px-64)>>4;
            glyph_row=(y-48)>>1;glyph_col=(px-64)>>1;
            case((px-64)>>4)
                0:ch=hexchar(score_bcd[23:20]);1:ch=hexchar(score_bcd[19:16]);
                2:ch=hexchar(score_bcd[15:12]);3:ch=hexchar(score_bcd[11:8]);
                4:ch=hexchar(score_bcd[7:4]);5:ch=hexchar(score_bcd[3:0]);
                10:ch="X";11:ch=hexchar(coins_bcd[7:4]);12:ch=hexchar(coins_bcd[3:0]);
                19:ch="1";20:ch="-";21:ch="1";
                27:ch=hexchar(seconds_bcd[11:8]);28:ch=hexchar(seconds_bcd[7:4]);
                29:ch=hexchar(seconds_bcd[3:0]);
                default:ch=" ";
            endcase
        end
        if(!world_visible || !assets_loaded) begin
            panel=px>=128&&px<512&&y>=96&&y<384;
            if(px>=192&&px<448&&y>=128&&y<136) begin
                text_area=1;char_col=(px-192)>>3;
                ch=static_char;
            end
            if(px>=192&&px<448&&y>=352&&y<360) begin
                text_area=1;char_col=(px-192)>>3;
                ch=static_char;
            end
            if(px>=192&&px<448&&y>=336&&y<344&&state!=1) begin
                text_area=1;char_col=(px-192)>>3;
                ch=static_char;
            end
            if(state==1&&px>=192&&px<448&&y>=248&&y<256) begin
                text_area=1;char_col=(px-192)>>3;
                ch=static_char;
            end
            if(state==0&&px>=192&&px<448&&((y>=192&&y<200)||(y>=224&&y<232)||(y>=256&&y<264))) begin
                text_area=1;char_col=(px-192)>>3;
                ch=static_char;
            end
            if(state==1&&px>=264&&px<360&&y>=208&&y<224) begin
                text_area=1;glyph_row=(y-208)>>1;glyph_col=(px-264)>>1;
                char_col=(px-264)>>4;ch=name_character(player_name,char_col[2:0]);
            end
            if(state==1&&y>=232&&y<235&&px>=264+profile_cursor*16&&px<280+profile_cursor*16&&profile_cursor<6) begin text_area=1;ch="-";glyph_row=3;end
            if(state==5&&px>=192&&px<448&&y>=160&&y<320) begin
                if(!y[3]) begin
                    text_area=1;char_col=(px-192)>>3;
                    case(char_col)
                        0:ch=rank_index==9?"1":" ";
                        1:ch=rank_index==9?"0":hexchar(rank_index+1'b1);
                        3,4,5,6,7,8:ch=rank_valid?name_character(rank_name,char_col[2:0]-3'd3):"-";
                        10:ch=hexchar(rank_score_bcd[23:20]);11:ch=hexchar(rank_score_bcd[19:16]);
                        12:ch=hexchar(rank_score_bcd[15:12]);13:ch=hexchar(rank_score_bcd[11:8]);
                        14:ch=hexchar(rank_score_bcd[7:4]);15:ch=hexchar(rank_score_bcd[3:0]);
                        17:ch="T";
                        19:ch=hexchar(rank_time_bcd[19:16]);20:ch=hexchar(rank_time_bcd[15:12]);
                        21:ch=hexchar(rank_time_bcd[11:8]);22:ch=hexchar(rank_time_bcd[7:4]);
                        23:ch=hexchar(rank_time_bcd[3:0]);default:ch=" ";
                    endcase
                end
            end
        end else if(osd_enable&&player_x>=400&&player_x<640&&px>=160&&px<416&&y>=88&&y<96) begin
            text_area=1;ch=static_char;
        end else if(osd_enable&&player_x>=1100&&px>=160&&px<416&&y>=88&&y<96) begin
            text_area=1;ch=static_char;
        end
        if(debug_mode&&px>=160&&px<416&&y>=104&&y<112) begin
            text_area=1;ch=static_char;
        end
        if(debug_mode&&osd_enable&&px>=160&&px<416&&y>=368&&y<376) begin
            text_area=1;char_col=(px-160)>>3;
            case(char_col)
                6:ch=hexchar(event_code);17:ch=hexchar(player_x[11:8]);
                18:ch=hexchar(player_x[7:4]);19:ch=hexchar(player_x[3:0]);default:ch=static_char;
            endcase
        end
        if(!debug_mode&&osd_enable&&px>=80&&px<336&&y>=72&&y<80) begin
            text_area=1;ch=static_char;
        end
        // Fullscreen debug presents the complete BMP unobstructed when SW4=0.
        if(debug_mode&&media_fullscreen) begin panel=0;text_area=0;end
    end
    wire [4:0] glyph;
    osd_font font(ch,glyph_row,glyph);
    wire ink=text_area&&glyph_col<5&&glyph[4-glyph_col];
    reg hs1,vs1,de1,inside1,sprite1,tile1,ink1,panel1,debug1,loaded1,palette1,player1,fire1,star1,grow1;
    reg [23:0] media0,media1;reg [8:0] ly1;
    wire [23:0] alignment_rgb;
    reg [23:0] alignment_rgb1;
    generate if(ALIGNMENT)begin:alignment_pattern
        game_alignment_pattern pattern(.clk(clk),.rst(rst),.x(request_px),.y(scan_y),.offset(alignment_offset),.rgb(alignment_rgb));
    end else begin:no_alignment
        assign alignment_rgb=24'd0;
    end endgenerate
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            hs1<=0;vs1<=0;de1<=0;inside1<=0;sprite1<=0;tile1<=0;ink1<=0;panel1<=0;alignment_rgb1<=0;
            debug1<=0;media0<=0;media1<=0;loaded1<=0;palette1<=0;ly1<=0;player1<=0;fire1<=0;star1<=0;grow1<=0;
        end else begin
            media0<=media_rgb;
            alignment_rgb1<=alignment_rgb;
            hs1<=hs0;vs1<=vs0;de1<=de0;inside1<=inside_view;sprite1<=sprite_on;tile1<=tile!=0||decor_on;
            ink1<=ink;panel1<=panel;loaded1<=assets_loaded;palette1<=palette_mode;ly1<=ly;player1<=player_sprite;fire1<=fire_mario;
            star1<=player_star===1'b1;grow1<=transform_frames!=0&&transform_frames[1];
            debug1<=debug_mode&&media_valid&&(media_fullscreen||(px>=160&&px<480&&y>=120&&y<360));media1<=media0;
        end
    end
    reg [23:0] color;
    always @* begin
        color=inside1?24'h6b8cff:24'h101a30;
        if(loaded1&&tile1&&bg_index!=0) color=palette(bg_index);
        if(loaded1&&sprite1&&sprite_index!=0) begin
            color=palette(sprite_index);
            if(player1&&fire1&&(sprite_index==5||sprite_index==6)) color=24'hfefefe;
            if(player1&&star1)color=palette(sprite_index^{2'b0,anim});
            if(player1&&grow1)color=24'hfff0b0;
        end
        if(palette1) color={color[23:20],4'b0,color[15:12],4'b0,color[7:4],4'b0};
        if(panel1) color=(loaded1&&sprite1&&sprite_index!=0)?palette(sprite_index):24'h182940;
        if(debug1) color=media1;
        if(ink1) color=24'hffffff;
        if(ALIGNMENT&&alignment_active)color=alignment_rgb1;
    end
    always @(posedge clk or posedge rst)
        if(rst) begin hs_o<=0;vs_o<=0;de_o<=0;rgb_o<=0;end
        else begin hs_o<=hs1;vs_o<=vs1;de_o<=de1;rgb_o<=de1?color:24'd0;end
endmodule

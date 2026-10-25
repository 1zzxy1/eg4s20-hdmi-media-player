`timescale 1ns/1ps
`include "game_assets.vh"
module tb_game_video;
    reg clk=0,rst=1,hs=0,vs=0,de=0,debug=0,full=0,narrow=0,pal=0,osd=0;
    reg [11:0] mario_x=32;
    reg [255:0] debug_line="EVENT B  WORLD X ABC            ";
    integer debug_chars=0;
    reg [11:0] camera=0;
    reg [2:0] scene_state=2;
    reg crouch=0;reg [8:0] mario_y=160;
    reg [3:0] seen_enemy=0;
    reg seen_big_top=0,seen_big_bottom=0,seen_powerup=0,seen_fireball=0;
    reg seen_castle=0,seen_flag=0,seen_cloud=0,seen_hill=0,seen_bush=0;
    reg [6:0] seen_terrain=0;
    reg seen_boundary=0;
    reg [4:0] seen_hud=0;
    always #5 clk=~clk;
    wire [14:0] ba,sa;reg [3:0] bi=0,si=0;wire [3:0] rank;
    wire [11:0] map_addr;reg [7:0] map_data=0;
    wire ho,vo,dout,ft;wire [23:0] rgb;
    game_video dut(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.media_rgb(24'h123456),
        .death_active(1'b0),
        .media_valid(1'b1),.debug_mode(debug),.media_fullscreen(full),.osd_enable(osd),.view_narrow(narrow),.palette_mode(pal),.assets_loaded(1'b1),
        .state(scene_state),.player_x(mario_x),.player_y(mario_y),.camera_x(camera),.facing_left(1'b0),.anim(2'd0),
        .map_addr(map_addr),.map_data(map_data),
        .block_fx_addr(12'd0),.block_fx_frames(5'd0),.block_fx_kind(2'd0),
        .player_blink(1'b0),.player_star(1'b0),.transform_frames(5'd0),
        .effects_paused(1'b0),.reward_valid(1'b0),.reward_kind(4'd0),.reward_x(12'd0),.reward_y(9'd0),
        .enemy_x({12'd160,12'd128,12'd96,12'd64}),
        .enemy_y({9'd160,9'd160,9'd160,9'd160}),
        .enemy_kind({2'd3,2'd2,2'd1,2'd0}),.enemy_active(4'hf),
        .coins_count(8'd0),.player_crouch(crouch),.flag_phase(2'd0),.flag_y(9'd48),
        .powerup_active(1'b1),.powerup_x(12'd192),.powerup_y(9'd160),.powerup_kind(2'd2),.super_mario(1'b1),
        .fire_mario(1'b1),.fireball_active(2'b01),.fireball_x({12'd0,12'd224}),.fireball_y({9'd0,9'd160}),
        .enemy0_x(12'd272),.enemy1_x(12'd736),.enemy_alive(2'b0),.coin_mask(8'hff),.score(24'd0),
        .seconds_left(9'd120),.lives(4'd3),.player_name("AAA   "),.avatar(3'd0),.profile_cursor(3'd0),.event_code(4'hb),
        .save_busy(1'b0),.save_error(1'b0),.save_available(1'b1),.audio_enabled(1'b0),
        .bg_addr(ba),.sprite_addr(sa),.bg_index(bi),.sprite_index(si),.rank_index(rank),
        .rank_valid(1'b0),.rank_name(48'd0),.rank_score(24'd0),.rank_time(16'd0),.rank_avatar(3'd0),
        .hs_o(ho),.vs_o(vo),.de_o(dout),.rgb_o(rgb),.frame_tick(ft));
    reg [2:0] dep=0,hsp=0,vsp=0;
    integer count=0,px,py,f,x,y;
    always @(posedge clk) begin
        bi<=0;si<=0;
        case(map_addr)
            12'h900:map_data<=8'd3;
            12'h901:map_data<=8'd4;
            12'h902:map_data<=8'd6;
            12'h903:map_data<=8'd7;
            12'h904:map_data<=8'd8;
            12'h905:map_data<=8'd10;
            12'h906:map_data<=8'd11;
            default:map_data<=map_addr[11:8]>=13?8'd1:8'd0;
        endcase
        if(rst)begin dep<=0;hsp<=0;vsp<=0;end
        else begin
            dep<={dep[1:0],de};hsp<={hsp[1:0],hs};vsp<={vsp[1:0],vs};
            #1;
            if(dout!==dep[2]||ho!==hsp[2]||vo!==vsp[2])$fatal(1,"sync alignment");
            if(dout)begin
                px=count%640;py=(count/640)%480;
                if(!full&&py==200&&px==100&&rgb!==24'h6b8cff)$fatal(1,"sky");
                if(narrow&&!full&&py==200&&(px==0||px==20||px==639)&&rgb!==24'h6b8cff)
                    $fatal(1,"full-width zoom sky x=%0d got=%h",px,rgb);
                if(debug&&py==200&&px==200&&rgb!==24'h123456)$fatal(1,"debug window");
                if(full&&py==200&&px==20&&rgb!==24'h123456)$fatal(1,"debug fullscreen");
                if(full&&py==32&&px==80&&rgb!==24'h123456)$fatal(1,"debug fullscreen HUD leak");
                count=count+1;
            end else if(rgb!==0)$fatal(1,"blanking");
        end
    end
    always @(negedge clk) if(!rst&&de&&dut.inside_view) begin
        if(dut.lx!==(narrow?(dut.px*2)/5:dut.px/2))
            $fatal(1,"viewport coordinate x=%0d logical=%0d narrow=%0d",dut.px,dut.lx,narrow);
        if(osd&&debug&&dut.y>=368&&dut.y<376&&dut.px>=160&&dut.px<416)begin
            if(!dut.text_area||dut.ch!==debug_line[(31-((dut.px-160)>>3))*8+:8]||
               dut.glyph_row!==dut.y[2:0]||dut.glyph_col!==dut.px[2:0])
                $fatal(1,"debug character alignment x=%0d y=%0d ch=%h",dut.px,dut.y,dut.ch);
            debug_chars=debug_chars+1;
        end
        if(camera==0&&dut.y==32&&dut.px==64) begin
            if(!dut.text_area||dut.char_col!==0||dut.glyph_row!==0||dut.glyph_col!==0||dut.ch!=="M")
                $fatal(1,"HUD origin");
            seen_hud[0]=1;
        end
        if(camera==0&&dut.y==32&&dut.px==79) begin
            if(dut.char_col!==0||dut.glyph_col!==7)$fatal(1,"HUD right edge of first character");
            seen_hud[1]=1;
        end
        if(camera==0&&dut.y==32&&dut.px==80) begin
            if(dut.char_col!==1||dut.glyph_col!==0||dut.ch!=="A")$fatal(1,"HUD second character boundary");
            seen_hud[2]=1;
        end
        if(camera==0&&dut.y==48&&dut.px==64) begin
            if(dut.char_col!==0||dut.glyph_row!==0||dut.ch!=="0")$fatal(1,"HUD value row");
            seen_hud[3]=1;
        end
        if(camera==0&&dut.y==47&&dut.px==575) begin
            if(dut.char_col!==31||dut.glyph_row!==7||dut.glyph_col!==7)$fatal(1,"HUD far edge");
            seen_hud[4]=1;
        end
        if(camera==0&&dut.ly==160) begin
            if(dut.wx==32) begin
                if(dut.stile!==(crouch?`GAME_TILE_BIG_CROUCH_TOP:`GAME_TILE_BIG_IDLE_TOP))$fatal(1,"big mario top");
                seen_big_top=1;
            end
            if(dut.wx==64) begin
                if(dut.stile!==`GAME_TILE_ENEMY0)$fatal(1,"goomba slot 0");
                seen_enemy[0]=1;
            end
            if(dut.wx==96) begin
                if(dut.stile!==`GAME_TILE_KOOPA_TOP)$fatal(1,"koopa slot 1");
                seen_enemy[1]=1;
            end
            if(dut.wx==128) begin
                if(dut.stile!==`GAME_TILE_SHELL)$fatal(1,"shell slot 2");
                seen_enemy[2]=1;
            end
            if(dut.wx==160) begin
                if(dut.stile!==`GAME_TILE_SHELL)$fatal(1,"sliding shell slot 3");
                seen_enemy[3]=1;
            end
            if(dut.wx==192) begin
                if(dut.stile!==`GAME_TILE_STAR)$fatal(1,"star powerup");
                seen_powerup=1;
            end
            if(dut.wx==224) begin
                if(dut.stile!==`GAME_TILE_FIREBALL)$fatal(1,"fireball");
                seen_fireball=1;
            end
        end
        if(camera==0&&dut.ly==176&&dut.wx==32) begin
            if(dut.stile!==(crouch?`GAME_TILE_BIG_CROUCH_BOTTOM:`GAME_TILE_BIG_IDLE_BOTTOM))$fatal(1,"big mario bottom");
            seen_big_bottom=1;
        end
        if(camera==0&&dut.ly==144&&dut.wx[3:0]==0&&dut.wx<112) begin
            case(dut.wx[7:4])
                0,1:if(dut.bg_addr[14:8]!==`GAME_TILE_QUESTION)$fatal(1,"question terrain");
                2:if(dut.bg_addr[14:8]!==`GAME_TILE_STONE)$fatal(1,"stone terrain");
                3:if(dut.bg_addr[14:8]!==`GAME_TILE_PIPE_TL)$fatal(1,"pipe left terrain");
                4:if(dut.bg_addr[14:8]!==`GAME_TILE_PIPE_TR)$fatal(1,"pipe right terrain");
                5:if(dut.bg_addr[14:8]!==`GAME_TILE_PIPE_BR)$fatal(1,"pipe body terrain");
                6:if(dut.bg_addr[14:8]!==`GAME_TILE_EMPTY)$fatal(1,"hidden 1UP must be invisible");
            endcase
            seen_terrain[dut.wx[7:4]]=1;
        end
        if(camera==0&&dut.ly==144&&dut.wx==15) begin
            if(dut.bg_addr[14:8]!==`GAME_TILE_QUESTION||dut.bg_addr[3:0]!==4'd15)
                $fatal(1,"tile right edge x15");
            seen_boundary=1;
        end
        if(camera==0&&dut.ly==144&&dut.wx==16) begin
            if(dut.bg_addr[14:8]!==`GAME_TILE_QUESTION||dut.bg_addr[3:0]!==4'd0)
                $fatal(1,"tile left edge x16");
        end
        if(camera==0&&dut.ly==32&&dut.wx==96) begin
            if(dut.bg_addr[14:8]!==`GAME_TILE_CLOUD_00)$fatal(1,"cloud");
            seen_cloud=1;
        end
        if(camera==0&&dut.ly==176&&dut.wx==288) begin
            if(dut.bg_addr[14:8]!==`GAME_TILE_HILL_00)$fatal(1,"hill");
            seen_hill=1;
        end
        if(camera==400&&dut.ly==192&&dut.wx==432) begin
            if(dut.bg_addr[14:8]!==`GAME_TILE_BUSH_L)$fatal(1,"bush");
            seen_bush=1;
        end
        if(camera==0&&dut.ly==176&&dut.wx==320&&dut.sprite_on)
            $fatal(1,"obsolete uncollectable coin overlay");
        if(camera==3136&&dut.ly==128&&dut.wx==3232) begin
            if(dut.bg_addr[14:8]!==`GAME_TILE_CASTLE_00)$fatal(1,"castle");
            if(dut.panel)$fatal(1,"finish animation obscured by menu");
            seen_castle=1;
        end
        if(camera==3136&&dut.ly==48&&dut.wx==3168) begin
            if(dut.stile!==`GAME_TILE_FLAG_POLE_BODY)$fatal(1,"flag pole");
            seen_flag=1;
        end
    end
    initial begin
        repeat(4)@(negedge clk);rst=0;
        for(f=0;f<4;f=f+1)begin
            narrow=f==1||f==2;debug=f>=2;full=f==2;osd=f==3;
            mario_x=f==3?12'habc:12'd32;
            camera=f==1?12'd3136:f>=2?12'd400:12'd0;
            scene_state=f==1?3'd6:3'd2;crouch=f==2;mario_y=crouch?9'd176:9'd160;
            for(y=0;y<525;y=y+1)for(x=0;x<800;x=x+1)begin
                hs=x<96;vs=y<2;de=x>=160&&y>=45;@(negedge clk);
            end
        end
        de=0;repeat(4)@(negedge clk);
        if(count!=1228800||debug_chars!=2048)$fatal(1,"pixel count %0d debug chars=%0d",count,debug_chars);
        if(seen_enemy!==4'hf||seen_terrain!==7'h7f||seen_hud!==5'h1f||!seen_boundary||!seen_big_top||!seen_big_bottom||!seen_powerup||
           !seen_fireball||!seen_castle||!seen_flag||!seen_cloud||!seen_hill||!seen_bush)
            $fatal(1,"missing sprite coverage enemy=%b terrain=%b edge=%b big=%b%b power=%b fire=%b castle=%b flag=%b decor=%b%b%b",
                   seen_enemy,seen_terrain,seen_boundary,seen_big_top,seen_big_bottom,
                   seen_powerup,seen_fireball,seen_castle,seen_flag,seen_cloud,seen_hill,seen_bush);
        $display("PASS game video: four full frames, every-column full-width zoom, debug overlay/dynamic characters, sync/blanking");$finish;
    end
endmodule

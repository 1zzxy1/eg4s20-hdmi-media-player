`timescale 1ns/1ps
`include "game_assets.vh"
// Real generated BMP -> texture cache -> synchronous texel reads -> HDMI raster.
module tb_game_scene;
    reg clk=0,rst=1,asset_begin=0,asset_we=0,asset_commit=0;
    reg [23:0] asset_rgb=0;
    always #5 clk=~clk;
    reg hs=0,vs=0,de=0;
    reg [2:0] scene_state=2,scene_avatar=0,scene_cursor=0;
    reg [11:0] scene_camera=0,scene_player_x=32;
    reg [8:0] scene_player_y=192,scene_flag_y=48;
    reg scene_super=0,scene_fire=0,scene_death=0;
    reg [1:0] scene_flag_phase=0,scene_anim=0;
    integer clear_mode=0,clear_pixels=0,clear_tile,clear_address,clear_u,clear_v;
    reg [23:0] clear_expected;
    reg [11:0] scene_fx_addr=0;
    reg [4:0] scene_fx_frames=0,scene_transform=0;
    reg [1:0] scene_fx_kind=0;
    reg scene_effects_paused=1,scene_reward_valid=0;
    reg [3:0] scene_reward_kind=0;
    reg [11:0] scene_reward_x=0;
    reg [8:0] scene_reward_y=0;
    integer reward_mode=0,reward_pixels=0,reward_address;
    integer fire_light_samples=0,fire_red_samples=0;
    reg fire_color_check;
    reg [23:0] fire_color_expected;
    reg [23:0] reward_expected;
    integer death_mode=0,death_pixels=0,death_v,death_address;
    reg [23:0] death_expected,death_texel;
    reg [47:0] scene_enemy_x=0;
    reg [35:0] scene_enemy_y=0;
    reg [7:0] scene_enemy_kind=0;
    reg [3:0] scene_enemy_active=0;
    reg [1:0] scene_fireball_active=0;
    reg [23:0] scene_fireball_x=0;
    reg [17:0] scene_fireball_y=0;
    reg [47:0] scene_name="AAA   ";
    wire rank_valid;
    reg [47:0] rank_name=0;
    reg [23:0] rank_score=0;
    reg [15:0] rank_time=0;
    reg [2:0] rank_avatar=0;
    assign rank_valid=scene_state==5 && rank_index==0;
    wire [14:0] bg_addr,sprite_addr;
    wire [3:0] bg_index,sprite_index;
    wire [11:0] map_addr;wire [7:0] map_data;wire map_ready;
    wire loaded,hs_o,vs_o,de_o,frame_tick;
    wire [23:0] rgb_o;
    wire [3:0] rank_index;
    reg [7:0] bmp [0:921653];
    integer file_handle,out_file,x,y,n,pixel_count=0,ground_count=0,player_count=0;
    integer scoreboard_x=0,scoreboard_y=0;
    reg [2:0] hs_pipe=0,vs_pipe=0,de_pipe=0;
    reg [23:0] ground_sample,player_sample;
    game_texture_cache texture(
        .write_clk(clk),.write_rst(rst),.asset_begin(asset_begin),.asset_we(asset_we),
        .asset_rgb(asset_rgb),.asset_commit(asset_commit),.read_clk(clk),.read_rst(rst),
        .bg_addr(bg_addr),.sprite_addr(sprite_addr),.bg_index(bg_index),
        .sprite_index(sprite_index),.loaded(loaded));
    game_level_map level_map(.clk(clk),.rst(rst),.reload(1'b0),.ready(map_ready),
        .world_addr(12'd0),.world_data(),.world_we(1'b0),.world_wdata(8'd0),
        .video_addr(map_addr),.video_data(map_data));
    game_video video(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.media_rgb(24'd0),
        .death_active(scene_death),
        .media_valid(1'b0),.debug_mode(1'b0),.media_fullscreen(1'b0),.osd_enable(1'b0),
        .view_narrow(1'b0),.palette_mode(1'b0),.assets_loaded(loaded),
        .state(scene_state),.player_x(scene_player_x),.player_y(scene_player_y),.camera_x(scene_camera),
        .map_addr(map_addr),.map_data(map_data),
        .block_fx_addr(scene_fx_addr),.block_fx_frames(scene_fx_frames),.block_fx_kind(scene_fx_kind),
        .player_blink(scene_death),.player_star(scene_death),.transform_frames(scene_transform),
        .effects_paused(scene_effects_paused),.reward_valid(scene_reward_valid),
        .reward_kind(scene_reward_kind),.reward_x(scene_reward_x),.reward_y(scene_reward_y),
        .enemy_x(scene_enemy_x),.enemy_y(scene_enemy_y),.enemy_kind(scene_enemy_kind),.enemy_active(scene_enemy_active),
        .coins_count(8'd0),.player_crouch(1'b0),.flag_phase(scene_flag_phase),.flag_y(scene_flag_y),
        .powerup_active(1'b0),.powerup_x(12'd0),.powerup_y(9'd0),.powerup_kind(2'd0),.super_mario(scene_super),
        .fire_mario(scene_fire),.fireball_active(scene_fireball_active),.fireball_x(scene_fireball_x),.fireball_y(scene_fireball_y),
        .facing_left(1'b0),.anim(scene_anim),.enemy0_x(12'd272),.enemy1_x(12'd736),
        .enemy_alive(2'd0),.coin_mask(8'hff),.score(24'd0),
        .seconds_left(9'd400),.lives(4'd3),.player_name(scene_name),.avatar(scene_avatar),
        .profile_cursor(scene_cursor),.event_code(4'd0),.save_busy(1'b0),.save_error(1'b0),
        .save_available(1'b1),.audio_enabled(1'b0),
        .bg_addr(bg_addr),.sprite_addr(sprite_addr),.bg_index(bg_index),
        .sprite_index(sprite_index),.rank_index(rank_index),.rank_valid(rank_valid),
        .rank_name(rank_name),.rank_score(rank_score),.rank_time(rank_time),.rank_avatar(rank_avatar),
        .hs_o(hs_o),.vs_o(vs_o),.de_o(de_o),.rgb_o(rgb_o),.frame_tick(frame_tick));

    // Independent 5x7 glyph golden constants, not the DUT font output.
    function [23:0] label_pixel(input [31:0] letters,input integer local_x,input integer local_y);
        reg [7:0] letter;
        reg [55:0] glyph;
        reg [7:0] row_bits;
        integer row,col;
        begin
            letter=letters>>(24-(local_x/16)*8);
            case(letter)
                "0":glyph=56'h0e11131519110e;"1":glyph=56'h040c040404040e;
                "2":glyph=56'h0e11010204081f;"U":glyph=56'h1111111111110e;
                "P":glyph=56'h1e11111e101010;default:glyph=0;
            endcase
            row=local_y/2;col=(local_x%16)/2;
            row_bits=row<7?glyph>>((6-row)*8):0;
            label_pixel=col<5&&row_bits[4-col]?24'hffffff:24'h6b8cff;
        end
    endfunction
    always @(posedge clk) begin
        if(rst) begin hs_pipe<=0;vs_pipe<=0;de_pipe<=0;end
        else begin
            fire_color_check=scene_fire && scene_state==2 && video.player1 &&
                video.fire1 && video.loaded1 && video.sprite1 &&
                (sprite_index==4'd6 || sprite_index==4'd9);
            fire_color_expected=sprite_index==4'd6?`GAME_PAL_3:`GAME_PAL_6;
            hs_pipe<={hs_pipe[1:0],hs};vs_pipe<={vs_pipe[1:0],vs};de_pipe<={de_pipe[1:0],de};
            #1;
            if(fire_color_check) begin
                if(fire_color_expected==`GAME_PAL_3)
                    fire_light_samples=fire_light_samples+1;
                else fire_red_samples=fire_red_samples+1;
                if(rgb_o!==fire_color_expected)
                    $fatal(1,"fire Mario color index=%0d got=%h expected=%h",
                           sprite_index,rgb_o,fire_color_expected);
            end
            if(hs_o!==hs_pipe[2]||vs_o!==vs_pipe[2]||de_o!==de_pipe[2])
                $fatal(1,"scene raster sync misaligned");
            if(de_o) begin
                if(pixel_count>=307200)$fatal(1,"scene emitted too many pixels");
                scoreboard_x=pixel_count%640;scoreboard_y=pixel_count/640;
                if(scene_state==2 && scoreboard_y==432 && scoreboard_x>=80 && scoreboard_x<176 && rgb_o==ground_sample)
                    ground_count=ground_count+1;
                if(scene_state==2 && scoreboard_y>=384 && scoreboard_y<416 && scoreboard_x>=64 && scoreboard_x<96 && rgb_o==player_sample)
                    player_count=player_count+1;
                reward_expected=24'hxxxxxx;
                if(reward_mode==1&&scoreboard_x>=320&&scoreboard_x<352&&scoreboard_y>=208&&scoreboard_y<240)begin
                    reward_address=54+(479-(scoreboard_y-208)/2)*1920+
                        (80+(scoreboard_x-320)/2)*3;
                    reward_expected={bmp[reward_address+2],bmp[reward_address+1],bmp[reward_address]};
                    if(reward_expected==24'hff00ff)reward_expected=24'h6b8cff;
                end
                if(reward_mode==2&&scoreboard_x>=312&&scoreboard_x<360&&scoreboard_y>=176&&scoreboard_y<192)
                    reward_expected=label_pixel("200 ",scoreboard_x-312,scoreboard_y-176);
                if(reward_mode>=2&&scoreboard_x>=440&&scoreboard_x<488&&scoreboard_y>=224&&scoreboard_y<240)
                    reward_expected=label_pixel("1UP ",scoreboard_x-440,scoreboard_y-224);
                if(reward_mode==3&&scoreboard_x>=304&&scoreboard_x<368&&scoreboard_y>=224&&scoreboard_y<240)
                    reward_expected=label_pixel("1000",scoreboard_x-304,scoreboard_y-224);
                if(reward_expected!==24'hxxxxxx)begin
                    reward_pixels=reward_pixels+1;
                    if(rgb_o!==reward_expected)$fatal(1,"reward raster mode=%0d xy=%0d,%0d got=%h expected=%h",
                        reward_mode,scoreboard_x,scoreboard_y,rgb_o,reward_expected);
                end
                // Read original BMP texels independently of the DUT addresses.
                // Door stripe covers both halves of a large player's old bounds.
                if(clear_mode!=0&&scoreboard_y>=352&&scoreboard_y<416&&
                   ((clear_mode==1&&scoreboard_x>=128&&scoreboard_x<160)||
                    (clear_mode>=2&&scoreboard_x>=256&&scoreboard_x<288)))begin
                    clear_u=(scoreboard_x/2)%16;clear_v=(scoreboard_y/2)%16;
                    clear_expected=24'h6b8cff;
                    if(clear_mode==1)begin
                        if(scoreboard_y>=384)begin
                            clear_tile=8;
                            clear_address=54+(479-(clear_tile/8)*16-clear_v)*1920+
                                ((clear_tile%8)*16+clear_u)*3;
                            clear_expected={bmp[clear_address+2],bmp[clear_address+1],bmp[clear_address]};
                        end
                    end else begin
                        clear_tile=scoreboard_y<384?54:59;
                        clear_address=54+(479-(clear_tile/8)*16-clear_v)*1920+
                            ((clear_tile%8)*16+clear_u)*3;
                        clear_expected={bmp[clear_address+2],bmp[clear_address+1],bmp[clear_address]};
                    end
                    if(clear_expected==24'hff00ff)clear_expected=24'h6b8cff;
                    clear_pixels=clear_pixels+1;
                    if(rgb_o!==clear_expected)$fatal(1,"clear raster mode=%0d xy=%0d,%0d got=%h expected=%h",
                        clear_mode,scoreboard_x,scoreboard_y,rgb_o,clear_expected);
                end
                // Independently sample original BMP colors, including transparent
                // death texels over ground and signed top clipping. This stripe
                // avoids HUD/decor so every one of its 480 rows has a golden.
                if(death_mode>=1&&death_mode<=4&&scoreboard_x>=32&&scoreboard_x<64)begin
                    death_expected=24'h6b8cff;
                    if(scoreboard_y>=416)begin
                        death_address=54+(479-((scoreboard_y/2)%16))*1920+
                            (16+(scoreboard_x-32)/2)*3;
                        death_expected={bmp[death_address+2],bmp[death_address+1],bmp[death_address]};
                    end
                    death_v=(scoreboard_y/2-scene_player_y)&511;
                    if(death_v<16)begin
                        // Tile 19 is atlas column 3, row 2 (8 tiles per row).
                        death_address=54+(479-32-death_v)*1920+(48+(scoreboard_x-32)/2)*3;
                        death_texel={bmp[death_address+2],bmp[death_address+1],bmp[death_address]};
                        if(death_texel!=24'hff00ff)death_expected=death_texel;
                    end
                    death_pixels=death_pixels+1;
                    if(rgb_o!==death_expected)$fatal(1,"death raster mode=%0d xy=%0d,%0d got=%h expected=%h",
                        death_mode,scoreboard_x,scoreboard_y,rgb_o,death_expected);
                end
                if(death_mode==5&&scoreboard_x==200&&scoreboard_y==200)begin
                    death_pixels=death_pixels+1;
                    if(rgb_o!==24'h182940)$fatal(1,"death prompt panel did not return");
                end
                $fwrite(out_file,"%c%c%c",rgb_o[23:16],rgb_o[15:8],rgb_o[7:0]);
                pixel_count=pixel_count+1;
            end else if(rgb_o!==0) $fatal(1,"nonblack blanking");
        end
    end
    task capture_frame(input [1023:0] filename);
        begin
            pixel_count=0;
            out_file=$fopen(filename,"wb");
            if(!out_file)$fatal(1,"cannot create %0s",filename);
            $fwrite(out_file,"P6\n640 480\n255\n");
            for(y=0;y<525;y=y+1) for(x=0;x<800;x=x+1) begin
                hs=x<96;vs=y<2;de=x>=160&&y>=45;
                @(negedge clk);
            end
            de=0;repeat(4)@(negedge clk);
            $fclose(out_file);
            if(pixel_count!=307200)$fatal(1,"%0s pixel count=%0d",filename,pixel_count);
            $display("SCENE captured %0s pixels=%0d",filename,pixel_count);
            $fflush();
        end
    endtask
    task emit_reward(input [3:0] code,input [11:0] rx,input [8:0] ry);
        @(negedge clk);scene_reward_valid=1;scene_reward_kind=code;scene_reward_x=rx;scene_reward_y=ry;
        @(negedge clk);scene_reward_valid=0;
    endtask
    task advance_reward_frame;
        @(negedge clk);vs=1;repeat(4)@(negedge clk);
        vs=0;repeat(4)@(negedge clk);
    endtask

    initial begin
        file_handle=$fopen("assets/game/atlas.bmp","rb");
        if(!file_handle)$fatal(1,"missing generated atlas.bmp");
        n=$fread(bmp,file_handle);$fclose(file_handle);
        if(n!=921654 || bmp[0]!=8'h42 || bmp[1]!=8'h4d)
            $fatal(1,"unexpected 640x480 BMP layout, bytes=%0d",n);
        // Known pixel color from tile 1 and tile 7, independently taken from the BMP.
        ground_sample={bmp[54+479*1920+16*3+2],
                       bmp[54+479*1920+16*3+1],bmp[54+479*1920+16*3]};
        player_sample={bmp[54+479*1920+117*3+2],
                       bmp[54+479*1920+117*3+1],bmp[54+479*1920+117*3]};
        repeat(4)@(negedge clk);rst=0;
        wait(map_ready);
        @(negedge clk);asset_begin=1;@(negedge clk);asset_begin=0;
        for(y=479;y>=0;y=y-1) for(x=0;x<640;x=x+1) begin
            n=54+(479-y)*1920+x*3;
            asset_rgb={bmp[n+2],bmp[n+1],bmp[n]};asset_we=1;
            @(negedge clk);
        end
        asset_we=0;repeat(3)@(negedge clk);
        if(loaded)$fatal(1,"atlas published before commit");
        asset_commit=1;repeat(4)@(negedge clk);asset_commit=0;
        if(!loaded)$fatal(1,"valid generated atlas rejected");
        capture_frame("build/game_sim/game_scene.ppm");
        if(ground_count<40 || player_count<10)
            $fatal(1,"real atlas colors missing ground=%0d player=%0d samples=%h/%h",
                   ground_count,player_count,ground_sample,player_sample);
        scene_camera=12'd128;scene_player_x=12'd256;scene_player_y=9'd168;
        scene_fx_addr=12'h910;scene_fx_frames=8;scene_fx_kind=3;
        capture_frame("build/game_sim/game_bounce.ppm");
        scene_fx_addr=12'h914;scene_fx_frames=12;scene_fx_kind=2;
        capture_frame("build/game_sim/game_debris.ppm");
        scene_fx_frames=0;scene_super=1;scene_player_y=9'd176;scene_transform=18;
        capture_frame("build/game_sim/game_transform.ppm");
        scene_transform=0;
        scene_camera=12'd800;scene_player_x=12'd880;scene_player_y=9'd176;
        scene_super=1;scene_fire=1;scene_enemy_x={36'd0,12'd944};
        scene_enemy_y={27'd0,9'd192};scene_enemy_kind=8'd1;scene_enemy_active=4'b0001;
        scene_fireball_active=2'b01;scene_fireball_x={12'd0,12'd1024};
        scene_fireball_y={9'd0,9'd160};
        capture_frame("build/game_sim/game_midcourse.ppm");
        if(fire_light_samples<100 || fire_red_samples<100)
            $fatal(1,"fire Mario colors not exercised light=%0d red=%0d",
                   fire_light_samples,fire_red_samples);
        scene_camera=12'd3136;scene_player_x=12'd3168;scene_player_y=9'd176;
        scene_enemy_active=0;scene_fireball_active=0;scene_state=6;scene_flag_y=9'd128;
        capture_frame("build/game_sim/game_finish.ppm");
        scene_state=7;scene_flag_phase=2;scene_anim=1;scene_player_x=3200;
        scene_player_y=192;scene_super=0;scene_fire=0;clear_mode=1;
        capture_frame("build/game_sim/game_castle_walk.ppm");
        scene_flag_phase=3;scene_anim=0;scene_player_x=3264;clear_mode=2;
        capture_frame("build/game_sim/game_castle_door_small.ppm");
        scene_super=1;scene_player_y=176;clear_mode=3;
        capture_frame("build/game_sim/game_castle_door_big.ppm");
        if(clear_pixels!=6144)$fatal(1,"clear golden pixel coverage=%0d",clear_pixels);
        clear_mode=0;scene_flag_phase=0;
        scene_player_x=3168;scene_player_y=176;scene_super=1;scene_fire=1;
        scene_state=0;
        capture_frame("build/game_sim/game_title.ppm");
        scene_state=1;scene_name="PIXEL1";scene_avatar=3;scene_cursor=6;
        capture_frame("build/game_sim/game_profile.ppm");
        scene_state=5;rank_name="PLAYER";rank_score=24'd123450;
        rank_time=16'd87;rank_avatar=3'd5;
        capture_frame("build/game_sim/game_leaderboard.ppm");
        scene_state=2;scene_camera=0;scene_player_x=32;scene_player_y=192;
        scene_super=0;scene_fire=0;
        emit_reward(0,160,120);reward_mode=1;
        capture_frame("build/game_sim/game_reward_coin.ppm");
        scene_effects_paused=0;repeat(24)advance_reward_frame();scene_effects_paused=1;
        emit_reward(3,224,120);reward_mode=2;
        capture_frame("build/game_sim/game_reward_200_1up.ppm");
        emit_reward(2,160,120);reward_mode=3;
        capture_frame("build/game_sim/game_reward_1000_1up.ppm");
        if(reward_pixels!=4352)$fatal(1,"reward golden pixel coverage=%0d",reward_pixels);
        reward_mode=0;scene_state=3;scene_death=1;scene_player_x=16;scene_player_y=196;
        scene_super=1;scene_fire=1;scene_transform=18;death_mode=1;
        capture_frame("build/game_sim/game_death_hold.ppm");
        scene_player_y=144;death_mode=2;
        capture_frame("build/game_sim/game_death_rise.ppm");
        scene_player_y=506;death_mode=3;
        capture_frame("build/game_sim/game_death_top_clip.ppm");
        scene_player_y=256;death_mode=4;
        capture_frame("build/game_sim/game_death_fallen.ppm");
        scene_death=0;death_mode=5;
        capture_frame("build/game_sim/game_death_prompt.ppm");
        if(death_pixels!=61441)$fatal(1,"death golden pixel coverage=%0d",death_pixels);
        $display("PASS game scene: real BMP atlas, twenty 307200-pixel frames, reward golden=%0d death/clipping/panel golden=%0d clear golden=%0d, ground=%0d player=%0d",reward_pixels,death_pixels,clear_pixels,ground_count,player_count);
        $finish;
    end
    initial begin #100000000;$fatal(1,"game scene timeout");end
endmodule

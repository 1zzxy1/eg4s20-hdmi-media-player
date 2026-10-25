// Stable game/HDMI path with an independent, optional lobby multimedia lab.
module media_player_top(
    input wire clk,input wire [3:0] keys_n,input wire [3:0] switches,
    output wire [3:0] led,
    output wire HDMI_CLK_P,HDMI_D0_P,HDMI_D1_P,HDMI_D2_P,HDMI_DDC_SCL,inout wire HDMI_DDC_SDA,
    output wire sd_ncs,sd_dclk,sd_mosi,input wire sd_miso,
    output wire flash_cs_n,flash_sck,flash_mosi,input wire flash_miso,output wire flash_wp_n,flash_hold_n);
    wire sd_clk,mem_clk,mem_clk_shift,pix_clk,serial_clk,sys_lock,video_lock,arst,rst_sd,rst_mem,rst_pix;
    sys_pll u_sys(.refclk(clk),.reset(1'b0),.locked(sys_lock),
        .clk0_out(sd_clk),.clk1_out(mem_clk),.clk2_out(mem_clk_shift));
    video_pll u_vid(.refclk(clk),.reset(1'b0),.locked(video_lock),
        .clk0_out(pix_clk),.clk1_out(serial_clk));
    game_boot_reset u_boot(.clk(sd_clk),.locked(sys_lock&&video_lock),.arst(arst));
    reset_sync u_rsd(sd_clk,arst,rst_sd);
    reset_sync u_rmem(mem_clk,arst,rst_mem);
    reset_sync u_rpix(pix_clk,arst,rst_pix);
    wire frame_tick,held_left,held_right,jump_hold,held_run,held_down;
    wire left_press,right_press,jump_press,jump_short,jump_long,back_press,sound_toggle;
    wire [2:0] game_state;
    wire [3:0] frame_switches;
    wire alignment_active,alignment_block;
    wire [9:0] alignment_offset;
    game_display_alignment u_alignment(.clk(pix_clk),.rst(rst_pix),.frame_tick(frame_tick),
        .keys_n(keys_n),.switches({1'b0,(switches[2]&&!switches[0]&&!switches[3]),2'b00}),.active(alignment_active),
        .block_controls(alignment_block),.offset(alignment_offset));
    wire lab_active,debug_mode,media_fullscreen,osd_enable,calibration;
    wire menu_active=lab_active||alignment_block;
    wire view_narrow,palette_mode,reset_game,scores_request,profile_request;
    wire audio_enabled,test_tone,audition;
    wire [4:0] audition_id;
    wire [1:0] master_volume,bgm_volume,sfx_volume,brightness,display_contrast,display_transition;
    wire [2:0] menu_page,menu_selection;
    wire auto_action,next_action,previous_action;
    wire auto_key_n,next_key_n,previous_key_n;
    game_menu u_menu(.clk(pix_clk),.rst(rst_pix),.frame_tick(frame_tick),.game_state(game_state),
        .switches(alignment_block?4'd0:{frame_switches[3],frame_switches[2]&&frame_switches[0],frame_switches[1:0]}),
        .back_press(back_press),.left_press(left_press),.right_press(right_press),
        .confirm(jump_press),.confirm_long(jump_long),.active(lab_active),.debug_mode(debug_mode),
        .page(menu_page),.selection(menu_selection),.view_narrow(view_narrow),.palette_mode(palette_mode),
        .osd_enable(osd_enable),.calibration(calibration),.audio_enabled(audio_enabled),.test_tone(test_tone),
        .brightness(brightness),.contrast(display_contrast),.transition_mode(display_transition),
        .master_volume(master_volume),.bgm_volume(bgm_volume),.sfx_volume(sfx_volume),
        .media_fullscreen(media_fullscreen),.auto_action(auto_action),.next_action(next_action),
        .previous_action(previous_action),.reset_game(reset_game),.profile_request(profile_request),
        .scores_request(scores_request),.audition(audition),.audition_id(audition_id));
    menu_media_controls #(.SHORT_CYCLES(1_250_000)) u_media_controls(.clk(pix_clk),.rst(rst_pix),
        .auto_action(auto_action),.next_action(next_action),.previous_action(previous_action),
        .effect_action(1'b0),.contrast_action(1'b0),.auto_key_n(auto_key_n),
        .next_key_n(next_key_n),.previous_key_n(previous_key_n));
    game_inputs u_in(.clk(pix_clk),.rst(rst_pix),.frame_tick(frame_tick),
        .keys_n(alignment_block?4'hf:keys_n),.switches(switches),
        .gameplay_active(game_state==2||game_state==6||game_state==7),.debug_mode(menu_active),
        .held_left(held_left),.held_right(held_right),.jump_hold(jump_hold),.held_run(held_run),
        .held_down(held_down),.left_press(left_press),.right_press(right_press),
        .jump_press(jump_press),.jump_short(jump_short),.jump_long(jump_long),
        .back_press(back_press),.reset_game(),.sound_toggle(sound_toggle),
        .frame_switches(frame_switches));
    wire sd_audio_req,sd_audio_valid,sd_audio_end,sd_audio_initialized;
    wire [31:0] sd_audio_addr;
    wire [7:0] sd_audio_data;
    wire asset_begin,asset_we,asset_commit,asset_failed,assets_loaded;
    wire [23:0] asset_rgb;
    wire card_req,card_valid,card_end;
    wire [31:0] card_addr;
    wire [7:0] card_data;
    wire gallery_req,gallery_valid,gallery_end;
    wire [31:0] gallery_addr;
    wire [7:0] gallery_data;
    sd_sector_arbiter u_sector_share(.clk(sd_clk),.rst(rst_sd),.initialized(sd_audio_initialized),
        .bmp_req(gallery_req),.bmp_addr(gallery_addr),.audio_req(sd_audio_req),.audio_addr(sd_audio_addr),
        .sd_req(card_req),.sd_addr(card_addr),.sd_data(card_data),.sd_valid(card_valid),.sd_end(card_end),
        .bmp_data(gallery_data),.bmp_valid(gallery_valid),.bmp_end(gallery_end),
        .audio_data(sd_audio_data),.audio_valid(sd_audio_valid),.audio_end(sd_audio_end));
    sd_card_top u_card(.clk(sd_clk),.rst(rst_sd),.SD_nCS(sd_ncs),.SD_DCLK(sd_dclk),
        .SD_MOSI(sd_mosi),.SD_MISO(sd_miso),.sd_init_done(sd_audio_initialized),
        .sd_sec_read(card_req),.sd_sec_read_addr(card_addr),.sd_sec_read_data(card_data),
        .sd_sec_read_data_valid(card_valid),.sd_sec_read_end(card_end),
        .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
        .sd_sec_write_data_req(),.sd_sec_write_end());
    wire media_hs,media_vs,media_de,read_req,raw_hs,raw_vs,raw_de;
    wire [23:0] adjusted_media;
    wire active_valid;
    wire [2:0] cache_count;
    wire [6:0] image_index,image_count;
    wire [4:0] fade_gain;
    wire [1:0] effect_mode;
    // The game renders from texture RAM. No SDRAM read handshake gates its raster.
    video_timing_data u_timing(.video_clk(pix_clk),.rst(rst_pix),
        .read_req(read_req),.read_req_ack(read_req),
        .hs(raw_hs),.vs(raw_vs),.de(raw_de));
    media_gallery u_gallery(.sd_clk(sd_clk),.mem_clk(mem_clk),.mem_clk_shift(mem_clk_shift),
        .pix_clk(pix_clk),.rst_sd(rst_sd),.rst_mem(rst_mem),.rst_pix(rst_pix),
        .initialized(sd_audio_initialized),.assets_ready(assets_loaded),.enabled(debug_mode),
        .next_key_n(next_key_n),.previous_key_n(previous_key_n),.auto_key_n(auto_key_n),
        .hs(raw_hs),.vs(raw_vs),.de(raw_de),.frame_request(read_req),
        .alignment_offset(alignment_offset),.transition_mode(display_transition),
        .request(gallery_req),.sector(gallery_addr),.data(gallery_data),.valid(gallery_valid),.sector_end(gallery_end),
        .hs_o(media_hs),.vs_o(media_vs),.de_o(media_de),.rgb(adjusted_media),
        .image_ready(active_valid),.fade_gain(fade_gain),.effect_mode(effect_mode),
        .cache_count(cache_count),.image_index(image_index),.image_count(image_count),
        .asset_begin(asset_begin),.asset_we(asset_we),.asset_commit(asset_commit),
        .asset_rgb(asset_rgb),.asset_failed(asset_failed));
    wire [14:0] bg_addr,sprite_addr;
       wire [3:0] bg_index,sprite_index;
    game_texture_cache u_tex(.write_clk(sd_clk),
           .write_rst(rst_sd),
           .asset_begin(asset_begin),
           .asset_we(asset_we),
           .asset_rgb(asset_rgb),
           .asset_commit(asset_commit),
           .read_clk(pix_clk),
           .read_rst(rst_pix),
           .bg_addr(bg_addr),
           .sprite_addr(sprite_addr),
           .bg_index(bg_index),
           .sprite_index(sprite_index),
           .loaded(assets_loaded));
       wire [1:0] enemy_alive;
       wire [11:0] player_x,camera_x,enemy0_x,enemy1_x;
       wire [8:0] player_y;
       wire powerup_active,super_mario;
       wire fire_mario;
       wire [1:0] fireball_active;
       wire [23:0] fireball_x;
       wire [17:0] fireball_y;
       wire [11:0] powerup_x;
       wire [8:0] powerup_y;
       wire facing_left;
       wire [1:0] anim,powerup_kind,flag_phase;
       wire [3:0] lives,enemy_active;
       wire [47:0] enemy_x;
       wire [35:0] enemy_y;
       wire [7:0] enemy_kind,coins_count;
       wire player_crouch;
       wire [8:0] flag_y;
       wire [2:0] profile_cursor;
       wire [7:0] coin_mask;
       wire [8:0] seconds_left;
       wire [23:0] score;
       wire [47:0] player_name;
       wire [2:0] avatar;
       wire submit;
       wire [15:0] elapsed_seconds;
       wire [3:0] event_code;
       wire event_valid,playing,paused;
    wire map_ready,map_reload,map_we;
    wire [11:0] block_fx_addr;
    wire [4:0] block_fx_frames,transform_frames;
    wire [1:0] block_fx_kind;
    wire player_blink,player_star,death_active;
    wire reward_valid;
    wire [3:0] reward_kind;
    wire [11:0] reward_x;
    wire [8:0] reward_y;
    wire [11:0] map_addr,map_video_addr;
    wire [7:0] map_data,map_wdata,map_video_data;
    game_level_map u_level(.clk(pix_clk),.rst(rst_pix||reset_game),.reload(map_reload),
        .ready(map_ready),.world_addr(map_addr),.world_data(map_data),
        .world_we(map_we),.world_wdata(map_wdata),
        .video_addr(map_video_addr),.video_data(map_video_data));
    game_world u_world(.clk(pix_clk),
           .death_active(death_active),
           .reward_valid(reward_valid),.reward_kind(reward_kind),.reward_x(reward_x),.reward_y(reward_y),
           .block_fx_addr(block_fx_addr),.block_fx_frames(block_fx_frames),.block_fx_kind(block_fx_kind),
           .player_blink(player_blink),.player_star(player_star),.transform_frames(transform_frames),
           .fire_mario(fire_mario),.fireball_active(fireball_active),
           .fireball_x(fireball_x),.fireball_y(fireball_y),
           .rst(rst_pix||reset_game),
           .frame_tick(frame_tick),
           .assets_loaded(assets_loaded),
           .held_left(held_left&&!alignment_block),
           .held_right(held_right&&!alignment_block),
           .jump_press(jump_press&&game_state!=0&&!alignment_block),
           .jump_hold(jump_hold&&!alignment_block),
           .back_press(back_press&&!menu_active&&(game_state==1||game_state==5)),
           .held_run(held_run),
           .held_down(held_down),
           .map_ready(map_ready),.map_data(map_data),.map_reload(map_reload),
           .map_addr(map_addr),.map_we(map_we),.map_wdata(map_wdata),
           .debug_mode(menu_active),
           .profile_request(profile_request),.scores_request(scores_request),
           .quick_start(jump_long&&game_state==1&&!alignment_block),
           .view_narrow(view_narrow),
           .state(game_state),
           .player_x(player_x),
           .player_y(player_y),
           .camera_x(camera_x),
           .facing_left(facing_left),
           .anim(anim),
           .enemy0_x(enemy0_x),
           .enemy1_x(enemy1_x),
           .enemy_alive(enemy_alive),
           .enemy_x(enemy_x),.enemy_y(enemy_y),.enemy_kind(enemy_kind),.enemy_active(enemy_active),
           .coins_count(coins_count),.player_crouch(player_crouch),.flag_phase(flag_phase),.flag_y(flag_y),
           .powerup_active(powerup_active),
           .powerup_x(powerup_x),
           .powerup_y(powerup_y),
           .powerup_kind(powerup_kind),
           .super_mario(super_mario),
           .coin_mask(coin_mask),
           .score(score),
           .seconds_left(seconds_left),
           .lives(lives),
           .player_name(player_name),
           .avatar(avatar),
           .profile_cursor(profile_cursor),
           .submit(submit),
           .elapsed_seconds(elapsed_seconds),
           .event_code(event_code),
           .event_valid(event_valid),
           .playing(playing),
           .paused(paused));
    wire [3:0] rank_index,flash_query_index,load_index;
       wire rank_valid;
       wire [47:0] rank_name;
       wire [23:0] rank_score;
       wire [15:0] rank_time;
       wire [2:0] rank_avatar;
       wire [95:0] query_record,store_record,load_record;
       wire load_valid,scores_changed,flash_busy,flash_ready,flash_error,persist_available;
    // Snapshot the result until the journal is ready; a quick soft reset cannot lose it.
    reg result_pending;
       reg [23:0] result_score;
       reg [15:0] result_time;
    reg [47:0] result_name;
       reg [2:0] result_avatar;
    wire result_accept=result_pending&&flash_ready&&!flash_busy&&!scores_changed;
    always @(posedge pix_clk or posedge rst_pix)
     if(rst_pix) begin result_pending<=0;result_score<=0;result_time<=0;result_name<=0;result_avatar<=0;end
     else if(submit) begin result_pending<=1;result_score<=score;result_time<=elapsed_seconds;result_name<=player_name;result_avatar<=avatar;end
     else if(result_accept) result_pending<=0;
    game_scores u_scores(.clk(pix_clk),
           .rst(rst_pix),
           .submit(result_accept),
           .save_busy(flash_busy||!flash_ready),
           .score(result_score),
           .elapsed_seconds(result_time),
           .player_name(result_name),
           .avatar(result_avatar),
           .query_index(rank_index),
           .query_record(query_record),
           .store_index(flash_query_index),
           .store_record(store_record),
           .load_valid(load_valid),
           .load_index(load_index),
           .load_record(load_record),
           .changed(scores_changed));
    game_score_flash u_flash(.clk(pix_clk),
           .rst(rst_pix),
           .save_req(scores_changed),
           .query_index(flash_query_index),
           .query_record(store_record),
           .load_valid(load_valid),
           .load_index(load_index),
           .load_record(load_record),
           .busy(flash_busy),
           .ready(flash_ready),
           .error(flash_error),
           .persist_available(persist_available),
           .flash_cs_n(flash_cs_n),
           .flash_sck(flash_sck),
           .flash_mosi(flash_mosi),
           .flash_miso(flash_miso));
    assign flash_wp_n=1'b1;
       assign flash_hold_n=1'b1;
    wire game_hs,game_vs,game_de;
       wire [23:0] game_rgb;
    game_video #(.ALIGNMENT(1)) u_game(.clk(pix_clk),
           .alignment_offset(alignment_offset),.alignment_active(alignment_active),
           .death_active(death_active),
           .effects_paused(menu_active),.reward_valid(reward_valid),.reward_kind(reward_kind),
           .reward_x(reward_x),.reward_y(reward_y),
           .block_fx_addr(block_fx_addr),.block_fx_frames(block_fx_frames),.block_fx_kind(block_fx_kind),
           .player_blink(player_blink),.player_star(player_star),.transform_frames(transform_frames),
           .fire_mario(fire_mario),.fireball_active(fireball_active),
           .fireball_x(fireball_x),.fireball_y(fireball_y),
           .rst(rst_pix),
           .hs(media_hs),
           .vs(media_vs),
           .de(media_de),
           .media_rgb(adjusted_media),
           .media_valid(active_valid),
           .debug_mode(debug_mode),
           .media_fullscreen(media_fullscreen),
           .osd_enable(osd_enable),
           .view_narrow(view_narrow),
           .palette_mode(palette_mode),
           .assets_loaded(assets_loaded),
           .state(game_state),
           .map_addr(map_video_addr),.map_data(map_video_data),
           .enemy_x(enemy_x),.enemy_y(enemy_y),.enemy_kind(enemy_kind),.enemy_active(enemy_active),
           .coins_count(coins_count),.player_crouch(player_crouch),.flag_phase(flag_phase),.flag_y(flag_y),
           .player_x(player_x),
           .camera_x(camera_x),
           .enemy0_x(enemy0_x),
           .enemy1_x(enemy1_x),
           .player_y(player_y),
           .powerup_active(powerup_active),
           .powerup_x(powerup_x),
           .powerup_y(powerup_y),
           .powerup_kind(powerup_kind),
           .super_mario(super_mario),
           .facing_left(facing_left),
           .anim(anim),
           .enemy_alive(enemy_alive),
           .coin_mask(coin_mask),
           .seconds_left(seconds_left),
           .score(score),
           .lives(lives),
           .player_name(player_name),
           .avatar(avatar),
           .profile_cursor(profile_cursor),
           .event_code(event_code),
           .save_busy(flash_busy||result_pending),.save_error(flash_error),.save_available(persist_available),.audio_enabled(audio_enabled),
           .bg_addr(bg_addr),
           .sprite_addr(sprite_addr),
           .bg_index(bg_index),
           .sprite_index(sprite_index),
           .rank_index(rank_index),
           .rank_valid(rank_valid),
           .rank_name(rank_name),
           .rank_score(rank_score),
           .rank_time(rank_time),
           .rank_avatar(rank_avatar),
           .hs_o(game_hs),
           .vs_o(game_vs),
           .de_o(game_de),
           .rgb_o(game_rgb),
           .frame_tick(frame_tick));
    assign rank_valid=query_record[91];
       assign rank_name=query_record[87:40];
       assign rank_avatar=query_record[90:88];
       assign rank_score=query_record[23:0];
       assign rank_time=query_record[39:24];
    wire audio_tick,acr_valid;
       reg audio_valid;
       wire [19:0] acr_n,acr_cts;
    always @(posedge pix_clk or posedge rst_pix)
     if(rst_pix) audio_valid<=0;
     else audio_valid<=audio_tick;
    wire [23:0] sd_pcm;
    wire sd_audio_available,sd_audio_error;
    wire [15:0] sd_audio_underruns,sd_audio_dropped;
    // Mix completes well before the next sample strobe. HDMI consumes the
    // previous stable sample, a fixed one-sample delay, never a partial mix.
    sd_pcm_player u_sd_audio(.clk(pix_clk),.rst(rst_pix),.sd_clk(sd_clk),.sd_rst(rst_sd),
        .initialized(sd_audio_initialized&&assets_loaded),.sample_tick(audio_tick),
        .play_enable(game_state==3'd0||game_state==3'd1||game_state==3'd2),
        .star_mode(player_star),
        .paused(1'b0),.mute(!audio_enabled),.event_valid(event_valid),
        .event_id(event_code==1&&super_mario?5'd16:{1'b0,event_code}),
        .audition(audition),.audition_id(audition_id),
        .master_volume(master_volume),.bgm_volume(bgm_volume),.sfx_volume(sfx_volume),
        .pcm(sd_pcm),.available(sd_audio_available),.error(sd_audio_error),
        .underruns(sd_audio_underruns),.dropped_events(sd_audio_dropped),
        .sd_req(sd_audio_req),.sd_addr(sd_audio_addr),.sd_data(sd_audio_data),
        .sd_valid(sd_audio_valid),.sd_end(sd_audio_end));
    wire signed [23:0] test_pcm;
    wire signed [23:0] test_level=master_volume==0?24'sd0:
        master_volume==1?test_pcm>>>2:master_volume==2?test_pcm>>>1:test_pcm;
    wire [23:0] output_pcm=!audio_enabled?24'd0:
        test_tone&&game_state==0?test_level:sd_audio_available?sd_pcm:24'd0;
    pcm48_tone u_tick(.clk(pix_clk),
           .rst(rst_pix),
           .valid(audio_tick),
           .left(test_pcm),
           .right(),
           .acr_valid(acr_valid),
           .acr_n(acr_n),
           .acr_cts(acr_cts));
    wire fx_hs,fx_vs,fx_de,final_hs,final_vs,final_de;
    wire [23:0] fx_rgb,final_rgb;
    advanced_video #(.DIRECT_CONTROLS(1),.LAB_UI(1),.ALIGNMENT(1)) u_effects(
        .clk(pix_clk),.rst(rst_pix),.hs(game_hs),.vs(game_vs),.de(game_de),.rgb(game_rgb),
        .alignment_offset(alignment_offset),.image_valid(1'b1),.key_menu(1'b1),
        .overlay_sw(osd_enable&&!alignment_block),.wave_sw(osd_enable&&!alignment_block),
        .brightness_sw(alignment_block?2'd0:brightness),
        .fade_gain(debug_mode?fade_gain:5'd16),.effect_mode(debug_mode?effect_mode:2'd0),
        .pcm_valid(audio_valid),.pcm(output_pcm),.audio_enabled(audio_enabled),
        .cache_count(cache_count),.image_index(image_index),.image_count(image_count),
        .control_contrast(alignment_block?2'd0:display_contrast),.control_transition(display_transition),
        .hs_o(fx_hs),.vs_o(fx_vs),.de_o(fx_de),.rgb_o(fx_rgb));
    game_menu_video #(.ALIGNMENT(1)) u_menu_video(.clk(pix_clk),.rst(rst_pix),
        .hs(fx_hs),.vs(fx_vs),.de(fx_de),.rgb(fx_rgb),.alignment_offset(alignment_offset),
        .active(lab_active&&!alignment_block),.debug_mode(debug_mode),.media_fullscreen(media_fullscreen),
        .calibration(calibration&&!alignment_block),.page(menu_page),.selection(menu_selection),
        .view_narrow(view_narrow),.palette_mode(palette_mode),.osd_enable(osd_enable),
        .audio_enabled(audio_enabled),.test_tone(test_tone),.brightness(brightness),
        .master_volume(master_volume),.bgm_volume(bgm_volume),.sfx_volume(sfx_volume),.audition_id(audition_id),
        .audio_available(sd_audio_available),.audio_error(sd_audio_error),
        .audio_underruns(sd_audio_underruns),.audio_dropped(sd_audio_dropped),
        .contrast(display_contrast),.transition_mode(display_transition),
        .assets_ready(assets_loaded),.image_ready(active_valid),
        .image_index(image_index),.image_count(image_count),.cache_count(cache_count),
        .hs_o(final_hs),.vs_o(final_vs),.de_o(final_de),.rgb_o(final_rgb));
    wire [9:0] ch0,ch1,ch2,chclk;
    wire hdmi_overflow;
    wire hdmi_locked;
    // Restore the pre-game vendor integration, including actual DDC/EDID.
    game_hdmi_output #(.READ_EDID(1)) u_hdmi(.clk(pix_clk),.rst(rst_pix),
        .hs(final_hs),.vs(final_vs),.de(final_de),.rgb(final_rgb),
        .sample_valid(audio_valid),.sample_left(output_pcm),.sample_right(output_pcm),
        .acr_valid(acr_valid),.c0(ch0),.c1(ch1),.c2(ch2),.cc(chclk),
        .overflow(hdmi_overflow),.locked(hdmi_locked),
        .ddc_scl(HDMI_DDC_SCL),.ddc_sda(HDMI_DDC_SDA));
    hdmi_phy_wrapper #(.DEVICE("EG")) u_phy(.I_pixel_clk(pix_clk),
           .I_serial_clk(serial_clk),
           .I_rst(rst_pix),
           .I_tmds_channel_0(ch0),
           .I_tmds_channel_1(ch1),
           .I_tmds_channel_2(ch2),
           .I_tmds_channel_clk(chclk),
           .O_tmds_ch0_p(HDMI_D0_P),
           .O_tmds_ch1_p(HDMI_D1_P),
           .O_tmds_ch2_p(HDMI_D2_P),
           .O_tmds_clk_p(HDMI_CLK_P));
    assign led={hdmi_overflow,asset_failed||sd_audio_error||flash_error,assets_loaded,sd_audio_initialized};
endmodule

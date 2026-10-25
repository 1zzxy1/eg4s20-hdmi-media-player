`timescale 1ns/1ps
module tb_game_world;
    reg clk=0,rst=1,frame_tick=0,assets_loaded=0;
    reg held_left=0,held_right=0,jump_press=0,jump_hold=0;
    reg back_press=0,held_run=0,held_down=0,debug_mode=0,view_narrow=0;
    reg profile_request=0,scores_request=0,quick_start=0;
    wire [11:0] block_fx_addr;wire [4:0] block_fx_frames,transform_frames;
    wire [1:0] block_fx_kind;wire player_blink,player_star;
    wire [2:0] state,avatar,profile_cursor;
    wire [11:0] player_x,camera_x,enemy0_x,enemy1_x;
    wire [8:0] player_y;
    wire facing_left,submit,event_valid,playing,paused,death_active;
    wire [1:0] anim,enemy_alive,powerup_kind,flag_phase;
    wire [7:0] coin_mask,coins_count;
    wire [8:0] seconds_left,flag_y;
    wire [3:0] lives,enemy_active;
    wire [47:0] enemy_x,player_name;
    wire [35:0] enemy_y;
    wire [7:0] enemy_kind;
    wire [23:0] score;
    wire [15:0] elapsed_seconds;
    wire [3:0] event_code;
    wire reward_valid;
    wire [3:0] reward_kind;
    wire [11:0] reward_x;
    wire [8:0] reward_y;
    wire powerup_active,super_mario,player_crouch;
    wire fire_mario; wire [1:0] fireball_active;
    wire [23:0] fireball_x; wire [17:0] fireball_y;
    wire [11:0] powerup_x,map_addr;
    wire [8:0] powerup_y;
    wire map_reload,map_we,map_ready;
    wire [7:0] map_data,map_wdata;
    always #5 clk=~clk;
    game_level_map level(.clk(clk),.rst(rst),.reload(map_reload),
        .ready(map_ready),.world_addr(map_addr),.world_data(map_data),
        .world_we(map_we),.world_wdata(map_wdata),
        .video_addr(12'd0),.video_data());
    game_world dut(.*);
    task step;
        begin
            @(negedge clk);frame_tick=1;
            @(negedge clk);frame_tick=0;
            repeat(100) @(negedge clk);
        end
    endtask
    task press;
        begin
            @(negedge clk);jump_press=1;
            @(negedge clk);jump_press=0;
            step();step();
        end
    endtask
    integer i,oldx,oldy,oldscore,miny,submits=0;
    always @(posedge clk) if(submit) submits=submits+1;
    initial begin
        repeat(4) @(negedge clk);rst=0;
        press();if(state!=0) $fatal(1,"unloaded start");
        assets_loaded=1;press();if(state!=1) $fatal(1,"profile");
        held_right=1;step();held_right=0;step();
        if(player_name[47:40]!="B") $fatal(1,"nickname %s cursor=%0d",player_name,profile_cursor);
        repeat(6) press();
        if(profile_cursor!=6) $fatal(1,"profile cursor");
        held_right=1;step();held_right=0;step();
        if(avatar!=1) $fatal(1,"avatar");
        press();if(!playing||lives!=3||seconds_left!=400) $fatal(1,"start");
        for(i=0;i<4200&&!map_ready;i=i+1) @(negedge clk);
        if(!map_ready) $fatal(1,"map reload");
        held_right=1;repeat(15) step();held_right=0;
        repeat(12) step();
        if(player_x<=32||player_y!=192) $fatal(1,"movement %0d %0d",player_x,player_y);
        oldx=player_x;repeat(8) step();
        if(player_x!=oldx) $fatal(1,"friction");
        jump_hold=1;jump_press=1;step();jump_press=0;miny=player_y;
        repeat(10) begin step();if(player_y<miny) miny=player_y;end
        jump_hold=0;repeat(45) step();
        if(miny>=180||player_y!=192) $fatal(1,"jump/land %0d %0d",miny,player_y);
        oldx=player_x;oldy=player_y;oldscore=score;
        debug_mode=1;held_right=1;repeat(8) step();
        if(player_x!=oldx||player_y!=oldy||score!=oldscore||!paused)
            $fatal(1,"debug freeze");
        debug_mode=0;held_right=0;
        scores_request=1;@(negedge clk);scores_request=0;step();
        if(state!=5||player_x!=oldx||score!=oldscore)$fatal(1,"rank menu lost world");
        back_press=1;step();back_press=0;
        if(state!=2||player_x!=oldx||score!=oldscore)$fatal(1,"rank did not resume");
        profile_request=1;@(negedge clk);profile_request=0;step();
        if(state!=1)$fatal(1,"profile menu request");
        held_right=1;step();held_right=0;step();back_press=1;step();back_press=0;
        if(state!=2||score!=oldscore||player_name[47:40]!="C")$fatal(1,"profile resume");
        if(submits!=0) $fatal(1,"premature submit");
        $display("PASS game world: profile, map load, movement, inertia, jump, debug freeze");
        $finish;
    end
    initial begin #2000000;$fatal(1,"timeout");end
endmodule

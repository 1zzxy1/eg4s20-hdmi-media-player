`timescale 1ns/1ps
// Full playable route using only the game_world public input and output ports.
module tb_game_playthrough;
    reg clk=0,rst=1,frame_tick=0,assets_loaded=0;
    reg held_left=0,held_right=0,jump_press=0,jump_hold=0,back_press=0,held_run=0;
    reg debug_mode=0,view_narrow=0,held_down=0;
    wire [2:0] state,avatar,profile_cursor;
    wire [11:0] player_x,camera_x,enemy0_x,enemy1_x;
    wire [8:0] player_y;
    wire facing_left,submit,event_valid,playing,paused;
    wire [1:0] anim,enemy_alive;
    wire [3:0] lives,enemy_active;
    wire [7:0] coin_mask;
    wire [8:0] seconds_left;
    wire [23:0] score;
    wire [47:0] player_name;
    wire [15:0] elapsed_seconds;
    wire [3:0] event_code;
    wire reward_valid;
    wire [3:0] reward_kind;
    wire [11:0] reward_x;
    wire [8:0] reward_y;
    wire [47:0] enemy_x; wire [35:0] enemy_y; wire [7:0] enemy_kind;
    wire powerup_active,super_mario,player_crouch; wire [1:0] powerup_kind,flag_phase;
    wire [11:0] powerup_x; wire [8:0] powerup_y,flag_y;
    wire [7:0] coins_count; wire map_ready,map_reload,map_we; wire [11:0] map_addr;
    wire [7:0] map_data,map_wdata;
    integer steps=0,submitted=0,jumps=0,death_count=0,max_x=0;
    integer last_x=0,last_y=192,stall=0,min_y=480;
    always #5 clk=~clk;
    game_level_map level(.clk(clk),.rst(rst),.reload(map_reload),.ready(map_ready),
        .world_addr(map_addr),.world_data(map_data),.world_we(map_we),.world_wdata(map_wdata),
        .video_addr(12'd0),.video_data());
    game_world dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),.assets_loaded(assets_loaded),
        .held_left(held_left),.held_right(held_right),.jump_press(jump_press),
        .jump_hold(jump_hold),.back_press(back_press),.debug_mode(debug_mode),
        .held_run(held_run),.held_down(held_down),.map_ready(map_ready),.map_data(map_data),
        .map_reload(map_reload),.map_addr(map_addr),.map_we(map_we),.map_wdata(map_wdata),
        .view_narrow(view_narrow),.state(state),.player_x(player_x),.player_y(player_y),
        .camera_x(camera_x),.facing_left(facing_left),.anim(anim),
        .enemy0_x(enemy0_x),.enemy1_x(enemy1_x),.enemy_alive(enemy_alive),
        .enemy_x(enemy_x),.enemy_y(enemy_y),.enemy_kind(enemy_kind),.enemy_active(enemy_active),
        .powerup_active(powerup_active),.powerup_x(powerup_x),.powerup_y(powerup_y),.powerup_kind(powerup_kind),.super_mario(super_mario),.player_crouch(player_crouch),
        .flag_phase(flag_phase),.flag_y(flag_y),.coins_count(coins_count),
        .coin_mask(coin_mask),.score(score),.seconds_left(seconds_left),.lives(lives),
        .player_name(player_name),.avatar(avatar),.profile_cursor(profile_cursor),
        .submit(submit),.elapsed_seconds(elapsed_seconds),.event_code(event_code),
        .event_valid(event_valid),.playing(playing),.paused(paused),
        .reward_valid(reward_valid),.reward_kind(reward_kind),.reward_x(reward_x),.reward_y(reward_y));
    always @(negedge clk) if(!rst) begin
        if(submit) submitted=submitted+1;
        if(event_valid && event_code==4) death_count=death_count+1;
        if(event_valid && event_code==10) begin
            if(!reward_valid||reward_x!=3168||reward_kind!=(reward_y<34?9:reward_y<80?8:
                reward_y<104?7:reward_y<144?6:5))$fatal(1,"flag reward payload");
        end
    end
    task step;
        begin
            frame_tick=1;
            @(negedge clk);frame_tick=0;
            // The synchronous map probes take several clocks (horizontal,
            // vertical, then four entity slots) before COMMIT returns to IDLE.
            // A real video frame is much longer; wait through that pipeline
            // here so the next synthetic frame tick cannot be dropped.
            repeat(100) @(negedge clk);
            steps=steps+1;
            if(player_y<last_y && last_y>=190) jumps=jumps+1;
            last_y=player_y;
            if(player_y<min_y) min_y=player_y;
            if(player_x>max_x) max_x=player_x;
        end
    endtask
    task confirm;
        begin
            @(negedge clk);jump_press=1;
            @(negedge clk);jump_press=0;
            step();step();
        end
    endtask
    task edit_right;
        begin
            @(negedge clk);held_right=1;
            @(negedge clk);
            @(negedge clk);held_right=0;
            step();step();
        end
    endtask
    integer i;
    initial begin
        repeat(4)@(negedge clk);rst=0;assets_loaded=1;
        confirm();
        if(state!=1) $fatal(1,"TITLE to PROFILE failed");
        for(i=0;i<6;i=i+1) begin
            edit_right();
            if(i>=3) edit_right();
            confirm();
        end
        if(player_name!="BBBBBB" || profile_cursor!=6)
            $fatal(1,"six-character profile failed: %s cursor %0d",player_name,profile_cursor);
        edit_right();
        if(avatar!=1) $fatal(1,"avatar select failed");
        confirm();
        if(state!=2 || !playing || avatar!=1)
            $fatal(1,"PROFILE to PLAY failed");
        repeat(4200) @(negedge clk);
        if(!map_ready) $fatal(1,"level map did not become ready");

        held_right=1;jump_hold=1;held_run=1;
        for(i=0;i<3000 && (state==2 || state==6 || state==7);i=i+1) begin
            // Repeat jump requests: the public grounded gate accepts them only
            // after landing, including landings on the tops of tall pipes.
            jump_press=state==2;
            step();
            if(player_x==last_x) stall=stall+1;else stall=0;
            last_x=player_x;
            if(stall>180 && state==2) $fatal(1,"stalled at x=%0d y=%0d, frame=%0d",player_x,player_y,i);
        end
        held_right=0;jump_press=0;jump_hold=0;
        if(state!=4) $fatal(1,"route failed state=%0d x=%0d y=%0d max=%0d jumps=%0d deaths=%0d",
                              state,player_x,player_y,max_x,jumps,death_count);
        if(player_x<3264 || max_x<3264 || camera_x<3000 || jumps<3)
            $fatal(1,"terminal screen reached without full movement/jumps x=%0d max=%0d cam=%0d jumps=%0d miny=%0d",
                      player_x,max_x,camera_x,jumps,min_y);
        if(submitted!=1 || score<1000 || lives!=3)
            $fatal(1,"clear did not submit the surviving player score submit=%0d pulse=%0d score=%0d lives=%0d",
                      submitted,submit,score,lives);
        confirm();
        if(state!=5) $fatal(1,"CLEAR to LEADERBOARD failed");
        confirm();
        if(state!=0) $fatal(1,"LEADERBOARD to TITLE failed");
        $display("PASS game playthrough: profile BBBBBB, avatar 1, %0d world steps, x=%0d, jumps=%0d, clear/leaderboard",
                 i,max_x,jumps);
        $finish;
    end
    initial begin #4000000;$fatal(1,"playthrough timeout");end
endmodule

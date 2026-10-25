`timescale 1ns/1ps
// Public-input enemy death plus directed COMMIT boundary snapshots.
module tb_game_death;
    reg clk=0,rst=1,frame_tick=0;
    reg held_left=0,held_right=0,jump_press=0,back_press=0,held_run=0;
    reg debug_mode=0,profile_request=0,scores_request=0;
    reg [7:0] map_data=0;
    wire [11:0] map_addr,player_x,camera_x;
    wire [8:0] player_y,seconds_left;
    wire [2:0] state;
    wire [3:0] lives,event_code,enemy_active;
    wire [47:0] enemy_x;
    wire [35:0] enemy_y;
    wire [23:0] score;
    wire [15:0] elapsed_seconds;
    wire submit,event_valid,playing,paused,death_active;
    integer deaths=0,submits=0,reloads=0,i,initial_y,golden_y,golden_vy;
    integer frozen_x,frozen_camera,frozen_seconds,frozen_elapsed,frozen_score;
    reg [47:0] frozen_enemy_x;
    reg [35:0] frozen_enemy_y;
    reg [3:0] frozen_enemy_active;
    always #5 clk=~clk;
    game_world dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),.assets_loaded(1'b1),
        .held_left(held_left),.held_right(held_right),.jump_press(jump_press),
        .jump_hold(1'b0),.back_press(back_press),.held_run(held_run),.held_down(1'b0),
        .debug_mode(debug_mode),.view_narrow(1'b0),
        .profile_request(profile_request),.scores_request(scores_request),
        .map_ready(1'b1),.map_data(map_data),.map_addr(map_addr),
        .state(state),.player_x(player_x),.player_y(player_y),.camera_x(camera_x),
        .lives(lives),.score(score),.seconds_left(seconds_left),.elapsed_seconds(elapsed_seconds),
        .enemy_x(enemy_x),.enemy_y(enemy_y),.enemy_active(enemy_active),
        .submit(submit),.event_valid(event_valid),.event_code(event_code),
        .playing(playing),.paused(paused),.death_active(death_active));
    always @(posedge clk) begin
        // Flat ground and the actual enemy spawn table; no internal contact injection.
        map_data<=map_addr[11:8]==13?8'd1:8'd0;
        if(rst) begin deaths<=0;submits<=0;reloads<=0;end
        else begin
            if(event_valid&&event_code==4)deaths<=deaths+1;
            if(submit)submits<=submits+1;
            if(dut.map_reload)reloads<=reloads+1;
        end
    end
    task step;
        @(negedge clk);frame_tick=1;
        @(negedge clk);frame_tick=0;
        repeat(120)@(negedge clk);
    endtask
    task tap;
        @(negedge clk);jump_press=1;
        @(negedge clk);jump_press=0;step();
    endtask
    task boot;
        rst=1;held_left=0;held_right=0;jump_press=0;back_press=0;held_run=0;
        debug_mode=0;profile_request=0;scores_request=0;
        repeat(4)@(negedge clk);rst=0;
        tap();step();repeat(7)begin tap();step();end
        if(state!=2||lives!=3)$fatal(1,"death boot");
    endtask
    task snapshot;
        frozen_x=player_x;frozen_camera=camera_x;frozen_seconds=seconds_left;
        frozen_elapsed=elapsed_seconds;frozen_score=score;
        frozen_enemy_x=enemy_x;frozen_enemy_y=enemy_y;frozen_enemy_active=enemy_active;
    endtask
    task check_frozen;
        if(player_x!=frozen_x||camera_x!=frozen_camera||seconds_left!=frozen_seconds||
           elapsed_seconds!=frozen_elapsed||score!=frozen_score||enemy_x!==frozen_enemy_x||
           enemy_y!==frozen_enemy_y||enemy_active!==frozen_enemy_active||playing||!paused)
            $fatal(1,"death advanced world, camera, timer, score or BGM enable");
    endtask
    task commit_death(input integer start_y,input integer start_lives);
        @(negedge clk);
        dut.state=2;dut.phase=13;dut.seconds_left=0;dut.lives=start_lives;
        dut.xq=512;dut.next_xq=512;dut.yq=start_y*16;dut.next_yq=start_y*16;
        dut.super_state=1;dut.fire_mario=1;dut.star_state=1;
        repeat(5)@(negedge clk);
        if(state!=3||lives!=start_lives-1||deaths!=1)$fatal(1,"directed death entry");
    endtask
    task finish_arc(input integer start_y,input integer start_vy);
        golden_y=start_y*16;golden_vy=start_vy;
        for(i=0;i<120;i=i+1)begin
            // Early confirms must not skip the scene or queue an automatic retry.
            jump_press=(i<20);
            if(i>=24)begin
                golden_y=golden_y+golden_vy;
                if(golden_y>4096)golden_y=4096;
                if(golden_vy<112)golden_vy=golden_vy+5;
                if(golden_vy>112)golden_vy=112;
            end
            step();check_frozen();
            if(state!=3||player_y!==((golden_y>>>4)&511))
                $fatal(1,"death arc frame=%0d state=%0d y=%0d expected=%0d",
                    i+1,state,player_y,(golden_y>>>4)&511);
            if(death_active!==(i<119))$fatal(1,"death active duration frame=%0d",i+1);
        end
        jump_press=0;
        repeat(4)begin step();check_frozen();end
        if(player_y!=256||deaths!=1)$fatal(1,"death did not finish below viewport once");
    endtask
    initial begin
        boot();held_right=1;held_run=1;
        for(i=0;i<200&&state==2;i=i+1)step();
        if(state!=3||lives!=2||deaths!=1)$fatal(1,"public-input side collision missing");
        snapshot();initial_y=player_y;
        // Menu pauses even the initial hold. No world or scene progress while open.
        debug_mode=1;repeat(30)begin step();check_frozen();end debug_mode=0;
        if(player_y!=initial_y)$fatal(1,"death moved while menu paused");
        finish_arc(initial_y,-96);
        if(submits!=0||reloads!=1)$fatal(1,"nonfinal death submitted/reloaded early");
        tap();step();
        if(state!=2||lives!=2||player_x!=32||player_y!=192||reloads!=2)
            $fatal(1,"death retry state=%0d lives=%0d xy=%0d,%0d reloads=%0d",
                state,lives,player_x,player_y,reloads);
        // A second death must start a fresh hold rather than inherit frame 120.
        held_right=1;held_run=1;
        for(i=0;i<200&&state==2;i=i+1)step();
        if(state!=3||lives!=1||deaths!=2)$fatal(1,"second side death missing");
        initial_y=player_y;jump_press=1;repeat(24)step();jump_press=0;
        if(state!=3||player_y!=initial_y)$fatal(1,"second death hold not reset");
        step();if(player_y>=initial_y)$fatal(1,"second death did not bounce");
        // Profile/rank excursions resume exactly the interrupted scene.
        initial_y=player_y;
        profile_request=1;@(negedge clk);profile_request=0;
        repeat(12)step();if(state!=1||player_y!=initial_y)$fatal(1,"profile paused death");
        back_press=1;step();back_press=0;
        if(state!=3||player_y!=initial_y)$fatal(1,"profile death return");
        scores_request=1;@(negedge clk);scores_request=0;
        repeat(12)step();if(state!=5||player_y!=initial_y)$fatal(1,"ranks paused death");
        tap();if(state!=3||player_y!=initial_y)$fatal(1,"ranks death return");
        step();if(player_y>=initial_y)$fatal(1,"death did not resume after ranks");
        // High timeout crosses signed y=0; final life publishes once only.
        boot();commit_death(2,1);snapshot();finish_arc(2,-96);
        if(lives!=0||submits!=1)$fatal(1,"last-life death submission count");
        tap();if(state!=5||submits!=1)$fatal(1,"last-life death did not enter ranks");
        // Falling into a pit must never bounce back into the visible playfield.
        boot();commit_death(243,3);snapshot();finish_arc(243,112);
        back_press=1;step();back_press=0;if(state!=0)$fatal(1,"death back to title");
        $display("PASS game death: public contact/retry, 24-frame hold/120-frame scene, signed arc, pit clamp, menu/profile/rank pause, frozen world, one-shot audio/rank");
        $finish;
    end
    initial begin #10000000;$fatal(1,"death timeout");end
endmodule

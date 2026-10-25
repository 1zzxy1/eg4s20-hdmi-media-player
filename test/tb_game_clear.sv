`timescale 1ns/1ps
// Directed flag entry; the full course is separately driven through public inputs.
module tb_game_clear;
    reg clk=0,rst=1,frame_tick=0,debug_mode=0;
    reg jump_press=0,back_press=0,profile_request=0,scores_request=0;
    wire [2:0] state;
    wire [11:0] player_x,camera_x;
    wire [8:0] player_y,seconds_left,flag_y;
    wire [1:0] anim,flag_phase;
    wire [23:0] score;
    wire [3:0] lives,event_code;
    wire [15:0] elapsed_seconds;
    wire submit,event_valid,playing;
    integer music=0,submitted=0,i,j,initial_time,expected_score,saved_frame,saved_x;
    reg saw_run1,saw_run2;
    always #5 clk=~clk;
    game_world dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),.assets_loaded(1'b1),
        .held_left(1'b1),.held_right(1'b1),.jump_press(jump_press),.jump_hold(1'b1),
        .back_press(back_press),.held_run(1'b1),.held_down(1'b1),
        .debug_mode(debug_mode),.view_narrow(1'b1),.profile_request(profile_request),
        .scores_request(scores_request),.map_ready(1'b1),.map_data(8'd0),
        .state(state),.player_x(player_x),.player_y(player_y),.camera_x(camera_x),
        .anim(anim),.flag_phase(flag_phase),.flag_y(flag_y),.score(score),
        .seconds_left(seconds_left),.lives(lives),.elapsed_seconds(elapsed_seconds),
        .event_code(event_code),.event_valid(event_valid),.submit(submit),.playing(playing));
    always @(posedge clk)begin
        if(rst)begin music<=0;submitted<=0;end
        else begin
            if(event_valid&&event_code==6)music<=music+1;
            if(submit)submitted<=submitted+1;
        end
    end
    task step;
        @(negedge clk);frame_tick=1;
        @(negedge clk);frame_tick=0;repeat(8)@(negedge clk);
    endtask
    task check_pause;
        saved_frame=dut.flag_frames;saved_x=player_x;
        debug_mode=1;repeat(20)step();debug_mode=0;
        if(dut.flag_frames!=saved_frame||player_x!=saved_x||music!=1||submitted)
            $fatal(1,"clear menu pause advanced scene");
        profile_request=1;@(negedge clk);profile_request=0;
        repeat(5)step();if(state!=1)$fatal(1,"clear profile entry");
        back_press=1;step();back_press=0;
        if(state!=7||dut.flag_frames!=saved_frame||player_x!=saved_x)
            $fatal(1,"clear profile resume");
        scores_request=1;@(negedge clk);scores_request=0;
        repeat(5)step();if(state!=5)$fatal(1,"clear rank entry");
        jump_press=1;step();jump_press=0;
        if(state!=7||dut.flag_frames!=saved_frame||player_x!=saved_x||music!=1||submitted)
            $fatal(1,"clear rank resume repeated music/submission");
    endtask
    initial begin
        // Small/large player, zero/full timer: both visibility phases and score extremes.
        for(j=0;j<4;j=j+1)begin
            rst=1;repeat(4)@(negedge clk);rst=0;
            @(negedge clk);dut.state=6;dut.phase=0;dut.xq=3167*16;
            dut.yq=32*16;dut.flag_y=48;dut.flag_phase=1;
            dut.super_state=j[0];dut.facing_left=1;dut.anim=3;
            initial_time=j[1]?400:0;expected_score=5000+initial_time*50;
            dut.seconds_left=initial_time;dut.score=5000;dut.elapsed_seconds=87;
            dut.camera_x=3036;
            for(i=0;i<60&&state==6;i=i+1)step();
            if(state!=7||flag_phase!=2||music!=1||submitted||dut.facing_left||anim!=1||
               player_y!=(j[0]?176:192)||flag_y!=176)
                $fatal(1,"flag slide/clear music entry case=%0d",j);
            saw_run1=0;saw_run2=0;
            if(j==0)check_pause();
            for(i=0;i<70&&flag_phase==2;i=i+1)begin
                jump_press=1;step();jump_press=0;
                saw_run1=saw_run1||anim==1;saw_run2=saw_run2||anim==2;
                if(player_x>3264||seconds_left!=initial_time||score!=5000)
                    $fatal(1,"door overshoot or early timer score");
            end
            if(player_x!=3264||flag_phase!=3||anim!=0||!saw_run1||!saw_run2)
                $fatal(1,"door walk/animation/visibility phase");
            if(j==0)check_pause();
            for(i=0;i<500&&state==7;i=i+1)begin
                step();
                if(player_x!=3264||camera_x!=3036||elapsed_seconds!=87||lives!=3||
                   (state==7&&!playing)||music!=1)$fatal(1,"clear world advanced/repeated music");
            end
            if(state!=4||seconds_left!=0||score!=expected_score||submitted!=1||
               dut.flag_frames!=480||playing)
                $fatal(1,"clear final case=%0d state=%0d time=%0d score=%0d submitted=%0d frames=%0d",
                    j,state,seconds_left,score,submitted,dut.flag_frames);
            repeat(10)step();if(submitted!=1||music!=1)$fatal(1,"duplicate clear event");
            jump_press=1;step();jump_press=0;if(state!=5)$fatal(1,"clear rank confirm");
        end
        $display("PASS game clear: small/large slide, one-shot early music, animated clamped walk, door phase, 480-frame hold, timer score, menu/profile/rank resume, one submission");
        $finish;
    end
    initial begin #10000000;$fatal(1,"clear timeout");end
endmodule

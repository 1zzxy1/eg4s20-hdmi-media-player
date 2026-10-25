`timescale 1ns/1ps
// Public board inputs through the same menu/world wiring as the top level.
module tb_game_lobby;
    parameter STABILITY=1;
    reg clk=0,rst=1,frame_tick=0;
    reg [3:0] keys_n=15,switches=0;
    reg assets_loaded=1;
    wire [3:0] frame_switches;
    wire [2:0] state,profile_cursor;
    wire active,debug_mode,profile_request,view_narrow;
    wire held_left,held_right,jump_hold,held_run,held_down;
    wire left_press,right_press,jump_press,jump_long,back_press;
    wire calibration,test_tone;
    integer f;
    always #5 clk=~clk;
    always @(negedge clk)begin
        if(rst)begin f=0;frame_tick=0;end
        else begin f=f==199?0:f+1;frame_tick=f==199;end
    end
    game_inputs #(.DEBOUNCE(2),.LONG_PRESS(3000)) controls(
        .clk(clk),.rst(rst),.frame_tick(frame_tick),.keys_n(keys_n),.switches(switches),
        .gameplay_active((state==2||state==6||state==7)&&!active),.debug_mode(active),
        .held_left(held_left),.held_right(held_right),.jump_hold(jump_hold),
        .held_run(held_run),.held_down(held_down),.left_press(left_press),
        .right_press(right_press),.jump_press(jump_press),.jump_long(jump_long),
        .back_press(back_press),.frame_switches(frame_switches));
    generate if(STABILITY)begin:stable_controls
        assign active=1'b0;
        assign debug_mode=1'b0;
        assign view_narrow=1'b0;
        assign profile_request=jump_press&&state==0;
        assign calibration=1'b0;
        assign test_tone=state==0&&frame_switches[1];
    end else begin:full_controls
    game_menu menu(.clk(clk),.rst(rst),.frame_tick(frame_tick),.game_state(state),
        .switches(frame_switches),.back_press(back_press),.left_press(left_press),
        .right_press(right_press),.confirm(jump_press),.confirm_long(jump_long),
        .active(active),.debug_mode(debug_mode),.view_narrow(view_narrow),
        .profile_request(profile_request),.calibration(calibration),.test_tone(test_tone));
    end endgenerate
    game_world world(.clk(clk),.rst(rst),.frame_tick(frame_tick),.assets_loaded(assets_loaded),
        .held_left(held_left),.held_right(held_right),.jump_hold(jump_hold),
        .jump_press(jump_press&&state!=0),
        .back_press(back_press&&!active&&(state==1||state==5)),
        .held_run(held_run),.held_down(held_down),.debug_mode(active),
        .profile_request(profile_request),.scores_request(1'b0),.view_narrow(view_narrow),
        .quick_start(jump_long&&state==1),
        .map_ready(1'b1),.map_data(8'd0),.state(state),.profile_cursor(profile_cursor));
    task wait_frames(input integer count);begin repeat(count*200)@(posedge clk);#1;end endtask
    task key(input integer index);begin
        @(negedge clk);keys_n[index]=0;wait_frames(3);
        @(negedge clk);keys_n[index]=1;wait_frames(3);
    end endtask
    task enter_game(input [3:0] sw);integer j;begin
        @(negedge clk);rst=1;keys_n=15;switches=sw;
        repeat(5)@(negedge clk);rst=0;wait_frames(5);
        if(state!=0||active!=(!STABILITY&&sw!=0))$fatal(1,"boot state / switch lab");
        key(3);
        if(state!=1||profile_cursor!=0||active||debug_mode||calibration||test_tone)
            $fatal(1,"KEY4 lobby exit or duplicate profile entry sw=%h state=%d cursor=%d",sw,state,profile_cursor);
        wait_frames(10);
        if(profile_cursor!=0)$fatal(1,"held confirm advanced profile");
        for(j=0;j<6;j=j+1)begin
            key(3);
            if(state!=1||profile_cursor!=j+1)$fatal(1,"profile field %d",j);
        end
        key(3);wait_frames(3);
        if(state!=2||active||debug_mode)$fatal(1,"profile must start game, not return to profile/title");
        if(held_left||held_right||jump_hold)$fatal(1,"debug keys leaked into gameplay");
        @(negedge clk);keys_n[0]=0;wait_frames(3);
        if(!held_right||held_left||jump_hold)$fatal(1,"KEY1 right");
        @(negedge clk);keys_n=15;keys_n[2]=0;wait_frames(3);
        if(!held_left||held_right||jump_hold)$fatal(1,"KEY3 left");
        @(negedge clk);keys_n=15;keys_n[1]=0;wait_frames(3);
        if(!jump_hold||held_left||held_right||held_run!=sw[3])$fatal(1,"KEY2 jump / SW4 run");
        @(negedge clk);keys_n=15;switches=15;wait_frames(3);
        if(active||debug_mode)$fatal(1,"switches reopened debug in game");
    end endtask
    initial begin
        enter_game(0);enter_game(15);enter_game(2);
        @(negedge clk);rst=1;keys_n=15;switches=15;assets_loaded=0;
        repeat(5)@(negedge clk);rst=0;wait_frames(5);key(3);
        if(state!=1||active)$fatal(1,"atlas wait must not swallow profile entry");
        @(negedge clk);keys_n[3]=0;repeat(3300)@(negedge clk);keys_n[3]=1;
        wait_frames(3);
        if(state!=1)$fatal(1,"started without atlas");
        assets_loaded=1;wait_frames(3);
        if(state!=2||active)$fatal(1,"long KEY4 lost between frames / atlas load");
        $display("PASS lobby integration: physical KEY4, profile confirms, long-press quick start, atlas wait, debug isolation, KEY3/2/1 + SW4");
        $finish;
    end
    initial begin #3000000;$fatal(1,"lobby timeout");end
endmodule

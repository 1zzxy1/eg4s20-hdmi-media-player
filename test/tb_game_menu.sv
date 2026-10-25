`timescale 1ns/1ps
module tb_game_menu;
    reg clk=0,rst=1,frame_tick=0;
    reg [2:0] game_state=0;
    reg [3:0] switches=0;
    reg back_press=0,left_press=0,right_press=0,confirm=0,confirm_long=0;
    wire active,debug_mode,view_narrow,palette_mode,osd_enable,calibration,audio_enabled;
    wire test_tone;
    wire [2:0] page,selection;
    wire [1:0] brightness,master_volume,bgm_volume,sfx_volume;
    wire [1:0] contrast,transition_mode;
    wire media_fullscreen,auto_action,next_action,previous_action,effect_action,contrast_action;
    wire reset_game,profile_request,scores_request,audition;
    wire [4:0] audition_id;
    integer autos=0,nexts=0,resets=0;
    game_menu dut(.*);
    always #5 clk=~clk;
    always @(negedge clk)begin if(auto_action)autos++;if(next_action)nexts++;if(reset_game)resets++;end
    task event_key(input integer k);begin
        @(negedge clk);case(k)0:back_press=1;1:left_press=1;2:right_press=1;3:confirm=1;4:confirm_long=1;endcase
        @(negedge clk);back_press=0;left_press=0;right_press=0;confirm=0;confirm_long=0;
        repeat(3)@(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;repeat(2)@(negedge clk);
    end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        if(!audio_enabled||view_narrow||active)$fatal(1,"boot defaults");
        switches=3;event_key(2);event_key(0);
        if(!active||!debug_mode||!media_fullscreen||!osd_enable||nexts!=1||autos!=1)$fatal(1,"media lab");
        switches=4;event_key(4);event_key(0);
        if(page!=2||!view_narrow)$fatal(1,"display lab");
        event_key(2);event_key(2);event_key(0);
        if(!calibration)$fatal(1,"calibration");
        event_key(2);event_key(0);
        if(brightness!=1)$fatal(1,"brightness setting");
        event_key(2);event_key(0);
        if(contrast!=1)$fatal(1,"contrast setting");
        event_key(2);event_key(0);event_key(0);
        if(transition_mode!=2)$fatal(1,"transition setting");
        event_key(0);
        if(transition_mode!=0)$fatal(1,"transition wrap");
        event_key(2);event_key(0);
        if(view_narrow||palette_mode||brightness||calibration||contrast||transition_mode)
            $fatal(1,"display reset must restore every setting");
        switches=8;event_key(4);event_key(1);event_key(0);
        if(page!=3||!test_tone||!audio_enabled)$fatal(1,"audio test tone");
        @(negedge clk);confirm=1;frame_tick=1;
        @(negedge clk);confirm=0;frame_tick=0;
        if(!profile_request||calibration||test_tone)$fatal(1,"KEY4 must leave any lab");
        game_state=1;switches=15;event_key(0);
        if(active||debug_mode||osd_enable||calibration)$fatal(1,"profile debug leaked");
        game_state=2;event_key(3);
        if(active||profile_request||resets)$fatal(1,"gameplay debug leaked");
        $display("PASS game menu: boot-only labs, media actions, display, tone, KEY4 exit and gameplay isolation");$finish;
    end
endmodule

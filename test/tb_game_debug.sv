`timescale 1ns/1ps
module tb_game_debug;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,frame_tick=0,debug_mode=0,back_press=0,left_press=0,right_press=0,
        jump_short=0,jump_long=0,held_left=0,held_right=0;
    wire media_fullscreen,test_tone,auto_key_n,effect_key_n,next_key_n,previous_key_n;wire [1:0] brightness;
    game_debug_controls #(.CLOCK_HZ(100),.SHORT_CYCLES(5),.LONG_CYCLES(12)) dut(.*);
    task frame;begin @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;end endtask
    task short_key;begin @(negedge clk);jump_short=1;@(negedge clk);jump_short=0;end endtask
    task long_key;begin @(negedge clk);jump_long=1;@(negedge clk);jump_long=0;end endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        if(!media_fullscreen||test_tone||brightness!=0)$fatal(1,"defaults");
        debug_mode=1;back_press=1;@(negedge clk);back_press=0;
        repeat(4)@(negedge clk);if(!media_fullscreen)$fatal(1,"mode changed midframe");
        frame;if(media_fullscreen)$fatal(1,"queued back lost");
        short_key;frame;if(auto_key_n)$fatal(1,"auto pulse missing");
        repeat(4)@(negedge clk);if(auto_key_n)$fatal(1,"auto pulse too short");
        @(negedge clk);if(!auto_key_n)$fatal(1,"auto pulse too long");
        held_left=1;held_right=1;repeat(3)@(negedge clk);frame;
        if(!test_tone)$fatal(1,"chord tone missing");frame;if(!test_tone)$fatal(1,"held chord repeated");
        short_key;frame;if(brightness!=1||!auto_key_n)$fatal(1,"brightness chord leaked auto");
        long_key;frame;if(effect_key_n)$fatal(1,"contrast pulse missing");
        repeat(5)@(negedge clk);if(!effect_key_n)$fatal(1,"contrast used long pulse");
        held_left=0;held_right=0;long_key;frame;if(effect_key_n)$fatal(1,"transition pulse missing");
        repeat(11)@(negedge clk);if(effect_key_n)$fatal(1,"transition pulse too short");
        @(negedge clk);if(!effect_key_n)$fatal(1,"transition pulse too long");
        short_key;debug_mode=0;@(negedge clk);frame;
        if(test_tone||!auto_key_n||!effect_key_n)$fatal(1,"exit did not clear tone or pending presses");
        debug_mode=1;frame;if(!auto_key_n)$fatal(1,"stale press on re-entry");
        $display("PASS game_debug queued frame controls chords pulse widths exit cancellation");$finish;
    end
endmodule

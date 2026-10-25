`timescale 1ns/1ps
module tb_game_reward_fx;
    reg clk=0,rst=1,frame_tick=0,paused=0,clear=0,reward_valid=0;
    reg [3:0] reward_kind=0;
    reg [11:0] reward_x=0,world_x=0;
    reg [8:0] reward_y=0,world_y=0;
    wire coin_on,text_on;
    wire [3:0] coin_u,coin_v;
    wire [7:0] text_char;
    wire [2:0] text_row,text_col;
    game_reward_fx dut(.*);
    always #5 clk=~clk;
    task tick;
        @(negedge clk);frame_tick=1;
        @(negedge clk);frame_tick=0;
        repeat(3)@(negedge clk);
    endtask
    task emit(input [3:0] code,input [11:0] x,input [8:0] y);
        @(negedge clk);reward_valid=1;reward_kind=code;reward_x=x;reward_y=y;
        @(negedge clk);reward_valid=0;
    endtask
    task reset_slots;
        @(negedge clk);clear=1;
        @(negedge clk);clear=0;
    endtask
    task probe(input [11:0] x,input [8:0] y);
        world_x=x;world_y=y;#1;
    endtask
    task letter(input [11:0] x,input [8:0] y,input [7:0] value);
        probe(x,y);
        if(!text_on||text_char!==value||text_col!==0||text_row!==0)
            $fatal(1,"reward text at %0d,%0d got on=%b ch=%h row=%d col=%d expected=%h",
                x,y,text_on,text_char,text_row,text_col,value);
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        probe(32,144);if(coin_on||text_on)$fatal(1,"effects visible before event");
        emit(0,32,160);probe(32,144);
        if(!coin_on||coin_u!=0||coin_v!=0||text_on)$fatal(1,"coin initial launch");
        repeat(2)tick();probe(32,136);
        if(coin_on)$fatal(1,"edge-on coin not narrowed");
        probe(36,136);if(!coin_on||coin_u!=0||coin_v!=0)$fatal(1,"half-width coin");
        repeat(2)tick();probe(36,129);
        if(coin_on)$fatal(1,"quarter-width coin not narrowed");
        probe(38,129);if(!coin_on||coin_u!=0)$fatal(1,"quarter-width coin");
        // Pause must preserve both trajectory and lifetime, including debug.
        paused=1;repeat(80)tick();probe(38,129);
        if(!coin_on||coin_v!=0)$fatal(1,"paused coin advanced");
        paused=0;repeat(20)tick();
        letter(28,128,"2");letter(36,128,"0");letter(44,128,"0");
        probe(52,128);if(text_on||coin_on)$fatal(1,"coin popup width");
        repeat(23)tick();letter(28,117,"2");
        tick();probe(28,116);if(text_on||coin_on)$fatal(1,"coin did not expire");
        // All reward kinds share one font lookup, with explicit character bounds.
        for(integer code=1;code<=9;code=code+1)begin
            reset_slots();emit(code,100,100);
            case(code)
                1:letter(96,92,"2");2:letter(92,92,"1");
                3:begin letter(96,92,"1");letter(104,92,"U");letter(112,92,"P");end
                4:begin letter(100,92,"5");letter(108,92,"0");end
                5:letter(96,92,"1");6:letter(96,92,"4");7:letter(96,92,"8");
                8:letter(92,92,"2");9:letter(92,92,"5");
            endcase
            repeat(39)tick();probe(100,73);if(!text_on)$fatal(1,"reward expired early kind=%d",code);
            tick();probe(100,72);if(text_on)$fatal(1,"reward never expired kind=%d",code);
        end
        // Two rapid rewards retain independent positions; a third replaces the oldest.
        reset_slots();emit(1,100,100);emit(2,200,120);
        letter(96,92,"2");letter(192,112,"1");
        emit(3,300,140);
        probe(96,92);if(text_on)$fatal(1,"oldest slot not replaced");
        letter(192,112,"1");letter(296,132,"1");
        // World coordinates remain attached as the camera moves; high bits and
        // negative differences must not alias the left or bottom screen edges.
        reset_slots();emit(2,3200,176);letter(3192,168,"1");
        probe(120,168);if(text_on)$fatal(1,"world x truncated");
        probe(3191,168);if(text_on)$fatal(1,"text leaked left");
        probe(3192,167);if(text_on)$fatal(1,"text leaked above");
        reset_slots();emit(2,0,0);letter(0,0,"1");
        probe(4095,511);if(text_on||coin_on)$fatal(1,"top-left effect wrapped");
        reset_slots();emit(0,0,4);probe(0,0);
        if(!coin_on||coin_u!=0||coin_v!=0)$fatal(1,"top-edge coin clipping");
        probe(0,500);if(coin_on)$fatal(1,"coin wrapped to bottom");
        // Clear dominates event insertion; reset and restart cannot retain stale rewards.
        @(negedge clk);clear=1;reward_valid=1;
        @(negedge clk);clear=0;reward_valid=0;probe(0,0);
        if(coin_on||text_on)$fatal(1,"clear/event collision");
        $display("PASS reward effects: coin arc/spin, two slots, 200/1000/1UP/flag text, pause, lifetime, clipping, replacement");
        $finish;
    end
    initial begin #1000000;$fatal(1,"reward effects timeout");end
endmodule

`timescale 1ns/1ps
module tb_game_alignment_controls;
    reg clk=0,rst=1,frame_tick=0;
    reg [3:0] keys=15,sw=0;
    wire active,blocked;
    wire [9:0] offset;
    always #5 clk=~clk;
    game_display_alignment dut(clk,rst,frame_tick,keys,sw,active,blocked,offset);
    task frame;begin
        @(negedge clk);frame_tick=1;@(negedge clk);frame_tick=0;repeat(8)@(negedge clk);
    end endtask
    task settle;begin repeat(7)frame();end endtask
    task tap(input [3:0] value);begin keys=value;settle();keys=15;settle();end endtask
    reg [9:0] saved;
    initial begin
        repeat(3)frame();rst=0;settle();
        if(offset!=128||blocked)$fatal(1,"Boot default/arming");
        tap(4'b1011);if(offset!=128)$fatal(1,"Game key changed offset");
        sw=4;keys=7;settle();
        if(!active||!blocked||offset!=128)$fatal(1,"Entry held key leaked");
        keys=15;settle();tap(7);if(offset!=0)$fatal(1,"Zero");
        tap(14);if(offset!=639)$fatal(1,"Right wrap");
        tap(11);if(offset!=0)$fatal(1,"Left wrap");
        keys=13;settle();keys=9;settle();keys=15;settle();
        if(offset!=16)$fatal(1,"Coarse step %d",offset);
        keys=11;repeat(40)frame();keys=15;settle();
        if(offset<=17)$fatal(1,"Hold did not repeat");
        saved=offset;keys=7;sw=0;settle();
        if(active||!blocked)$fatal(1,"Exit must await key release");
        keys=15;settle();if(blocked||offset!=saved)$fatal(1,"Exit changed offset");
        tap(11);if(offset!=saved)$fatal(1,"Game key changed saved offset");
        // A sub-frame glitch cannot activate calibration or move the image.
        sw=4;repeat(2)@(negedge clk);sw=0;settle();
        if(active||offset!=saved)$fatal(1,"Switch bounce");
        $display("PASS alignment controls: fine/coarse/wrap/repeat/entry/exit/bounce");$finish;
    end
endmodule

`timescale 1ns/1ps
module tb_game_inputs;
    reg clk=0,rst=1,frame_tick=0,gameplay_active=0,debug_mode=0;
    reg [3:0] keys_n=15,switches=0;
    wire held_left,held_right,jump_hold,held_run,held_down,switches_armed;
    wire left_press,right_press,jump_press,jump_short,jump_long,back_press,reset_game,sound_toggle;
    wire [3:0] frame_switches;
    integer nj=0,ns=0,nl=0,nb=0,np=0;
    always #5 clk=~clk;
    game_inputs #(.DEBOUNCE(3),.LONG_PRESS(16)) dut(.*,.key_left_held(),.key_right_held());
    always @(negedge clk) if(!rst) begin
        if(jump_press)nj=nj+1;if(jump_short)ns=ns+1;if(jump_long)nl=nl+1;
        if(back_press)nb=nb+1;if(left_press)np=np+1;
        if(reset_game||sound_toggle)$fatal(1,"legacy gesture leaked");
    end
    task cycles(input integer n);begin repeat(n)begin @(posedge clk);#1;end end endtask
    task tick;begin @(negedge clk);frame_tick=1;cycles(1);@(negedge clk);frame_tick=0;cycles(1);end endtask
    task sw(input [3:0] v);begin switches=v;cycles(8);tick();end endtask
    initial begin
        cycles(3);rst=0;cycles(4);
        keys_n[1]=0;cycles(8);
        if(!held_left||np!=1)$fatal(1,"KEY2 menu navigation");
        keys_n[1]=1;cycles(8);
        keys_n[3]=0;cycles(8);keys_n[3]=1;cycles(8);
        if(nj!=1||ns!=1||nl!=0||jump_hold)$fatal(1,"KEY4 short confirm");
        keys_n[3]=0;cycles(30);keys_n[3]=1;cycles(8);
        if(nl!=1||ns!=1)$fatal(1,"KEY4 long also short");
        keys_n[1]=0;cycles(8);switches=15;cycles(8);gameplay_active=1;cycles(3);tick();
        if(switches_armed||held_left||jump_hold||held_run)$fatal(1,"unsafe entry with action key held");
        keys_n=15;cycles(8);tick();tick();
        if(!switches_armed||!held_run||held_right||held_left||jump_hold)$fatal(1,"SW1-3 leaked into gameplay");
        keys_n[0]=0;cycles(8);if(!held_right||held_left)$fatal(1,"KEY1 right");
        keys_n[2]=0;cycles(8);if(!held_down)$fatal(1,"opposing directions crouch");
        keys_n[0]=1;cycles(8);if(!held_left||held_right)$fatal(1,"KEY3 left");
        keys_n=15;cycles(8);keys_n[1]=0;cycles(8);tick();
        if(!jump_hold||nj!=3)$fatal(1,"KEY2 jump %0d",nj);
        repeat(3)tick();if(nj!=3)$fatal(1,"held KEY2 repeated jump");
        keys_n[1]=1;cycles(8);tick();keys_n[1]=0;cycles(8);tick();
        if(nj!=4)$fatal(1,"KEY2 rearm jump");
        debug_mode=1;cycles(4);tick();
        if(jump_hold||held_run||switches_armed)$fatal(1,"pause did not disarm");
        keys_n=15;cycles(8);debug_mode=0;cycles(4);tick();
        tick();if(!switches_armed||jump_hold)$fatal(1,"released keys must resume even with switches on");
        keys_n[1]=0;cycles(8);tick();if(nj!=5)$fatal(1,"resume jump missing");
        keys_n[0]=0;cycles(30);keys_n[0]=1;cycles(8);
        if(nb!=0)$fatal(1,"gameplay KEY1 must not open debug");
        $display("PASS game inputs: key UI, KEY3/KEY2/KEY1 gameplay, SW4 run, jump edges, safe resume");$finish;
    end
    initial begin #100000;$fatal(1,"timeout");end
endmodule

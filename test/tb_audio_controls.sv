`timescale 1ns/1ps
module tb_audio_controls;
    reg clk=0,rst=1,key=1;wire auto_n,sound;
    always #20 clk=~clk;
    audio_controls #(.DEBOUNCE(3),.LONG_PRESS(20),.AUTO_PULSE(8)) dut(clk,rst,key,auto_n,sound);
    task tick(input integer n);begin repeat(n)@(negedge clk);end endtask
    integer autoplay_pulses=0;reg auto_prev=1;
    always @(posedge clk) if(!rst) begin
        auto_prev<=auto_n;
        if(auto_prev&&!auto_n) autoplay_pulses=autoplay_pulses+1;
    end
    initial begin
        tick(4);rst=0;tick(2);if(sound||!auto_n) $fatal(1,"not muted at reset");
        key=0;tick(1);key=1;tick(8);if(autoplay_pulses||sound) $fatal(1,"bounce");
        key=0;tick(9);key=1;tick(20);
        if(autoplay_pulses!=1||sound) $fatal(1,"short release");
        key=0;tick(40);if(sound) $fatal(1,"enabled before release");key=1;tick(20);
        if(!sound||autoplay_pulses!=1) $fatal(1,"long also toggled autoplay");
        key=0;tick(40);key=1;tick(20);if(sound) $fatal(1,"mute toggle");
        key=0;tick(40);key=1;tick(20);rst=1;tick(2);
        if(sound) $fatal(1,"reset did not mute");
        $display("PASS audio controls: reset mute, debounce, short autoplay, long sound only");$finish;
    end
endmodule

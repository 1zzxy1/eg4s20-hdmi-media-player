`timescale 1ns/1ps
module tb_game_audio;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,sample_tick=0,play_enable=1,paused=0,mute=1;
    reg [3:0] event_code=0;wire signed [23:0] pcm;
    game_audio dut(.*);
    integer changes=0;integer i;reg signed [23:0] last_pcm;reg [23:0] old_phase;
    reg signed [23:0] signatures [1:13];
    function integer expected_length(input integer kind);
        case(kind)
            1:expected_length=2600;2:expected_length=4600;3:expected_length=3400;
            4:expected_length=9600;5:expected_length=7200;6:expected_length=12000;
            7:expected_length=7600;8:expected_length=1800;9:expected_length=5800;
            10:expected_length=4200;11:expected_length=10400;12:expected_length=2200;
            13:expected_length=9000;default:expected_length=0;
        endcase
    endfunction
    task sample;begin @(negedge clk);sample_tick=1;@(negedge clk);sample_tick=0;end endtask
    initial begin
        repeat(3) @(negedge clk);rst=0;sample;#1;if(pcm!=0)$fatal(1,"mute");
        mute=0;last_pcm=0;
        for(i=0;i<500;i=i+1) begin sample;#1;if(pcm!=last_pcm) changes=changes+1;last_pcm=pcm;
            if(pcm>1200000 || pcm< -1200000)$fatal(1,"clipping");end
        if(changes<30)$fatal(1,"melody not changing");
        @(negedge clk);event_code=2;@(negedge clk);event_code=0;
        if(dut.fx_left!=4600)$fatal(1,"off-sample event lost");sample;
        if(dut.fx_left!=4599)$fatal(1,"effect countdown");
        paused=1;old_phase=dut.phase_a;repeat(10)sample;
        if(pcm!=0 || dut.phase_a!=old_phase)$fatal(1,"pause");
        paused=0;mute=1;sample;if(pcm!=0)$fatal(1,"final mute");
        play_enable=0;sample;if(dut.note!=0)$fatal(1,"stop melody");
        mute=0;@(negedge clk);event_code=4;@(negedge clk);event_code=0;
        if(dut.fx_left!=9600)$fatal(1,"clear event lost after leaving PLAY");
        sample;if(pcm==0)$fatal(1,"clear tail silent");
        repeat(9602)sample;if(pcm!=0)$fatal(1,"tail did not end");
        @(negedge clk);event_code=3;@(negedge clk);event_code=0;sample;
        if(pcm==0)$fatal(1,"death tail silent");
        for(i=1;i<=13;i=i+1) begin
            @(negedge clk);event_code=i;@(negedge clk);event_code=0;
            if(dut.fx_kind!=i || dut.fx_left!=expected_length(i))
                $fatal(1,"event %0d length/capture",i);
            signatures[i]=dut.fx_pitch;
            sample;
            if(pcm==0)$fatal(1,"event %0d silent",i);
        end
        for(i=1;i<=13;i=i+1)
            for(integer j=i+1;j<=13;j=j+1)
                if(signatures[i]==signatures[j])$fatal(1,"events %0d and %0d share pitch",i,j);
        $display("PASS game_audio waveform mute pause asynchronous event and terminal tails");$finish;
    end
endmodule

`timescale 1ns/1ps
// Public-port PCM integration, including the real sector arbiter and byte bridge.
module tb_game_sd_audio;
    parameter LIFECYCLE=0;
    reg clk=0,sd_clk=0,rst=1;
    always #20 clk=~clk;
    always #10 sd_clk=~sd_clk;
    reg sample_tick=0,play_enable=0,paused=0,mute=0,event_valid=0,audition=0;
    reg star_mode=0;
    reg [4:0] event_id=0,audition_id=0;
    reg [1:0] master_volume=3,bgm_volume=3,sfx_volume=3;
    wire signed [23:0] pcm;
    wire available,error;
    wire [15:0] underruns,dropped_events;
    wire audio_req;wire [31:0] audio_addr;
    wire [7:0] audio_data;wire audio_valid,audio_end;
    reg bmp_req=0;reg [31:0] bmp_addr=500;
    wire [7:0] bmp_data;wire bmp_valid,bmp_end;
    wire sd_req;wire [31:0] sd_addr;
    reg [7:0] sd_data=0;reg sd_valid=0,sd_end=0;
    sd_pcm_player dut(.clk(clk),.rst(rst),.sd_clk(sd_clk),.sd_rst(rst),.initialized(!rst),
        .sample_tick(sample_tick),.play_enable(play_enable),.star_mode(star_mode),.paused(paused),.mute(mute),
        .event_valid(event_valid),.event_id(event_id),.audition(audition),.audition_id(audition_id),
        .master_volume(master_volume),.bgm_volume(bgm_volume),.sfx_volume(sfx_volume),
        .pcm(pcm),.available(available),.error(error),.underruns(underruns),
        .dropped_events(dropped_events),.sd_req(audio_req),.sd_addr(audio_addr),
        .sd_data(audio_data),.sd_valid(audio_valid),.sd_end(audio_end));
    sd_sector_arbiter arb(.clk(sd_clk),.rst(rst),.initialized(!rst),
        .bmp_req(bmp_req),.bmp_addr(bmp_addr),.audio_req(audio_req),.audio_addr(audio_addr),
        .sd_req(sd_req),.sd_addr(sd_addr),.sd_data(sd_data),.sd_valid(sd_valid),.sd_end(sd_end),
        .bmp_data(bmp_data),.audio_data(audio_data),.bmp_valid(bmp_valid),.bmp_end(bmp_end),
        .audio_valid(audio_valid),.audio_end(audio_end));
    function [15:0] metadata(input integer w);
        integer t,f;
        begin
            metadata=0;
            case(w)
                0:metadata=16'h5046;1:metadata=16'h4147;
                2:metadata=16'h4455;3:metadata=16'h2131;
                4:metadata=48000;6:metadata=24;7:metadata=1;8:metadata=100;10:metadata=97;
            endcase
            if(w>=16&&w<208)begin
                t=(w-16)/8;f=(w-16)%8;
                case(f)0:metadata=1+t*4;2:metadata=1021;4:metadata=t==0;5:metadata=t;endcase
            end
        end
    endfunction
    function [7:0] sector_byte(input integer lba,n);
        reg signed [15:0] value;integer t;
        begin
            t=(lba-101)/4;
            value=lba==1?metadata(n/2):t==0?1000:t==5?30000:t*100;
            if(LIFECYCLE&&lba!=1&&(t==0||t==13))
                value=(t==0?1000:4000)+((lba-101)%4)*256+n/2;
            sector_byte=n%2?value[15:8]:value[7:0];
        end
    endfunction
    reg busy=0,wait_low=0;integer byte_index=0,delay_count=0,sector_lba=0;
    integer audio_sectors=0,bmp_bytes=0;
    always @(posedge sd_clk)begin
        sd_valid<=0;sd_end<=0;
        if(rst)begin busy<=0;wait_low<=0;byte_index<=0;delay_count<=0;end
        else if(wait_low)begin if(!sd_req)wait_low<=0;end
        else if(!busy)begin
            if(sd_req)begin
                busy<=1;sector_lba<=sd_addr;byte_index<=0;delay_count<=0;
                if(sd_addr!=500)audio_sectors<=audio_sectors+1;
            end
        end else if(delay_count==31)begin
            delay_count<=0;sd_valid<=1;sd_data<=sector_byte(sector_lba,byte_index);
            if(byte_index==511)begin busy<=0;wait_low<=1;sd_end<=1;end
            else byte_index<=byte_index+1;
        end else delay_count<=delay_count+1;
        if(bmp_valid)bmp_bytes<=bmp_bytes+1;
        if(bmp_end)bmp_req<=0;
        if(bmp_valid&&audio_valid)$fatal(1,"sector leaked between clients");
    end
    task tick;
        begin @(negedge clk);sample_tick=1;@(negedge clk);sample_tick=0;repeat(519)@(negedge clk);end
    endtask
    task expect_pcm(input integer n);
        begin if($signed(pcm)!=(n*256))$fatal(1,"PCM expected %0d got %0d",n,$signed(pcm)/256);end
    endtask
    task event_sound(input [4:0] id);
        begin @(negedge clk);event_id=id;event_valid=1;@(negedge clk);event_valid=0;end
    endtask
    integer i;
    initial begin
        #200;@(negedge clk);rst=0;bmp_req=1;
        wait(available);if(error)$fatal(1,"metadata failed");
        play_enable=1;#2000000;
        if(bmp_bytes!=512)$fatal(1,"BMP sector was not atomic");
        if(LIFECYCLE)begin
            tick;expect_pcm(1000);tick;expect_pcm(1001);
            paused=1;tick;expect_pcm(0);
            paused=0;tick;expect_pcm(1002);
            mute=1;tick;expect_pcm(0);mute=0;tick;expect_pcm(1004);
            // Star replaces the ordinary song, does not consume a SFX slot,
            // and loops at the descriptor's non-sector-aligned sample count.
            star_mode=1;event_sound(13);#2000000;tick;expect_pcm(4000);
            for(i=0;i<1021;i=i+1)tick;
            expect_pcm(4000);tick;expect_pcm(4001);
            paused=1;star_mode=0;#2000000;tick;expect_pcm(0);
            paused=0;tick;expect_pcm(1000);
            // Stop only BGM. A death/flag cue must remain audible, then the
            // next life must start at sample zero instead of resuming sample 1.
            play_enable=0;event_sound(4);#2000000;tick;expect_pcm(400);
            for(i=0;i<1021;i=i+1)tick;
            expect_pcm(0);
            play_enable=1;#2000000;tick;expect_pcm(1000);tick;expect_pcm(1001);
            // Multiple switches during a 12.5MHz SPI sector: no old fill may
            // become valid for the final song, including stop/restart in flight.
            star_mode=1;#1000;star_mode=0;#1000;star_mode=1;
            #2500000;tick;expect_pcm(4000);
            star_mode=0;#1000;play_enable=0;#1000;play_enable=1;
            #2500000;tick;expect_pcm(1000);
            if(error||dropped_events!=0||underruns!=0)
                $fatal(1,"music lifecycle fault error=%0d dropped=%0d underruns=%0d",error,dropped_events,underruns);
            $display("PASS music lifecycle: output PCM ramp, star replacement/loop, pause, mute, death cue, respawn reset, in-flight switching; underruns=%0d",underruns);
            $finish;
        end
        tick;expect_pcm(1000);
        for(i=0;i<4;i=i+1)event_sound(i+1);
        #2500000;tick;expect_pcm(2000);
        master_volume=2;tick;expect_pcm(1000);master_volume=3;
        mute=1;tick;expect_pcm(0);mute=0;tick;expect_pcm(2000);
        paused=1;tick;expect_pcm(0);
        @(negedge clk);audition_id=1;audition=1;@(negedge clk);audition=0;
        #1000000;tick;expect_pcm(100);
        // Reset independently through public ports for a saturation/loop endurance run.
        rst=1;repeat(5)@(negedge clk);rst=0;paused=0;
        wait(available);#2000000;event_sound(5);event_sound(5);#1500000;
        tick;expect_pcm(32767);
        // Once both SFX finish, BGM must wrap and refill without stale voice data.
        for(i=0;i<1100;i=i+1)tick;
        expect_pcm(1000);
        if(error||dropped_events!=0)$fatal(1,"stream error or event loss");
        if(underruns!=0)$fatal(1,"unexpected underruns %0d",underruns);
        $display("PASS SD PCM: 5 voices, sector arbitration, volumes, mute, pause, audition, saturation, loop; underruns=%0d sectors=%0d",underruns,audio_sectors);
        $finish;
    end
    initial begin #150000000;$fatal(1,"SD audio timeout");end
endmodule

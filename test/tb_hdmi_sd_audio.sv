`timescale 1ns/1ps
// Real card-image bytes -> arbiter -> CDC -> mixer -> protected HDMI core.
// The endpoint models byte delivery at 12.5 MHz, not SD command/electrical IO.
module tb_hdmi_sd_audio;
    parameter DIRECT=1;
    reg clk=0,sd_clk=0,rst=1;
    always #20 clk=~clk;
    always #10 sd_clk=~sd_clk;
    integer cycle=0,ticks=0;
    wire tick,acr;
    wire [19:0] n,cts;
    pcm48_tone clock_source(clk,rst,tick,,,acr,n,cts);
    reg av=0;
    always @(posedge clk) if(rst)av<=0;else av<=tick;
    reg play_enable=0,paused=0,mute=0,event_valid=0;
    reg [4:0] event_id=0;
    reg [1:0] master_volume=3,bgm_volume=3,sfx_volume=3;
    wire signed [23:0] pcm;
    wire available,error;
    wire [15:0] underruns,dropped;
    wire audio_req,audio_valid,audio_end;
    wire [31:0] audio_addr;
    wire [7:0] audio_data;
    sd_pcm_player player(.clk(clk),.rst(rst),.sd_clk(sd_clk),.sd_rst(rst),.initialized(!rst),
        .sample_tick(tick),.play_enable(play_enable),.star_mode(1'b0),.paused(paused),.mute(mute),
        .event_valid(event_valid),.event_id(event_id),.audition(1'b0),.audition_id(5'd0),
        .master_volume(master_volume),.bgm_volume(bgm_volume),.sfx_volume(sfx_volume),
        .pcm(pcm),.available(available),.error(error),.underruns(underruns),.dropped_events(dropped),
        .sd_req(audio_req),.sd_addr(audio_addr),.sd_data(audio_data),.sd_valid(audio_valid),.sd_end(audio_end));
    reg bmp_req=0;
    reg [31:0] bmp_addr=2337;
    wire [7:0] bmp_data;
    wire bmp_valid,bmp_end,sd_req;
    wire [31:0] sd_addr;
    reg [7:0] sd_data=0;
    reg sd_valid=0,sd_end=0;
    sd_sector_arbiter arb(.clk(sd_clk),.rst(rst),.initialized(!rst),
        .bmp_req(bmp_req),.bmp_addr(bmp_addr),.audio_req(audio_req),.audio_addr(audio_addr),
        .sd_req(sd_req),.sd_addr(sd_addr),.sd_data(sd_data),.sd_valid(sd_valid),.sd_end(sd_end),
        .bmp_data(bmp_data),.bmp_valid(bmp_valid),.bmp_end(bmp_end),
        .audio_data(audio_data),.audio_valid(audio_valid),.audio_end(audio_end));
    string image_path;
    integer image_fd,rc;
    reg [7:0] sector[0:511];
    reg busy=0,wait_low=0;
    integer byte_index=0,divider=0,latency=0,lba=0,bmp_bytes=0,bmp_sectors=0,audio_sectors=0;
    integer symbols_fd,pcm_fd,ticks_fd,events_fd,sectors_fd,status_fd;
    initial begin
        if(!$value$plusargs("IMAGE=%s",image_path))$fatal(1,"missing IMAGE");
        image_fd=$fopen(image_path,"rb");
        symbols_fd=$fopen("audio_sd_symbols.txt","w");
        pcm_fd=$fopen("audio_sd_input.txt","w");
        ticks_fd=$fopen("audio_sd_ticks.txt","w");
        events_fd=$fopen("audio_sd_events.txt","w");
        sectors_fd=$fopen("audio_sd_sectors.txt","w");
        status_fd=$fopen("audio_sd_status.txt","w");
        if(!image_fd||!symbols_fd||!pcm_fd||!ticks_fd||!events_fd||!sectors_fd||!status_fd)
            $fatal(1,"cannot open SD audio fixture/trace");
    end
    always @(posedge sd_clk)begin
        sd_valid<=0;sd_end<=0;
        if(!rst)begin
            if(wait_low)begin if(!sd_req)wait_low<=0;end
            else if(!busy)begin
                if(sd_req)begin
                    lba=sd_addr;
                    rc=$fseek(image_fd,lba*512,0);
                    if(rc!=0)$fatal(1,"image seek failed LBA %0d",lba);
                    rc=$fread(sector,image_fd);
                    if(rc!=512)$fatal(1,"short image sector %0d: %0d",lba,rc);
                    busy<=1;byte_index<=0;divider<=0;latency<=0;
                end
            // Fixed command/response latency keeps first-sector completion
            // clear of the mix window; the independent oracle rejects any
            // ambiguous boundary rather than looking at private DUT state.
            end else if(latency<64)latency<=latency+1;
            else if(divider==31)begin
                divider<=0;sd_valid<=1;sd_data<=sector[byte_index];
                if(byte_index==511)begin busy<=0;wait_low<=1;sd_end<=1;end
                else byte_index<=byte_index+1;
            end else divider<=divider+1;
            if(audio_end)begin
                audio_sectors=audio_sectors+1;
                $fdisplay(sectors_fd,"%0d %0d A",cycle,lba);
            end
            if(bmp_valid)begin
                if(bmp_data!==sector[bmp_bytes])$fatal(1,"BMP byte changed owner/index");
                bmp_bytes=bmp_bytes+1;
            end
            if(bmp_end)begin
                if(bmp_bytes!=512)$fatal(1,"non-atomic BMP sector %0d",bmp_bytes);
                bmp_bytes=0;bmp_sectors=bmp_sectors+1;bmp_req<=0;
                $fdisplay(sectors_fd,"%0d %0d B",cycle,lba);
            end else if(!bmp_req)begin
                bmp_req<=1;bmp_addr<=2337+(bmp_sectors%64);
            end
            if(bmp_valid&&audio_valid)$fatal(1,"SD sector client overlap");
        end
    end
    wire hs,vs,de,req,user,valid,last,ready,locked;
    wire [23:0] axis;
    video_timing_data timing(clk,rst,req,req,hs,vs,de);
    video_rgb_to_axis_640x480 pack(clk,rst,vs,de,24'h305070,user,valid,last,axis);
    wire [23:0] output_pcm=mute||!available?24'd0:pcm;
    wire [9:0] c0,c1,c2,cc;
    reg serial_clk=0;
    always #4 serial_clk=~serial_clk;
    wire sd0,sd1,sd2,sck;
    wire [31:0] serial_words;
    hdmi_phy_wrapper #(.DEVICE("EG")) phy(
        .I_pixel_clk(clk),.I_serial_clk(serial_clk),.I_rst(rst),
        .I_tmds_channel_0(c0),.I_tmds_channel_1(c1),.I_tmds_channel_2(c2),.I_tmds_channel_clk(cc),
        .O_tmds_ch0_p(sd0),.O_tmds_ch1_p(sd1),.O_tmds_ch2_p(sd2),.O_tmds_clk_p(sck));
    hdmi_serial_capture receiver(clk,serial_clk,rst,c0,c1,c2,cc,sd0,sd1,sd2,sck,serial_words);
    tri1 sda;
    generate if(DIRECT)begin:direct_tx
        wire overflow;
        game_hdmi_tx dut(clk,rst,hs,vs,de,24'h305070,av,output_pcm,output_pcm,acr,c0,c1,c2,cc,overflow);
        assign ready=1'b1;
        assign locked=!rst;
        always @(posedge clk)if(!rst&&overflow)$fatal(1,"direct HDMI overflow");
    end else begin:vendor_tx
        wire overflow;
        game_hdmi_output hdmi(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.rgb(24'h305070),
            .sample_valid(av),.sample_left(output_pcm),.sample_right(output_pcm),.acr_valid(acr),
            .c0(c0),.c1(c1),.c2(c2),.cc(cc),.overflow(overflow),.locked(locked));
        assign ready=hdmi.ready;
        always @(posedge clk)if(!rst&&overflow)$fatal(1,"vendor HDMI overflow");
    end endgenerate
    always @(posedge clk)begin
        if(!rst&&tick)begin
            $fdisplay(ticks_fd,"%0d %0d %0d %0d %0d %0d %0d",cycle,ticks,paused,mute,master_volume,bgm_volume,sfx_volume);
            ticks=ticks+1;
        end
        if(!rst&&av)$fdisplay(pcm_fd,"%0d %06h %06h",cycle,output_pcm,output_pcm);
        #1;cycle=cycle+1;
        if(!rst)$fdisplay(symbols_fd,"%0d %03h %03h %03h",cycle,c0,c1,c2);
        if(cycle==420000*5)begin
            if(error||dropped!=0||!available||!locked||bmp_sectors<20||audio_sectors<20)
                $fatal(1,"SD HDMI status error=%0d dropped=%0d BMP=%0d audio=%0d",error,dropped,bmp_sectors,audio_sectors);
            $fdisplay(status_fd,"%0d %0d %0d %0d %0d",underruns,dropped,error,bmp_sectors,audio_sectors);
            $fclose(image_fd);$fclose(symbols_fd);$fclose(pcm_fd);$fclose(ticks_fd);$fclose(events_fd);$fclose(sectors_fd);$fclose(status_fd);
            #120;
            if(serial_words<2099900)$fatal(1,"SD HDMI serial capture incomplete words=%0d",serial_words);
            $display("PASS HDMI serial pins: words=%0d",serial_words);
            $display("PASS SD HDMI audio: real image, BGM + four SFX, pause/mute/volumes, BMP=%0d audio=%0d startup-inclusive underruns=%0d",bmp_sectors,audio_sectors,underruns);
            $finish;
        end
    end
    task event_sound(input [4:0] id);
        begin
            @(negedge clk);event_id=id;event_valid=1;
            $fdisplay(events_fd,"%0d %0d",cycle,id);
            @(negedge clk);event_valid=0;
        end
    endtask
    initial begin
        repeat(10)@(negedge clk);rst=0;
        wait(available);@(negedge clk);play_enable=1;
        $fdisplay(events_fd,"%0d 0",cycle);
        wait(ticks==768);repeat(64)@(negedge clk);
        event_sound(1);event_sound(2);event_sound(12);event_sound(15);
        wait(ticks==1500);repeat(64)@(negedge clk);master_volume=2;bgm_volume=1;sfx_volume=2;
        wait(ticks==2000);repeat(64)@(negedge clk);master_volume=3;bgm_volume=3;sfx_volume=3;
        wait(ticks==2200);repeat(64)@(negedge clk);paused=1;
        wait(ticks==2500);repeat(64)@(negedge clk);paused=0;
        wait(ticks==2800);repeat(64)@(negedge clk);mute=1;
        wait(ticks==3100);repeat(64)@(negedge clk);mute=0;
    end
endmodule

// Fixed 640x480 RGB + stereo 24-bit LPCM / 48 kHz, at a 25 MHz pixel clock.
// Raster timing is preserved, including blanking: no frame/line FIFO or EDID
// mode change can move pixels relative to sync. Ten look-ahead clocks provide
// the HDMI video preamble/guard without guessing which blank lines are active.
module game_hdmi_tx(
    input wire clk,rst,hs,vs,de,input wire [23:0] rgb,
    input wire sample_valid,input wire [23:0] sample_left,sample_right,
    input wire acr_valid,
    output wire [9:0] c0,c1,c2,cc,
    output reg overflow
);
    reg [9:0] hp,vp,dp;
    reg [23:0] pixels[0:9];
    reg de_d,vs_d;
    reg [9:0] x;
    wire active=dp[9];
    wire video_pre=de&&!dp[7]&&!active;
    wire video_guard=dp[7]&&!active;
    integer p;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            hp<=10'h3ff;vp<=10'h3ff;dp<=0;de_d<=0;vs_d<=1;x<=0;
            for(p=0;p<10;p=p+1)pixels[p]<=0;
        end else begin
            hp<={hp[8:0],hs};vp<={vp[8:0],vs};dp<={dp[8:0],de};
            pixels[0]<=rgb;for(p=1;p<10;p=p+1)pixels[p]<=pixels[p-1];
            de_d<=active;vs_d<=vp[9];
            // Falling DE is the start of the 160-clock horizontal blank.
            if(de_d&&!active)x<=641;
            else if(active&&!de_d)x<=1;
            else x<=x==799?0:x+1'b1;
        end
    end
    wire [9:0] raster_x=de_d&&!active?10'd640:active&&!de_d?10'd0:x;
    reg [1:0] collect;
    reg [7:0] audio_frame;
    reg [55:0] samples[0:2];
    reg [223:0] audio_body;
    reg audio_pending,audio_start,packet_load;
    reg acr_pending,avi_pending,info_pending,gcp_pending;
    reg [2:0] kind;
    reg [5:0] phase;
    reg sending;
    reg [31:0] header;
    reg [63:0] body[0:3];
    reg [3:0] bch_step;
    wire prepare=raster_x==650&&!active&&!sending;
    wire take_audio=prepare&&audio_pending;
    function [55:0] audio_word(input [23:0] l,r,input [7:0] frame_id);
        reg status,lp,rp;
        begin
            // Consumer IEC 60958: 48 kHz, 24-bit, PCM, valid samples.
            status=frame_id==25||frame_id==32||frame_id==33||frame_id==35;
            lp=^{l,status};rp=^{r,status};
            audio_word={{rp,status,2'b00,lp,status,2'b00},r,l};
        end
    endfunction
    // HDMI BCH processes bytes low first, and each byte LSB first. Compute
    // one byte per clock, avoiding a 56-XOR combinational timing path.
    function [7:0] bch_byte(input [7:0] rem,data);
        reg [7:0] v;integer k;
        begin
            v=rem;
            for(k=0;k<8;k=k+1)
                v=((v[0]^data[k])?8'h83:8'h00)^{1'b0,v[7:1]};
            bch_byte=v;
        end
    endfunction
    reg [7:0] hecc,becc[0:3];
    integer i;
    wire frame_start=vs_d&&!vp[9];
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            collect<=0;audio_frame<=0;audio_body<=0;audio_pending<=0;audio_start<=0;
            acr_pending<=1;avi_pending<=1;info_pending<=1;gcp_pending<=1;
            sending<=0;phase<=0;kind<=0;header<=0;bch_step<=8;hecc<=0;overflow<=0;packet_load<=0;
            for(i=0;i<3;i=i+1)samples[i]<=0;
            for(i=0;i<4;i=i+1)begin body[i]<=0;becc[i]<=0;end
        end else begin
            packet_load<=prepare;
            if(frame_start)begin avi_pending<=1;info_pending<=1;gcp_pending<=1;end
            if(acr_valid)acr_pending<=1;
            if(take_audio)audio_pending<=0;
            if(sample_valid)begin
                if(collect==3)begin
                    if(audio_pending&&!take_audio)overflow<=1;
                    audio_body<={audio_word(sample_left,sample_right,audio_frame),samples[2],samples[1],samples[0]};
                    audio_start<=audio_frame==3;audio_pending<=1;collect<=0;
                end else begin
                    samples[collect]<=audio_word(sample_left,sample_right,audio_frame);
                    collect<=collect+1'b1;
                end
                audio_frame<=audio_frame==191?0:audio_frame+1'b1;
            end
            if(prepare)begin
                // Audio has priority: a full four-sample group is always
                // claimed within one 800-clock line, before the next group.
                kind<=audio_pending?1:acr_pending?2:avi_pending?3:info_pending?4:gcp_pending?5:0;
                hecc<=0;for(i=0;i<4;i=i+1)becc[i]<=0;
                bch_step<=8;
                // Snapshot PCM before acknowledging it. Select constant
                // packets one clock later, keeping audio_pending off the
                // 224-bit payload mux and its physical routing fanout.
                header<={8'd0,audio_start?8'h10:8'h00,8'h0f,8'h02};
                for(i=0;i<4;i=i+1)body[i]<={8'd0,audio_body[i*56+:56]};
                if(!audio_pending)begin
                    if(acr_pending)acr_pending<=0;
                    else if(avi_pending)avi_pending<=0;
                    else if(info_pending)info_pending<=0;
                    else gcp_pending<=0;
                end
            end else if(packet_load)begin
                bch_step<=0;
                if(kind==2)begin
                    header<=32'h00000001;
                    for(i=0;i<4;i=i+1)body[i]<=64'h00001800a8610000;
                end else if(kind==3)begin
                    // RGB, underscan, 4:3, VIC 1, no repetition; checksum 5c.
                    header<=32'h000d0282;
                    body[0]<=64'h000000010010025c;body[1]<=0;body[2]<=0;body[3]<=0;
                end else if(kind==4)begin
                    // Explicit LPCM, two channels, 48 kHz, 24 bits; checksum 51.
                    header<=32'h000a0184;
                    body[0]<=64'h00000000000f1151;body[1]<=0;body[2]<=0;body[3]<=0;
                end else if(kind==5)begin
                    header<=32'h00000003;
                    // General Control: Clear_AVMUTE, default 24-bit depth.
                    body[0]<=64'h10;body[1]<=0;body[2]<=0;body[3]<=0;
                end
            end else if(bch_step<7)begin
                if(bch_step<3)hecc<=bch_byte(hecc,header[bch_step*8+:8]);
                for(i=0;i<4;i=i+1)becc[i]<=bch_byte(becc[i],body[i][bch_step*8+:8]);
                bch_step<=bch_step+1'b1;
            end else if(bch_step==7)begin
                header[31:24]<=hecc;
                for(i=0;i<4;i=i+1)body[i][63:56]<=becc[i];
                bch_step<=8;
            end
            if(raster_x==680&&kind!=0&&!active)begin sending<=1;phase<=0;end
            else if(sending)begin
                if(phase==43)begin sending<=0;kind<=0;end
                else phase<=phase+1'b1;
            end
            if(sending&&(active||video_guard||video_pre))overflow<=1;
        end
    end
    wire payload=sending&&phase>=10&&phase<42;
    wire island_guard=sending&&((phase>=8&&phase<10)||phase>=42);
    wire island_pre=sending&&phase<8;
    wire [4:0] bit_index=phase-10;
    wire [5:0] even_bit={bit_index,1'b0},odd_bit={bit_index,1'b1};
    wire [3:0] d0={1'b1,header[bit_index],vp[9],hp[9]};
    wire [3:0] d1={body[3][even_bit],body[2][even_bit],body[1][even_bit],body[0][even_bit]};
    wire [3:0] d2={body[3][odd_bit],body[2][odd_bit],body[1][odd_bit],body[0][odd_bit]};
    wire [2:0] mode=active?1:video_guard?2:payload?3:island_guard?4:0;
    game_hdmi_channel #(.CHANNEL(0)) blue(clk,!rst,mode,pixels[9][7:0],d0,{vp[9],hp[9]},c0);
    game_hdmi_channel #(.CHANNEL(1)) green(clk,!rst,mode,pixels[9][15:8],d1,{1'b0,video_pre||island_pre},c1);
    game_hdmi_channel #(.CHANNEL(2)) red(clk,!rst,mode,pixels[9][23:16],d2,{1'b0,island_pre},c2);
    assign cc=10'b1111100000;
endmodule

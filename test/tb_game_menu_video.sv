`timescale 1ns/1ps
module tb_game_menu_video;
    reg clk=0,rst=1,hs=0,vs=0,de=0;
    always #5 clk=~clk;
    reg [23:0] rgb=0;
    reg active=0,debug_mode=0,media_fullscreen=0,calibration=0;
    reg [2:0] page=0,selection=0;
    reg view_narrow=1,palette_mode=0,osd_enable=0,audio_enabled=0;
    reg test_tone=0;
    reg [1:0] brightness=2,master_volume=1,bgm_volume=2,sfx_volume=3;
    reg [4:0] audition_id=23;
    reg audio_available=1,audio_error=0;
    reg [15:0] audio_underruns=16'h1234,audio_dropped=16'habcd;
    reg [1:0] contrast=0,transition_mode=0;
    reg assets_ready=1,image_ready=1;
    reg [6:0] image_index=2,image_count=6;
    reg [2:0] cache_count=4;
    wire hs_o,vs_o,de_o;wire [23:0] rgb_o;
    game_menu_video dut(.alignment_offset(10'd0),.*);
    integer px,py,pixels=0,ox,oy,mode=0,outfile,white_count=0;
    reg [1:0] hp=0,vp=0,dp=0;
    function [23:0] base_color(input integer x,y);
        begin base_color={x[7:0],y[7:0],8'h5a};end
    endfunction
    // Independent labels check every rendered glyph, including dynamic fields.
    // This catches character-position mistakes that a white-pixel count misses.
    function [7:0] expected_char(input integer view_mode,line,col);
        reg [255:0] label;
        integer length,k;
        begin
            label=0;
            if(view_mode==1||view_mode==4)case(line)
                0:label=view_mode==1?"AUDIO: OFF":"AUDIO: ON";
                1:label="MASTER VOLUME: 1";
                2:label="BGM VOLUME: 2";
                3:label="SFX VOLUME: 3";
                4:label="SOUND ID HEX:17";
                5:label="PLAY SELECTED SOUND";
                6:label=view_mode==1?"1KHZ TEST TONE: OFF":"1KHZ TEST TONE: ON";
            endcase
            else case(line)
                0:label="GAME VIEW: WIDE / FULL SCREEN";
                1:label="PALETTE: QUANTIZED";
                2:label="HDMI TEST PATTERN: ON";
                3:label="BRIGHTNESS: 2";
                4:label="CONTRAST: NORMAL";
                5:label="TRANSITION: CUT";
                6:label="RESET DISPLAY SETTINGS";
            endcase
            length=0;
            for(k=0;k<32;k=k+1)if(label[k*8+:8]!=0)length=k+1;
            expected_char=col<length?label[(length-1-col)*8+:8]:8'd32;
        end
    endfunction
    reg [7:0] reference_char;
    reg [2:0] reference_row;
    wire [4:0] reference_glyph;
    osd_font reference_font(reference_char,reference_row,reference_glyph);
    always @(posedge clk)begin
        hp={hp[0],hs};vp={vp[0],vs};dp={dp[0],de};
        #1;
        if(!rst)begin
            if({hs_o,vs_o,de_o}!=={hp[1],vp[1],dp[1]})$fatal(1,"menu sync latency");
            if(de_o)begin
                ox=pixels%640;oy=pixels/640;
                if(mode==0 && rgb_o!==base_color(ox,oy))$fatal(1,"bypass pixel %0d,%0d",ox,oy);
                if(mode==2&&ox>=160&&ox<480&&oy>=120&&oy<360&&rgb_o!==base_color(ox,oy))
                    $fatal(1,"Debug menu covered preview %0d,%0d",ox,oy);
                if(mode==3)begin
                    if(ox==0&&oy==200&&rgb_o!==24'hff0000)$fatal(1,"left calibration border");
                    if(ox==639&&oy==200&&rgb_o!==24'h00ff00)$fatal(1,"right calibration border");
                    if(ox==200&&oy==0&&rgb_o!==24'h0000ff)$fatal(1,"top calibration border");
                    if(ox==200&&oy==479&&rgb_o!==24'hffff00)$fatal(1,"bottom calibration border");
                end
                if((mode==1||mode==4||mode==5)&&ox>=192&&ox<448&&oy>=152&&oy<264&&!oy[3])begin
                    reference_char=expected_char(mode,(oy-152)>>4,(ox-192)>>3);
                    reference_row=oy[2:0];
                    #0;
                    if((rgb_o==24'hffffff)!==((ox%8<5)&&reference_glyph[4-(ox%8)]))
                        $fatal(1,"menu glyph mode=%0d x=%0d y=%0d char=%0d",mode,ox,oy,reference_char);
                end
                if(rgb_o==24'hffffff)white_count=white_count+1;
                if(outfile)$fwrite(outfile,"%c%c%c",rgb_o[23:16],rgb_o[15:8],rgb_o[7:0]);
                pixels=pixels+1;
            end else if(rgb_o!==0)$fatal(1,"menu blanking not black");
        end
    end
    task frame(input [1023:0] filename);
        begin
            pixels=0;white_count=0;outfile=$fopen(filename,"wb");
            if(!outfile)$fatal(1,"menu image open");
            $fwrite(outfile,"P6\n640 480\n255\n");
            for(py=0;py<525;py=py+1)for(px=0;px<800;px=px+1)begin
                hs=px<96;vs=py<2;de=px>=160&&py>=45;
                rgb=base_color(px-160,py-45);@(negedge clk);
            end
            de=0;repeat(3)@(negedge clk);$fclose(outfile);outfile=0;
            if(pixels!=307200)$fatal(1,"menu frame length %0d",pixels);
            if(mode==1&&white_count<1000)$fatal(1,"missing menu characters");
        end
    endtask
    initial begin
        outfile=0;repeat(4)@(negedge clk);rst=0;
        frame("build/game_sim/menu_bypass.ppm");
        mode=1;active=1;page=3;selection=2;
        frame("build/game_sim/menu_audio.ppm");
        mode=4;audio_enabled=1;test_tone=1;
        frame("build/game_sim/menu_audio_on.ppm");
        mode=5;page=2;debug_mode=1;view_narrow=0;palette_mode=1;osd_enable=1;calibration=1;
        frame("build/game_sim/menu_display.ppm");
        calibration=0;
        mode=2;debug_mode=1;page=1;
        frame("build/game_sim/menu_debug.ppm");
        mode=3;active=0;debug_mode=0;calibration=1;
        frame("build/game_sim/menu_calibration.ppm");
        $display("PASS menu video: 6 complete frames, independent menu glyphs, bypass coordinates, 2-clock sync, unobstructed Debug, calibration edges");
        $finish;
    end
    initial begin #30000000;$fatal(1,"menu video timeout");end
endmodule

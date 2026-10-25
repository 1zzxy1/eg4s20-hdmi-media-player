`timescale 1ns/1ps
// Exercise the actual final composition: scope/caption followed by preview HUD.
module tb_lab_ui #(parameter ALIGN_OFFSET=0);
    reg clk=0,rst=1,hs=0,vs=0,de=0;
    always #5 clk=~clk;
    integer tick=0,sample_number=0;
    wire pcm_valid=tick==15;
    wire signed [23:0] pcm=sample_number%16<8?24'sh0c0000:-24'sh0c0000;
    always @(posedge clk)begin
        if(rst)begin tick<=0;sample_number<=0;end
        else begin tick<=tick==15?0:tick+1;if(pcm_valid)sample_number<=sample_number+1;end
    end
    wire fh,fv,fd,mh,mv,md;
    wire [23:0] frgb,mrgb;
    advanced_video #(.DIRECT_CONTROLS(1),.LAB_UI(1),.TRANSITION(0),.ALIGNMENT(1)) fx(
        .alignment_offset(10'(ALIGN_OFFSET)),
        .clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.rgb(24'h182840),
        .image_valid(1'b1),.key_menu(1'b1),.overlay_sw(1'b1),.wave_sw(1'b1),
        .brightness_sw(2'd0),.fade_gain(5'd16),.pcm_valid(pcm_valid),.pcm(pcm),
        .hs_o(fh),.vs_o(fv),.de_o(fd),.rgb_o(frgb),.effect_mode(2'd0),
        .audio_enabled(1'b1),.cache_count(3'd4),.image_index(7'd2),.image_count(7'd6),
        .control_contrast(2'd0),.control_transition(2'd0));
    game_menu_video #(.ALIGNMENT(1)) menu(.clk(clk),.rst(rst),.hs(fh),.vs(fv),.de(fd),.rgb(frgb),
        .alignment_offset(10'(ALIGN_OFFSET)),
        .active(1'b1),.debug_mode(1'b1),.media_fullscreen(1'b1),.calibration(1'b0),
        .page(3'd1),.selection(3'd0),.view_narrow(1'b0),.palette_mode(1'b0),
        .osd_enable(1'b1),.audio_enabled(1'b1),.test_tone(1'b0),.brightness(2'd0),
        .master_volume(2'd3),.bgm_volume(2'd2),.sfx_volume(2'd3),.audition_id(5'd1),
        .audio_available(1'b1),.audio_error(1'b0),.audio_underruns(16'd0),.audio_dropped(16'd0),
        .contrast(2'd0),.transition_mode(2'd0),.assets_ready(1'b1),.image_ready(1'b1),
        .image_index(7'd2),.image_count(7'd6),.cache_count(3'd4),
        .hs_o(mh),.vs_o(mv),.de_o(md),.rgb_o(mrgb));
    integer f,x,y,pixels=0,xx,yy,positive=0,negative=0,heading=0,level=0,caption=0;
    integer preview=0,caption_sum=0,first_sum=0,outfile=0;
    reg [55:0] first_glyph;
    reg expected_ink;
    integer number_value;
    integer channel_value,bright_value,contrast_value,color_reference;
    reg [7:0] expected_pair;
    reg [7:0] font_character;
    reg [2:0] font_row;
    wire [4:0] font_reference,font_clocked;
    osd_font font_comb(font_character,font_row,font_reference);
    osd_font_sync font_registered(clk,font_character,font_row,font_clocked);
    integer font_code,font_scanline;
    initial begin
        // Check every character, including unsupported ASCII and bit-7 blanks.
        for(font_code=0;font_code<256;font_code=font_code+1)
            for(font_scanline=0;font_scanline<8;font_scanline=font_scanline+1)begin
                @(negedge clk);
                font_character=font_code[7:0];font_row=font_scanline[2:0];
                @(posedge clk);#1;
                if(font_clocked!==font_reference)
                    $fatal(1,"clocked font mismatch code=%0d row=%0d actual=%b expected=%b",font_code,font_scanline,font_clocked,font_reference);
            end
        $display("PASS clocked font: 256 characters x 8 scanlines");
    end
    initial begin
        // Exhaustive byte/setting comparison protects saturation and signed
        // shifts when the color datapath's intermediate width is narrowed.
        for(channel_value=0;channel_value<256;channel_value=channel_value+1)
            for(bright_value=0;bright_value<4;bright_value=bright_value+1)
                for(contrast_value=0;contrast_value<4;contrast_value=contrast_value+1)begin
                    color_reference=channel_value-128;
                    case(contrast_value)
                        1:color_reference=color_reference>>>1;
                        2:color_reference=color_reference+(color_reference>>>1);
                        3:color_reference=color_reference*2;
                    endcase
                    color_reference=color_reference+128;
                    case(bright_value)
                        1:color_reference=color_reference+32;
                        2:color_reference=color_reference+64;
                        3:color_reference=color_reference-32;
                    endcase
                    if(color_reference<0)color_reference=0;
                    if(color_reference>255)color_reference=255;
                    if(fx.color_adjust(channel_value[7:0],bright_value[1:0],contrast_value[1:0])!==color_reference[7:0])
                        $fatal(1,"color arithmetic mismatch c=%0d b=%0d k=%0d",channel_value,bright_value,contrast_value);
                end
        for(number_value=0;number_value<128;number_value=number_value+1)begin
            expected_pair=((number_value/10)<<4)|(number_value%10);
            if(fx.number_pair(number_value[6:0])!==expected_pair||
               menu.number_pair(number_value[6:0])!==expected_pair)
                $fatal(1,"gallery decimal mismatch at %0d",number_value);
        end
    end
    always @(posedge clk)begin
        #1;
        if(!rst&&md)begin
            xx=(pixels%640+ALIGN_OFFSET)%640;yy=pixels/640;
            if(f>0&&yy>=272&&yy<280&&((xx>=64&&xx<72)||(xx>=320&&xx<328)))begin
                // Independent first-character bitmaps catch packed-string truncation.
                first_glyph=xx<320?56'h1e11111e101010:56'h0608101e11110e;
                expected_ink=0;
                if(yy<279&&xx%8<5)
                    expected_ink=(first_glyph>>((278-yy)*8+4-xx%8))&1;
                if((mrgb==24'hffffff)!==expected_ink)
                    $fatal(1,"scope heading first glyph x=%0d y=%0d rgb=%h",xx,yy,mrgb);
            end
            if(mrgb==24'h20ff60&&yy>=327&&yy<=329)positive=positive+1;
            if(mrgb==24'h20ff60&&yy>=375&&yy<=377)negative=negative+1;
            if(mrgb==24'hffffff)begin
                if(yy>=272&&yy<280)heading=heading+1;
                if(yy>=408&&yy<416&&xx<128)level=level+1;
                if(yy>=456&&yy<464)begin caption=caption+1;caption_sum=caption_sum+xx;end
                if(yy>=88&&yy<96)preview=preview+1;
            end
            if(outfile)$fwrite(outfile,"%c%c%c",mrgb[23:16],mrgb[15:8],mrgb[7:0]);
            pixels=pixels+1;
        end
    end
    initial begin
        repeat(5)@(negedge clk);rst=0;
        for(f=0;f<4;f=f+1)begin
            pixels=0;positive=0;negative=0;heading=0;level=0;caption=0;caption_sum=0;preview=0;
            if(f==3)begin
                outfile=$fopen("build/sim/lab_ui.ppm","wb");
                if(!outfile)$fatal(1,"lab screenshot open");
                $fwrite(outfile,"P6\n640 480\n255\n");
            end
            for(y=0;y<525;y=y+1)for(x=0;x<800;x=x+1)begin
                hs=x<96;vs=y<2;de=x>=160&&y>=45;@(negedge clk);
            end
            de=0;repeat(7)@(negedge clk);
            if(pixels!=307200||(f>0&&(positive<500||negative<500||heading<100||level<30||caption<100||preview<100)))
                $fatal(1,"lab missing pixels=%0d wave=%0d/%0d heading=%0d level=%0d caption=%0d preview=%0d",
                    pixels,positive,negative,heading,level,caption,preview);
            if(f==1)first_sum=caption_sum;
            if(f==3&&caption_sum==first_sum)$fatal(1,"caption did not move");
        end
        $fclose(outfile);
        $display("PASS lab UI: preview HUD, signed PCM trace, gain/time labels, level, moving final-layer caption across three complete frames");
        $finish;
    end
endmodule

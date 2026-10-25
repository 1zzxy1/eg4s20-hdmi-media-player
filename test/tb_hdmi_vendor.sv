`timescale 1ns/1ps
// Actual encrypted HDMI RTL. Test digital TMDS video symbols, input handshake,
// clock and audio/ACR stimulation. Does not model PHY analog eye or sink EDID.
module tb_hdmi_vendor;
    parameter AUDIO_PATTERN=0;
    parameter EDID_START=0;
    parameter DIRECT=0;
    integer clock_count=0;
    reg clk=0,rst=1;
    always #20 clk=~clk;
    wire hs,vs,de,req;wire [23:0] pixel;
    wire user,valid,last,ready,locked;
    wire [23:0] axis,left,right,tone_left,tone_right;
    wire av,acr;wire [19:0] n,cts;
    reg [23:0] serial=24'h13579b;
    // A unique, asymmetric stereo challenge also detects swaps and truncation.
    assign left=AUDIO_PATTERN ? serial : tone_left;
    assign right=AUDIO_PATTERN ? (serial ^ 24'ha5c39e) : tone_right;
    always @(posedge clk) if(rst)serial<=24'h13579b;else if(av)serial<=serial+24'h010207;
    wire [9:0] c0,c1,c2,cc;wire scl;tri1 sda;
    reg serial_clk=0;
    always #4 serial_clk=~serial_clk;
    wire sd0,sd1,sd2,sck;
    wire [31:0] serial_words;
    hdmi_phy_wrapper #(.DEVICE("EG")) phy(
        .I_pixel_clk(clk),.I_serial_clk(serial_clk),.I_rst(rst),
        .I_tmds_channel_0(c0),.I_tmds_channel_1(c1),.I_tmds_channel_2(c2),.I_tmds_channel_clk(cc),
        .O_tmds_ch0_p(sd0),.O_tmds_ch1_p(sd1),.O_tmds_ch2_p(sd2),.O_tmds_clk_p(sck));
    hdmi_serial_capture receiver(clk,serial_clk,rst,c0,c1,c2,cc,sd0,sd1,sd2,sck,serial_words);
    wire oh,ov,od,wipe;wire [23:0] out_pixel;
    video_timing_data timing(clk,rst,req,req,hs,vs,de);
    advanced_video effects(clk,rst,hs,vs,de,24'h804020,1'b1,1'b1,1'b1,1'b1,
        2'b00,5'd16,av,left,oh,ov,od,out_pixel,wipe,,2'd0,1'b0,3'd4,7'd1,7'd6,2'd0,2'd0);
    reg prev_de=0,prev_vs=0;
    reg [9:0] px=0,py=0;
    wire [9:0] xpos=prev_de?px:10'd0;
    wire [23:0] pattern={xpos[7:0],py[5:0],xpos[9:8],8'h5a};
    always @(posedge clk) begin
        if(rst) begin prev_de<=0;prev_vs<=0;px<=0;py<=0;end
        else begin
            prev_de<=de;prev_vs<=vs;px<=de?xpos+1'b1:0;
            if(vs&&!prev_vs)py<=0;else if(prev_de&&!de)py<=py+1'b1;
        end
    end
    video_rgb_to_axis_640x480 axis_pack(clk,rst,vs,de,pattern,user,valid,last,axis);
    pcm48_tone audio(clk,rst,av,tone_left,tone_right,acr,n,cts);
    generate if(DIRECT)begin:direct_tx
        wire overflow;
        game_hdmi_tx dut(clk,rst,hs,vs,de,pattern,av,left,right,acr,c0,c1,c2,cc,overflow);
        assign ready=1'b1;
        assign locked=!rst;
        always @(posedge clk)if(!rst&&overflow)$fatal(1,"direct HDMI overflow");
    end else begin:vendor_tx
        wire overflow;
        game_hdmi_output #(.READ_EDID(EDID_START)) dut(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.rgb(pattern),
            .sample_valid(av),.sample_left(left),.sample_right(right),.acr_valid(acr),
            .c0(c0),.c1(c1),.c2(c2),.cc(cc),.overflow(overflow),.locked(locked),
            .ddc_scl(scl),.ddc_sda(sda));
        assign ready=dut.ready;
        always @(posedge clk)if(!rst&&overflow)$fatal(1,"vendor HDMI overflow");
    end endgenerate
    function [7:0] decode(input [9:0] code);
        reg [7:0] q;integer k;
        begin q=code[9]?~code[7:0]:code[7:0];decode[0]=q[0];
            for(k=1;k<8;k=k+1) decode[k]=code[8]?(q[k]^q[k-1]):~(q[k]^q[k-1]);end
    endfunction
    integer locked_cycles=0,base_pixels=0,audio_count=0,ddc_edges=0;
    always @(negedge scl)if(!rst)ddc_edges=ddc_edges+1;
    integer row_pixels=0,rows_checked=0,decoded_x;
    reg row_seen=0;
    reg row_bad=0;
    reg [5:0] row_y;
    integer symbols_file,pcm_file;
    initial begin
        if(AUDIO_PATTERN) begin
            symbols_file=$fopen("audio_stereo_symbols.txt","w");
            pcm_file=$fopen("audio_stereo_input.txt","w");
        end else begin
            symbols_file=$fopen("audio_tone_symbols.txt","w");
            pcm_file=$fopen("audio_tone_input.txt","w");
        end
        if(!symbols_file || !pcm_file)$fatal(1,"cannot open audio trace");
    end
    always @(posedge clk) begin
        // Inputs are observed at the same edge as the protected transmitter.
        if(!rst && av)$fdisplay(pcm_file,"%0d %06h %06h",clock_count,left,right);
        #1;clock_count=clock_count+1;
        if(!rst)$fdisplay(symbols_file,"%0d %03h %03h %03h",clock_count,c0,c1,c2);
        if(!rst && av) audio_count=audio_count+1;
        if(!rst && locked) begin
            locked_cycles=locked_cycles+1;
            if(valid && !ready) $fatal(1,"HDMI backpressure while locked");
            if(^{c0,c1,c2,cc}===1'bx) $fatal(1,"unknown TMDS outputs while locked");
            if(decode(c0)==8'h5a) begin
                decoded_x={decode(c1)&8'h03,decode(c2)};
                if(row_pixels==0) row_y=decode(c1)>>2;
                if(decoded_x!=row_pixels || (decode(c1)>>2)!=row_y) row_bad=1;
                // Data islands can decode to one marker byte. Only a sustained
                // video run is a row; never treat an audio symbol as a pixel.
                if(row_seen && row_pixels>=32 && row_bad)
                    $fatal(1,"HDMI horizontal wrap row=%0d pixel=%0d decoded_x=%0d",rows_checked,row_pixels,decoded_x);
                row_pixels=row_pixels+1;base_pixels=base_pixels+1;
            end else if(row_pixels!=0) begin
                if(row_pixels>=32) begin
                    if(row_seen && row_pixels!=640)$fatal(1,"HDMI line width %0d",row_pixels);
                    if(row_seen)rows_checked=rows_checked+1;
                    row_seen=1;
                end
                row_pixels=0;row_bad=0;
            end
        end
        if(clock_count==420000*5) begin
            if(!DIRECT&&EDID_START&&ddc_edges==0)$fatal(1,"EDID startup did not exercise DDC");
            if(locked_cycles<420000||rows_checked<480||base_pixels<307200||audio_count<3000) $fatal(1,"HDMI no valid output lock=%0d base=%0d audio=%0d",locked_cycles,base_pixels,audio_count);
            $fclose(symbols_file);$fclose(pcm_file);
            // Drain the final word through the serializer before finishing.
            #120;
            if(serial_words<2099900)$fatal(1,"HDMI serial capture incomplete words=%0d",serial_words);
            $display("PASS HDMI serial pins: words=%0d",serial_words);
            $display("PASS vendor HDMI: coordinate rows=%0d, pixels=%0d, PCM samples=%0d, DDC edges=%0d, no wrap/backpressure/X",rows_checked,base_pixels,audio_count,ddc_edges);$finish;
        end
    end
    initial begin repeat(10)@(negedge clk);rst=0;end
endmodule

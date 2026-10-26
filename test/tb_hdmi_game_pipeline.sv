`timescale 1ns/1ps
// Actual top-level video tail and protected HDMI encoder. Decode only after
// the two video guard bands; audio data islands must never count as pixels.
module tb_hdmi_game_pipeline;
    parameter CALIBRATION=0, INJECT_SHIFT=0, INJECT_HS_SHIFT=0;
    parameter DIRECT=1, GAMEPLAY=0, INJECT_ISLAND_SYNC=0;
    parameter STABILITY=1;
    parameter ALIGN_OFFSET=0, ALIGN_ENABLE=0;
    reg clk=0,rst=1;
    always #20 clk=~clk;
    wire hs,vs,de,req,th,tv,td,dh,dv,ddelay,read_en;
    wire [23:0] delay_rgb,upstream_rgb;
    video_timing_data timing(clk,rst,req,req,th,tv,td);
    generate if(STABILITY)begin:stable_raster
        assign hs=th;assign vs=tv;assign de=td;
        assign upstream_rgb=24'h5c94fc;
    end else begin:full_raster
    video_delay delay_path(.video_clk(clk),.rst(rst),.read_en(read_en),.read_data(24'd0),
        .hs(th),.vs(tv),.de(td),.hs_r(dh),.vs_r(dv),.de_r(ddelay),.vout_data(delay_rgb));
    advanced_video #(.TEXT(0),.COLOR(0),.SCOPE(0),.TRANSITION(0)) media_effects(
        .clk(clk),.rst(rst),.hs(dh),.vs(dv),.de(ddelay),.rgb(delay_rgb),
        .image_valid(1'b1),.key_menu(1'b1),.overlay_sw(1'b0),.wave_sw(1'b0),
        .brightness_sw(2'd0),.fade_gain(5'd16),.pcm_valid(1'b0),.pcm(24'd0),
        .hs_o(hs),.vs_o(vs),.de_o(de),.rgb_o(upstream_rgb),.wipe_mode(),.requested_mode(),
        .effect_mode(2'd0),.audio_enabled(1'b1),.cache_count(3'd4),.image_index(7'd0),.image_count(7'd6),
        .control_contrast(2'd0),.control_transition(2'd0),.caption_mode(3'd0));
    end endgenerate
    reg pd=0,pv=0;
    reg [9:0] sx=0,sy=0;
    wire [9:0] x=pd?sx:10'd0;
    function [23:0] coordinate(input integer xx,yy);
        coordinate={8'(xx),8'(yy),1'(yy>>8),2'(xx>>8),5'b10101};
    endfunction
    always @(posedge clk) begin
        if(rst)begin pd<=0;pv<=0;sx<=0;sy<=0;end
        else begin
            pd<=de;pv<=vs;sx<=de?x+1'b1:0;
            if(vs&&!pv)sy<=0;else if(pd&&!de)sy<=sy+1'b1;
        end
    end
    wire gh,gv,gd,fh,fv,fd,mh,mv,md;
    wire [23:0] grgb,frgb,mrgb;
    game_video #(.ALIGNMENT(ALIGN_ENABLE)) game(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),
        .alignment_offset(10'(ALIGN_OFFSET)),.alignment_active(1'b0),
        .media_rgb(coordinate(x,sy)),.media_valid(1'b1),.debug_mode(!GAMEPLAY),
        .media_fullscreen(1'b1),.osd_enable(1'b0),.view_narrow(!STABILITY),
        .palette_mode(1'b0),.assets_loaded(1'b1),.state(3'd2),
        .player_x(12'd32),.player_y(9'd160),.camera_x(12'd0),
        .enemy0_x(12'd0),.enemy1_x(12'd0),.enemy_alive(2'd0),
        .powerup_active(1'b0),.powerup_x(12'd0),.powerup_y(9'd0),.powerup_kind(2'd0),
        .map_addr(),.map_data(8'd0),.enemy_x(48'd0),.enemy_y(36'd0),
        .enemy_kind(8'd0),.enemy_active(4'd0),.coins_count(8'd0),.player_crouch(1'b0),
        .flag_phase(2'd0),.flag_y(9'd0),.super_mario(1'b0),.facing_left(1'b0),
        .anim(2'd0),.coin_mask(8'd0),.seconds_left(9'd120),.score(24'd0),
        .lives(4'd3),.player_name("AAA   "),.avatar(3'd0),.profile_cursor(3'd0),
        .fire_mario(1'b0),.fireball_active(2'd0),.fireball_x(24'd0),.fireball_y(18'd0),
        .event_code(4'd0),.block_fx_addr(12'd0),.block_fx_frames(5'd0),
        .transform_frames(5'd0),.block_fx_kind(2'd0),.player_blink(1'b0),
        .player_star(1'b0),.death_active(1'b0),.effects_paused(1'b1),
        .reward_valid(1'b0),.reward_kind(4'd0),.reward_x(12'd0),.reward_y(9'd0),
        .save_busy(1'b0),.save_error(1'b0),.save_available(1'b0),.audio_enabled(1'b0),
        .bg_addr(),.sprite_addr(),.bg_index(4'd0),.sprite_index(4'd0),
        .rank_index(),.rank_valid(1'b0),.rank_name(48'd0),.rank_score(24'd0),
        .rank_time(16'd0),.rank_avatar(3'd0),
        .hs_o(gh),.vs_o(gv),.de_o(gd),.rgb_o(grgb),.frame_tick());
    wire av,acr;wire [23:0] left,right;wire [19:0] n,cts;
    pcm48_tone audio(clk,rst,av,left,right,acr,n,cts);
    generate if(STABILITY)begin:stable_tail
        assign mh=gh;assign mv=gv;assign md=gd;assign mrgb=grgb;
    end else begin:full_tail
    advanced_video #(.TEXT(0),.COLOR(0),.SCOPE(1),.TRANSITION(0)) effects(
        .clk(clk),.rst(rst),.hs(gh),.vs(gv),.de(gd),.rgb(grgb),
        .image_valid(1'b1),.key_menu(1'b1),.overlay_sw(1'b0),.wave_sw(1'b0),
        .brightness_sw(2'd0),.fade_gain(5'd16),.pcm_valid(av),.pcm(left),
        .hs_o(fh),.vs_o(fv),.de_o(fd),.rgb_o(frgb),.wipe_mode(),.requested_mode(),
        .effect_mode(2'd0),.audio_enabled(1'b0),.cache_count(3'd4),
        .image_index(7'd0),.image_count(7'd6),.control_contrast(2'd0),.control_transition(2'd0),.caption_mode(3'd0));
    game_menu_video menu(.clk(clk),.rst(rst),.hs(fh),.vs(fv),.de(fd),.rgb(frgb),
        .active(1'b0),.debug_mode(1'b1),.media_fullscreen(1'b1),.calibration(CALIBRATION!=0),
        .page(3'd0),.selection(3'd0),.view_narrow(1'b1),.palette_mode(1'b0),
        .osd_enable(1'b0),.audio_enabled(1'b0),.test_tone(1'b0),
        .brightness(2'd0),.master_volume(2'd3),.bgm_volume(2'd2),.sfx_volume(2'd3),
        .audition_id(5'd1),.audio_available(1'b1),.audio_error(1'b0),
        .audio_underruns(16'd0),.audio_dropped(16'd0),
        .contrast(2'd0),.transition_mode(2'd0),.assets_ready(1'b1),.image_ready(1'b1),
        .image_index(7'd0),.image_count(7'd6),.cache_count(3'd4),
        .hs_o(mh),.vs_o(mv),.de_o(md),.rgb_o(mrgb));
    end endgenerate
    wire user,valid,last,ready,locked;
    wire [23:0] axis;
    // Negative control delays RGB by one clock without delaying DE/VS.
    reg [23:0] previous_rgb=0;
    always @(posedge clk)if(rst)previous_rgb<=0;else previous_rgb<=mrgb;
    wire [23:0] axis_rgb=INJECT_SHIFT?previous_rgb:mrgb;
    reg [7:0] previous_hs=0;
    always @(posedge clk)if(rst)previous_hs<=0;else previous_hs<={previous_hs[6:0],mh};
    wire tx_hs=INJECT_HS_SHIFT?previous_hs[7]:mh;
    video_rgb_to_axis_640x480 pack(clk,rst,mv,md,axis_rgb,user,valid,last,axis);
    wire [9:0] c0,c1,c2,cc;wire scl;tri1 sda;
    generate if(DIRECT)begin:direct_tx
        wire overflow;
        game_hdmi_tx dut(clk,rst,tx_hs,mv,md,axis_rgb,av,left,right,acr,c0,c1,c2,cc,overflow);
        if(INJECT_ISLAND_SYNC)begin
            // Flip HS only inside an island. A control-only sink misses this.
            always @* if(dut.payload)force dut.d0[0]=1'b1;else release dut.d0[0];
        end
        assign ready=1'b1;
        assign locked=!rst;
        always @(posedge clk)if(!rst&&overflow)$fatal(1,"direct HDMI overflow");
    end else begin:vendor_tx
        wire overflow;
        game_hdmi_output dut(.clk(clk),.rst(rst),.hs(tx_hs),.vs(mv),.de(md),.rgb(axis_rgb),
            .sample_valid(av),.sample_left(left),.sample_right(right),.acr_valid(acr),
            .c0(c0),.c1(c1),.c2(c2),.cc(cc),.overflow(overflow),.locked(locked));
        assign ready=dut.ready;
        always @(posedge clk)if(!rst&&overflow)$fatal(1,"vendor HDMI overflow");
    end endgenerate
    function [7:0] decode(input [9:0] code);
        reg [7:0] q;integer k;
        begin q=code[9]?~code[7:0]:code[7:0];decode[0]=q[0];
            for(k=1;k<8;k=k+1)decode[k]=code[8]?(q[k]^q[k-1]):~(q[k]^q[k-1]);end
    endfunction
    function [23:0] golden(input integer xx,yy);
        reg [255:0] letters;
        reg [7:0] letter,row_bits;
        reg [55:0] glyph;
        integer col,row;
        begin
            if(ALIGN_ENABLE&&GAMEPLAY)xx=(xx+ALIGN_OFFSET)%640;
            golden=coordinate(xx,yy);
            if(GAMEPLAY)begin
                golden=24'h6b8cff;letters="MARIO     COIN    WORLD   TIME  ";
                letter=" ";col=((xx-64)%16)/2;row=(yy%16)/2;glyph=0;
                if(xx>=64&&xx<576)begin
                    if(yy>=32&&yy<48)letter=letters>>((31-(xx-64)/16)*8);
                    if(yy>=48&&yy<64)case((xx-64)/16)
                        0,1,2,3,4,5,11,12,29:letter="0";
                        10:letter="X";19,21,27:letter="1";
                        20:letter="-";28:letter="2";default:letter=" ";
                    endcase
                end
                // Independent golden glyphs for the four HUD fields.
                case(letter)
                    "0":glyph=56'h0e11131519110e;"1":glyph=56'h040c040404040e;
                    "2":glyph=56'h0e11010204081f;"A":glyph=56'h0e11111f111111;
                    "C":glyph=56'h0e11101010110e;"D":glyph=56'h1e11111111111e;
                    "E":glyph=56'h1f10101e10101f;"I":glyph=56'h0e04040404040e;
                    "L":glyph=56'h1010101010101f;"M":glyph=56'h111b1515111111;
                    "N":glyph=56'h11191513111111;"O":glyph=56'h0e11111111110e;
                    "R":glyph=56'h1e11111e141211;"T":glyph=56'h1f040404040404;
                    "W":glyph=56'h11111115151b11;"X":glyph=56'h11110a040a1111;
                    "-":glyph=56'h0000001f000000;default:glyph=0;
                endcase
                row_bits=row<7?glyph>>((6-row)*8):0;
                if(xx>=64&&xx<576&&yy>=32&&yy<64&&col<5&&row_bits[4-col])golden=24'hffffff;
            end
            if(CALIBRATION)begin
                golden={8'(xx),8'(yy),8'h5a};
                if(xx%64==0||yy==120||yy==240||yy==360)golden=24'h808080;
                if(xx<8)golden=24'hff0000;else if(xx>=632)golden=24'h00ff00;
                if(yy<8)golden=24'h0000ff;else if(yy>=472)golden=24'hffff00;
            end
        end
    endfunction
    localparam [9:0] CTL00=10'b1101010100,CTL01=10'b0010101011,
        CTL10=10'b0101010100,CTL11=10'b1010101011;
    wire guard=c0==10'b1011001100&&c1==10'b0100110011&&c2==10'b1011001100;
    wire control=c1==CTL00&&c2==CTL00&&
        (c0==CTL00||c0==CTL01||c0==CTL10||c0==CTL11);
    function [3:0] un_terc(input [9:0] code);
        case(code)
            10'h29c:un_terc=0;10'h263:un_terc=1;10'h2e4:un_terc=2;10'h2e2:un_terc=3;
            10'h171:un_terc=4;10'h11e:un_terc=5;10'h18e:un_terc=6;10'h13c:un_terc=7;
            10'h2cc:un_terc=8;10'h139:un_terc=9;10'h19c:un_terc=10;10'h2c6:un_terc=11;
            10'h28e:un_terc=12;10'h271:un_terc=13;10'h163:un_terc=14;10'h2c3:un_terc=15;
            default:un_terc=4'bxxxx;
        endcase
    endfunction
    // Recover HS/VS in every blanking mode, including packet preambles,
    // guards and payload. Compare against the transmitter input at its
    // specified eleven-clock encode latency, independently of its counters.
    integer cycles=0;
    reg [10:0] expected_hs=0,expected_vs=0,expected_de=0;
    integer island_remaining=0,island_pre_count=0,island_sync_samples=0;
    reg [1:0] recovered_sync;
    reg [3:0] nibble;
    always @(posedge clk)begin
        if(rst)begin expected_hs<=0;expected_vs<=0;expected_de<=0;end
        else begin
            expected_hs<={expected_hs[9:0],tx_hs};expected_vs<={expected_vs[9:0],mv};
            expected_de<={expected_de[9:0],md};
        end
        #1;
        if(DIRECT&&!rst&&cycles>40&&!expected_de[10]&&!guard)begin
            if(c1==CTL01&&c2==CTL01)island_pre_count=island_pre_count+1;
            else begin
                if(island_pre_count==8)island_remaining=36;
                island_pre_count=0;
            end
            if(island_remaining>0)begin
                nibble=un_terc(c0);recovered_sync=nibble[1:0];
                island_remaining=island_remaining-1;island_sync_samples=island_sync_samples+1;
            end else begin
                case(c0)
                    CTL00:recovered_sync=0;CTL01:recovered_sync=1;
                    CTL10:recovered_sync=2;CTL11:recovered_sync=3;
                    default:$fatal(1,"unrecognized blanking symbol %h",c0);
                endcase
            end
            if(recovered_sync!=={expected_vs[10],expected_hs[10]})
                $fatal(1,"HDMI blanking sync mismatch cycle=%0d island=%0d got=%b expected=%b",
                    cycles,island_remaining,recovered_sync,{expected_vs[10],expected_hs[10]});
        end
    end
    reg vseen=0,out_vs=1,synced=0,in_video=0,after_video=0;
    integer guards=0,xx=0,yy=0,frames=0,pixels=0,rows=0,line_start=0;
    reg out_hs=1,hseen=0;
    integer hs_fall=0,hs_rise=0;
    integer sink_pre_count=0,sink_island_active=0,sink_island_cycles=0;
    reg sink_trailing=0;
    reg sink_sync_valid;
    reg [1:0] sink_sync;
    reg [3:0] sink_nibble;
    reg [23:0] got;
    always @(posedge clk)begin
        #1;cycles=cycles+1;
        if(!rst&&locked)begin
            // HS/VS also travel in the data-island guards and payload.
            // Looking only at control periods delays edges inside packets.
            sink_sync_valid=0;
            if(!in_video&&!guard)begin
                if(c1==CTL01&&c2==CTL01)sink_pre_count=sink_pre_count+1;
                else begin
                    if(sink_pre_count==8)begin
                        sink_island_active=1;sink_island_cycles=0;sink_trailing=0;
                    end
                    sink_pre_count=0;
                end
                if(sink_island_active)begin
                    sink_nibble=un_terc(c0);
                    if(^sink_nibble===1'bx)$fatal(1,"invalid island sync symbol");
                    sink_sync=sink_nibble[1:0];sink_sync_valid=1;
                    // An island may contain several contiguous 32-clock
                    // packets. Only its trailing guards end the island.
                    if(sink_trailing)sink_island_active=0;
                    else if(sink_island_cycles>=2&&c1==10'h133&&c2==10'h133)
                        sink_trailing=1;
                    sink_island_cycles=sink_island_cycles+1;
                end else case(c0)
                    CTL00:begin sink_sync=0;sink_sync_valid=1;end
                    CTL01:begin sink_sync=1;sink_sync_valid=1;end
                    CTL10:begin sink_sync=2;sink_sync_valid=1;end
                    CTL11:begin sink_sync=3;sink_sync_valid=1;end
                endcase
            end
            if(valid&&!ready)$fatal(1,"pipeline backpressure");
            if($test$plusargs("TRACE_SYNC")&&synced&&yy<2&&!in_video)
                $display("TRACE_SYNC cycle=%0d row=%0d lanes=%h,%h,%h sync_valid=%0d sync=%b",cycles,yy,c0,c1,c2,sink_sync_valid,sink_sync);
            if(^{c0,c1,c2,cc}===1'bx)$fatal(1,"pipeline unknown TMDS");
            if(after_video&&!control)$fatal(1,"pipeline video exceeds 640 pixels");
            after_video=0;
            if(in_video)begin
                if(synced)begin
                    got={decode(c2),decode(c1),decode(c0)};
                    if(yy>=480||got!==golden(xx,yy))
                        $fatal(1,"pipeline pixel mismatch calibration=%0d x=%0d y=%0d got=%h expected=%h",CALIBRATION,xx,yy,got,golden(xx,yy));
                    pixels=pixels+1;
                end
                if(xx==639)begin
                    in_video=0;xx=0;after_video=1;
                    if(synced)begin yy=yy+1;rows=rows+1;end
                end else xx=xx+1;
            end else if(guard)begin
                guards=guards+1;
                if(guards==2)begin
                    if(synced&&cycles-hs_rise!=47)
                        $fatal(1,"HDMI horizontal back porch %0d (expected 48 to first pixel)",cycles-hs_rise+1);
                    if(synced&&yy>0&&cycles-line_start!=800)$fatal(1,"pipeline line period %0d",cycles-line_start);
                    line_start=cycles;in_video=1;xx=0;guards=0;
                end
            end else begin
                guards=0;
                if(sink_sync_valid)begin
                    if(hseen&&out_hs&&!sink_sync[0])hs_fall=cycles;
                    if(hseen&&!out_hs&&sink_sync[0])begin
                        if(synced&&cycles-hs_fall!=96)$fatal(1,"HDMI HS pulse width %0d",cycles-hs_fall);
                        hs_rise=cycles;
                    end
                    out_hs=sink_sync[0];hseen=1;
                    if(vseen&&!out_vs&&sink_sync[1])begin
                        if(synced)begin
                            if(yy!=480)$fatal(1,"pipeline frame height %0d",yy);
                            frames=frames+1;
                        end
                        synced=1;yy=0;
                    end
                    out_vs=sink_sync[1];vseen=1;
                end
            end
        end
        if(cycles==420000*5)begin
            if(frames<2||pixels<640*480*2)$fatal(1,"pipeline incomplete frames=%0d rows=%0d pixels=%0d",frames,rows,pixels);
            if(DIRECT&&island_sync_samples<1000)$fatal(1,"missing island sync coverage");
            $display("PASS HDMI game pipeline: calibration=%0d gameplay=%0d complete_frames=%0d rows=%0d pixels=%0d island_sync=%0d, all four edges checked",CALIBRATION,GAMEPLAY,frames,rows,pixels,island_sync_samples);
            $finish;
        end
    end
    initial begin repeat(10)@(negedge clk);rst=0;end
endmodule

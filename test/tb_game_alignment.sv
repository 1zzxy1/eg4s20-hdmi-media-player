`timescale 1ns/1ps
// Compare actual game pixels after a receiver-side cyclic shift with an
// unshifted render. This models the photographed symptom, not the monitor RTL.
module tb_game_alignment;
    parameter ACTUAL_OFFSET=128, SINK_SHIFT=128;
    reg clk=0,rst=1,hs=0,vs=0,de=0,calibration=0;
    always #5 clk=~clk;
    wire [1:0] ho,vo,dout;
    wire [23:0] rgb[0:1];
    reg [23:0] pixels[0:1][0:639];
    reg previous_de=0;
    integer column=0,line=0,checked=0,x,y,mode,i,source;
    genvar g;
    generate for(g=0;g<2;g=g+1)begin:render
        wire [11:0] ma;
        wire [14:0] ba,sa;
        reg [7:0] md=0;
        reg [3:0] bi=0,si=0;
        // Synchronous map/texture latency as in the deployed game.
        always @(posedge clk)begin
            md<=ma[11:8]>=12?8'd1:ma[3:0]==4?8'd3:0;
            bi<=ba[3:0]^ba[7:4]^ba[11:8];
            si<=sa[3:0]^sa[7:4]^sa[11:8];
        end
        game_video #(.ALIGNMENT(1)) dut(
            .clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),
            .alignment_offset(g==0?10'd0:10'(ACTUAL_OFFSET)),.alignment_active(calibration),
            .media_rgb(24'd0),.media_valid(1'b0),.debug_mode(1'b0),
            .media_fullscreen(1'b0),.osd_enable(1'b0),.view_narrow(1'b0),.palette_mode(1'b0),
            .assets_loaded(1'b1),.state(3'd2),.player_x(12'd32),.player_y(9'd176),.camera_x(12'd0),
            .enemy0_x(12'd272),.enemy1_x(12'd736),.powerup_active(1'b0),
            .powerup_x(12'd0),.powerup_y(9'd0),.powerup_kind(2'd0),.map_addr(ma),.map_data(md),
            .enemy_x(48'd0),.enemy_y(36'd0),.enemy_kind(8'd0),.enemy_active(4'd0),
            .coins_count(8'd0),.player_crouch(1'b0),.flag_phase(2'd0),.flag_y(9'd32),
            .super_mario(1'b0),.facing_left(1'b0),.anim(2'd0),.enemy_alive(2'd0),.coin_mask(8'd0),
            .seconds_left(9'd400),.score(24'd0),.lives(4'd3),.player_name("AAA   "),
            .avatar(3'd0),.profile_cursor(3'd0),.fire_mario(1'b0),.fireball_active(2'd0),
            .fireball_x(24'd0),.fireball_y(18'd0),.event_code(4'd0),.block_fx_addr(12'd0),
            .block_fx_frames(5'd0),.transform_frames(5'd0),.block_fx_kind(2'd0),
            .player_blink(1'b0),.player_star(1'b0),.death_active(1'b0),.effects_paused(1'b1),
            .reward_valid(1'b0),.reward_kind(4'd0),.reward_x(12'd0),.reward_y(9'd0),
            .save_busy(1'b0),.save_error(1'b0),.save_available(1'b0),.audio_enabled(1'b1),
            .bg_addr(ba),.sprite_addr(sa),.bg_index(bi),.sprite_index(si),
            .rank_index(),.rank_valid(1'b0),.rank_name(48'd0),.rank_score(24'd0),
            .rank_time(16'd0),.rank_avatar(3'd0),.hs_o(ho[g]),.vs_o(vo[g]),.de_o(dout[g]),
            .rgb_o(rgb[g]),.frame_tick());
    end endgenerate
    always @(negedge clk)if(!rst)begin
        if(ho[0]!==ho[1]||vo[0]!==vo[1]||dout[0]!==dout[1])$fatal(1,"Timing changed");
        previous_de=dout[0];
        if(dout[0])begin
            if(column>=640)$fatal(1,"Long line");
            pixels[0][column]=rgb[0];pixels[1][column]=rgb[1];column=column+1;
        end else if(column!=0)begin
            if(column!=640)$fatal(1,"Short line %d",column);
            // The displayed offset number intentionally differs between renders.
            if(!calibration||line<224||line>=240)for(i=0;i<640;i=i+1)begin
                source=(i+640-SINK_SHIFT)%640;
                if(pixels[1][source]!==pixels[0][i])
                    $fatal(1,"Wrapped pixel mode=%d x=%d y=%d got=%h expected=%h",calibration,i,line,pixels[1][source],pixels[0][i]);
                checked=checked+1;
            end
            column=0;line=line+1;
        end
    end
    task tick;begin @(posedge clk);#1;end endtask
    initial begin
        repeat(5)tick();rst=0;
        for(mode=0;mode<2;mode=mode+1)begin
            calibration=mode;line=0;vs=1;repeat(5)tick();vs=0;repeat(10)tick();
            for(y=0;y<480;y=y+1)begin
                de=1;for(x=0;x<640;x=x+1)tick();
                de=0;hs=1;repeat(10)tick();hs=0;repeat(10)tick();
            end
            if(line!=480)$fatal(1,"Missing lines");
        end
        $display("PASS alignment offset=%0d sink=%0d pixels=%0d",ACTUAL_OFFSET,SINK_SHIFT,checked);$finish;
    end
endmodule

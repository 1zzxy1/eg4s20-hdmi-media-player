`timescale 1ns/1ps
// Directed collision-boundary injection complements the public-input playthrough.
// Seed pre-settlement registers; check score/state/events and real rank outputs,
// plus internal emergence/phase invariants. This is not a public-input route.
module tb_game_settlement;
    reg clk=0,rst=1,debug_mode=0,held_run=0;
    wire [2:0] state;
    wire [23:0] score;
    wire [3:0] lives,event_code,reward_kind;
    wire [7:0] coins_count;
    wire event_valid,reward_valid,submit,map_we;
    wire [11:0] reward_x;
    wire [8:0] reward_y;
    wire [95:0] record;
    integer events[0:15],rewards[0:15];
    integer submits,writes,h,bonus;
    game_world dut(.clk(clk),.rst(rst),.frame_tick(1'b0),.assets_loaded(1'b1),
        .held_left(1'b0),.held_right(1'b0),.jump_press(1'b0),.jump_hold(1'b0),
        .back_press(1'b0),.held_run(held_run),.held_down(1'b0),
        .debug_mode(debug_mode),.view_narrow(1'b0),
        .profile_request(1'b0),.scores_request(1'b0),.map_ready(1'b1),.map_data(8'd0),
        .state(state),.score(score),.lives(lives),.coins_count(coins_count),
        .event_valid(event_valid),.event_code(event_code),.reward_valid(reward_valid),
        .reward_kind(reward_kind),.reward_x(reward_x),.reward_y(reward_y),
        .submit(submit),.map_we(map_we));
    game_reward_fx fx(.clk(clk),.rst(rst),.frame_tick(1'b0),.paused(debug_mode),
        .clear(1'b0),.reward_valid(reward_valid),.reward_kind(reward_kind),
        .reward_x(reward_x),.reward_y(reward_y),.world_x(12'd0),.world_y(9'd0),
        .coin_on(),.coin_u(),.coin_v(),.text_on(),.text_char(),.text_row(),.text_col());
    game_scores ranks(.clk(clk),.rst(rst),.submit(submit),.save_busy(1'b0),
        .score(score),.elapsed_seconds(16'd42),.player_name("TEST  "),.avatar(3'd2),
        .query_index(4'd0),.query_record(record),.store_index(4'd0),.store_record(),
        .load_valid(1'b0),.load_index(4'd0),.load_record(96'd0),.changed());
    always #5 clk=~clk;
    always @(posedge clk) if(!rst) begin
        if(event_valid) events[event_code]=events[event_code]+1;
        if(reward_valid) rewards[reward_kind]=rewards[reward_kind]+1;
        if(submit) submits=submits+1;
        if(map_we) writes=writes+1;
    end
    task seed;
        begin
            rst=1;debug_mode=0;held_run=0;
            repeat(3) @(negedge clk);rst=0;
            repeat(15) @(negedge clk);
            for(integer i=0;i<16;i=i+1) begin events[i]=0;rewards[i]=0;end
            submits=0;writes=0;
            dut.state=dut.PLAY;dut.phase=dut.COMMIT;
            dut.score=24'd700;dut.lives=3;dut.coins_count=0;
            dut.xq=16'd512;dut.yq=14'd3072;
            dut.next_xq=17'd512;dut.next_yq=15'd3072;
            dut.next_vx=0;dut.next_vy=0;dut.body_height=16;
            dut.head_effect=1;dut.head_tile=dut.Q_COIN;dut.head_addr=12'hA02;
            dut.powerup_live=1;dut.powerup_type=1;
            dut.powerup_px=32;dut.powerup_py=192;dut.emerge_frames=0;
            dut.spawn_index=31;
        end
    endtask
    task settle;
        begin
            repeat(30) @(negedge clk);
            if(dut.phase!=dut.IDLE) $fatal(1,"settlement did not complete");
        end
    endtask
    initial begin
        seed();settle();
        if(score!=1900||coins_count!=1||lives!=4||writes!=1||
           events[2]!=1||events[11]!=1||rewards[0]!=1||rewards[3]!=1)
            $fatal(1,"coin + 1UP lost score/event: score=%0d lives=%0d coin=%0d 1up=%0d",score,lives,events[2],events[11]);
        if(fx.active!=3||fx.is_coin!=1||fx.label[1]!="1UP ")
            $fatal(1,"back-to-back world rewards did not fill both real FX slots");

        seed();dut.coins_count=99;settle();
        if(score!=1900||coins_count!=0||lives!=5)
            $fatal(1,"100 coins + 1UP must award two lives: %0d",lives);
        seed();dut.coins_count=99;dut.lives=14;settle();
        if(lives!=15) $fatal(1,"life cap overflow: %0d",lives);

        seed();dut.super_state=1;dut.fire_mario=1;held_run=1;
        dut.head_tile=dut.BRICK;dut.powerup_type=3;
        settle();
        if(score!=1750||events[15]!=1||events[7]!=1||events[12]!=1||
           rewards[4]!=1||rewards[2]!=1||dut.fireball_active==0)
            $fatal(1,"brick + flower + fireball events collided score=%0d",score);

        seed();dut.next_xq=17'd50448;dut.xq=16'd50448;dut.powerup_px=3153;
        settle();
        if(state!=dut.FLAG||score!=2000||events[2]!=1||events[11]!=1||events[10]!=1||rewards[5]!=1)
            $fatal(1,"pickup + coin + flag lost reward score=%0d state=%0d",score,state);

        // All pickup kinds and flag-height tiers use the pre-commit pose,
        // including a mushroom that changes the player's height this frame.
        for(integer p=0;p<4;p=p+1) for(integer f=0;f<5;f=f+1) begin
            seed();
            case(f)
                0:begin h=20;bonus=5000;end
                1:begin h=60;bonus=2000;end
                2:begin h=90;bonus=800;end
                3:begin h=120;bonus=400;end
                4:begin h=192;bonus=100;end
            endcase
            dut.next_xq=17'd50448;dut.xq=16'd50448;
            dut.yq=h*16;dut.next_yq=h*16;
            dut.powerup_type=p;dut.powerup_px=3153;dut.powerup_py=h;
            settle();
            if(state!=dut.FLAG||score!=1900+bonus||events[2]!=1||events[10]!=1||
               events[p==1?11:p==2?13:7]!=1||rewards[0]!=1||rewards[p==1?3:2]!=1)
                $fatal(1,"flag tier/pickup collision p=%0d height=%0d score=%0d",p,h,score);
        end

        seed();dut.powerup_type=0;settle();
        if(score!=1900||!dut.super_state||dut.player_y!=176)
            $fatal(1,"serialized mushroom moved the feet");
        seed();dut.powerup_live=0;dut.head_tile=dut.Q_POWER;settle();
        if(!dut.powerup_live||dut.emerge_frames!=16||score!=700||events[14]!=1)
            $fatal(1,"newly spawned pickup advanced/collected in its birth frame");
        seed();dut.head_effect=0;dut.emerge_frames=1;settle();
        if(!dut.powerup_live||dut.emerge_frames!=0||score!=700||events[11]!=0)
            $fatal(1,"emerging pickup collected a frame early");

        seed();dut.phase=dut.CONTACT;dut.entity_index=0;dut.star_state=1;
        dut.star_frames=100;dut.enemy_active=15;
        dut.enemy_x={12'd32,12'd32,12'd32,12'd32};
        dut.enemy_y={9'd192,9'd192,9'd192,9'd192};
        settle();
        if(score!=2700||events[3]!=4||events[2]!=1||events[11]!=1||rewards[1]!=4)
            $fatal(1,"four kills + coin + pickup lost an award score=%0d",score);

        seed();dut.coins_count=99;
        @(negedge clk);debug_mode=1;
        repeat(10) @(negedge clk);
        if(score!=900||lives!=4||events[11]!=0||events[2]!=1)
            $fatal(1,"paused settlement repeated or skipped block");
        debug_mode=0;settle();
        if(score!=1900||lives!=5||events[11]!=1||events[2]!=1)
            $fatal(1,"settlement resume duplicated rewards");

        // Side contact at the flag, with expired time and a pickup: death wins
        // once, and the final leaderboard snapshot cannot gain posthumous points.
        seed();dut.phase=dut.CONTACT;dut.entity_index=0;
        dut.lives=1;dut.seconds_left=0;
        dut.next_xq=17'd50448;dut.xq=16'd50448;dut.powerup_px=3153;
        dut.enemy_active=1;dut.enemy_x=48'd3153;dut.enemy_y=36'd192;
        settle();
        if(state!=dut.DEAD||lives!=0||score!=700||submits!=1||events[4]!=1||
           events[10]!=0||events[11]!=0||writes!=0||!record[91]||record[23:0]!=700)
            $fatal(1,"death overwritten/double charged: state=%0d lives=%0d score=%0d submits=%0d rank=%0d",
                   state,lives,score,submits,record[23:0]);

        seed();dut.phase=dut.CONTACT;dut.entity_index=0;dut.lives=1;
        dut.enemy_active=3;dut.enemy_x={24'd0,12'd40,12'd32};
        dut.enemy_y={18'd0,9'd192,9'd192};
        dut.fireball_active=1;dut.fireball_x=24'd32;dut.fireball_y=18'd192;
        settle();
        if(state!=dut.DEAD||lives!=0||score!=900||submits!=1||events[3]!=1||
           events[4]!=1||events[2]!=0||record[23:0]!=900)
            $fatal(1,"last-life snapshot lost a preceding kill score=%0d rank=%0d",score,record[23:0]);

        seed();dut.lives=1;dut.seconds_left=0;settle();
        if(state!=dut.DEAD||lives!=0||score!=700||submits!=1||events[4]!=1||
           events[2]!=0||events[11]!=0||writes!=0||record[23:0]!=700)
            $fatal(1,"timeout accepted rewards or wrong final snapshot");
        seed();dut.next_yq=15'sd3856;dut.powerup_py=241;settle();
        if(state!=dut.DEAD||lives!=2||score!=700||events[4]!=1||writes!=0)
            $fatal(1,"fall accepted rewards or lost death");
        $display("PASS game settlement: concurrent score/lives/events, cap, flag, pause, death priority and leaderboard snapshot");
        $finish;
    end
    initial begin #100000;$fatal(1,"settlement timeout");end
endmodule

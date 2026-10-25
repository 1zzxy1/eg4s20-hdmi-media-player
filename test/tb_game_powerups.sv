`timescale 1ns/1ps
// Exercise block effects and moving pickups through world public ports.
module tb_game_powerups;
    reg clk=0,rst=1,frame_tick=0,assets_loaded=1;
    reg held_left=0,held_right=0,jump_press=0,jump_hold=0,back_press=0;
    reg held_run=0,held_down=0,debug_mode=0,view_narrow=0;
    wire [2:0] state;
    wire [11:0] player_x,map_addr,powerup_x;
    wire [8:0] player_y,powerup_y;
    wire [1:0] powerup_kind,fireball_active;
    wire [23:0] fireball_x,score;
    wire [17:0] fireball_y;
    wire [3:0] lives,event_code;
    wire [7:0] coins_count,map_wdata;
    wire event_valid,map_reload,map_we,playing,paused,powerup_active,super_mario,fire_mario,player_crouch;
    wire [11:0] block_fx_addr;
    wire [4:0] block_fx_frames,transform_frames;
    wire [1:0] block_fx_kind;
    wire reward_valid;
    wire [3:0] reward_kind;
    wire [11:0] reward_x;
    wire [8:0] reward_y;
    integer reward_coins=0,reward_pickups=0,reward_breaks=0;
    reg seen_emerge=0,seen_break=0,seen_bounce=0,seen_grow=0;
    reg map_ready=1;
    reg [7:0] map_data=0;
    reg [7:0] tile [0:4095];
    integer i,reloads=0,reload_wait=0,old_x,old_y,old_score;
    game_world dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),.assets_loaded(assets_loaded),
        .held_left(held_left),.held_right(held_right),.jump_press(jump_press),
        .jump_hold(jump_hold),.back_press(back_press),.held_run(held_run),
        .held_down(held_down),.debug_mode(debug_mode),.view_narrow(view_narrow),
        .map_ready(map_ready),.map_data(map_data),.map_reload(map_reload),
        .map_addr(map_addr),.map_we(map_we),.map_wdata(map_wdata),
        .state(state),.player_x(player_x),.player_y(player_y),
        .powerup_active(powerup_active),.powerup_x(powerup_x),
        .powerup_y(powerup_y),.powerup_kind(powerup_kind),
        .super_mario(super_mario),.fire_mario(fire_mario),.player_crouch(player_crouch),
        .fireball_active(fireball_active),.fireball_x(fireball_x),
        .fireball_y(fireball_y),.score(score),.coins_count(coins_count),
        .lives(lives),.event_code(event_code),.event_valid(event_valid),
        .playing(playing),.paused(paused),.block_fx_addr(block_fx_addr),
        .block_fx_frames(block_fx_frames),.block_fx_kind(block_fx_kind),.transform_frames(transform_frames),
        .reward_valid(reward_valid),.reward_kind(reward_kind),.reward_x(reward_x),.reward_y(reward_y));
    always #5 clk=~clk;
    always @(posedge clk) begin
        if(event_valid&&event_code==14)begin
            seen_emerge<=1;
            if(block_fx_frames!=16||block_fx_kind!=3)$fatal(1,"power block bounce/appearance event");
        end
        if(event_valid&&event_code==15)begin
            seen_break<=1;
            if(block_fx_frames!=20||block_fx_kind!=2)$fatal(1,"break debris event");
        end
        if(event_valid&&(event_code==2||event_code==15)) begin
            if(!reward_valid||reward_kind!=(event_code==2?0:4)||
               reward_x!={block_fx_addr[7:0],4'b0}||
               reward_y!={1'b0,block_fx_addr[11:8],4'b0})
                $fatal(1,"block reward payload event=%0d kind=%0d xy=%0d,%0d",event_code,reward_kind,reward_x,reward_y);
            if(event_code==2)reward_coins<=reward_coins+1;
            else reward_breaks<=reward_breaks+1;
        end
        if(event_valid&&(event_code==7||event_code==11||event_code==13)) begin
            if(!reward_valid||reward_kind!=(event_code==11?3:2)||
               reward_x!=powerup_x||reward_y!=powerup_y)
                $fatal(1,"pickup reward payload event=%0d kind=%0d xy=%0d,%0d",event_code,reward_kind,reward_x,reward_y);
            reward_pickups<=reward_pickups+1;
        end
        if(block_fx_frames!=0)seen_bounce<=1;
        if(transform_frames!=0)seen_grow<=1;
        map_data<=tile[map_addr];
        if(map_we) tile[map_addr]<=map_wdata;
        if(map_reload) begin map_ready<=0;reload_wait<=10;reloads<=reloads+1;end
        else if(reload_wait!=0) begin
            reload_wait<=reload_wait-1;
            if(reload_wait==1) map_ready<=1;
        end
    end
    task step; begin
        @(negedge clk);frame_tick=1;
        @(negedge clk);frame_tick=0;
        repeat(120) @(negedge clk);
    end endtask
    task tap; begin jump_press=1;step();jump_press=0;end endtask
    task clear_map; begin
        for(integer k=0;k<4096;k=k+1) tile[k]=0;
        for(integer k=0;k<256;k=k+1) tile[{4'd13,k[7:0]}]=1;
    end endtask
    task boot; begin
        rst=1;held_left=0;held_right=0;jump_press=0;jump_hold=0;
        held_run=0;debug_mode=0;map_ready=1;reload_wait=0;
        repeat(4) @(negedge clk);rst=0;
        tap();step();
        for(integer k=0;k<7;k=k+1) begin tap();step();end
        if(state!=2 || !map_ready || reloads==0) $fatal(1,"powerup test boot/reload");
        repeat(40) step();
        if(player_y!=192) $fatal(1,"powerup spawn not settled y=%0d",player_y);
    end endtask
    task hit_block; begin
        jump_hold=1;tap();jump_hold=0;
        repeat(40) step();
    end endtask
    initial begin
        clear_map();boot();
        tile[{4'd10,8'd2}]=4;tile[{4'd9,8'd4}]=4;
        hit_block();
        if(tile[{4'd10,8'd2}]!=5 || !powerup_active || powerup_kind!=0)
            $fatal(1,"first Q_POWER did not create mushroom");
        held_right=1;held_run=1;
        for(i=0;i<75 && !super_mario;i=i+1) step();
        held_right=0;held_run=0;
        if(!super_mario) $fatal(1,"mushroom not collected x=%0d pickup=%0d,%0d",
                               player_x,powerup_x,powerup_y);
        repeat(6) step();
        hit_block();
        if(tile[{4'd9,8'd4}]!=5 || !powerup_active || powerup_kind!=3)
            $fatal(1,"second Q_POWER failed tile=%0d active=%0b kind=%0d player=%0d,%0d",
                   tile[{4'd9,8'd4}],powerup_active,powerup_kind,player_x,player_y);
        held_left=1;repeat(8) step();held_left=0;repeat(5) step();
        jump_hold=1;held_right=1;tap();
        for(i=0;i<45 && !fire_mario;i=i+1) step();
        held_right=0;jump_hold=0;
        if(!fire_mario) $fatal(1,"flower not collected player=%0d,%0d flower=%0d,%0d",
                              player_x,player_y,powerup_x,powerup_y);
        held_run=1;step();
        if(fireball_active==0) $fatal(1,"KEY1 run did not launch fireball");
        held_run=0;

        clear_map();boot();tile[{4'd10,8'd2}]=11;hit_block();
        if(tile[{4'd10,8'd2}]!=5 || powerup_kind!=1)
            $fatal(1,"hidden 1UP failed tile=%0d active=%0b kind=%0d x=%0d y=%0d player=%0d,%0d",
                   tile[{4'd10,8'd2}],powerup_active,powerup_kind,powerup_x,powerup_y,player_x,player_y);
        held_right=1;held_run=1;
        for(i=0;i<75 && lives==3;i=i+1) step();
        held_right=0;held_run=0;
        if(lives!=4 || powerup_active) $fatal(1,"hidden 1UP not collected lives=%0d",lives);

        clear_map();boot();tile[{4'd10,8'd2}]=14;hit_block();
        if(tile[{4'd10,8'd2}]!=5 || powerup_kind!=0)
            $fatal(1,"BRICK_POWER did not become USED/mushroom");
        clear_map();boot();tile[{4'd10,8'd2}]=13;hit_block();
        if(tile[{4'd10,8'd2}]!=5 || powerup_kind!=2)
            $fatal(1,"BRICK_STAR did not become USED/star");

        clear_map();boot();tile[{4'd10,8'd2}]=3;old_score=score;hit_block();
        if(tile[{4'd10,8'd2}]!=5 || coins_count!=1 || score!=old_score+200)
            $fatal(1,"Q_COIN write/score failed tile=%0d coins=%0d score=%0d old=%0d",
                   tile[{4'd10,8'd2}],coins_count,score,old_score);
        clear_map();boot();tile[{4'd10,8'd2}]=12;old_score=score;hit_block();
        if(tile[{4'd10,8'd2}]!=12 || coins_count!=1 || score!=old_score+200)
            $fatal(1,"BRICK_COIN first hit/window tile=%0d coins=%0d score=%0d",
                   tile[{4'd10,8'd2}],coins_count,score);
        hit_block();
        if(tile[{4'd10,8'd2}]!=12 || coins_count!=2 || score!=old_score+400)
            $fatal(1,"BRICK_COIN repeated hit/window tile=%0d coins=%0d score=%0d",
                   tile[{4'd10,8'd2}],coins_count,score);
        repeat(240) step();
        hit_block();
        if(tile[{4'd10,8'd2}]!=5 || coins_count!=3 || score!=old_score+600)
            $fatal(1,"BRICK_COIN expiry hit tile=%0d coins=%0d score=%0d",
                   tile[{4'd10,8'd2}],coins_count,score);

        clear_map();boot();
        for(i=0;i<100;i=i+1) begin
            tile[{4'd10,8'd2}]=3;
            hit_block();
            if(tile[{4'd10,8'd2}]!=5 ||
               coins_count!=((i+1)%100) || lives!=(i>=99?4:3))
                $fatal(1,"coin 100 rollover at %0d tile=%0d count=%0d lives=%0d",
                       i+1,tile[{4'd10,8'd2}],coins_count,lives);
        end

        clear_map();boot();tile[{4'd10,8'd2}]=4;hit_block();
        held_right=1;held_run=1;
        for(i=0;i<75 && !super_mario;i=i+1) step();
        held_right=0;held_run=0;
        if(!super_mario) $fatal(1,"headroom setup mushroom missing");
        held_down=1;step();
        if(!player_crouch || player_y!=192) $fatal(1,"super crouch failed y=%0d",player_y);
        tile[{4'd11,player_x[11:4]}]=2;
        held_down=0;step();
        if(!player_crouch || player_y!=192)
            $fatal(1,"stood inside ceiling brick y=%0d crouch=%0b",player_y,player_crouch);
        tile[{4'd11,player_x[11:4]}]=0;
        step();
        if(player_crouch || player_y!=176)
            $fatal(1,"did not stand after ceiling removed y=%0d crouch=%0b",player_y,player_crouch);
        // Let horizontal momentum decay before placing a brick over the head
        // probe; otherwise the short jump drifts out from under that column.
        repeat(20) step();
        old_x=(player_x+2)>>4;
        tile[{4'd9,old_x[7:0]}]=2;
        hit_block();
        if(tile[{4'd9,old_x[7:0]}]!=0) $fatal(1,"super head hit did not remove brick");
        if(!seen_break||!seen_emerge||!seen_bounce||!seen_grow)
            $fatal(1,"missing visual/audio feedback break=%b emerge=%b bounce=%b grow=%b",seen_break,seen_emerge,seen_bounce,seen_grow);

        clear_map();boot();held_right=1;
        @(negedge clk);frame_tick=1;
        @(negedge clk);frame_tick=0;
        repeat(3) @(negedge clk);
        if(map_addr==0) $fatal(1,"did not reach map probe before debug");
        old_x=player_x;old_y=player_y;debug_mode=1;
        repeat(150) @(negedge clk);
        if(player_x!=old_x || player_y!=old_y || !paused)
            $fatal(1,"debug changed unfinished physics frame");
        debug_mode=0;repeat(10) step();
        if(player_x==old_x) $fatal(1,"unfinished physics frame did not resume");
        if(reward_coins<104||reward_pickups<4||reward_breaks<1)
            $fatal(1,"reward coverage coins=%0d pickups=%0d breaks=%0d",reward_coins,reward_pickups,reward_breaks);
        $display("PASS game powerups: mushroom, flower/fireball, 1UP, multi-coin window, 100-coin life, crouch headroom, debug, reward payloads");
        $finish;
    end
    initial begin #20000000 $fatal(1,"powerup timeout"); end
endmodule

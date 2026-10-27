`timescale 1ns/1ps
// Enemy contact regression using only game_world ports and a synchronous map.
module tb_game_enemies;
    reg clk=0,rst=1,frame_tick=0,assets_loaded=1;
    reg held_left=0,held_right=0,jump_press=0,jump_hold=0,back_press=0;
    reg held_run=0,held_down=0,debug_mode=0,view_narrow=0;
    wire [2:0] state;
    wire [11:0] player_x,camera_x,map_addr;
    wire [8:0] player_y;
    wire [3:0] lives,enemy_active,event_code;
    wire super_mario,powerup_active;
    wire [11:0] powerup_x;
    wire [8:0] powerup_y;
    wire [1:0] powerup_kind;
    wire [47:0] enemy_x;
    wire [35:0] enemy_y;
    wire [7:0] enemy_kind,map_wdata;
    wire [23:0] score,fireball_x;
    wire [17:0] fireball_y;
    wire [1:0] fireball_active;
    wire map_reload,map_we,event_valid,fire_mario;
    wire reward_valid;
    wire [3:0] reward_kind;
    wire [11:0] reward_x;
    wire [8:0] reward_y;
    reg reward_matches_enemy;
    reg map_ready=1;
    reg [7:0] map_data=0;
    reg [7:0] tile [0:4095];
    integer i,j,reload_wait=0,stomps=0,deaths=0;
    integer koopa_slot,koopa_x;
    reg fire_kill_far;
    game_world dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),.assets_loaded(assets_loaded),
        .held_left(held_left),.held_right(held_right),.jump_press(jump_press),
        .jump_hold(jump_hold),.back_press(back_press),.held_run(held_run),
        .held_down(held_down),.debug_mode(debug_mode),.view_narrow(view_narrow),
        .map_ready(map_ready),.map_data(map_data),.map_reload(map_reload),
        .map_addr(map_addr),.map_we(map_we),.map_wdata(map_wdata),
        .state(state),.player_x(player_x),.player_y(player_y),.camera_x(camera_x),
        .enemy_active(enemy_active),.enemy_x(enemy_x),.enemy_y(enemy_y),
        .enemy_kind(enemy_kind),.lives(lives),.score(score),
        .super_mario(super_mario),.powerup_active(powerup_active),
        .powerup_x(powerup_x),.powerup_y(powerup_y),.powerup_kind(powerup_kind),
        .event_code(event_code),.event_valid(event_valid),.fire_mario(fire_mario),
        .fireball_active(fireball_active),.fireball_x(fireball_x),.fireball_y(fireball_y),
        .reward_valid(reward_valid),.reward_kind(reward_kind),.reward_x(reward_x),.reward_y(reward_y));
    always #5 clk=~clk;
    always @(posedge clk) begin
        map_data<=tile[map_addr];
        if(map_we) tile[map_addr]<=map_wdata;
        if(map_reload) begin map_ready<=0;reload_wait<=10;end
        else if(reload_wait!=0) begin
            reload_wait<=reload_wait-1;
            if(reload_wait==1) map_ready<=1;
        end
        if(event_valid && event_code==3) begin
            stomps<=stomps+1;
            reward_matches_enemy=0;
            for(integer s=0;s<4;s=s+1)
                if(reward_x==enemy_x[s*12+:12]&&reward_y==enemy_y[s*9+:9])reward_matches_enemy=1;
            if(!reward_valid||reward_kind!=1||!reward_matches_enemy)
                $fatal(1,"enemy reward does not match a world-space enemy");
        end
        if(event_valid && event_code==4) deaths<=deaths+1;
    end
    task step; begin
        @(negedge clk);frame_tick=1;
        @(negedge clk);frame_tick=0;
        repeat(120) @(negedge clk);
    end endtask
    task tap; begin jump_press=1;step();jump_press=0;end endtask
    task boot; begin
        for(integer k=0;k<4096;k=k+1) tile[k]=0;
        for(integer k=0;k<256;k=k+1) tile[{4'd13,k[7:0]}]=1;
        rst=1;held_left=0;held_right=0;jump_press=0;jump_hold=0;
        held_run=0;debug_mode=0;map_ready=1;reload_wait=0;
        repeat(4) @(negedge clk);rst=0;
        tap();step();
        for(integer k=0;k<7;k=k+1) begin tap();step();end
        if(state!=2) $fatal(1,"enemy bench boot");
        repeat(40) step();
    end endtask
    initial begin
        boot();held_right=1;held_run=1;
        for(i=0;i<200 && state==2;i=i+1) step();
        if(state!=3 || lives!=2 || deaths==0)
            $fatal(1,"Goomba side contact did not kill state=%0d lives=%0d x=%0d enemy=%0d",
                   state,lives,player_x,enemy_x[11:0]);
        if(i<10) $fatal(1,"side contact occurred before enemy approach");

        boot();held_right=1;held_run=1;jump_hold=1;
        for(i=0;i<200 && stomps==0 && state==2;i=i+1) begin
            jump_press=(player_x>=125 && player_y>=190);
            step();
        end
        jump_press=0;
        if(state!=2 || lives!=3 || stomps==0 || score<200 || enemy_active[0])
            $fatal(1,"Goomba stomp failed state=%0d lives=%0d x=%0d active=%b score=%0d",
                   state,lives,player_x,enemy_active,score);

        boot();held_right=1;held_run=1;jump_hold=1;koopa_slot=-1;
        for(i=0;i<500 && state==2 && koopa_slot<0;i=i+1) begin
            jump_press=(player_y>=190);
            step();
            for(j=0;j<4;j=j+1)
                if(enemy_active[j] && enemy_kind[j*2 +: 2]==1) koopa_slot=j;
        end
        jump_press=0;
        if(koopa_slot<0) $fatal(1,"Koopa never spawned on public route");
        // Keep moving and jump at ground contact until the shell state is observed.
        jump_hold=0;
        for(i=0;i<220 && state==2 && enemy_kind[koopa_slot*2 +: 2]!=2;i=i+1) begin
            jump_press=(player_y>=190);step();
        end
        jump_press=0;
        if(enemy_kind[koopa_slot*2 +: 2]!=2 || !enemy_active[koopa_slot])
            $fatal(1,"Koopa stomp did not produce shell kind=%0d x=%0d y=%0d",
                   enemy_kind[koopa_slot*2 +: 2],player_x,player_y);
        // A second contact while the shell is stopped must kick it into kind 3.
        held_left=1;held_right=0;jump_hold=0;
        for(i=0;i<80 && state==2 && enemy_kind[koopa_slot*2 +: 2]!=3;i=i+1) step();
        held_left=0;
        if(enemy_kind[koopa_slot*2 +: 2]!=3 || !enemy_active[koopa_slot])
            $fatal(1,"shell was not kicked kind=%0d player=%0d enemy=%0d",
                   enemy_kind[koopa_slot*2 +: 2],player_x,enemy_x[koopa_slot*12 +: 12]);
        // Recreate a top contact with a stopped shell through the real CONTACT
        // state. A shell stomp must kick it and the entity pass must move it.
        @(negedge clk);
        koopa_x=enemy_x[koopa_slot*12 +: 12];
        dut.enemy_kind[koopa_slot*2 +: 2]=2;
        dut.xq=koopa_x<<4;dut.yq=(enemy_y[koopa_slot*9 +: 9]-16)<<4;
        dut.next_xq=koopa_x<<4;
        dut.next_yq=(enemy_y[koopa_slot*9 +: 9]-15)<<4;
        dut.next_vy=1;dut.body_height=16;dut.grounded=0;
        dut.entity_index=koopa_slot;dut.phase=15;
        @(negedge clk);
        if(enemy_kind[koopa_slot*2 +: 2]!=3)
            $fatal(1,"top stomp did not kick stopped shell kind=%0d",enemy_kind[koopa_slot*2 +: 2]);
        for(i=0;i<4 && enemy_x[koopa_slot*12 +: 12]==koopa_x;i=i+1) step();
        if(enemy_x[koopa_slot*12 +: 12]==koopa_x)
            $fatal(1,"rolling shell did not move from x=%0d phase=%0d state=%0d",
                   koopa_x,dut.phase,state);

        boot();tile[{4'd10,8'd2}]=4;tile[{4'd9,8'd4}]=4;
        jump_hold=1;tap();jump_hold=0;repeat(40) step();
        held_right=1;held_run=1;
        for(i=0;i<75 && !super_mario;i=i+1) step();
        held_right=0;held_run=0;
        if(!super_mario) $fatal(1,"fire test mushroom pickup");
        repeat(6) step();jump_hold=1;tap();jump_hold=0;repeat(40) step();
        held_left=1;repeat(8) step();held_left=0;repeat(5) step();
        jump_hold=1;held_right=1;tap();
        for(i=0;i<45 && !fire_mario;i=i+1) step();
        held_right=0;jump_hold=0;
        if(!fire_mario) $fatal(1,"fire test flower pickup");
        held_right=1;held_run=1;fire_kill_far=0;
        for(i=0;i<100 && state==2 && !fire_kill_far;i=i+1) begin
            koopa_x=enemy_x[11:0];
            j=enemy_active[0] && koopa_x>player_x+24;
            step();
            if(j && !enemy_active[0]) fire_kill_far=1;
        end
        if(!fire_kill_far || state!=2 || score<2200)
            $fatal(1,"fireball did not remove Goomba at range x=%0d score=%0d state=%0d",
                   player_x,score,state);
        $display("PASS game enemies: Goomba contact, Koopa side/top shell kicks and motion, ranged fireball kill");
        $finish;
    end
    initial begin #10000000 $fatal(1,"enemy timeout"); end
endmodule

`timescale 1ns/1ps
// Public-port physics regression with a synchronous, reloadable tile map.
module tb_game_physics;
    reg clk=0,rst=1,frame_tick=0,assets_loaded=1;
    reg held_left=0,held_right=0,jump_press=0,jump_hold=0,back_press=0;
    reg held_run=0,held_down=0,debug_mode=0,view_narrow=0;
    wire [2:0] state;
    wire [11:0] player_x,map_addr;
    wire [8:0] player_y;
    wire facing_left;
    wire fire_mario;
    wire [1:0] fireball_active;
    wire [23:0] fireball_x;
    wire [17:0] fireball_y;
    wire [23:0] score;
    wire [8:0] seconds_left;
    wire [3:0] lives,event_code;
    wire event_valid,map_reload,map_we,playing,paused;
    wire [7:0] map_wdata;
    reg map_ready=1;
    reg [7:0] map_data=0;
    reg [7:0] tile [0:4095];
    integer i,j,old_x,old_y,peak_short,peak_long,jump_events=0,events_before;
    integer reloads=0,reload_wait=0;
    game_world dut(.clk(clk),.rst(rst),.frame_tick(frame_tick),
        .assets_loaded(assets_loaded),.held_left(held_left),.held_right(held_right),
        .jump_press(jump_press),.jump_hold(jump_hold),.back_press(back_press),
        .held_run(held_run),.held_down(held_down),.debug_mode(debug_mode),
        .view_narrow(view_narrow),.map_ready(map_ready),.map_data(map_data),
        .map_reload(map_reload),.map_addr(map_addr),.map_we(map_we),
        .map_wdata(map_wdata),.state(state),.player_x(player_x),.player_y(player_y),
        .facing_left(facing_left),.fire_mario(fire_mario),
        .fireball_active(fireball_active),.fireball_x(fireball_x),
        .fireball_y(fireball_y),
        .score(score),.seconds_left(seconds_left),.lives(lives),
        .event_code(event_code),.event_valid(event_valid),.playing(playing),.paused(paused));
    always #5 clk=~clk;
    always @(posedge clk) begin
        map_data<=tile[map_addr];
        if(map_we) tile[map_addr]<=map_wdata;
        if(event_valid && event_code==1) jump_events<=jump_events+1;
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
    task tap_jump; begin
        jump_press=1;step();jump_press=0;
    end endtask
    task start_game; begin
        rst=1;held_left=0;held_right=0;jump_press=0;jump_hold=0;
        held_run=0;debug_mode=0;map_ready=1;reload_wait=0;
        repeat(4) @(negedge clk);rst=0;
        tap_jump();step();
        if(state!=1) $fatal(1,"profile entry");
        for(integer k=0;k<7;k=k+1) begin tap_jump();step();end
        if(state!=2 || reloads==0 || !map_ready)
            $fatal(1,"play entry/reload state=%0d reloads=%0d ready=%0b",
                   state,reloads,map_ready);
        repeat(40) step();
        if(player_y!=192) $fatal(1,"spawn did not settle y=%0d",player_y);
    end endtask
    task clear_map; begin
        for(integer k=0;k<4096;k=k+1) tile[k]=0;
        for(integer k=0;k<256;k=k+1) tile[{4'd13,k[7:0]}]=1;
    end endtask
    initial begin
        clear_map();
        start_game();
        held_right=1;repeat(12) step();held_right=0;
        old_x=player_x;
        if(old_x<45) $fatal(1,"right acceleration x=%0d",old_x);
        held_left=1;repeat(18) step();held_left=0;
        if(player_x>=old_x || !facing_left)
            $fatal(1,"left reversal failed x=%0d old=%0d",player_x,old_x);
        repeat(20) step();
        if(player_x<0 || player_x>old_x) $fatal(1,"negative velocity wrap x=%0d",player_x);

        clear_map();start_game();
        events_before=jump_events;
        jump_hold=0;tap_jump();peak_short=player_y;
        repeat(28) begin step();if(player_y<peak_short) peak_short=player_y;end
        if(player_y!=192) $fatal(1,"short jump did not land y=%0d",player_y);
        jump_hold=1;tap_jump();peak_long=player_y;
        repeat(4) begin jump_press=1;step();jump_press=0;
            if(player_y<peak_long) peak_long=player_y;end
        repeat(50) begin step();if(player_y<peak_long) peak_long=player_y;end
        if(peak_long>=peak_short || jump_events-events_before!=2)
            $fatal(1,"long/short or air re-jump short=%0d long=%0d events=%0d",
                   peak_short,peak_long,jump_events-events_before);
        if(player_y!=192) $fatal(1,"long jump did not land y=%0d",player_y);

        clear_map();
        tile[{4'd11,8'd7}]=2;tile[{4'd12,8'd7}]=2;
        tile[{4'd11,8'd12}]=7;tile[{4'd12,8'd12}]=9;
        start_game();held_right=1;repeat(70) step();held_right=0;
        if(player_x>7*16 || player_x<70)
            $fatal(1,"brick wall passed or not approached x=%0d",player_x);
        old_x=player_x;held_right=1;jump_hold=1;tap_jump();repeat(35) step();
        if(player_x<=old_x || player_x>12*16)
            $fatal(1,"brick obstacle not cleared or pipe passed x=%0d",player_x);

        old_x=player_x;old_y=player_y;
        debug_mode=1;held_right=1;repeat(12) step();
        if(player_x!=old_x || player_y!=old_y || !paused)
            $fatal(1,"debug freeze moved player");
        debug_mode=0;repeat(10) step();
        if(player_x==old_x) $fatal(1,"debug resume did not move");
        $display("PASS game physics: signed reversal, jump height/rejump, brick/pipe, debug freeze/resume");
        $finish;
    end
    initial begin #5000000 $fatal(1,"physics timeout"); end
endmodule

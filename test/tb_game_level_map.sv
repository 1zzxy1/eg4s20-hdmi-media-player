`timescale 1ns/1ps
module tb_game_level_map;
    reg clk=0,rst=1,reload=0,world_we=0;
    reg [11:0] world_addr=0,video_addr=0;
    reg [7:0] world_wdata=0;
    wire ready; wire [7:0] world_data,video_data;
    game_level_map dut(.*);
    always #5 clk=~clk;
    task tick; begin @(negedge clk); end endtask
    integer i;
    initial begin
        repeat(2) tick; rst=0;
        for(i=0;i<4105;i=i+1) tick;
        if(!ready) $fatal(1,"initial reload never became ready");
        // Check both public read ports, including different simultaneous addresses.
        for(i=0;i<4096;i=i+1) begin
            world_addr=i; video_addr=4095-i; tick; #1;
            if(world_data!=={4'd0,dut.level_rom[i]} ||
               video_data!=={4'd0,dut.level_rom[4095-i]})
                $fatal(1,"initial cell %0d mismatch",i);
        end
        // The video port must keep reading an unrelated cell during a world write.
        video_addr=12'h123;
        world_addr=12'h5a3; world_wdata=8'd14; world_we=1; tick; world_we=0;
        if(video_data!=={4'd0,dut.level_rom[12'h123]})
            $fatal(1,"world write blocked the independent video port");
        world_addr=12'h5a3; video_addr=12'h5a3; tick; #1;
        if(world_data!==8'd14 || video_data!==8'd14) $fatal(1,"synchronous read mismatch");
        world_wdata=8'h5a; world_we=1; tick; world_we=0;
        world_addr=12'h5a3; video_addr=12'h5a3; tick; #1;
        if(world_data!==8'd14 || video_data!==8'd14)
            $fatal(1,"invalid cell write changed RAM");
        // Reload must clear ready and restore all 4096 cells, including the changed one.
        reload=1; tick; reload=0;
        if(ready) $fatal(1,"ready did not drop on reload");
        for(i=0;i<4105;i=i+1) tick;
        world_addr=12'h5a3;video_addr=12'h5a3;tick;#1;
        if(!ready || world_data!=={4'd0,dut.level_rom[12'h5a3]} || video_data!==world_data)
            $fatal(1,"reload did not restore ROM");
        $display("PASS game level map: 4096-cell dual-port reload, concurrent write/read, synchronous reads");
        $finish;
    end
    initial begin #200000 $fatal(1,"game level map timeout"); end
endmodule

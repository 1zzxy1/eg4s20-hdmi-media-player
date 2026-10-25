`timescale 1ns/1ps
module tb_game_hud_decimal;
    reg clk=0,rst=1;
    reg [23:0] score=0,rank_score=0;
    reg [8:0] seconds_left=0;
    reg [7:0] coins_count=0;
    reg [15:0] rank_time=0;
    wire [23:0] score_bcd,rank_score_bcd;
    wire [11:0] seconds_bcd;
    wire [7:0] coins_bcd;
    wire [19:0] rank_time_bcd;
    integer n;
    reg [23:0] old_rank;
    game_hud_decimal dut(.*);
    always #5 clk=~clk;
    function [23:0] golden(input integer value);
        integer d,v;
        begin
            golden=0;v=value;
            for(d=0;d<6;d=d+1)begin golden[d*4+:4]=v%10;v=v/10;end
        end
    endfunction
    task check;
        repeat(250)@(negedge clk);
        if(score_bcd!==golden(score)||rank_score_bcd!==golden(rank_score)||
           seconds_bcd!==(golden(seconds_left)&12'hfff)||
           coins_bcd!==(golden(coins_count)&8'hff)||rank_time_bcd!==(golden(rank_time)&20'hfffff))
            $fatal(1,"shared decimal conversion mismatch");
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;check();
        score=24'hffffff;rank_score=999999;seconds_left=511;coins_count=255;rank_time=65535;check();
        for(n=0;n<100;n=n+1)begin
            score=$urandom;rank_score=$urandom;seconds_left=$urandom;coins_count=$urandom;rank_time=$urandom;
            check();
        end
        // A leaderboard row has a different record at x=0. Before x=272,
        // where score digits begin, the complete new value must be visible.
        for(n=0;n<125;n=n+1)begin
            @(negedge clk);rank_score=123456;rank_time=87;
            repeat(272)@(negedge clk);
            if(rank_score_bcd!==24'h123456||rank_time_bcd!==20'h00087)
                $fatal(1,"leaderboard deadline at scheduler phase %0d",n);
            rank_score=654321;rank_time=54321;
            // Drain an earlier captured record before checking atomic publication.
            // The 649-clock loop also visits every phase of the 125-clock round.
            repeat(250)@(negedge clk);
            old_rank=rank_score_bcd;
            @(negedge clk);rank_score=123456;
            repeat(125)begin
                @(negedge clk);
                if(rank_score_bcd!==old_rank&&rank_score_bcd!==24'h123456)
                    $fatal(1,"partially published decimal result");
            end
        end
        rst=1;@(negedge clk);
        if({score_bcd,rank_score_bcd,seconds_bcd,coins_bcd,rank_time_bcd}!==0)$fatal(1,"decimal reset");
        $display("PASS shared HUD decimal: boundaries, 100 random tuples, atomic results, 125 leaderboard phases");
        $finish;
    end
    initial begin #2000000;$fatal(1,"HUD decimal timeout");end
endmodule

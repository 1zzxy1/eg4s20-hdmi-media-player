`timescale 1ns/1ps
`include "game_assets.vh"
module tb_game_texture_cache;
    reg wc=0,pc=0,wr=1,rr=1,start=0,we=0,commit=0;reg [23:0] rgb=0;
    always #5 wc=~wc;always #10 pc=~pc;
    reg [14:0] ba=0,sa=0;wire [3:0] bi,si;wire loaded;
    game_texture_cache dut(wc,wr,start,we,rgb,commit,pc,rr,ba,sa,bi,si,loaded);
    reg [23:0] signature[0:15];integer x,y,k;
    task frame(input good);begin
        @(negedge wc);start=1;@(negedge wc);start=0;
        for(y=479;y>=0;y=y-1)for(x=0;x<640;x=x+1)begin
            we=1;rgb=((x/16+y/16)%2)?`GAME_PAL_2:`GAME_PAL_1;
            if(y==0&&x>=128&&x<144)rgb=good?signature[x-128]:24'd0;
            @(negedge wc);
        end
        we=0;repeat(6)@(negedge wc);
    end endtask
    initial begin
        signature[0]=`GAME_SIG_0;signature[1]=`GAME_SIG_1;signature[2]=`GAME_SIG_2;signature[3]=`GAME_SIG_3;
        signature[4]=`GAME_SIG_4;signature[5]=`GAME_SIG_5;signature[6]=`GAME_SIG_6;signature[7]=`GAME_SIG_7;
        signature[8]=`GAME_SIG_8;signature[9]=`GAME_SIG_9;signature[10]=`GAME_SIG_10;signature[11]=`GAME_SIG_11;
        signature[12]=`GAME_SIG_12;signature[13]=`GAME_SIG_13;signature[14]=`GAME_SIG_14;signature[15]=`GAME_SIG_15;
        repeat(4)@(negedge wc);wr=0;rr=0;
        frame(0);commit=1;repeat(5)@(negedge pc);if(loaded)$fatal(1,"accepted normal BMP");commit=0;
        frame(1);repeat(5)@(negedge pc);if(loaded)$fatal(1,"published before DMA finish");
        commit=1;repeat(5)@(negedge pc);if(!loaded)$fatal(1,"not published");
        // Read every texel through both ports across all physical bank boundaries.
        for(k=0;k<85*256;k=k+1)begin
            ba=k;sa=85*256-1-k;
            @(posedge pc);#1;
            if(bi!=(((k/256)%8+(k/256)/8)%2?2:1) ||
               si!=((((85*256-1-k)/256)%8+((85*256-1-k)/256)/8)%2?2:1))
                $fatal(1,"atlas bank/address mismatch at %0d: %0d %0d",k,bi,si);
            @(negedge pc);
        end
        ba={7'd0,4'd0,4'd0};sa={7'd1,4'd0,4'd0};repeat(3)@(negedge pc);
        if(bi!=1||si!=2)$fatal(1,"tile/orientation %0d %0d",bi,si);
        ba={7'd8,4'd15,4'd15};sa={7'd84,4'd15,4'd15};repeat(3)@(negedge pc);
        if(bi!=2||si!=1)$fatal(1,"highest valid tile texel %0d %0d",bi,si);
        ba={7'd85,4'd0,4'd0};sa={7'd127,4'd15,4'd15};repeat(3)@(negedge pc);
        if(bi!=0||si!=0)$fatal(1,"invalid atlas tile was not blank %0d %0d",bi,si);
        ba={7'd0,4'd0,4'd0};sa={7'd84,4'd15,4'd15};
        @(posedge pc);#1;
        if(bi!=1||si!=1)$fatal(1,"bank switch read latency %0d %0d",bi,si);
        ba={7'd85,4'd0,4'd0};sa={7'd1,4'd0,4'd0};
        @(posedge pc);#1;
        if(bi!=0||si!=2)$fatal(1,"bank switch invalid/valid %0d %0d",bi,si);
        ba={7'd8,4'd15,4'd15};sa={7'd84,4'd15,4'd15};repeat(3)@(negedge pc);
        // A later cache refill of image zero must not overwrite live texture RAM.
        @(negedge wc);start=1;@(negedge wc);start=0;we=1;rgb=`GAME_PAL_6;
        repeat(20)@(negedge wc);we=0;repeat(3)@(negedge pc);
        if(bi!=2||si!=1||!loaded)$fatal(1,"live atlas overwritten");
        $display("PASS game texture cache: bottom-up atlas, signature, DMA publication, dual read, immutable reload");$finish;
    end
endmodule

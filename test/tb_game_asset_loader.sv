`timescale 1ns/1ps
`include "game_assets.vh"
// Actual V4 image bytes -> BMP decoder -> texture cache, with a truncated
// sector and an invalid signature before the successful retry.
module tb_game_asset_loader #(parameter SHARED=0);
    reg clk=0,pclk=0,rst=1;
    always #10 clk=~clk;
    always #20 pclk=~pclk;
    wire begin_asset,we,commit,req,loaded,failed;
    wire [23:0] rgb;
    wire [31:0] addr;
    wire [3:0] status,bi,si;
    reg [7:0] data=0;
    reg valid=0,sector_end=0;
    reg [14:0] ba=0,sa=0;
    wire gallery_write;
    wire [6:0] image_count;
    generate if(SHARED)begin:shared
        sd_card_bmp #(.CLK_FREQ_HZ(50_000_000),.EXTERNAL_CARD(1),.BOOT_ATLAS(1),
            .ATLAS_RETRY_CYCLES(128),.SCAN_START_SECTOR(2048),.SCAN_MAX_SECTOR(131071)) loader(
            .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_previous(1'b1),
            .auto_enable(1'b0),.bmp_width(16'd640),.bmp_height(16'd480),
            .write_finish_toggle(1'b0),.display_ack_toggle(1'b0),
            .write_req(gallery_write),.write_req_ack(1'b0),.write_ready(1'b1),.image_count(image_count),
            .asset_begin(begin_asset),.asset_we(we),.asset_commit(commit),.asset_rgb(rgb),
            .native_assets_ready(loaded),.native_failed(failed),.state_code(status),
            .audio_req(1'b0),.audio_addr(32'd0),.SD_MISO(1'b1),
            .card_initialized(!rst),.card_read_req(req),.card_read_addr(addr),
            .card_read_data(data),.card_read_valid(valid),.card_read_end(sector_end));
    end else begin:native
    assign gallery_write=0;assign image_count=0;
    game_asset_loader #(.RETRY_CYCLES(128)) loader(
        .clk(clk),.rst(rst),.initialized(!rst),.assets_ready(loaded),
        .asset_begin(begin_asset),.asset_we(we),.asset_commit(commit),.asset_rgb(rgb),
        .req(req),.addr(addr),.data(data),.valid(valid),.sector_end(sector_end),
        .status(status),.failed(failed));
    end endgenerate
    game_texture_cache cache(clk,rst,begin_asset,we,rgb,commit,pclk,rst,ba,sa,bi,si,loaded);
    integer image_fd,rc,count=0,sectors=0,begins=0,commits=0,pixels=0;
    integer attempts=0,target_bytes=512,at=0;
    reg busy=0,wait_low=0,was_begin=0,failed_seen=0;
    reg [7:0] sector[0:511];
    reg [7:0] expected[0:921653];
    localparam ATLAS_LBA=2337;
    initial begin
        image_fd=$fopen("build/media/game-audio-v4.img","rb");
        if(!image_fd)$fatal(1,"missing V4 image");
        rc=$fseek(image_fd,ATLAS_LBA*512,0);rc=$fread(expected,image_fd);
        if(rc!=921654||expected[0]!=8'h42||expected[1]!=8'h4d)
            $fatal(1,"wrong atlas fixture offset/size");
    end
    always @(posedge clk)begin
        valid<=0;sector_end<=0;was_begin<=begin_asset;
        if(failed)failed_seen<=1;
        if(begin_asset&&!was_begin)begin
            begins=begins+1;pixels=0;
            $display("ATLAS begin attempt=%0d at %0t",attempts,$time);
        end
        if(commit)begin
            commits=commits+1;
            $display("ATLAS commit attempt=%0d pixels=%0d at %0t",attempts,pixels,$time);
        end
        if(we)pixels=pixels+1;
        if(!rst)begin
            if(wait_low)begin if(!req)wait_low<=0;end
            else if(!busy&&req)begin
                if(addr==ATLAS_LBA&&!loaded)begin
                    attempts=attempts+1;
                    if(attempts>3)$fatal(1,"atlas retry failed status=%h",status);
                    $display("ATLAS attempt=%0d at %0t",attempts,$time);
                end
                rc=$fseek(image_fd,addr*512,0);rc=$fread(sector,image_fd);
                if(rc!=512)$fatal(1,"short sector");
                // The top-row signature lies in the last source row.
                if(!loaded&&attempts==2&&addr==ATLAS_LBA+1797)sector[54]=sector[54]^8'h01;
                target_bytes=attempts==1?128:512;
                busy<=1;count<=0;
            end else if(busy)begin
                valid<=1;data<=sector[count];
                if(count==target_bytes-1)begin
                    busy<=0;wait_low<=1;sector_end<=1;sectors=sectors+1;
                end else count<=count+1;
            end
        end
    end
    // Compare both texture ports against independently indexed atlas pixels.
    function [23:0] source_color(input integer texel);
        integer tile,x,y,offset;
        begin
            tile=texel/256;x=(tile%8)*16+texel%16;
            y=(tile/8)*16+(texel%256)/16;
            offset=54+(479-y)*1920+x*3;
            source_color={expected[offset+2],expected[offset+1],expected[offset]};
        end
    endfunction
    reg [23:0] colors[0:15];
    reg [23:0] bg_color,sprite_color;
    integer k;
    initial begin
        colors[0]=`GAME_PAL_0;colors[1]=`GAME_PAL_1;colors[2]=`GAME_PAL_2;colors[3]=`GAME_PAL_3;
        colors[4]=`GAME_PAL_4;colors[5]=`GAME_PAL_5;colors[6]=`GAME_PAL_6;colors[7]=`GAME_PAL_7;
        colors[8]=`GAME_PAL_8;colors[9]=`GAME_PAL_9;colors[10]=`GAME_PAL_10;colors[11]=`GAME_PAL_11;
        colors[12]=`GAME_PAL_12;colors[13]=`GAME_PAL_13;colors[14]=`GAME_PAL_14;colors[15]=`GAME_PAL_15;
        repeat(6)@(negedge clk);rst=0;
        wait(loaded);repeat(6)@(negedge clk);
        if(attempts!=3||begins!=2||commits!=2||!failed_seen||pixels!=307200)
            $fatal(1,"retry/publication attempts=%0d begin=%0d commit=%0d pixels=%0d",attempts,begins,commits,pixels);
        for(k=0;k<85*256;k=k+1)begin
            ba=k;sa=85*256-1-k;
            @(posedge pclk);#1;
            bg_color=colors[bi];sprite_color=colors[si];
            if(bg_color!==source_color(k)||sprite_color!==source_color(85*256-1-k))
                $fatal(1,"atlas texel mismatch at %0d",k);
            @(negedge pclk);
        end
        at=sectors;repeat(1000)@(negedge clk);
        if(SHARED)begin
            wait(gallery_write);repeat(10)@(negedge clk);
            if(image_count!=6||begins!=2||commits!=2||we||failed)
                $fatal(1,"shared decoder did not hand off cleanly to six-image gallery");
        end else if(req||sectors!=at||failed)$fatal(1,"loader did not stop after publication");
        $display("PASS atlas loader: V4 bytes, truncated-sector retry, signature retry, all 21760 texels independent of SDRAM");
        if(SHARED)$display("PASS shared atlas decoder: native retry/signature first, six-image catalog next, game textures remain locked");
        $finish;
    end
    initial begin #600000000;$fatal(1,"native atlas timeout");end
endmodule

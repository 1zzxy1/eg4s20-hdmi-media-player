`include "game_assets.vh"
// Two mirrored 4-bpp dual-clock memories supply background and sprite pixels.
// Input is the real 640x480 bottom-up BMP pixel stream; publish only on DMA commit.
module game_texture_cache(
    input wire write_clk,write_rst,asset_begin,asset_we,
    input wire [23:0] asset_rgb,input wire asset_commit,
    input wire read_clk,read_rst,input wire [14:0] bg_addr,sprite_addr,
    output reg [3:0] bg_index,sprite_index,output wire loaded
);
    // Eight tiles fit one 2048x4 BRAM. Eleven banks cover all 85 tiles,
    // avoiding the unused tail of the previous three 8192x4 banks.
    wire [3:0] bg_q[0:10],sprite_q[0:10];
    reg [3:0] bg_bank_q,sprite_bank_q;
    reg bg_valid_q,sprite_valid_q;
    reg [9:0] sx;reg [8:0] sy;reg receiving,complete,published;
    reg [15:0] signature;
    reg [23:0] expected_sig;
    reg [1:0] ready_sync;
    reg [3:0] index;
    wire [8:0] top_y=9'd479-sy;
    wire [14:0] wa={top_y[7:4],sx[6:4],top_y[3:0],sx[3:0]};
    always @* begin
        case(sx[3:0])
        0:expected_sig=`GAME_SIG_0;1:expected_sig=`GAME_SIG_1;2:expected_sig=`GAME_SIG_2;3:expected_sig=`GAME_SIG_3;
        4:expected_sig=`GAME_SIG_4;5:expected_sig=`GAME_SIG_5;6:expected_sig=`GAME_SIG_6;7:expected_sig=`GAME_SIG_7;
        8:expected_sig=`GAME_SIG_8;9:expected_sig=`GAME_SIG_9;10:expected_sig=`GAME_SIG_10;11:expected_sig=`GAME_SIG_11;
        12:expected_sig=`GAME_SIG_12;13:expected_sig=`GAME_SIG_13;14:expected_sig=`GAME_SIG_14;default:expected_sig=`GAME_SIG_15;
        endcase
        case(asset_rgb)
        `GAME_PAL_0:index=0;`GAME_PAL_1:index=1;`GAME_PAL_2:index=2;`GAME_PAL_3:index=3;
        `GAME_PAL_4:index=4;`GAME_PAL_5:index=5;`GAME_PAL_6:index=6;`GAME_PAL_7:index=7;
        `GAME_PAL_8:index=8;`GAME_PAL_9:index=9;`GAME_PAL_10:index=10;`GAME_PAL_11:index=11;
        `GAME_PAL_12:index=12;`GAME_PAL_13:index=13;`GAME_PAL_14:index=14;
        default:index=15;
        endcase
    end
    wire tex_write=asset_we&&receiving&&sx<128&&top_y<256&&wa[14:8]<7'd85;
    genvar bank;
    generate for(bank=0;bank<11;bank=bank+1) begin: tiles
        reg [3:0] bg_mem[0:2047],sprite_mem[0:2047];
        reg [3:0] bg_read,sprite_read;
        // RAM ports have no reset so TD can infer embedded memory.
        always @(posedge write_clk) begin
            if(tex_write&&wa[14:11]==bank) begin
                bg_mem[wa[10:0]]<=index;
                sprite_mem[wa[10:0]]<=index;
            end
        end
        always @(posedge read_clk) begin
            bg_read<=bg_mem[bg_addr[10:0]];
            sprite_read<=sprite_mem[sprite_addr[10:0]];
        end
        assign bg_q[bank]=bg_read;
        assign sprite_q[bank]=sprite_read;
    end endgenerate
    always @(posedge read_clk) begin
        bg_bank_q<=bg_addr[14:11];
        sprite_bank_q<=sprite_addr[14:11];
        bg_valid_q<=bg_addr[14:8]<7'd85;
        sprite_valid_q<=sprite_addr[14:8]<7'd85;
    end
    always @* begin
        bg_index=0;sprite_index=0;
        if(bg_valid_q) bg_index=bg_q[bg_bank_q];
        if(sprite_valid_q) sprite_index=sprite_q[sprite_bank_q];
    end
    always @(posedge write_clk or posedge write_rst) begin
        if(write_rst) begin sx<=0;sy<=0;receiving<=0;complete<=0;published<=0;signature<=0;end
        else begin
            if(asset_begin&&!published) begin sx<=0;sy<=0;receiving<=1;complete<=0;signature<=0;end
            else if(asset_we&&receiving) begin
                if(top_y==0&&sx>=128&&sx<144) signature[sx[3:0]]<=asset_rgb==expected_sig;
                if(sx==639) begin sx<=0;if(sy==479) begin receiving<=0;complete<=1;end else sy<=sy+1'b1;end
                else sx<=sx+1'b1;
            end
            if(asset_commit&&complete&&(&signature)) published<=1;
        end
    end
    always @(posedge read_clk or posedge read_rst)
        if(read_rst) ready_sync<=0;else ready_sync<={ready_sync[0],published};
    assign loaded=ready_sync[1];
endmodule

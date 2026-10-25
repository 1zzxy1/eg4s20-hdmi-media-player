// Resettable level from ROM into one true dual-port tile RAM. The world port
// reads/writes cells; the independent video port keeps one-cycle reads.
module game_level_map(
    input wire clk,rst,reload,output reg ready,
    input wire [11:0] world_addr,output reg [7:0] world_data,
    input wire world_we,input wire [7:0] world_wdata,
    input wire [11:0] video_addr,output reg [7:0] video_data
);
    reg [3:0] level_rom[0:4095];
    initial begin
        `include "game_level_init.vh"
    end
    reg [3:0] map_mem[0:4095];
    reg [12:0] load_step;
    reg [3:0] rom_data;
    wire loading=!ready&&load_step!=0;
    wire [11:0] write_addr=ready?world_addr:load_step[11:0]-12'd1;
    wire [3:0] write_data=ready?world_wdata[3:0]:rom_data;
    wire write_en=!rst&&!reload&&
                  (loading||(ready&&world_we&&world_wdata<=8'd14));
    // During reload the world is stopped, so its port can initialize the RAM.
    wire [11:0] port_a_addr=write_en?write_addr:world_addr;
    always @(posedge clk) begin
        rom_data<=level_rom[load_step[11:0]];
        if(write_en) map_mem[port_a_addr]<=write_data;
        world_data<=map_mem[port_a_addr];
        video_data<=map_mem[video_addr];
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin ready<=0;load_step<=0;end
        else if(reload) begin ready<=0;load_step<=0;end
        else if(!ready) begin
            if(load_step==4096) ready<=1;
            else load_step<=load_step+1'b1;
        end
    end
endmodule

// Stability build: load the native atlas directly into texture RAM once.
// Publication depends on the complete BMP and its signature, not SDRAM DMA.
module game_asset_loader #(
    parameter RETRY_CYCLES=2_500_000,
    // V4 FAT16 layout: partition + boot + two FATs + root directory.
    parameter [31:0] ATLAS_LBA=32'd2337
)(
    input wire clk,rst,initialized,assets_ready,
    output wire asset_begin,asset_we,asset_commit,
    output wire [23:0] asset_rgb,
    output wire req,output wire [31:0] addr,
    input wire [7:0] data,input wire valid,sector_end,
    output wire [3:0] status,output reg failed
);
    (* ASYNC_REG="TRUE" *) reg [1:0] ready_sync;
    reg started,start;
    reg [$clog2(RETRY_CYCLES+1)-1:0] retry_count;
    wire idle,write_req,done;
    wire [3:0] error_code;
    assign asset_begin=write_req;
    assign asset_commit=done;
    always @(posedge clk or posedge rst)
        if(rst)begin
            ready_sync<=0;started<=0;start<=0;retry_count<=0;failed<=0;
        end else begin
            ready_sync<={ready_sync[0],assets_ready};start<=0;
            if(!initialized)begin started<=0;retry_count<=0;failed<=0;end
            else if(ready_sync[1])begin failed<=0;retry_count<=0;end
            else if(idle&&!start)begin
                if(!started)begin start<=1;started<=1;end
                else if(retry_count==RETRY_CYCLES-1)begin
                    start<=1;retry_count<=0;failed<=1;
                end else retry_count<=retry_count+1'b1;
            end else retry_count<=0;
        end
    bmp_sector_player #(.ENABLE_SCALE(0)) decoder(
        .clk(clk),.rst(rst),.sd_init_done(initialized),
        .scan_start(1'b0),.scan_start_sector(ATLAS_LBA),.scan_max_sector(ATLAS_LBA),
        .scan_target_count(7'd1),.scan_done(),.scan_found_valid(),
        .scan_found_sector(),.scan_found_total(),
        .load_start(start),.load_sector(ATLAS_LBA),.ready(idle),.state_code(status),
        .write_req(write_req),.write_req_ack(write_req),.pixel_ready(1'b1),
        .bmp_data_wr_en(asset_we),.bmp_data(asset_rgb),.load_done(done),.error_code(error_code),
        .sd_sec_read(req),.sd_sec_read_addr(addr),.sd_sec_read_data(data),
        .sd_sec_read_data_valid(valid),.sd_sec_read_end(sector_end));
endmodule

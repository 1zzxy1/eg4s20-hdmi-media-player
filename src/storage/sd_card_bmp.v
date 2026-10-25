module sd_card_bmp #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter ENABLE_SCALE = 1,
    parameter [31:0] SCAN_START_SECTOR = 32'd0,
    parameter [31:0] SCAN_MAX_SECTOR = 32'd131071,
    parameter [6:0] SCAN_TARGET_COUNT = 7'd64
)(
    input clk, rst, key_next, key_auto,
    output [3:0] state_code,
    input [15:0] bmp_width, bmp_height,
    output display_valid,
    input write_finish_toggle, display_ack_toggle,
    output display_commit_toggle,
    output [1:0] write_buf_idx, disp_buf_idx,
    output write_req,
    input write_req_ack, write_ready,
    output write_en,
    output [31:0] write_data,
    output SD_nCS, SD_DCLK, SD_MOSI,
    input SD_MISO,
    output [2:0] cache_count,
    output [6:0] image_index, image_count,
    output wire asset_begin,asset_we,asset_commit,
    output wire [23:0] asset_rgb,
    input wire key_previous,auto_enable,
    input wire audio_req,input wire [31:0] audio_addr,
    output wire [7:0] audio_data,output wire audio_valid,audio_end,audio_initialized
);
    wire key_previous_i=(key_previous===1'b0)?1'b0:1'b1;
    wire auto_enable_i=(auto_enable===1'b0)?1'b0:1'b1;
    wire key_next_press, key_auto_press,key_previous_press;
    wire sd_sec_read, sd_sec_read_data_valid, sd_sec_read_end, sd_init_done;
    wire [31:0] sd_sec_read_addr;
    wire [7:0] sd_sec_read_data;
    wire bmp_ready, load_done;
    wire [3:0] load_error;
    wire [23:0] bmp_data;
    wire scan_done, scan_found_valid;
    wire [31:0] scan_found_sector;
    wire [6:0] scan_found_total;
    reg [31:0] image_sectors [0:63];
    reg [6:0] found_count;
    reg scan_kicked, scan_start_pulse, bmp_ready_prev;
    reg auto_play_en;
    reg [31:0] auto_count;
    (* ASYNC_REG="TRUE" *) reg [2:0] finish_sync, display_ack_sync;
    wire load_start;
    wire [5:0] load_image;
    wire catalog_ready = scan_done && scan_kicked;
    wire finish_pulse = finish_sync[2]^finish_sync[1];
    wire source_error = bmp_ready && !bmp_ready_prev && load_error!=0;
    wire auto_tick = auto_play_en && display_valid && auto_count==CLK_FREQ_HZ-1;
    wire cache_reset = rst || !sd_init_done;
    assign image_count=found_count;
    assign write_data={bmp_data,8'd0};
    // Tap the first decoded image; game texture cache checks its identity and
    // locks after successful publication. Subsequent gallery loads cannot
    // overwrite textures while the renderer is consuming them.
    reg write_req_prev;
    always @(posedge clk or posedge rst)
        if(rst) write_req_prev<=0;else write_req_prev<=write_req;
    assign asset_begin=write_req && !write_req_prev && load_image==0;
    assign asset_we=write_en && load_image==0;
    assign asset_rgb=bmp_data;
    // Index 1 is published only after source + memory completion and display
    // acceptance, so a failed/partial frame cannot publish game textures.
    assign asset_commit=image_index==1;

    key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.DEBOUNCE_MS(20))
        u_key_next(clk,rst,key_next,key_next_press);
    key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.DEBOUNCE_MS(20))
        u_key_auto(clk,rst,key_auto,key_auto_press);
    key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.DEBOUNCE_MS(20))
        u_key_previous(clk,rst,key_previous_i,key_previous_press);

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            finish_sync<=0;display_ack_sync<=0;scan_kicked<=0;scan_start_pulse<=0;
            found_count<=0;bmp_ready_prev<=1;auto_play_en<=0;auto_count<=0;
        end else begin
            finish_sync<={finish_sync[1:0],write_finish_toggle};
            display_ack_sync<={display_ack_sync[1:0],display_ack_toggle};
            bmp_ready_prev<=bmp_ready;scan_start_pulse<=0;
            if(!sd_init_done) begin
                scan_kicked<=0;found_count<=0;auto_play_en<=0;auto_count<=0;
            end else begin
                if(!scan_kicked && bmp_ready) begin scan_start_pulse<=1;scan_kicked<=1;end
                if(scan_found_valid && found_count<64) begin
                    image_sectors[found_count[5:0]]<=scan_found_sector;
                    found_count<=found_count+1'b1;
                end
                if(!auto_enable_i) begin auto_play_en<=0;auto_count<=0;end
                else if(key_auto_press && catalog_ready && found_count>1) begin
                    auto_play_en<=~auto_play_en;auto_count<=0;
                end else if(auto_play_en && display_valid && found_count>1) begin
                    if(auto_tick || key_next_press || display_ack_sync[2]!=display_commit_toggle)
                        auto_count<=0;
                    else auto_count<=auto_count+1'b1;
                end else auto_count<=0;
            end
        end
    end

    image_cache_controller u_cache(
        .clk(clk),.rst(cache_reset),.catalog_ready(catalog_ready),.catalog_count(found_count),
        .next_request(key_next_press || auto_tick),.loader_ready(bmp_ready),
        .source_done(load_done),.source_error(source_error),
        .write_started(write_req && write_req_ack),.memory_done(finish_pulse),
        .load_start(load_start),.load_image(load_image),.load_slot(write_buf_idx),
        .display_ack_toggle(display_ack_sync[2]),.display_commit_toggle(display_commit_toggle),
        .pending_slot(disp_buf_idx),.display_valid(display_valid),
        .image_index(image_index),.cache_count(cache_count),.previous_request(key_previous_press));

    bmp_sector_player #(.ENABLE_SCALE(ENABLE_SCALE)) bmp_read_m0(
        .clk(clk),.rst(rst),.sd_init_done(sd_init_done),.ready(bmp_ready),.state_code(state_code),
        .scan_start(scan_start_pulse),.scan_start_sector(SCAN_START_SECTOR),
        .scan_max_sector(SCAN_MAX_SECTOR),.scan_target_count(SCAN_TARGET_COUNT),
        .scan_done(scan_done),.scan_found_valid(scan_found_valid),
        .scan_found_sector(scan_found_sector),.scan_found_total(scan_found_total),
        .load_start(load_start),.load_sector(image_sectors[load_image]),
        .load_done(load_done),.error_code(load_error),.pixel_ready(write_ready),
        .write_req(write_req),.write_req_ack(write_req_ack),
        .sd_sec_read(sd_sec_read),.sd_sec_read_addr(sd_sec_read_addr),
        .sd_sec_read_data(sd_sec_read_data),.sd_sec_read_data_valid(sd_sec_read_data_valid),
        .sd_sec_read_end(sd_sec_read_end),.bmp_data_wr_en(write_en),.bmp_data(bmp_data));

    wire card_req,card_valid,card_end;
    wire [31:0] card_addr;
    wire [7:0] card_data;
    assign audio_initialized=sd_init_done;
    sd_sector_arbiter u_sector_share(.clk(clk),.rst(rst),.initialized(sd_init_done),
        .bmp_req(sd_sec_read),.bmp_addr(sd_sec_read_addr),.audio_req(audio_req),.audio_addr(audio_addr),
        .sd_req(card_req),.sd_addr(card_addr),.sd_data(card_data),.sd_valid(card_valid),.sd_end(card_end),
        .bmp_data(sd_sec_read_data),.bmp_valid(sd_sec_read_data_valid),.bmp_end(sd_sec_read_end),
        .audio_data(audio_data),.audio_valid(audio_valid),.audio_end(audio_end));
    sd_card_top sd_card_top_m0(
        .clk(clk),.rst(rst),.SD_nCS(SD_nCS),.SD_DCLK(SD_DCLK),.SD_MOSI(SD_MOSI),.SD_MISO(SD_MISO),
        .sd_init_done(sd_init_done),.sd_sec_read(card_req),.sd_sec_read_addr(card_addr),
        .sd_sec_read_data(card_data),.sd_sec_read_data_valid(card_valid),
        .sd_sec_read_end(card_end),.sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),
        .sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
endmodule

module key_press_debounce #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input wire clk, rst, button_in,
    output reg press_pulse
);
    localparam integer DEBOUNCE_CYCLES=(CLK_FREQ_HZ/1000)*DEBOUNCE_MS;
    reg button_sync0,button_sync1,button_stable;
    reg [31:0] count;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            button_sync0<=1;button_sync1<=1;button_stable<=1;count<=0;press_pulse<=0;
        end else begin
            button_sync0<=button_in;button_sync1<=button_sync0;press_pulse<=0;
            if(button_sync1==button_stable) count<=0;
            else if(count>=DEBOUNCE_CYCLES-1) begin
                if(button_stable && !button_sync1) press_pulse<=1;
                button_stable<=button_sync1;count<=0;
            end else count<=count+1'b1;
        end
    end
endmodule

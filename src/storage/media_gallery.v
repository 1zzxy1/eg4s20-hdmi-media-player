// Load game textures first, then reuse the BMP decoder for the lobby gallery.
// Gallery faults never gate the game raster or texture RAM publication.
module media_gallery(
    input wire sd_clk,mem_clk,mem_clk_shift,pix_clk,rst_sd,rst_mem,rst_pix,
    input wire initialized,assets_ready,enabled,
    input wire next_key_n,previous_key_n,auto_key_n,
    input wire hs,vs,de,frame_request,
    input wire [9:0] alignment_offset,input wire [1:0] transition_mode,
    output wire request,output wire [31:0] sector,
    input wire [7:0] data,input wire valid,sector_end,
    output wire hs_o,vs_o,de_o,output wire [23:0] rgb,
    output wire image_ready,output wire [4:0] fade_gain,
    output wire [1:0] effect_mode,
    output wire [2:0] cache_count,output wire [6:0] image_index,image_count,
    output wire asset_begin,asset_we,asset_commit,asset_failed,
    output wire [23:0] asset_rgb
);
    (* ASYNC_REG="TRUE" *) reg [1:0] ready_sync,enable_sync,write_ack_sync,read_ack_sync;
    (* ASYNC_REG="TRUE" *) reg [16:0] status0,status1;
    wire [2:0] cached;
    wire [6:0] picture,total;
    assign {cache_count,image_index,image_count}=status1;
    wire write_req,write_ack,write_en,write_ready,write_finish,read_ack,read_en;
    wire [31:0] write_data,read_data;
    wire [1:0] write_bank,pending_bank,active_bank;
    wire commit_toggle,ack_toggle,commit_hold;
    reg write_toggle,read_pending,frame_d;
    always @(posedge sd_clk or posedge rst_sd)
        if(rst_sd)begin ready_sync<=0;enable_sync<=0;write_ack_sync<=0;end
        else begin
            ready_sync<={ready_sync[0],assets_ready};
            enable_sync<={enable_sync[0],enabled};
            write_ack_sync<={write_ack_sync[0],write_ack};
        end
    always @(posedge mem_clk or posedge rst_mem)
        if(rst_mem)write_toggle<=0;else if(write_finish)write_toggle<=!write_toggle;
    always @(posedge pix_clk or posedge rst_pix)
        if(rst_pix)begin
            read_ack_sync<=0;read_pending<=0;frame_d<=0;status0<=0;status1<=0;
        end else begin
            read_ack_sync<={read_ack_sync[0],read_ack};
            frame_d<=frame_request;
            if(frame_request&&!frame_d)read_pending<=1;
            else if(read_ack_sync[1])read_pending<=0;
            status0<={cached,picture,total};status1<=status0;
        end
    sd_card_bmp #(.CLK_FREQ_HZ(50_000_000),.EXTERNAL_CARD(1),.BOOT_ATLAS(1),
        .SCAN_START_SECTOR(32'd2048),.SCAN_MAX_SECTOR(32'd131071)) loader(
        .clk(sd_clk),.rst(rst_sd),.key_next(next_key_n),.key_auto(auto_key_n),
        .key_previous(previous_key_n),.auto_enable(enable_sync[1]),
        .bmp_width(16'd640),.bmp_height(16'd480),
        .write_finish_toggle(write_toggle),.display_ack_toggle(ack_toggle),
        .display_commit_toggle(commit_toggle),.write_buf_idx(write_bank),.disp_buf_idx(pending_bank),
        .write_req(write_req),.write_req_ack(write_ack_sync[1]),.write_ready(write_ready),
        .write_en(write_en),.write_data(write_data),
        .cache_count(cached),.image_index(picture),.image_count(total),
        .SD_MISO(1'b1),.audio_req(1'b0),.audio_addr(32'd0),
        .asset_begin(asset_begin),.asset_we(asset_we),.asset_commit(asset_commit),.asset_rgb(asset_rgb),
        .native_assets_ready(assets_ready),.native_failed(asset_failed),
        .card_initialized(initialized),.card_read_data(data),
        .card_read_valid(valid),.card_read_end(sector_end),
        .card_read_req(request),.card_read_addr(sector));
    transition_control transition(.clk(pix_clk),.rst(rst_pix),
        .frame_tick(frame_request&&!frame_d),.image_valid(image_ready),
        .commit_toggle(commit_toggle),.ack_toggle(ack_toggle),.commit_hold(commit_hold),
        .gain(fade_gain),.requested_mode(enabled?transition_mode:2'd0),.effect_mode(effect_mode));
    frame_commit_bridge commit(.clk(pix_clk),.rst(rst_pix),.commit_toggle(commit_toggle),
        .pending_bank(pending_bank),.frame_request(frame_request),.commit_hold(commit_hold),
        .active_bank(active_bank),.active_valid(image_ready),.ack_toggle(ack_toggle),
        .reader_ack(read_ack_sync[1]));
    wire init_done,refreshing,busy,app_rd,app_wr,mem_valid;
    wire [20:0] rd_addr,wr_addr;
    wire [31:0] mem_data,wr_data;
    wire [3:0] wr_mask;
    frame_read_write #(.BURST_SIZE(128),.ALIGNMENT(1)) frame_memory(
        .rst(rst_mem),.mem_clk(mem_clk),.Sdr_init_done(init_done),
        .Sdr_init_ref_vld(refreshing),.Sdr_busy(busy),.App_rd_en(app_rd),.App_rd_addr(rd_addr),
        .Sdr_rd_en(mem_valid),.Sdr_rd_dout(mem_data),
        .read_clk(pix_clk),.read_req(read_pending),.read_req_ack(read_ack),
        .read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd614400),.read_addr_3(21'd921600),
        .read_addr_index(active_bank),.read_len(21'd307200),.read_en(read_en),.read_data(read_data),
        .App_wr_en(app_wr),.App_wr_addr(wr_addr),.App_wr_din(wr_data),.App_wr_dm(wr_mask),
        .write_clk(sd_clk),.write_req(write_req),.write_req_ack(write_ack),.write_finish(write_finish),
        .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd614400),.write_addr_3(21'd921600),
        .write_addr_index(write_bank),.write_len(21'd307200),.write_en(write_en),
        .write_data(write_data),.write_ready(write_ready),.alignment_offset(alignment_offset));
    sdram u_sdram(.Clk(mem_clk),.Clk_sft(mem_clk_shift),.Rst(rst_mem),
        .Sdr_init_done(init_done),.Sdr_init_ref_vld(refreshing),.Sdr_busy(busy),
        .App_wr_en(app_wr),.App_wr_addr(wr_addr),.App_wr_dm(wr_mask),.App_wr_din(wr_data),
        .App_rd_en(app_rd),.App_rd_addr(rd_addr),.Sdr_rd_en(mem_valid),.Sdr_rd_dout(mem_data));
    video_delay delay(.video_clk(pix_clk),.rst(rst_pix),.read_en(read_en),
        .read_data(read_data[31:8]),.hs(hs),.vs(vs),.de(de),
        .hs_r(hs_o),.vs_r(vs_o),.de_r(de_o),.vout_data(rgb));
endmodule

// New implementation: sector-cache backed, backpressured nearest-neighbour loader.
// BMP bottom-up row order is retained; frame DMA performs the single vertical flip.
module bmp_sector_player #(
    parameter ENABLE_SCALE=1, OUT_WIDTH=640, OUT_HEIGHT=480,
    parameter TIMEOUT_CYCLES=100_000_000
)(
    input wire clk, rst, sd_init_done,
    input wire scan_start, input wire [31:0] scan_start_sector, scan_max_sector,
    input wire [6:0] scan_target_count,
    output reg scan_done, scan_found_valid,
    output reg [31:0] scan_found_sector, output reg [6:0] scan_found_total,
    input wire load_start, input wire [31:0] load_sector,
    output wire ready, output wire [3:0] state_code,
    output reg write_req, input wire write_req_ack, pixel_ready,
    output wire bmp_data_wr_en, output reg [23:0] bmp_data,
    output reg load_done, output reg [3:0] error_code,
    output reg sd_sec_read, output reg [31:0] sd_sec_read_addr,
    input wire [7:0] sd_sec_read_data, input wire sd_sec_read_data_valid, sd_sec_read_end
);
    localparam IDLE=0, FETCH=1, HEADER=2, GEOMETRY=3, VALIDATE=4, ACK=5,
        BYTE=6, BYTE_WAIT=7, BYTE_USE=8, PIXEL=9, XSTEP=10, YSTEP=11;
    reg [3:0] state, after_fetch;
    reg scanning, cache_valid;
    reg [31:0] base_sector, cache_sector, scan_limit;
    reg [6:0] target;
    reg [127:0] header_tag;
    reg [9:0] count;
    reg [7:0] cache [0:511];
    reg [7:0] byte_q;
    reg [15:0] magic, planes, bpp;
    reg [31:0] length, offset, dib, width, height, compression;
    reg [31:0] row_stride, required_size, row_base, byte_ptr;
    reg [10:0] dx, dy;
    reg [12:0] x_acc, y_acc;
    reg [1:0] channel;
    reg [$clog2(TIMEOUT_CYCLES+1)-1:0] watchdog;
    wire [31:0] wanted_sector = base_sector + (byte_ptr >> 9);
    wire [31:0] next_scan = base_sector + ((length + 511) >> 9);
    wire [23:0] geometry_bytes=row_stride[12:0]*height[10:0];
    wire good = magic==16'h4d42 && dib>=40 && dib<=124 && planes==1 && bpp==24 &&
        compression==0 && width>=1 && width<=1920 && height>=1 && height<=1440 &&
        offset>=54 && offset<=4096 && offset>=14+dib && length>=required_size &&
        length<=required_size+4096 && (ENABLE_SCALE || (width==OUT_WIDTH && height==OUT_HEIGHT));
    assign ready = state==IDLE;
    assign state_code = error_code!=0 ? 4'he : state;
    assign bmp_data_wr_en = state==PIXEL && pixel_ready;
    // Synchronous RAM read: BYTE issues address, BYTE_WAIT absorbs RAM latency.
    always @(posedge clk) begin
        byte_q <= cache[byte_ptr[8:0]];
        if(state==FETCH && sd_sec_read_data_valid && count<512)
            cache[count[8:0]] <= sd_sec_read_data;
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=IDLE; after_fetch<=HEADER; scanning<=0; cache_valid<=0;
            base_sector<=0; cache_sector<=0; scan_limit<=0; target<=0; count<=0;header_tag<=0;
            magic<=0; planes<=0; bpp<=0; length<=0; offset<=0; dib<=0;
            width<=0; height<=0; compression<=0; row_stride<=0; required_size<=0;
            row_base<=0; byte_ptr<=0; dx<=0; dy<=0; x_acc<=0; y_acc<=0; channel<=0;
            watchdog<=0; scan_done<=0; scan_found_valid<=0; scan_found_sector<=0;
            scan_found_total<=0; write_req<=0; bmp_data<=0; load_done<=0;
            error_code<=0; sd_sec_read<=0; sd_sec_read_addr<=0;
        end else begin
            scan_found_valid<=0; load_done<=0;
            if(state==IDLE || sd_sec_read_data_valid || bmp_data_wr_en || write_req_ack)
                watchdog<=0;
            else watchdog<=watchdog+1'b1;
            if(!sd_init_done || (state!=IDLE && watchdog==TIMEOUT_CYCLES-1)) begin
                state<=IDLE; sd_sec_read<=0; write_req<=0; cache_valid<=0;
                error_code<=!sd_init_done ? 4'd4 : 4'd3;
                if(scanning) scan_done<=1;
            end else case(state)
                IDLE: begin
                    sd_sec_read<=0; write_req<=0;
                    if(scan_start || load_start) begin
                        error_code<=0; cache_valid<=0; count<=0;
                        scanning<=scan_start; state<=FETCH; after_fetch<=HEADER;
                        sd_sec_read<=1;
                        base_sector<=scan_start ? scan_start_sector : load_sector;
                        sd_sec_read_addr<=scan_start ? scan_start_sector : load_sector;
                        if(scan_start) begin
                            scan_done<=0; scan_found_total<=0;
                            scan_limit<=scan_max_sector;
                            target<=(scan_target_count==0 || scan_target_count>64) ? 7'd64 : scan_target_count;
                        end
                    end
                end
                FETCH: begin
                    if(sd_sec_read_data_valid) begin
                        count<=count+1'b1;
                        if(after_fetch==HEADER && count<16)
                            header_tag<={header_tag[119:0],sd_sec_read_data};
                        if(after_fetch==HEADER) case(count)
                            0:magic[7:0]<=sd_sec_read_data; 1:magic[15:8]<=sd_sec_read_data;
                            2,3,4,5:length[(count-2)*8 +: 8]<=sd_sec_read_data;
                            10,11,12,13:offset[(count-10)*8 +: 8]<=sd_sec_read_data;
                            14,15,16,17:dib[(count-14)*8 +: 8]<=sd_sec_read_data;
                            18,19,20,21:width[(count-18)*8 +: 8]<=sd_sec_read_data;
                            22,23,24,25:height[(count-22)*8 +: 8]<=sd_sec_read_data;
                            26:planes[7:0]<=sd_sec_read_data;27:planes[15:8]<=sd_sec_read_data;
                            28:bpp[7:0]<=sd_sec_read_data;29:bpp[15:8]<=sd_sec_read_data;
                            30,31,32,33:compression[(count-30)*8 +: 8]<=sd_sec_read_data;
                        endcase
                    end
                    if(sd_sec_read_end) begin
                        sd_sec_read<=0;
                        if(count+(sd_sec_read_data_valid?1:0)!=512) begin
                            state<=IDLE; error_code<=2; if(scanning) scan_done<=1;
                        end else begin
                            cache_sector<=sd_sec_read_addr; cache_valid<=1;
                            state<=after_fetch;
                        end
                    end
                end
                HEADER: begin
                    row_stride<=ENABLE_SCALE ? (((width*3+3)>>2)<<2) : ((OUT_WIDTH*3+3)/4)*4;
                    state<=GEOMETRY;
                end
                GEOMETRY: begin
                    required_size<=offset+(ENABLE_SCALE ? {8'd0,geometry_bytes} : ((OUT_WIDTH*3+3)/4)*4*OUT_HEIGHT);
                    state<=VALIDATE;
                end
                VALIDATE: begin
                    if(scanning) begin
                        if(good && header_tag!="FPGA_BMP_END_V1!") begin
                            scan_found_valid<=1; scan_found_sector<=base_sector;
                            scan_found_total<=scan_found_total+1'b1;
                        end
                        if(header_tag=="FPGA_BMP_END_V1!" || (good && scan_found_total+1>=target) || base_sector>=scan_limit ||
                            (good && (next_scan>scan_limit || next_scan<base_sector))) begin
                            scan_done<=1; state<=IDLE;
                        end else begin
                            base_sector<=good ? next_scan : base_sector+1;
                            sd_sec_read_addr<=good ? next_scan : base_sector+1;
                            count<=0; sd_sec_read<=1; state<=FETCH;
                        end
                    end else if(!good) begin error_code<=1; state<=IDLE; end
                    else begin
                        write_req<=1; state<=ACK; dx<=0;dy<=0;x_acc<=0;y_acc<=0;
                        row_base<=offset; byte_ptr<=offset; channel<=0;
                    end
                end
                ACK: if(write_req_ack) begin write_req<=0;state<=BYTE;end
                BYTE: if(cache_valid && cache_sector==wanted_sector) state<=BYTE_WAIT;
                    else begin
                        after_fetch<=BYTE; count<=0; sd_sec_read_addr<=wanted_sector;
                        sd_sec_read<=1;state<=FETCH;
                    end
                BYTE_WAIT: state<=BYTE_USE;
                BYTE_USE: begin
                    case(channel)
                        0:bmp_data[7:0]<=byte_q;
                        1:bmp_data[15:8]<=byte_q;
                        2:bmp_data[23:16]<=byte_q;
                    endcase
                    if(channel==2) begin channel<=0; state<=PIXEL; end
                    else begin channel<=channel+1'b1;byte_ptr<=byte_ptr+1;state<=BYTE;end
                end
                PIXEL: if(pixel_ready) begin
                    // byte_ptr points at R; rewind to B before moving the source X.
                    byte_ptr<=byte_ptr-2;
                    if(dx==OUT_WIDTH-1) begin
                        dx<=0;x_acc<=0;y_acc<=ENABLE_SCALE ? y_acc+height[12:0] : 13'd0;state<=YSTEP;
                    end else if(ENABLE_SCALE) begin dx<=dx+1'b1;x_acc<=x_acc+width[12:0];state<=XSTEP;end
                    else begin dx<=dx+1'b1;byte_ptr<=byte_ptr+1;state<=BYTE;end
                end
                XSTEP: if(x_acc>=OUT_WIDTH) begin x_acc<=x_acc-OUT_WIDTH;byte_ptr<=byte_ptr+3;end
                    else state<=BYTE;
                YSTEP: if(dy==OUT_HEIGHT-1) begin state<=IDLE;load_done<=1;end
                    else if(!ENABLE_SCALE) begin
                        dy<=dy+1'b1;row_base<=row_base+row_stride;byte_ptr<=row_base+row_stride;state<=BYTE;
                    end
                    else if(y_acc>=OUT_HEIGHT) begin y_acc<=y_acc-OUT_HEIGHT;row_base<=row_base+row_stride;end
                    else begin dy<=dy+1'b1;byte_ptr<=row_base;state<=BYTE;end
                default:begin state<=IDLE;error_code<=5;end
            endcase
        end
    end
endmodule

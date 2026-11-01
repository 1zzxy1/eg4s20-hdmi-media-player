// Physical slots are independent of the (up to 64-entry) image catalog.
// A slot becomes reusable only after the display consumer acknowledges a swap.
module image_cache_controller #(parameter SLOTS=4, BANK_BITS=2)(
    input wire clk, rst,
    input wire catalog_ready,
    input wire [6:0] catalog_count,
    input wire next_request,
    input wire loader_ready, source_done, source_error, write_started, memory_done,
    output reg load_start,
    output reg [5:0] load_image,
    output reg [BANK_BITS-1:0] load_slot,
    input wire view_zoom,
    output reg load_zoom,
    input wire display_ack_toggle,
    output reg display_commit_toggle,
    output reg [BANK_BITS-1:0] pending_slot,
    output reg display_valid,
    output wire [6:0] image_index,
    output reg [2:0] cache_count,
    input wire previous_request,
    output wire navigation_busy
);
    wire previous_request_i=(previous_request===1'b1);
    localparam FREE=2'd0, LOADING=2'd1, READY=2'd2, ACTIVE=2'd3;
    reg [1:0] slot_state [0:SLOTS-1];
    reg [5:0] slot_image [0:SLOTS-1];
    reg slot_zoom [0:SLOTS-1];
    wire zoom_i=(view_zoom===1'b1);
    reg zoom_prev;
    reg [63:0] bad_images;
    reg [6:0] bad_count;
    reg [5:0] prefetch_image, wanted_image, current_image;
    reg [BANK_BITS-1:0] current_slot;
    reg current_valid, awaiting_display, next_pending;
    reg loading, source_seen, memory_seen, write_epoch;
    reg backwards;
    reg wanted_resident,evict_found;
    reg [BANK_BITS-1:0] evict_slot;
    reg evict_outside;
    reg [BANK_BITS-1:0] evict_scan;
    reg evict_complete;
    reg evict_release;
    reg free_found, resident, ready_found;
    reg [BANK_BITS-1:0] free_slot, ready_slot;
    wire [6:0] usable_count = catalog_count - bad_count;
    assign image_index = current_valid ? {1'b0,current_image}+7'd1 : 7'd0;
    assign navigation_busy=next_pending || awaiting_display || zoom_i!=zoom_prev;
    // Retain one predecessor and SLOTS-2 successors. This bounded window
    // preloads both directions without repeatedly decoding distant pictures.
    function in_window;
        input [5:0] index;
        reg [6:0] ahead;
        begin
            ahead=index>=current_image?index-current_image:catalog_count-current_image+index;
            in_window=(ahead<=SLOTS-2) || ({1'b0,index}==(current_image==0?catalog_count-1'b1:{1'b0,current_image}-1'b1));
        end
    endfunction

    function [5:0] successor;
        input [5:0] index;
        begin successor = ({1'b0,index}+7'd1 >= catalog_count) ? 6'd0 : index+1'b1; end
    endfunction
    function [5:0] predecessor;
        input [5:0] index;
        begin predecessor=index==0 ? catalog_count-1'b1 : index-1'b1;end
    endfunction

    // One bounded sweep shares metadata comparisons and distance arithmetic.
    // Requests, completed DMA writes and display swaps invalidate the snapshot.
    // Six SD clocks are negligible next to a sector transfer.
    reg scan_valid;
    reg [2:0] scan_count;
    wire scan_reset=awaiting_display || next_request || previous_request_i ||
        load_start || evict_release || zoom_i!=zoom_prev ||
        (loading && (source_error || (source_seen && memory_seen)));
    wire [1:0] scanned_state=slot_state[evict_scan];
    wire [5:0] scanned_image=slot_image[evict_scan];
    wire scanned_zoom=slot_zoom[evict_scan];
    wire selected_in_window=in_window(evict_complete?prefetch_image:scanned_image);
    always @(posedge clk or posedge rst) begin
        if(rst)begin
            evict_scan<=0;evict_complete<=0;evict_found<=0;evict_slot<=0;evict_outside<=0;
            free_found<=0;free_slot<=0;resident<=0;wanted_resident<=0;
            ready_found<=0;ready_slot<=0;cache_count<=0;scan_count<=0;scan_valid<=0;
        end else begin
            scan_valid<=0;
            if(zoom_i!=zoom_prev)cache_count<=0;
            if(scan_reset || scan_valid)begin
                evict_scan<=0;evict_complete<=0;evict_found<=0;evict_outside<=0;
                free_found<=0;resident<=0;wanted_resident<=0;ready_found<=0;
            end else if(!evict_complete)begin
                if(evict_scan==0)scan_count<=0;
                if(scanned_state==FREE && !free_found)begin free_found<=1;free_slot<=evict_scan;end
                if(scanned_state!=FREE && scanned_zoom==zoom_i)begin
                    if(scanned_image==prefetch_image)resident<=1;
                    if(scanned_image==wanted_image)wanted_resident<=1;
                end
                if((scanned_state==READY || scanned_state==ACTIVE) && scanned_zoom==zoom_i)
                    scan_count<=evict_scan==0?3'd1:scan_count+1'b1;
                if(scanned_state==READY && scanned_zoom==zoom_i && !ready_found &&
                    (!current_valid || scanned_image==wanted_image))begin
                    ready_found<=1;ready_slot<=evict_scan;
                end
                if(scanned_state==READY && (!evict_found || (!evict_outside && !selected_in_window)))begin
                    evict_found<=1;evict_slot<=evict_scan;evict_outside<=!selected_in_window;
                end
                if(evict_scan==SLOTS-1)begin
                    evict_complete<=1;scan_valid<=1;
                    cache_count<=scan_count+(((scanned_state==READY || scanned_state==ACTIVE) && scanned_zoom==zoom_i)?3'd1:3'd0);
                end
                else evict_scan<=evict_scan+1'b1;
            end
        end
    end

    // Decode each metadata write once per physical slot. Variable-index writes
    // to the whole array otherwise infer a large read/modify/write mux network.
    genvar g;
    generate for(g=0;g<SLOTS;g=g+1)begin:metadata
        always @(posedge clk or posedge rst)begin
            if(rst)begin slot_state[g]<=FREE;slot_image[g]<=0;slot_zoom[g]<=0;end
            else begin
                if(slot_state[g]==READY && slot_zoom[g]!=zoom_i &&
                   !(awaiting_display && pending_slot==g))slot_state[g]<=FREE;
                if(loading && load_slot==g)begin
                    if(source_error)slot_state[g]<=FREE;
                    else if(source_seen && memory_seen)slot_state[g]<=READY;
                end
                if(awaiting_display && display_ack_toggle==display_commit_toggle)begin
                    if(current_valid && current_slot==g)
                        slot_state[g]<=slot_zoom[g]==zoom_i?READY:FREE;
                    if(pending_slot==g)slot_state[g]<=ACTIVE;
                end
                if(evict_release && evict_slot==g)slot_state[g]<=FREE;
                if(load_start && load_slot==g)begin
                    slot_state[g]<=LOADING;slot_image[g]<=load_image;slot_zoom[g]<=load_zoom;
                end
            end
        end
    end
    for(g=0;g<64;g=g+1)begin:bad_catalog
        always @(posedge clk or posedge rst)
            if(rst)bad_images[g]<=0;
            else if(loading && source_error && load_image==g)bad_images[g]<=1;
    end endgenerate

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            zoom_prev<=0;load_zoom<=0;
            bad_count<=0;prefetch_image<=0;wanted_image<=0;current_image<=0;evict_release<=0;
            current_slot<=0;current_valid<=0;awaiting_display<=0;next_pending<=0;
            loading<=0;source_seen<=0;memory_seen<=0;write_epoch<=0;
            load_start<=0;load_image<=0;load_slot<=0;pending_slot<=0;backwards<=0;
            display_commit_toggle<=0;display_valid<=0;
        end else begin
            load_start<=0;evict_release<=0;
            zoom_prev<=zoom_i;
            // Keep the displayed frame until its replacement is acknowledged.
            // In-flight decodes retain their own mode and can finish safely.
            if(zoom_i!=zoom_prev && current_valid)begin
                next_pending<=1;wanted_image<=current_image;prefetch_image<=current_image;
            end
            if((next_request||previous_request_i) && catalog_ready && usable_count>1) begin
                next_pending<=1;
                if(!awaiting_display && current_valid) begin
                    backwards<=previous_request_i;
                    wanted_image<=previous_request_i ? predecessor(current_image) : successor(current_image);
                end
            end

            // Ignore finishes from before this transfer's DMA reset/ack. A
            // partial aborted transfer cannot produce a full-frame finish;
            // the next write handshake resets its FIFO and remaining count.
            if(loading) begin
                if(write_started && !write_epoch) begin
                    write_epoch<=1;
                    memory_seen<=0;
                end else if(write_epoch && memory_done) memory_seen<=1;
                if(source_done) source_seen<=1;
                if(source_error) begin
                    // Flagged entries are never scheduled again.
                    bad_count<=bad_count+1'b1;
                    loading<=0;source_seen<=0;memory_seen<=0;write_epoch<=0;
                end else if(source_seen && memory_seen) begin
                    loading<=0;source_seen<=0;memory_seen<=0;write_epoch<=0;
                end
            end

            if(awaiting_display && display_ack_toggle==display_commit_toggle) begin
                current_slot<=pending_slot;current_image<=slot_image[pending_slot];
                wanted_image<=slot_zoom[pending_slot]==zoom_i ? successor(slot_image[pending_slot]) : slot_image[pending_slot];
                if(slot_zoom[pending_slot]!=zoom_i)next_pending<=1;
                backwards<=0;
                prefetch_image<=predecessor(slot_image[pending_slot]);
                current_valid<=1;display_valid<=1;awaiting_display<=0;
            end else if(scan_valid && !scan_reset && !awaiting_display && catalog_ready && !next_request && !previous_request_i && zoom_i==zoom_prev) begin
                if(current_valid && bad_images[wanted_image])
                    wanted_image<=backwards ? predecessor(wanted_image) : successor(wanted_image);
                else if(current_valid && wanted_image==current_image && slot_zoom[current_slot]==zoom_i)
                    next_pending<=0;
                else if(ready_found && (!current_valid || next_pending)) begin
                    pending_slot<=ready_slot;
                    display_commit_toggle<=~display_commit_toggle;
                    awaiting_display<=1;
                    // Repeated presses while waiting coalesce into one next
                    // request. A new edge on this issue cycle is retained.
                    next_pending<=current_valid ? next_request : (next_pending || next_request);
                end
            end

            // A backward gallery request may lie outside the forward window.
            // Fetch it on demand, evicting only READY (never ACTIVE/pending) data.
            if(scan_valid && !scan_reset && catalog_ready && current_valid && next_pending && !awaiting_display &&
               !next_request && !previous_request_i && zoom_i==zoom_prev && !bad_images[wanted_image] &&
               !wanted_resident && loader_ready && !loading) begin
                if(free_found) begin
                    load_image<=wanted_image;load_slot<=free_slot;
                    load_zoom<=zoom_i;
                    load_start<=1;loading<=1;source_seen<=0;memory_seen<=0;write_epoch<=0;
                    prefetch_image<=successor(wanted_image);
                end else if(evict_complete && evict_found && slot_state[evict_slot]==READY)
                    evict_release<=1;
            end else if(scan_valid && !scan_reset && catalog_ready && usable_count!=0 && loader_ready && !loading &&
                        !awaiting_display && (!next_pending || !current_valid) && zoom_i==zoom_prev) begin
                if(bad_images[prefetch_image] || resident || (current_valid && !free_found && !selected_in_window))
                    prefetch_image<=successor(prefetch_image);
                else if(free_found) begin
                    load_image<=prefetch_image;load_slot<=free_slot;
                    load_zoom<=zoom_i;
                    prefetch_image<=successor(prefetch_image);
                    load_start<=1;loading<=1;
                    source_seen<=0;memory_seen<=0;write_epoch<=0;
                end else if(evict_complete && evict_found && slot_state[evict_slot]==READY &&
                            evict_outside)
                    evict_release<=1;
                else prefetch_image<=successor(prefetch_image);
            end
        end
    end
endmodule

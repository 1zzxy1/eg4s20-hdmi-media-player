// Four physical slots are independent of the (up to 64-entry) image catalog.
// A slot becomes reusable only after the display consumer acknowledges a swap.
module image_cache_controller(
    input wire clk, rst,
    input wire catalog_ready,
    input wire [6:0] catalog_count,
    input wire next_request,
    input wire loader_ready, source_done, source_error, write_started, memory_done,
    output reg load_start,
    output reg [5:0] load_image,
    output reg [1:0] load_slot,
    input wire display_ack_toggle,
    output reg display_commit_toggle,
    output reg [1:0] pending_slot,
    output reg display_valid,
    output wire [6:0] image_index,
    output reg [2:0] cache_count,
    input wire previous_request
);
    wire previous_request_i=(previous_request===1'b1);
    localparam FREE=2'd0, LOADING=2'd1, READY=2'd2, ACTIVE=2'd3;
    reg [1:0] slot_state [0:3];
    reg [5:0] slot_image [0:3];
    reg [63:0] bad_images;
    reg [6:0] bad_count;
    reg [5:0] prefetch_image, wanted_image, current_image;
    reg [1:0] current_slot;
    reg current_valid, awaiting_display, next_pending;
    reg loading, source_seen, memory_seen, write_epoch;
    reg backwards;
    reg wanted_resident,evict_found;
    reg [1:0] evict_slot;
    integer i,s;
    reg free_found, resident, ready_found;
    reg [1:0] free_slot, ready_slot;
    wire [6:0] usable_count = catalog_count - bad_count;
    assign image_index = current_valid ? {1'b0,current_image}+7'd1 : 7'd0;

    function [5:0] successor;
        input [5:0] index;
        begin successor = ({1'b0,index}+7'd1 >= catalog_count) ? 6'd0 : index+1'b1; end
    endfunction
    function [5:0] predecessor;
        input [5:0] index;
        begin predecessor=index==0 ? catalog_count-1'b1 : index-1'b1;end
    endfunction

    always @* begin
        free_found=0; resident=0; ready_found=0;
        free_slot=0; ready_slot=0; cache_count=0;
        wanted_resident=0;evict_found=0;evict_slot=0;
        for(s=0;s<4;s=s+1) begin
            if(slot_state[s]==FREE && !free_found) begin free_found=1;free_slot=s[1:0];end
            if(slot_state[s]!=FREE && slot_image[s]==prefetch_image) resident=1;
            if(slot_state[s]!=FREE && slot_image[s]==wanted_image) wanted_resident=1;
            if(slot_state[s]==READY && slot_image[s]!=wanted_image) begin evict_found=1;evict_slot=s[1:0];end
            if(slot_state[s]==READY || slot_state[s]==ACTIVE) cache_count=cache_count+1'b1;
            if(slot_state[s]==READY && !ready_found &&
               (!current_valid || slot_image[s]==wanted_image)) begin
                ready_found=1;ready_slot=s[1:0];
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            for(i=0;i<4;i=i+1) begin slot_state[i]<=FREE;slot_image[i]<=0;end
            bad_images<=0;bad_count<=0;prefetch_image<=0;wanted_image<=0;current_image<=0;
            current_slot<=0;current_valid<=0;awaiting_display<=0;next_pending<=0;
            loading<=0;source_seen<=0;memory_seen<=0;write_epoch<=0;
            load_start<=0;load_image<=0;load_slot<=0;pending_slot<=0;backwards<=0;
            display_commit_toggle<=0;display_valid<=0;
        end else begin
            load_start<=0;
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
                    slot_state[load_slot]<=FREE;
                    if(!bad_images[load_image]) begin
                        bad_images[load_image]<=1;
                        bad_count<=bad_count+1'b1;
                    end
                    loading<=0;source_seen<=0;memory_seen<=0;write_epoch<=0;
                end else if(source_seen && memory_seen) begin
                    slot_state[load_slot]<=READY;
                    loading<=0;source_seen<=0;memory_seen<=0;write_epoch<=0;
                end
            end

            if(awaiting_display && display_ack_toggle==display_commit_toggle) begin
                if(current_valid)
                    slot_state[current_slot] <= usable_count<=4 ? READY : FREE;
                slot_state[pending_slot]<=ACTIVE;
                current_slot<=pending_slot;current_image<=slot_image[pending_slot];
                wanted_image<=successor(slot_image[pending_slot]);
                backwards<=0;
                current_valid<=1;display_valid<=1;awaiting_display<=0;
            end else if(!awaiting_display && catalog_ready && !next_request && !previous_request_i) begin
                if(current_valid && bad_images[wanted_image])
                    wanted_image<=backwards ? predecessor(wanted_image) : successor(wanted_image);
                else if(current_valid && wanted_image==current_image)
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
            if(catalog_ready && current_valid && next_pending && !awaiting_display &&
               !next_request && !previous_request_i && !bad_images[wanted_image] &&
               !wanted_resident && loader_ready && !loading) begin
                if(free_found) begin
                    load_image<=wanted_image;load_slot<=free_slot;
                    slot_image[free_slot]<=wanted_image;slot_state[free_slot]<=LOADING;
                    load_start<=1;loading<=1;source_seen<=0;memory_seen<=0;write_epoch<=0;
                    prefetch_image<=successor(wanted_image);
                end else if(evict_found) slot_state[evict_slot]<=FREE;
            end else if(catalog_ready && usable_count!=0 && loader_ready && !loading && free_found) begin
                if(bad_images[prefetch_image] || resident)
                    prefetch_image<=successor(prefetch_image);
                else begin
                    load_image<=prefetch_image;load_slot<=free_slot;
                    slot_image[free_slot]<=prefetch_image;slot_state[free_slot]<=LOADING;
                    prefetch_image<=successor(prefetch_image);
                    load_start<=1;loading<=1;
                    source_seen<=0;memory_seen<=0;write_epoch<=0;
                end
            end
        end
    end
endmodule

// Bundled-data handshake. Source holds bank/valid from commit until ack.
// Destination captures only when the video reader requests a new frame.
module frame_commit_bridge #(parameter BANK_BITS=2)(
    input wire clk, input wire rst,
    input wire commit_toggle, input wire [BANK_BITS-1:0] pending_bank,
    input wire frame_request, input wire commit_hold,
    output reg [BANK_BITS-1:0] active_bank, output reg active_valid,
    output reg ack_toggle,
    input wire reader_ack
);
    (* ASYNC_REG = "TRUE" *) reg [2:0] req_sync;
    reg frame_prev;
    reg waiting_reader, reader_was_low, captured_toggle;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            req_sync <= 0; frame_prev <= 0; active_bank <= 0;
            active_valid <= 0; ack_toggle <= 0;
            waiting_reader<=0;reader_was_low<=0;captured_toggle<=0;
        end else begin
            req_sync <= {req_sync[1:0], commit_toggle};
            frame_prev <= frame_request;
            if (frame_request && !frame_prev && !waiting_reader && req_sync[2] != ack_toggle && !commit_hold) begin
                active_bank <= pending_bank;
                active_valid <= 1;
                captured_toggle<=req_sync[2];
                waiting_reader<=1;
                reader_was_low<=!reader_ack;
            end
            // Do not free the previous slot until the real read DMA accepts
            // this frame. A stale high acknowledge must not release a slot.
            if(waiting_reader) begin
                if(!reader_ack) reader_was_low<=1;
                if(reader_was_low && reader_ack) begin
                    ack_toggle<=captured_toggle;
                    waiting_reader<=0;
                end
            end
        end
    end
endmodule

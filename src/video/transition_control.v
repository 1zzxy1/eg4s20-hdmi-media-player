// Source holds pending bank until bridge acknowledges. Fade runs independently
// of that ack; the bridge may release the previous bank only at full black.
module transition_control #(parameter ENABLE=1)(
    input wire clk,rst,frame_tick,image_valid,commit_toggle,ack_toggle,
    output wire commit_hold, output reg [4:0] gain,
    input wire [1:0] requested_mode,
    output reg [1:0] effect_mode
);
    (* ASYNC_REG="TRUE" *) reg [2:0] req_sync;
    reg [1:0] state;
    reg transition_request;
    wire pending=req_sync[2]!=ack_toggle;
    // Initial commit bypasses fade. For subsequent commits, block immediately
    // on the same synchronization stage used by frame_commit_bridge.
    assign commit_hold=ENABLE && image_valid &&
        ((state==0 && pending && requested_mode!=0) ||
         (state==1 && gain!=0) || state==3);
    always @(posedge clk or posedge rst) begin
        if(rst) begin req_sync<=0;state<=0;gain<=16;effect_mode<=0;transition_request<=0;end
        else begin
            req_sync<={req_sync[1:0],commit_toggle};
            if(!ENABLE || !image_valid) begin state<=0;gain<=16;effect_mode<=0;end
            else if(state==2 && ack_toggle==transition_request) begin
                // Observe this transaction's completion every cycle, even if
                // a queued request arrives before the next frame boundary.
                state<=3;gain<=0;
            end else if(frame_tick) case(state)
                0: if(pending) begin
                    effect_mode<=requested_mode;
                    transition_request<=req_sync[2];
                    if(requested_mode!=0) begin state<=1;gain<=15;end
                end
                1: if(gain!=0) gain<=gain-1'b1;else state<=2;
                2: gain<=0;
                3: if(gain==16) state<=0;else gain<=gain+1'b1;
            endcase
        end
    end
endmodule

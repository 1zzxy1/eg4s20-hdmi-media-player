// Record: reserved[95:92], valid[91], avatar[90:88], name[87:40], time[39:24], score[23:0].
module game_scores(input wire clk,rst,submit,save_busy,
    input wire [23:0] score, input wire [15:0] elapsed_seconds,
    input wire [47:0] player_name, input wire [2:0] avatar,
    input wire [3:0] query_index, output wire [95:0] query_record,
    input wire [3:0] store_index, output wire [95:0] store_record,
    input wire load_valid, input wire [3:0] load_index, input wire [95:0] load_record,
    output reg changed);
    reg [95:0] records[0:9];
    reg initializing,inserting,dirty;
    reg [3:0] cursor;
    reg [95:0] candidate;
    wire [95:0] current_record=records[cursor];
    wire better=candidate[91] && (!current_record[91] ||
        candidate[23:0]>current_record[23:0] ||
        (candidate[23:0]==current_record[23:0] && candidate[39:24]<current_record[39:24]));
    wire write_enable=initializing || (load_valid && !inserting && load_index<10) ||
        (inserting && better);
    wire [3:0] write_index=initializing || inserting?cursor:load_index;
    wire [95:0] write_data=initializing?96'd0:inserting?candidate:load_record;
    // One write port, no per-bit reset: TD can infer distributed RAM instead
    // of ten parallel register banks with a full-table shift network.
    always @(posedge clk) if(!rst && write_enable)records[write_index]<=write_data;
    assign query_record=(!initializing && query_index<10)?records[query_index]:96'd0;
    assign store_record=(!initializing && store_index<10)?records[store_index]:96'd0;
    // Track the live result while idle; the submit edge freezes this snapshot
    // by entering inserting. Keep submit out of the 96-bit data enable path
    // to avoid a high-fanout local routing bottleneck on the packed RAM bank.
    // Candidate contents are irrelevant until a submit, so no reset is needed.
    always @(posedge clk) begin
        if(!inserting) candidate<={4'd0,1'b1,avatar,player_name,elapsed_seconds,score};
        else if(better) candidate<=current_record;
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin changed<=0;initializing<=1;inserting<=0;dirty<=0;cursor<=0;end
        else begin
            changed<=0;
            if(initializing) begin
                if(cursor==9)begin initializing<=0;cursor<=0;end
                else cursor<=cursor+1'b1;
            end else if(inserting) begin
                if(better)dirty<=1;
                if(cursor==9)begin inserting<=0;changed<=dirty||better;end
                else cursor<=cursor+1'b1;
            end else if(submit && !save_busy && !load_valid) begin
                cursor<=0;dirty<=0;inserting<=1;
            end
        end
    end
endmodule

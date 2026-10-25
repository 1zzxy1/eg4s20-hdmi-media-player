`timescale 1ns/1ps
module tb_game_scores;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,submit=0,save_busy=0,load_valid=0;
    reg [23:0] score=0;reg [15:0] elapsed_seconds=0;
    reg [47:0] player_name="PLAYER";reg [2:0] avatar=3;
    reg [3:0] query_index=0,store_index=0,load_index=0;
    reg [95:0] load_record=0;wire [95:0] query_record,store_record;wire changed;
    integer notifications=0;
    reg [95:0] snapshot[0:9];
    game_scores dut(.*);
    always @(posedge clk) if(changed)notifications<=notifications+1;
    task add(input integer s,input integer t);
        begin @(negedge clk);score=s;elapsed_seconds=t;submit=1;@(negedge clk);submit=0;
            repeat(12) @(negedge clk);end
    endtask
    initial begin
        repeat(3) @(negedge clk);rst=0;repeat(12) @(negedge clk);
        for(integer n=0;n<12;n=n+1) begin
            player_name=48'h504c41593030+n;avatar=n%8;add(n*100,100);
        end
        for(integer n=0;n<10;n=n+1) begin query_index=n;#1;
            if(query_record[23:0]!=(11-n)*100 || !query_record[91] ||
               query_record[87:40]!=48'h504c41593030+11-n || query_record[90:88]!=(11-n)%8)
                $fatal(1,"rank ordering/name/avatar %d",n);
            snapshot[n]=query_record;
        end
        if(notifications!=12)$fatal(1,"insertion completion pulse count");
        add(1,999);
        for(integer n=0;n<10;n=n+1)begin query_index=n;#1;
            if(query_record!=snapshot[n])$fatal(1,"nonqualifying score changed full table");end
        if(notifications!=12)$fatal(1,"nonqualifying score requested save");
        add(1100,50);query_index=0;#1;if(query_record[39:24]!=50) $fatal(1,"time tie break");
        save_busy=1;add(9999,1);query_index=0;#1;if(query_record[23:0]!=1100) $fatal(1,"save lock");
        save_busy=0;load_index=4;load_record={4'd0,1'b1,3'd7,48'h414243444546,16'd12,24'd321};load_valid=1;
        @(negedge clk);load_valid=0;store_index=4;#1;if(store_record!=load_record) $fatal(1,"restore");
        query_index=15;#1;if(query_record!=0) $fatal(1,"invalid index");
        @(negedge clk);score=9000;elapsed_seconds=7;player_name="LOCKED";avatar=6;submit=1;
        @(negedge clk);submit=0;score=1;elapsed_seconds=999;player_name="CHANGE";avatar=0;
        repeat(12)@(negedge clk);query_index=0;store_index=4;#1;
        if(query_record!={4'd0,1'b1,3'd6,48'h4c4f434b4544,16'd7,24'd9000})
            $fatal(1,"submit did not freeze result snapshot");
        if(store_record==query_record)$fatal(1,"independent read ports aliased");
        rst=1;repeat(3)@(negedge clk);rst=0;repeat(12)@(negedge clk);
        for(integer n=0;n<10;n=n+1)begin query_index=n;#1;
            if(query_record!=0)$fatal(1,"reset did not clear record %0d",n);end
        $display("PASS game_scores top10 metadata, rejection, completion pulses, tie-break, save lock, restore, reset");$finish;
    end
endmodule

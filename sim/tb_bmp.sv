`timescale 1ns/1ps
module tb_bmp;
    reg clk=0,rst=1,scan=0,load=0,ack=0,dvalid=0,done=0;
    reg [7:0] data=0;
    always #5 clk=~clk;
    wire ready,scan_done,found,wreq,readreq,pvalid;
    wire [31:0] sector,found_sector;
    wire [2:0] total; wire [3:0] state;wire [23:0] pixel;
    integer pixels=0,i,j,offset; reg bad_header=0;
    bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(scan),
        .scan_start_sector(32'd2048),.scan_max_sector(32'd2048),.scan_target_count(3'd1),
        .scan_done(scan_done),.scan_found_valid(found),.scan_found_sector(found_sector),.scan_found_total(total),
        .load_start(load),.load_sector(32'd2048),.sd_init_done(1'b1),.state_code(state),
        .bmp_width(16'd640),.bmp_height(16'd480),.write_req(wreq),.write_req_ack(ack),
        .sd_sec_read(readreq),.sd_sec_read_addr(sector),.sd_sec_read_data(data),
        .sd_sec_read_data_valid(dvalid),.sd_sec_read_end(done),.bmp_data_wr_en(pvalid),.bmp_data(pixel));
    function [7:0] byte_at(input integer n);
        integer bytepos;
        begin
            byte_at=0;
            case(n)
                0:byte_at="B";1:byte_at="M";
                2:byte_at=8'h36;3:byte_at=8'h10;4:byte_at=8'h0e;
                10:byte_at=54;14:byte_at=40;
                18:byte_at=8'h80;19:byte_at=2;
                20:byte_at=bad_header?1:0;
                22:byte_at=8'he0;23:byte_at=1;26:byte_at=1;28:byte_at=24;
                default: if(n>=54 && n<921654) begin
                    bytepos=(n-54)%3;
                    case(bytepos) 0:byte_at=8'h12;1:byte_at=8'h34;2:byte_at=8'h56;endcase
                end
            endcase
        end
    endfunction
    always @(posedge clk) begin
        #1;
        if(pvalid) begin
            pixels=pixels+1;
            if(pixel!==24'h563412) $fatal(1,"RGB byte order");
        end
    end
    task sector_reply(input integer base);
        begin
            wait(readreq);repeat(3) @(negedge clk);
            for(j=0;j<512;j=j+1) begin
                data=byte_at(base+j);dvalid=1;@(negedge clk);
                dvalid=0;@(negedge clk);
            end
            done=1;@(negedge clk);done=0;repeat(3) @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst=0;scan=1;@(negedge clk);scan=0;
        sector_reply(0);
        if(!scan_done||total!=1) $fatal(1,"valid BMP scan");
        load=1;@(negedge clk);load=0;sector_reply(0);
        wait(wreq);@(negedge clk);ack=1;repeat(3) @(negedge clk);ack=0;
        for(i=0;i<1801;i=i+1) sector_reply(i*512);
        if(!ready||pixels!=307200) $fatal(1,"frame pixels %d",pixels);
        bad_header=1;scan=1;@(negedge clk);scan=0;sector_reply(0);
        if(!scan_done||total!=0) $fatal(1,"high width bits must be rejected");
        $display("PASS BMP: 307200 RGB pixels across 1801 sectors; invalid dimensions rejected");$finish;
    end
    initial begin #50000000;$fatal(1,"timeout");end
endmodule

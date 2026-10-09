`timescale 1ns/1ps
// Sector-level card responder below replaces only the physical SPI endpoint.
module tb_loader_recovery;
    reg clk=0,rst=1,finished=0,ack=0;
    always #10 clk=~clk;
    wire [3:0] state;wire valid,commit,wreq,we;wire [1:0] wb,db;wire [31:0] data;
    integer pixels=0,wait_ack=0,commits=0;
    sd_card_bmp #(.CLK_FREQ_HZ(1000),.SCAN_START_SECTOR(2048),.SCAN_MAX_SECTOR(2051)) dut(
        .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.state_code(state),
        .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(valid),.write_finish_toggle(finished),
        .display_ack_toggle(ack),.display_commit_toggle(commit),.write_buf_idx(wb),.disp_buf_idx(db),
        .write_req(wreq),.write_req_ack(wreq),.write_ready(1'b1),.write_en(we),.write_data(data),
        .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1));
    always @(posedge clk) if(!rst) begin
        if(we) begin
            if(data!==32'h80201000 || wb!=0) $fatal(1,"bad source committed or wrong initial bank %h",data);
            pixels=pixels+1;
            if(pixels==307200) finished<=!finished;
        end
        if(commit!=ack) begin
            if(pixels!=307200 || !valid || db!=0) $fatal(1,"commit before complete recovery");
            wait_ack=wait_ack+1;
            if(wait_ack==16) ack<=commit;
        end
        if(ack && wait_ack==16) begin
            $display("PASS loader recovery: first source fails after scan; automatically skips to next image; complete frame before commit");$finish;
        end
    end
    initial begin repeat(5)@(negedge clk);rst=0;end
    initial begin #200000000;$fatal(1,"loader recovery timeout pixels=%0d",pixels);end
endmodule

module sd_card_top(input wire clk,rst,output wire SD_nCS,SD_DCLK,SD_MOSI,input wire SD_MISO,
    output wire sd_init_done,input wire sd_sec_read,input wire [31:0] sd_sec_read_addr,
    output reg [7:0] sd_sec_read_data,output reg sd_sec_read_data_valid,sd_sec_read_end,
    input wire sd_sec_write,input wire [31:0] sd_sec_write_addr,input wire [7:0] sd_sec_write_data,
    output wire sd_sec_write_data_req,sd_sec_write_end);
    assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=0;assign sd_init_done=!rst;
    assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
    integer served=0,j;reg [7:0] red;
    function [7:0] byte_at(input integer p,input [7:0] r);
        begin
            byte_at=0;
            case(p)
                0:byte_at="B";1:byte_at="M";2:byte_at=70;10:byte_at=54;
                14:byte_at=40;18:byte_at=2;22:byte_at=2;26:byte_at=1;28:byte_at=24;
                54,57,62,65:byte_at=16;
                55,58,63,66:byte_at=32;
                56,59,64,67:byte_at=r;
            endcase
        end
    endfunction
    initial begin
        sd_sec_read_data=0;sd_sec_read_data_valid=0;sd_sec_read_end=0;
        forever begin
            wait(sd_sec_read&&!rst);served=served+1;red=(sd_sec_read_addr-2047)*64;
            for(j=0;j<(served==5?511:512);j=j+1) begin
                @(negedge clk);sd_sec_read_data=byte_at(j,red);sd_sec_read_data_valid=1;
                @(negedge clk);sd_sec_read_data_valid=0;
            end
            sd_sec_read_end=1;@(negedge clk);sd_sec_read_end=0;wait(!sd_sec_read);
        end
    end
endmodule

`timescale 1ns/1ps
module tb_frame_write;
    reg clk=0,rst=1,req=0;
    always #12.5 clk=~clk;
    wire ack,finish,en,busy,clear;wire [20:0] addr;
    integer count=0,expected;
    frame_fifo_write #(.BURST_SIZE(128)) dut(
        .rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
        .App_rd_busy(1'b0),.O_wr_busy(busy),.App_wr_en(en),.App_wr_addr(addr),
        .write_req(req),.write_req_ack(ack),.write_finish(finish),
        .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd0),.write_addr_3(21'd0),
        .write_addr_index(2'd1),.write_len(21'd307200),.fifo_aclr(clear),.rdusedw(10'd511));
    always @(posedge clk) if(en) begin
        expected=307200+(479-count/640)*640+count%640;
        if(addr!==expected || addr<307200 || addr>=614400) $fatal(1,"SDRAM address %d expected %d",addr,expected);
        count=count+1;
    end
    initial begin
        repeat(5)@(negedge clk);rst=0;req=1;
        wait(ack);@(negedge clk);req=0;
        wait(finish);@(negedge clk);
        if(count!=307200) $fatal(1,"write length %d",count);
        $display("PASS frame write: 307200 addresses, bottom-up mapping, isolated bank1");$finish;
    end
    initial begin #15000000;$fatal(1,"timeout");end
endmodule

`timescale 1ns/1ps
// Recover words using only the four output pins. No serializer internals.
module tb_hdmi_phy;
    parameter integer PHASE_PS=0;
    parameter integer FAULT=0;
    parameter integer USE_PLL=0;
    parameter integer TX_POSEDGE=0;
    reg ideal_pixel_clk=0,ideal_serial_clk=0,refclk=0,rst=1;
    reg pll_reset=1;
    initial begin #200;pll_reset=0;end
    wire pll_pixel_clk,pll_serial_clk,pll_locked;
    wire pixel_clk=USE_PLL?pll_pixel_clk:ideal_pixel_clk;
    wire serial_clk=USE_PLL?pll_serial_clk:ideal_serial_clk;
    always #10 refclk=~refclk;
    always #20 ideal_pixel_clk=~ideal_pixel_clk;
    generate if(USE_PLL)begin:real_clock
        video_pll pll(.refclk(refclk),.reset(pll_reset),.locked(pll_locked),
            .clk0_out(pll_pixel_clk),.clk1_out(pll_serial_clk));
    end endgenerate
    initial begin
        #(PHASE_PS/1000.0);
        forever #4 ideal_serial_clk=~ideal_serial_clk;
    end
    integer sequence_id=0,epoch=0;
    reg [9:0] c0=0,c1=0,c2=0;
    wire d0,d1,d2,ck;
    // Distinct changing lanes expose swaps, stale words, and bit order errors.
    always @(pixel_clk) if(!rst&&pixel_clk===TX_POSEDGE[0]) begin
        sequence_id=sequence_id+1;
        c0=(sequence_id*37) ^ 10'h12b;
        c1=(sequence_id*73) ^ 10'h2d6;
        c2=(sequence_id*109) ^ 10'h369;
    end
    function [9:0] reverse_bits(input [9:0] value);
        integer i;
        begin for(i=0;i<10;i=i+1)reverse_bits[i]=value[9-i];end
    endfunction
    hdmi_phy_wrapper #(.DEVICE("EG")) dut(
        .I_pixel_clk(pixel_clk),.I_serial_clk(serial_clk),.I_rst(rst),
        .I_tmds_channel_0(FAULT==1 ? reverse_bits(c0) : c0),
        .I_tmds_channel_1(FAULT==2 ? c2 : c1),
        .I_tmds_channel_2(FAULT==2 ? c1 : c2),
        .I_tmds_channel_clk(10'b1111100000),
        .O_tmds_ch0_p(d0),.O_tmds_ch1_p(d1),.O_tmds_ch2_p(d2),.O_tmds_clk_p(ck));

    reg [29:0] expected[0:4095];
    integer written=0;
    always @(posedge pixel_clk) begin
        #0.2;
        if(rst)written=0;
        else begin
            if(written>=4096)$fatal(1,"PHY expected queue overflow");
            expected[written]={c2,c1,c0};
            written=written+1;
        end
    end

    reg previous_clock=0,armed=0,locked=0;
    reg [9:0] recovered_clock=0;
    reg [29:0] recovered=0;
    integer bit_index=0,next_word=0,checked_epoch=0,checked_total=0;
    integer i,match_count,match_index;
    // The vendor ODDR model has a 0.1 ns mux delay. Sample at +0.6 ns,
    // comfortably within each 4 ns bit cell, on both serial clock edges.
    always @(serial_clk) begin
        #0.6;
        if(rst)begin
            armed=0;locked=0;bit_index=0;previous_clock=0;checked_epoch=0;
        end else begin
            if(!armed && previous_clock===1'b1 && ck===1'b0)begin
                armed=1;bit_index=0;
            end
            if(armed)begin
                recovered[bit_index]=d0;
                recovered[10+bit_index]=d1;
                recovered[20+bit_index]=d2;
                recovered_clock[bit_index]=ck;
                if(bit_index==9)begin
                    if(written>12)begin
                        if(recovered_clock!==10'b1111100000)
                            $fatal(1,"PHY forwarded clock framing mismatch");
                        if(!locked)begin
                            // Acquire once within a bounded pipeline window.
                            // Subsequent words must advance exactly once.
                            match_count=0;match_index=0;
                            for(i=written-6;i<written;i=i+1)
                                if(recovered===expected[i])begin
                                    match_count=match_count+1;match_index=i;
                                end
                            if(match_count!=1)$fatal(1,"PHY acquisition mismatch phase=%0d fault=%0d",PHASE_PS,FAULT);
                            next_word=match_index;locked=1;
                        end
                        if(next_word>=written || next_word<written-6)
                            $fatal(1,"PHY pipeline latency outside bounded window");
                        if(recovered!==expected[next_word])
                            $fatal(1,"PHY word mismatch phase=%0d word=%0d got=%h expected=%h",PHASE_PS,next_word,recovered,expected[next_word]);
                        next_word=next_word+1;
                        checked_epoch=checked_epoch+1;checked_total=checked_total+1;
                    end
                    bit_index=0;
                end else bit_index=bit_index+1;
            end
            previous_clock=ck;
        end
    end
    initial begin
        if(USE_PLL)begin wait(pll_locked===1'b1);repeat(20)@(negedge pixel_clk);end
        // Two independent releases exercise initial startup and live reset.
        for(epoch=0;epoch<2;epoch=epoch+1)begin
            rst=1;
            repeat(10)@(negedge pixel_clk);
            #1;rst=0;
            repeat(1100)@(negedge pixel_clk);
            #1;
            if(checked_epoch<1000)$fatal(1,"PHY insufficient recovered words epoch=%0d count=%0d",epoch,checked_epoch);
        end
        $display("PASS HDMI PHY: pll=%0d phase_ps=%0d epochs=2 words=%0d, all lanes LSB-first and continuous",USE_PLL,PHASE_PS,checked_total);
        $finish;
    end
    initial begin #200000;$fatal(1,"PHY watchdog");end
endmodule

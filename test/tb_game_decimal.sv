`timescale 1ns/1ps
module tb_game_decimal;
    reg clk=0,rst=1;always #5 clk=~clk;
    reg [23:0] value=0;wire [23:0] bcd;
    game_decimal dut(.*);
    integer i,j,v;reg [23:0] expected;
    initial begin
        repeat(3)@(negedge clk);rst=0;
        for(i=0;i<100;i=i+1) begin
            value=i==0?0:i==1?999999:i*7919;
            v=value;expected=0;
            for(j=0;j<6;j=j+1)begin expected[j*4+:4]=v%10;v=v/10;end
            repeat(52)@(negedge clk);
            if(bcd!==expected)$fatal(1,"decimal %0d got %h expected %h",value,bcd,expected);
        end
        $display("PASS game decimal: boundaries and 100 independently calculated values");$finish;
    end
endmodule

`timescale 1ns/1ps
module tb_game_alignment_digits;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    reg [9:0] x=0,y=224,offset=0;
    wire [23:0] rgb;
    game_alignment_pattern dut(.clk(clk),.rst(rst),.x(x),.y(y),.offset(offset),.rgb(rgb));
    integer value,digit,expected;
    initial begin
        repeat(2)@(negedge clk);rst=0;
        for(value=0;value<1024;value=value+1)begin
            offset=value;
            repeat(22)@(negedge clk);
            for(digit=0;digit<3;digit=digit+1)begin
                x=64+(21+digit)*16;
                case(digit)
                    0:expected=48+value/100;
                    1:expected=48+(value/10)%10;
                    2:expected=48+value%10;
                endcase
                @(posedge clk);#1;
                if(dut.ch!==expected[7:0])$fatal(1,"Offset %0d digit %0d: %0d != %0d",value,digit,dut.ch,expected);
            end
        end
        $display("PASS alignment digits: all 1024 inputs and three glyphs");$finish;
    end
endmodule

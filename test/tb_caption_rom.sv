`timescale 1ns/1ps
module tb_caption_rom;
    reg clk=0;
    reg [2:0] mode=0;
    reg [4:0] column=0;
    wire [7:0] character;
    caption_rom dut(clk,mode,column,character);
    always #5 clk=~clk;
    task check_line(input [2:0] which,input [255:0] expected);
        integer col;
        begin
            for(col=0;col<32;col=col+1) begin
                @(negedge clk);mode=which;column=col;
                @(posedge clk);#1;
                if(character!==expected[(31-col)*8+:8])
                    $fatal(1,"caption mode=%0d col=%0d got=%h",which,col,character);
            end
        end
    endtask
    initial begin
        check_line(0,"EG4S20 HDMI MULTIMEDIA PLAYER   ");
        check_line(1,"ASSET GALLERY - BROWSE IMAGES   ");
        check_line(2,"POWERED UP - MARIO IS BIG       ");
        check_line(3,"LEVEL CLEAR - CONGRATULATIONS   ");
        check_line(4,"WORLD 1-1 - THE JOURNEY BEGINS  ");
        check_line(5,"THE FINISH IS NEAR - KEEP GOING ");
        $display("PASS caption ROM: synchronous gallery, power-up, clear and course location messages");
        $finish;
    end
endmodule

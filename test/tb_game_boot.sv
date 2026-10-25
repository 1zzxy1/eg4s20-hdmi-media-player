`timescale 1ns/1ps
module tb_game_boot;
    reg clk=0,locked=0;
    wire arst;
    always #5 clk=~clk;
    game_boot_reset #(.HOLD_CYCLES(4)) dut(.clk(clk),.locked(locked),.arst(arst));
    task tick;begin @(posedge clk);#1;end endtask
    initial begin
        if(arst!==1'b1) $fatal(1,"startup reset must be asserted");
        repeat(3)tick();
        locked=1;
        repeat(3)begin tick();if(arst!==1'b1)$fatal(1,"reset released too early");end
        tick();if(arst!==1'b0)$fatal(1,"reset did not release after hold");
        repeat(6)begin tick();if(arst!==1'b0)$fatal(1,"reset flickered after release");end
        locked=0;#1;if(arst!==1'b1)$fatal(1,"lock loss did not immediately assert reset");
        tick();locked=1;
        repeat(3)begin tick();if(arst!==1'b1)$fatal(1,"lock reacquire lacked full hold");end
        tick();if(arst!==1'b0)$fatal(1,"reset did not recover after relock");
        $display("PASS game boot: startup hold, stable release, async lock loss, full relock hold");
        $finish;
    end
    initial begin #1000;$fatal(1,"game boot timeout");end
endmodule

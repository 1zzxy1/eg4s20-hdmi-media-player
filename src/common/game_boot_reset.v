// Startup reset independent of KEY1, which is now a menu/game input.
module game_boot_reset #(parameter integer HOLD_CYCLES=1024)(
    input wire clk,locked,output wire arst
);
    reg [$clog2(HOLD_CYCLES+1)-1:0] count=0;
    reg released=0;
    always @(posedge clk or negedge locked) begin
        if(!locked) begin count<=0;released<=0;end
        else if(!released) begin
            if(count==HOLD_CYCLES-1) released<=1;
            else count<=count+1'b1;
        end
    end
    assign arst=!locked || !released;
endmodule

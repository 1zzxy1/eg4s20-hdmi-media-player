// Asynchronous assertion, synchronous release in each destination domain.
module reset_sync(input wire clk, input wire arst, output wire rst);
    (* ASYNC_REG = "TRUE" *) reg [2:0] sync = 3'b111;
    always @(posedge clk or posedge arst)
        if (arst) sync <= 3'b111;
        else sync <= {sync[1:0], 1'b0};
    assign rst = sync[2];
endmodule

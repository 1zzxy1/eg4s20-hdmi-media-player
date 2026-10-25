// Binary-to-BCD runs in the background, one source bit per cycle. A complete
// value is published atomically; no combinational division in the pixel path.
module game_decimal #(parameter WIDTH=24,DIGITS=6)(
    input wire clk,rst,input wire [WIDTH-1:0] value,
    output reg [DIGITS*4-1:0] bcd
);
    reg [WIDTH-1:0] bits;
    reg [DIGITS*4-1:0] work;
    reg [DIGITS*4-1:0] adjusted;
    reg [$clog2(WIDTH+1)-1:0] remaining;
    integer i;
    always @* begin
        adjusted=work;
        for(i=0;i<DIGITS;i=i+1)
            if(work[i*4+:4]>=5) adjusted[i*4+:4]=work[i*4+:4]+4'd3;
    end
    always @(posedge clk or posedge rst)
        if(rst) begin bits<=0;work<=0;remaining<=0;bcd<=0;end
        else if(remaining==0) begin bits<=value;work<=0;remaining<=WIDTH;end
        else begin
            work<={adjusted[DIGITS*4-2:0],bits[WIDTH-1]};
            bits<=bits<<1;remaining<=remaining-1'b1;
            if(remaining==1) bcd<={adjusted[DIGITS*4-2:0],bits[WIDTH-1]};
        end
endmodule

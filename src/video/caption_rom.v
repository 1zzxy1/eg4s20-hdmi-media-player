// Synchronous caption lookup, addressed one pixel before the font pipeline.
module caption_rom(input wire clk,input wire [2:0] mode,input wire [4:0] column,
    output reg [7:0] character);
    reg [7:0] text_rom[0:255];
    reg [255:0] line;
    integer i,j;
    initial begin
        for(i=0;i<8;i=i+1) begin
            case(i)
                1:line="ASSET GALLERY - BROWSE IMAGES   ";
                2:line="POWERED UP - MARIO IS BIG       ";
                3:line="LEVEL CLEAR - CONGRATULATIONS   ";
                4:line="WORLD 1-1 - THE JOURNEY BEGINS  ";
                5:line="THE FINISH IS NEAR - KEEP GOING ";
                6,7:line="                                ";
                default:line="EG4S20 HDMI MULTIMEDIA PLAYER   ";
            endcase
            for(j=0;j<32;j=j+1)
                text_rom[i*32+j]=line[(31-j)*8+:8];
        end
    end
    always @(posedge clk) character<=text_rom[{mode,column}];
endmodule

// Original 5x7 bitmap font, bit4 is the leftmost pixel; lowercase maps to blank.
module osd_font(input wire [7:0] ch, input wire [2:0] row, output wire [4:0] bits);
    reg [55:0] glyph;
    always @* case(ch)
        "0":glyph=56'h0e11131519110e;"1":glyph=56'h040c040404040e;
        "2":glyph=56'h0e11010204081f;"3":glyph=56'h1e01010601011e;
        "4":glyph=56'h02060a121f0202;"5":glyph=56'h1f101e0101110e;
        "6":glyph=56'h0608101e11110e;"7":glyph=56'h1f010204080808;
        "8":glyph=56'h0e11110e11110e;"9":glyph=56'h0e11110f01020c;
        "A":glyph=56'h0e11111f111111;"B":glyph=56'h1e11111e11111e;
        "C":glyph=56'h0e11101010110e;"D":glyph=56'h1e11111111111e;
        "E":glyph=56'h1f10101e10101f;"F":glyph=56'h1f10101e101010;
        "G":glyph=56'h0e11101711110f;"H":glyph=56'h1111111f111111;
        "I":glyph=56'h0e04040404040e;"J":glyph=56'h0702020212120c;
        "K":glyph=56'h11121418141211;"L":glyph=56'h1010101010101f;
        "M":glyph=56'h111b1515111111;"N":glyph=56'h11191513111111;
        "O":glyph=56'h0e11111111110e;"P":glyph=56'h1e11111e101010;
        "Q":glyph=56'h0e11111115120d;"R":glyph=56'h1e11111e141211;
        "S":glyph=56'h0f10100e01011e;"T":glyph=56'h1f040404040404;
        "U":glyph=56'h1111111111110e;"V":glyph=56'h11111111110a04;
        "W":glyph=56'h11111115151b11;"X":glyph=56'h11110a040a1111;
        "Y":glyph=56'h11110a04040404;"Z":glyph=56'h1f01020408101f;
        ":":glyph=56'h00040400040400;"+":glyph=56'h0004041f040400;
        "-":glyph=56'h0000001f000000;"%":glyph=56'h19190204081313;
        "/":glyph=56'h01010204081010;".":glyph=56'h00000000000606;
        default:glyph=0;
    endcase
    assign bits = row<7 ? (glyph >> ((6-row)*8)) : 5'd0;
endmodule

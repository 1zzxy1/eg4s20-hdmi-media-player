// Independent 640x480 raster. No game coordinates, memory or media pipeline.
module video_diagnostic_pattern(
    input wire clk,rst,dvi_mode,
    output wire hs,vs,de,output reg [23:0] rgb,
    output reg [9:0] x,y
);
    always @(posedge clk or posedge rst)
        if(rst)begin x<=0;y<=0;end
        else if(x==799)begin x<=0;y<=y==524?0:y+1'b1;end
        else x<=x+1'b1;
    assign hs=!(x>=656&&x<752);
    assign vs=!(y>=490&&y<492);
    assign de=x<640&&y<480;
    reg [7:0] ch;
    reg [2:0] row,col;
    reg text_region;
    reg [127:0] line_text;
    wire [4:0] glyph;
    osd_font font(ch,row,glyph);
    always @* begin
        ch=" ";row=0;col=0;text_region=0;line_text=0;
        // Each numbered strip is exactly 64 output pixels wide.
        if(y>=32&&y<60&&x[5:0]>=20&&x[5:0]<40)begin
            ch=8'd48+{4'd0,x[9:6]};row=(y-32)>>2;col=(x[5:0]-20)>>2;text_region=1;
        end else if(y>=208&&y<222&&x>=192&&x<448)begin
            line_text=dvi_mode?"B PURE DVI      ":"A VENDOR HDMI   ";
            ch=line_text>>((15-((x-192)>>4))*8);
            row=(y-208)>>1;col=x[3:1];text_region=1;
        end else if(y>=240&&y<254&&x>=192&&x<448)begin
            line_text="640 X 480       ";ch=line_text>>((15-((x-192)>>4))*8);
            row=(y-240)>>1;col=x[3:1];text_region=1;
        end else if(y>=400&&y<414&&x>=16&&x<144)begin
            line_text="LEFT 000        ";ch=line_text>>((15-((x-16)>>4))*8);
            row=(y-400)>>1;col=x[3:1];text_region=1;
        end else if(y>=400&&y<414&&x>=480&&x<624)begin
            line_text="RIGHT 639       ";ch=line_text>>((15-((x-480)>>4))*8);
            row=(y-400)>>1;col=x[3:1];text_region=1;
        end
        case(x[9:6])
            0:rgb=24'h603030;1:rgb=24'h604020;2:rgb=24'h606020;
            3:rgb=24'h306030;4:rgb=24'h206060;5:rgb=24'h203060;
            6:rgb=24'h403060;7:rgb=24'h603060;8:rgb=24'h604040;
            default:rgb=24'h505050;
        endcase
        if(x[5:0]==0||y==120||y==240||y==360)rgb=24'h909090;
        if(y>=432&&y<464)rgb={x[7:0],y[7:0],3'b101,x[9:8],y[8],2'b01};
        if(text_region)rgb=(col<5&&glyph[4-col])?24'hffffff:24'h101018;
        if(x<8)rgb=24'hff0000;else if(x>=632)rgb=24'h00ff00;
        if(y<8)rgb=24'h0000ff;else if(y>=472)rgb=24'hffff00;
        if(!de)rgb=0;
    end
endmodule

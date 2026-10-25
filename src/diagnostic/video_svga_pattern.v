// VESA DMT 800x600 at 60.317Hz: 40MHz, 1056x628, positive HS/VS.
// No frame memory, media, coordinate wrap or horizontal compensation.
module video_svga_pattern(
    input wire clk,rst,
    output wire hs,vs,de,output reg [23:0] rgb,
    output reg [10:0] x,output reg [9:0] y
);
    always @(posedge clk or posedge rst)
        if(rst)begin x<=0;y<=0;end
        else if(x==1055)begin x<=0;y<=y==627?0:y+1'b1;end
        else x<=x+1'b1;
    assign hs=x>=840&&x<968;
    assign vs=y>=601&&y<605;
    assign de=x<800&&y<600;
    reg [3:0] strip;
    reg [6:0] strip_x;
    reg [7:0] ch;
    reg [2:0] row,col;
    reg text_region;
    reg [127:0] line_text;
    wire [4:0] glyph;
    osd_font font(ch,row,glyph);
    always @* begin
        if(x<80)strip=0;else if(x<160)strip=1;else if(x<240)strip=2;
        else if(x<320)strip=3;else if(x<400)strip=4;else if(x<480)strip=5;
        else if(x<560)strip=6;else if(x<640)strip=7;else if(x<720)strip=8;else strip=9;
        strip_x=x-strip*11'd80;
        ch=" ";row=0;col=0;text_region=0;line_text=0;
        if(y>=40&&y<68&&strip_x>=28&&strip_x<48)begin
            ch=8'd48+strip;row=(y-40)>>2;col=(strip_x-28)>>2;text_region=1;
        end else if(y>=260&&y<274&&x>=272&&x<528)begin
            line_text="C SVGA DVI      ";ch=line_text>>((15-((x-272)>>4))*8);
            row=(y-260)>>1;col=x[3:1];text_region=1;
        end else if(y>=292&&y<306&&x>=272&&x<528)begin
            line_text="800 X 600       ";ch=line_text>>((15-((x-272)>>4))*8);
            row=(y-292)>>1;col=x[3:1];text_region=1;
        end else if(y>=500&&y<514&&x>=16&&x<144)begin
            line_text="LEFT 000        ";ch=line_text>>((15-((x-16)>>4))*8);
            row=(y-500)>>1;col=x[3:1];text_region=1;
        end else if(y>=500&&y<514&&x>=640&&x<784)begin
            line_text="RIGHT 799       ";ch=line_text>>((15-((x-640)>>4))*8);
            row=(y-500)>>1;col=x[3:1];text_region=1;
        end
        case(strip)
            0:rgb=24'h603030;1:rgb=24'h604020;2:rgb=24'h606020;
            3:rgb=24'h306030;4:rgb=24'h206060;5:rgb=24'h203060;
            6:rgb=24'h403060;7:rgb=24'h603060;8:rgb=24'h604040;
            default:rgb=24'h505050;
        endcase
        if(strip_x==0||y==150||y==300||y==450)rgb=24'h909090;
        if(y>=540&&y<580)rgb={x[7:0],y[7:0],3'b101,x[9:8],y[8],2'b01};
        if(text_region)rgb=(col<5&&glyph[4-col])?24'hffffff:24'h101018;
        if(x<8)rgb=24'hff0000;else if(x>=792)rgb=24'h00ff00;
        if(y<8)rgb=24'h0000ff;else if(y>=592)rgb=24'hffff00;
        if(!de)rgb=0;
    end
endmodule

// Same source coordinates as the game, before its existing RGB register.
module game_alignment_pattern(
    input wire [9:0] x,y,offset,
    output reg [23:0] rgb
);
    reg [7:0] ch;
    reg [2:0] row,col;
    reg [255:0] line_text;
    wire [4:0] glyph;
    osd_font font(ch,row,glyph);
    always @* begin
        ch=" ";row=y[2:0];col=x[2:0];line_text=0;
        rgb=x[6]?24'h183858:24'h284868;
        if(x[5:0]==0||y==120||y==360)rgb=24'h808080;
        if(y>=64&&y<80)begin
            ch="0"+{4'b0,x[9:6]};row=y[3:1];col=x[3:1];
            if(x[5:4]!=1)ch=" ";
        end
        if(y>=192&&y<208)line_text="     HORIZONTAL ALIGNMENT       ";
        if(y>=224&&y<240)line_text="      SOURCE OFFSET: 000        ";
        if(y>=272&&y<288)line_text=" KEY3 LEFT       KEY1 RIGHT     ";
        if(y>=304&&y<320)line_text=" HOLD KEY2: STEP 16 ELSE 1      ";
        if(y>=336&&y<352)line_text=" KEY4 ZERO   SW3 OFF: PLAY      ";
        if(line_text!=0&&x>=64&&x<576)begin
            ch=line_text>>((31-((x-64)>>4))*8);row=y[3:1];col=x[3:1];
            if(y>=224&&y<240)case((x-64)>>4)
                21:ch="0"+offset/100;
                22:ch="0"+(offset/10)%10;
                23:ch="0"+offset%10;
            endcase
        end
        if(col<5&&glyph[4-col])rgb=24'hffffff;
        if(x<4)rgb=24'hff0000;
        else if(x>=636)rgb=24'h00ff00;
        if(y<4)rgb=24'h0000ff;
        else if(y>=476)rgb=24'hffff00;
    end
endmodule

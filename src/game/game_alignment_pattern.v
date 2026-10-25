// Fetch calibration text alongside the game's synchronous map/texture reads.
module game_alignment_pattern(
    input wire clk,rst,
    input wire [9:0] x,y,offset,
    output reg [23:0] rgb
);
    reg [7:0] ch;
    reg [2:0] row,col;
    reg [7:0] text_rom[0:255];
    reg [255:0] init_line;
    integer line_index,char_index;
    initial begin
        for(line_index=0;line_index<8;line_index=line_index+1)begin
            case(line_index)
                0:init_line="     HORIZONTAL ALIGNMENT       ";
                1:init_line="      SOURCE OFFSET: 000        ";
                2:init_line=" KEY3 LEFT       KEY1 RIGHT     ";
                3:init_line=" HOLD KEY2: STEP 16 ELSE 1      ";
                4:init_line=" KEY4 ZERO   SW3 OFF: PLAY      ";
                default:init_line={32{8'h20}};
            endcase
            for(char_index=0;char_index<32;char_index=char_index+1)
                text_rom[line_index*32+char_index]=init_line[(31-char_index)*8+:8];
        end
    end
    reg [2:0] line_id;
    wire [4:0] column=(x-10'd64)>>4;
    reg [9:0] x0,y0;
    reg [7:0] text_char;
    always @* begin
        case(y[8:4])
            12:line_id=0;14:line_id=1;17:line_id=2;19:line_id=3;21:line_id=4;
            default:line_id=5;
        endcase
    end
    always @(posedge clk)begin
        text_char<=text_rom[{line_id,column}];x0<=x;y0<=y;
    end
    // Publish all three digits together after ten shifts. Offset changes at
    // frame boundaries, leaving ample blanking time before this text is read.
    reg [11:0] decimal,work,adjusted;
    reg [9:0] bits;
    reg [3:0] remaining;
    wire [11:0] shifted={adjusted[10:0],bits[9]};
    integer digit_index;
    always @* begin
        adjusted=work;
        for(digit_index=0;digit_index<2;digit_index=digit_index+1)
            if(work[digit_index*4+:4]>=5)
                adjusted[digit_index*4+:4]=work[digit_index*4+:4]+4'd3;
    end
    always @(posedge clk)begin
        if(rst)begin decimal<=0;work<=0;bits<=0;remaining<=0;end
        else if(remaining==0)begin bits<=offset;work<=0;remaining<=10;end
        else begin
            work<=shifted;bits<={bits[8:0],1'b0};remaining<=remaining-1'b1;
            if(remaining==1)decimal<=shifted;
        end
    end
    wire [4:0] glyph;
    osd_font font(ch,row,glyph);
    always @* begin
        ch=" ";row=y0[2:0];col=x0[2:0];
        rgb=x0[6]?24'h183858:24'h284868;
        if(x0[5:0]==0||y0==120||y0==360)rgb=24'h808080;
        if(y0>=64&&y0<80)begin
            ch="0"+{4'b0,x0[9:6]};row=y0[3:1];col=x0[3:1];
            if(x0[5:4]!=1)ch=" ";
        end
        if(x0>=64&&x0<576&&((y0>=192&&y0<208)||(y0>=224&&y0<240)||
            (y0>=272&&y0<288)||(y0>=304&&y0<320)||(y0>=336&&y0<352)))begin
            ch=text_char;row=y0[3:1];col=x0[3:1];
            if(y0>=224&&y0<240)case((x0-10'd64)>>4)
                21:ch=8'h30+{4'd0,decimal[11:8]};
                22:ch=8'h30+{4'd0,decimal[7:4]};
                23:ch=8'h30+{4'd0,decimal[3:0]};
            endcase
        end
        if(col<5&&glyph[4-col])rgb=24'hffffff;
        if(x0<4)rgb=24'hff0000;
        else if(x0>=636)rgb=24'h00ff00;
        if(y0<4)rgb=24'h0000ff;
        else if(y0>=476)rgb=24'hffff00;
    end
endmodule

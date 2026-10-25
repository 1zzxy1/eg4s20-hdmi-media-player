// Synchronous character ROM replaces the wide menu string mux.
// RGB and sync take the same two clocks; Debug leaves its preview unobstructed.
module game_menu_video(input wire clk,rst,hs,vs,de,input wire [23:0] rgb,
    input wire active,debug_mode,media_fullscreen,calibration,
    input wire [2:0] page,selection,
    input wire view_narrow,palette_mode,osd_enable,audio_enabled,test_tone,
    input wire [1:0] brightness,master_volume,bgm_volume,sfx_volume,
    input wire [4:0] audition_id,
    input wire audio_available,audio_error,
    input wire [15:0] audio_underruns,audio_dropped,
    input wire [1:0] contrast,transition_mode,
    input wire assets_ready,image_ready,
    input wire [6:0] image_index,image_count,input wire [2:0] cache_count,
    output reg hs_o,vs_o,de_o,output reg [23:0] rgb_o);
    reg vd,dd;
    reg [9:0] sx,sy;
    wire [9:0] x=dd?sx:10'd0;
    always @(posedge clk or posedge rst)
        if(rst) begin vd<=0;dd<=0;sx<=0;sy<=0;end
        else begin
            vd<=vs;dd<=de;sx<=de?x+1'b1:0;
            if(vs&&!vd)sy<=0;else if(dd&&!de)sy<=sy+1'b1;
        end
    function [255:0] message(input integer id);
        begin case(id)
            0:message="1KHZ TEST TONE: OFF";
            1:message="BOOT MULTIMEDIA LAB";
            2:message="TF BMP ASSET LAB";
            3:message="DISPLAY SETTINGS";
            4:message="AUDIO SETTINGS";
            5:message="RESTART THIS RUN?";
            6:message="RESUME";
            7:message="DEBUG / TF IMAGE PREVIEW";
            8:message="DISPLAY";
            9:message="AUDIO";
            10:message="NAME AND AVATAR";
            11:message="LEADERBOARD";
            12:message="RESTART";
            13:message="GAME VIEW: WIDE / FULL SCREEN";
            14:message="PALETTE: ORIGINAL";
            15:message="HDMI TEST PATTERN: OFF";
            16:message="BRIGHTNESS: 0";
            17:message="CONTRAST: NORMAL";
            18:message="TRANSITION: CUT";
            19:message="RESET DISPLAY SETTINGS";
            20:message="AUDIO: OFF";
            21:message="MASTER VOLUME: 3";
            22:message="BGM VOLUME: 2";
            23:message="SFX VOLUME: 3";
            24:message="SOUND ID HEX:01";
            25:message="PLAY SELECTED SOUND";
            26:message="K2/K3 SELECT - K1 CHANGE";
            27:message="K4 CONFIRM - K1 CANCEL";
            28:message="SW2 TEXT/SCOPE - K4 NAME";
            29:message="K2 PREV K3 NEXT K1 AUTO";
            30:message="IMG:00/00 CACHE:0 ATLAS:WAIT";
            31:message="SD PCM: W UNDER:0000 DROP:0000";
            default:message=0;
        endcase end
    endfunction
    reg [7:0] text_rom[0:1023];
    reg [255:0] init_line;
    integer n,j,first;
    initial begin
        for(n=0;n<32;n=n+1)begin
            init_line=message(n);first=-1;
            for(j=31;j>=0;j=j-1)if(init_line[j*8+:8]!=0 && first==-1)first=j;
            for(j=0;j<32;j=j+1)
                if(j<=first)text_rom[n*32+j]=init_line[(first-j)*8+:8];
                else text_rom[n*32+j]=32;
        end
    end
    reg [4:0] msg;
    wire [4:0] column=(x-10'd192)>>3;
    reg panel,text_on,selected;
    reg [2:0] row;
    reg [7:0] dynamic_char;
    reg dynamic_on;
    wire preview=debug_mode&&page==1;
    function [7:0] digit(input [3:0] value);
        begin digit=value<10?"0"+value:"A"+value-10;end
    endfunction
    always @* begin
        msg=0;panel=0;text_on=0;selected=0;row=0;
        dynamic_char=32;dynamic_on=0;
        if(active) begin
            panel=preview?(x>=144&&x<496&&((sy>=80&&sy<112)||(sy>=424&&sy<448))):
                (x>=176&&x<464&&sy>=104&&sy<344);
            if(x>=192&&x<448) begin
                if((!preview&&sy>=120&&sy<128)||(preview&&sy>=88&&sy<96))begin
                    text_on=1;msg=page==1?2:page==2?3:page==3?4:page==4?5:1;
                end
                if(!preview&&sy>=152&&sy<264)begin
                    row=(sy-152)>>4;selected=row==selection;text_on=!sy[3];
                    if(page==0)msg=6+row;
                    else if(page==2)msg=13+row;
                    else if(page==3)msg=row==6?0:20+row;
                    else begin text_on=0;selected=0;end
                end
                if(page==3&&sy>=272&&sy<280)begin text_on=1;msg=31;end
                if((!preview&&sy>=296&&sy<304)||(preview&&sy>=88&&sy<96))begin
                    text_on=1;msg=page==1?29:page==4?27:26;
                end
                if((!preview&&sy>=312&&sy<320)||(preview&&sy>=432&&sy<440))begin
                    text_on=1;msg=page==1?30:28;
                end
                case(msg)
                    0:if(column>=17)begin
                        dynamic_on=1;
                        case(column)
                            17:dynamic_char=test_tone?"N":"F";
                            18:dynamic_char=test_tone?32:"F";
                            default:dynamic_char=32;
                        endcase
                    end
                    13:if(column>=11&&column<=14&&view_narrow)begin
                        dynamic_on=1;
                        dynamic_char="ZOOM" >> ((14-column)*8);
                    end
                    17:if(column>=10)begin
                        dynamic_on=1;
                        case(contrast)
                            1:dynamic_char=column<18?"LOW     " >> ((17-column)*8):32;
                            2:dynamic_char=column<18?"HIGH    " >> ((17-column)*8):32;
                            3:dynamic_char=column<18?"MAX     " >> ((17-column)*8):32;
                            default:dynamic_char=column<18?"NORMAL  " >> ((17-column)*8):32;
                        endcase
                    end
                    18:if(column>=12)begin
                        dynamic_on=1;
                        dynamic_char=column<16?(transition_mode==1?"FADE":transition_mode==2?"WIPE":"CUT ") >> ((15-column)*8):32;
                    end
                    14:if(column>=9&&column<18&&palette_mode)begin
                        dynamic_on=1;dynamic_char="QUANTIZED" >> ((17-column)*8);
                    end
                    15,20:begin
                        if(column>=(msg==20?7:19))begin
                            dynamic_on=1;
                            case(column-(msg==20?7:19))
                                0:dynamic_char="O";
                                1:dynamic_char=(msg==20?audio_enabled:calibration)?"N":"F";
                                2:dynamic_char=(msg==20?audio_enabled:calibration)?32:"F";
                                default:dynamic_char=32;
                            endcase
                        end
                    end
                    16:if(column==12)begin dynamic_on=1;dynamic_char=digit({2'd0,brightness});end
                    21:if(column==15)begin dynamic_on=1;dynamic_char=digit({2'd0,master_volume});end
                    22,23:if(column==12)begin dynamic_on=1;dynamic_char=digit({2'd0,msg==22?bgm_volume:sfx_volume});end
                    24:if(column==13||column==14)begin dynamic_on=1;dynamic_char=column==13?digit({3'd0,audition_id[4]}):digit(audition_id[3:0]);end
                    31:begin
                        if(column==8)begin dynamic_on=1;dynamic_char=audio_error?"E":audio_available?"R":"W";end
                        if(column>=16&&column<20)begin dynamic_on=1;dynamic_char=digit(audio_underruns>>((19-column)*4));end
                        if(column>=26&&column<30)begin dynamic_on=1;dynamic_char=digit(audio_dropped>>((29-column)*4));end
                    end
                    30:begin
                        if(column==4||column==5||column==7||column==8||column==16)begin
                            dynamic_on=1;
                            case(column)
                                4:dynamic_char=digit(image_index/10);5:dynamic_char=digit(image_index%10);
                                7:dynamic_char=digit(image_count/10);8:dynamic_char=digit(image_count%10);
                                16:dynamic_char=digit({1'b0,cache_count});
                            endcase
                        end
                        if(column>=24&&column<28)begin dynamic_on=1;
                            dynamic_char=(assets_ready?"OK  ":image_ready?"BAD ":"WAIT") >> ((27-column)*8);
                        end
                    end
                endcase
            end
        end
    end
    reg [23:0] color;
    always @* begin
        color=rgb;
        if(calibration) begin
            color={x[7:0],sy[7:0],8'h5a};
            if(x[5:0]==0||sy==120||sy==240||sy==360)color=24'h808080;
            if(x<8)color=24'hff0000;else if(x>=632)color=24'h00ff00;
            if(sy<8)color=24'h0000ff;else if(sy>=472)color=24'hffff00;
        end
        if(panel)color={1'b0,color[23:17],1'b0,color[15:9],1'b0,color[7:1]};
        if(panel&&selected&&sy>=152&&sy<264)color=24'h244c78;
    end
    reg [7:0] rom_char,char1;
    reg hs1,vs1,de1,text1,dynamic1;
    reg [23:0] color1;
    reg [2:0] gx1,gy1;
    always @(posedge clk)rom_char<=text_rom[{msg,column}];
    wire [4:0] glyph;
    osd_font font(dynamic1?char1:rom_char,gy1,glyph);
    always @(posedge clk or posedge rst)
        if(rst)begin
            hs1<=0;vs1<=0;de1<=0;text1<=0;dynamic1<=0;color1<=0;gx1<=0;gy1<=0;char1<=32;
            hs_o<=0;vs_o<=0;de_o<=0;rgb_o<=0;
        end else begin
            hs1<=hs;vs1<=vs;de1<=de;text1<=text_on;dynamic1<=dynamic_on;
            color1<=color;gx1<=x[2:0];gy1<=sy[2:0];char1<=dynamic_char;
            hs_o<=hs1;vs_o<=vs1;de_o<=de1;
            rgb_o<=!de1?24'd0:text1&&gx1<5&&glyph[4-gx1]?24'hffffff:color1;
        end
endmodule

// All enables are compile-time resource profiles; default integrates all effects.
// One shared raster coordinate, pipelined together with pixel data and sync.
module advanced_video #(
    parameter TEXT=1, COLOR=1, SCOPE=1, TRANSITION=1, DIRECT_CONTROLS=0, LAB_UI=0,
    parameter CLOCK_HZ=25_000_000, DEBOUNCE=500_000, LONG_PRESS=25_000_000
)(
    input wire clk,rst,hs,vs,de,input wire [23:0] rgb,
    input wire image_valid,key_menu,overlay_sw,wave_sw,
    input wire [1:0] brightness_sw,
    input wire [4:0] fade_gain,
    input wire pcm_valid,input wire signed [23:0] pcm,
    output reg hs_o,vs_o,de_o,output reg [23:0] rgb_o,
    output wire wipe_mode,
    output wire [1:0] requested_mode,
    input wire [1:0] effect_mode,
    input wire audio_enabled,
    input wire [2:0] cache_count,
    input wire [6:0] image_index,image_count,
    input wire [1:0] control_contrast,control_transition
);
    reg vs_d,de_d;reg [9:0] x,y;
    wire frame_tick=vs&&!vs_d;
    wire [9:0] px=de_d?x:10'd0;
    wire [1:0] brightness,contrast;wire overlay,wave;
    wire [15:0] timestamp;
    video_controls #(.CLOCK_HZ(CLOCK_HZ),.DEBOUNCE(DEBOUNCE),.LONG_PRESS(LONG_PRESS),.DIRECT(DIRECT_CONTROLS)) controls(clk,rst,frame_tick,key_menu,brightness_sw,overlay_sw,wave_sw,
        brightness,contrast,overlay,wave,requested_mode,timestamp,control_contrast,control_transition);
    assign wipe_mode=effect_mode==2;
    // Status is informational; synchronize in the parent, then snapshot at VS.
    reg sound;
    reg [2:0] cached;
    reg [6:0] picture,total;
    always @(posedge clk or posedge rst)
        if(rst) begin sound<=0;cached<=0;picture<=0;total<=0;end
        else if(frame_tick) begin
            sound<=audio_enabled;cached<=cache_count;picture<=image_index;total<=image_count;
        end
    reg [9:0] scroll;
    reg scroll_half;
    always @(posedge clk or posedge rst) begin
        if(rst) begin x<=0;y<=0;vs_d<=0;de_d<=0;scroll<=640;scroll_half<=0;end
        else begin
            vs_d<=vs;de_d<=de;
            if(frame_tick) begin
                y<=0;scroll_half<=!scroll_half;
                if(scroll_half) scroll<=scroll==895?0:scroll+1'b1;
            end else if(de_d&&!de) y<=y+1'b1;
            x<=de?px+1'b1:10'd0;
        end
    end
    function [7:0] color_adjust;
        input [7:0] c;input [1:0] b,k;
        reg signed [11:0] v;
        begin
            v=$signed({1'b0,c})-12'sd128;
            case(k) 1:v=v>>>1;2:v=v+(v>>>1);3:v=v<<<1;endcase
            v=v+12'sd128;
            case(b) 1:v=v+12'sd32;2:v=v+12'sd64;3:v=v-12'sd32;endcase
            color_adjust = v < 12'sd0 ? 8'd0 : (v > 12'sd255 ? 8'd255 : v[7:0]);
        end
    endfunction
    reg [23:0] adjusted;
    reg [9:0] x1,y1,scroll1;
    reg hs1,vs1,de1;
    always @(posedge clk or posedge rst) begin
        if(rst) begin adjusted<=0;x1<=0;y1<=0;hs1<=0;vs1<=0;de1<=0;scroll1<=0;end
        else begin
            adjusted<=de&&image_valid ? (COLOR ?
                {color_adjust(rgb[23:16],brightness,contrast),color_adjust(rgb[15:8],brightness,contrast),
                 color_adjust(rgb[7:0],brightness,contrast)} : rgb) : 24'd0;
            x1<=px;y1<=y;hs1<=hs;vs1<=vs;de1<=de;scroll1<=scroll;
        end
    end
    // Gain is 0..16. Three small products, followed by a register.
    wire [12:0] rprod=adjusted[23:16]*fade_gain;
    wire [12:0] gprod=adjusted[15:8]*fade_gain;
    wire [12:0] bprod=adjusted[7:0]*fade_gain;
    reg [23:0] transitioned;
    reg [9:0] x2,y2,scroll2;reg hs2,vs2,de2;
    always @(posedge clk or posedge rst) begin
        if(rst) begin transitioned<=0;x2<=0;y2<=0;scroll2<=0;hs2<=0;vs2<=0;de2<=0;end
        else begin
            transitioned<=!TRANSITION || effect_mode==0 ? adjusted : wipe_mode ?
                (x1 < fade_gain*10'd40 ? adjusted : 24'd0) : {rprod[11:4],gprod[11:4],bprod[11:4]};
            x2<=x1;y2<=y1;scroll2<=scroll1;hs2<=hs1;vs2<=vs1;de2<=de1;
        end
    end
    wire signed [7:0] sample;wire [7:0] peak;wire scope_valid;
    wire [5:0] sample_index=(x2-10'd64)>>3;
    generate if(SCOPE) begin: scope_on
        audio_scope scope(clk,rst,frame_tick,pcm_valid,pcm,sample_index,sample,peak,scope_valid);
    end else begin:scope_off
        assign sample=0;assign peak=0;assign scope_valid=0;
    end endgenerate
    wire signed [10:0] wave_y=11'sd352-($signed(sample)>>>1);
    wire signed [10:0] amplified=$signed(sample)*11'sd2;
    wire signed [10:0] lab_wave_y=11'sd352-(amplified>60?11'sd60:amplified< -60?-11'sd60:amplified);
    wire signed [10:0] wave_distance=$signed({1'b0,y2})-lab_wave_y;
    wire panel=TEXT&&overlay&&x2>=8&&x2<304&&y2>=8&&y2<56;
    wire caption=TEXT&&overlay&&y2>=448&&y2<472;
    wire wave_area=SCOPE&&wave&&x2>=64&&x2<576&&y2>=288&&y2<417;
    reg [7:0] ch;
    reg [2:0] glyph_row,glyph_col;
    reg text_area;
    reg [10:0] scroll_coord;
    reg [255:0] message;
    always @* begin
        ch=32;glyph_row=0;glyph_col=0;text_area=0;scroll_coord={1'b0,x2}+scroll2;
        message="EG4S20 HDMI MULTIMEDIA PLAYER   ";
        if(panel && y2>=12 && y2<20 && x2>=16 && x2<104) begin
            text_area=1;glyph_row=y2-12;glyph_col=x2[2:0];
            case((x2-16)>>3)
                0:ch="T";1:ch="I";2:ch="M";3:ch="E";4:ch=32;
                5:ch=48+timestamp[15:12];6:ch=48+timestamp[11:8];7:ch=":";
                8:ch=48+timestamp[7:4];9:ch=48+timestamp[3:0];
            endcase
        end
        if(panel && y2>=28 && y2<36 && x2>=16 && x2<288) begin
            text_area=1;glyph_row=y2-28;glyph_col=x2[2:0];
            case((x2-16)>>3)
                0:ch="B";1:ch=brightness==3?"-":"+";
                2:ch=brightness==0?"0":brightness==2?"6":"3";
                3:ch=brightness==0?"0":brightness==2?"4":"2";
                5:ch="C";6:ch=contrast==1?"0":contrast==3?"2":"1";
                7:ch=(contrast==1||contrast==2)?"5":"0";8:ch="0";9:ch="%";
                11:ch=requested_mode==0?"C":requested_mode==2?"W":"F";
                12:ch=requested_mode==0?"U":requested_mode==2?"I":"A";
                13:ch=requested_mode==0?"T":requested_mode==2?"P":"D";
                14:ch=requested_mode==0?32:"E";
                16:ch="S";17:ch="O";18:ch="U";19:ch="N";20:ch="D";
                22:ch="O";23:ch=sound?"N":"F";24:ch=sound?32:"F";
            endcase
        end
        if(panel && y2>=44 && y2<52 && x2>=16 && x2<224) begin
            text_area=1;glyph_row=y2-44;glyph_col=x2[2:0];
            case((x2-16)>>3)
                0:ch="C";1:ch="A";2:ch="C";3:ch="H";4:ch="E";
                6:ch=48+cached;7:ch="/";8:ch=48+(total<4?total:7'd4);
                10:ch="I";11:ch="M";12:ch="G";
                14:ch=48+picture/10;15:ch=48+picture%10;16:ch="/";
                17:ch=48+total/10;18:ch=48+total%10;
            endcase
        end
        if(caption && y2>=456 && y2<464 && scroll_coord>=640 && scroll_coord<896) begin
            text_area=1;glyph_row=y2-456;glyph_col=scroll_coord[2:0];
            ch=message >> ((31-((scroll_coord-640)>>3))*8);
        end
        if(LAB_UI&&SCOPE&&wave&&x2>=64&&x2<576&&y2>=272&&y2<280)begin
            text_area=1;glyph_row=y2-272;glyph_col=x2[2:0];
            message=x2<320?{"PCM 48KHZ - GAIN X2",{13{8'h20}}}:
                {"64 SAMPLES: 1.33MS",{14{8'h20}}};
            ch=message >> ((31-((x2-(x2<320?64:320))>>3))*8);
        end
        if(LAB_UI&&SCOPE&&wave&&x2>=64&&x2<128&&y2>=408&&y2<416)begin
            text_area=1;glyph_row=y2-408;glyph_col=x2[2:0];message="LEVEL                           ";
            ch=message >> ((31-((x2-64)>>3))*8);
        end
    end
    wire [4:0] glyph;
    osd_font font(ch,glyph_row,glyph);
    wire ink=text_area&&glyph_col<5&&glyph[4-glyph_col];
    function [23:0] half_blend;
        input [23:0] a,b;
        reg [8:0] r,g,bl;
        begin
            r={1'b0,a[23:16]}+{1'b0,b[23:16]};g={1'b0,a[15:8]}+{1'b0,b[15:8]};bl={1'b0,a[7:0]}+{1'b0,b[7:0]};
            half_blend={r[8:1],g[8:1],bl[8:1]};
        end
    endfunction
    reg [23:0] composed;
    always @* begin
        composed=transitioned;
        if(wave_area) begin
            composed=half_blend(composed,24'h002020);
            if(y2==352) composed=24'h305050;
            if(LAB_UI)begin
                if(x2[5:0]==0||y2==320||y2==384)composed=24'h244048;
                if(y2==352)composed=24'h709090;
                if(scope_valid&&y2<408&&wave_distance>=-1&&wave_distance<=1)composed=24'h20ff60;
                if(y2>=408)composed=x2>=136&&x2<136+{peak,2'b00}?
                    (peak>100?24'hff4040:24'h20dc70):24'h103028;
            end else begin
                if(scope_valid && $signed({1'b0,y2})==wave_y) composed=24'h20ff60;
                if(y2>=408 && x2<64+{peak,2'b00}) composed=24'hffb020;
            end
        end
        if(panel) composed=half_blend(composed,24'h101828);
        if(caption) composed=half_blend(composed,24'h002040);
        if(ink) composed=24'hffffff;
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin rgb_o<=0;hs_o<=0;vs_o<=0;de_o<=0;end
        else begin rgb_o<=de2?composed:24'd0;hs_o<=hs2;vs_o<=vs2;de_o<=de2;end
    end
endmodule

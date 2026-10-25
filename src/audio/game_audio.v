// Original four-voice chip melody and event voices. All synthesis advances on 48 kHz ticks.
module game_audio(input wire clk, rst, sample_tick, play_enable, paused,
    input wire [3:0] event_code, input wire mute,
    output reg signed [23:0] pcm);
    reg [23:0] phase_a, phase_b, phase_t, phase_fx;
    reg [13:0] beat;
    reg [4:0] note;
    reg [15:0] noise;
    reg [13:0] fx_left;
    reg [3:0] fx_kind;
    reg [23:0] pitch;
    reg [13:0] event_length;
    reg [23:0] fx_pitch;
    always @* begin
        case(event_code)
            1:event_length=14'd2600;
            2:event_length=14'd4600;
            3:event_length=14'd3400;
            4:event_length=14'd9600;
            5:event_length=14'd7200;
            6:event_length=14'd12000;
            7:event_length=14'd7600;
            8:event_length=14'd1800;
            9:event_length=14'd5800;
            10:event_length=14'd4200;
            11:event_length=14'd10400;
            12:event_length=14'd2200;
            13:event_length=14'd9000;
            14:event_length=14'd7600;
            15:event_length=14'd3000;
            default:event_length=0;
        endcase
        case(fx_kind)
            1:fx_pitch=24'd140000+{7'd0,(14'd9600-fx_left),3'b0};
            2:fx_pitch=24'd366000;
            3:fx_pitch=24'd110000;
            4:fx_pitch=24'd155000-{9'd0,fx_left,1'b0};
            5:fx_pitch=24'd100000+{6'd0,(14'd9600-fx_left),4'b0};
            6:fx_pitch=24'd230000;
            7:fx_pitch=24'd175000+{8'd0,(14'd9600-fx_left),2'b0};
            8:fx_pitch=24'd68000;
            9:fx_pitch=24'd94000;
            10:fx_pitch=24'd191000;
            11:fx_pitch=24'd310000;
            12:fx_pitch=24'd275000;
            13:fx_pitch=24'd123000;
            14:fx_pitch=24'd175000+{8'd0,(14'd9600-fx_left),2'b0};
            15:fx_pitch=24'd68000;
            default:fx_pitch=0;
        endcase
    end
    wire signed [23:0] square_a = phase_a[23] ? 24'sd360000 : -24'sd360000;
    wire signed [23:0] square_b = phase_b[23] ? 24'sd180000 : -24'sd180000;
    wire [7:0] triangle = phase_t[23] ? ~phase_t[22:15] : phase_t[22:15];
    wire signed [23:0] tri_voice = ($signed({1'b0,triangle}) - 24'sd128) <<< 10;
    reg signed [23:0] fx_voice;
    always @* begin
        fx_voice=24'sd0;
        if(fx_left!=0) begin
            case(fx_kind)
                1: fx_voice=phase_fx[23] ? 24'sd330000 : -24'sd330000; // jump
                2: fx_voice=phase_fx[23] ? 24'sd260000 : -24'sd260000; // coin
                3: fx_voice=noise[0] ? 24'sd430000 : -24'sd430000; // stomp
                4: fx_voice=phase_fx[22] ? 24'sd500000 : -24'sd500000; // death
                5: fx_voice=phase_fx[23] ? 24'sd300000 : -24'sd300000; // start
                6: fx_voice=phase_fx[21] ? 24'sd420000 : -24'sd420000; // clear
                7: fx_voice=phase_fx[22] ? 24'sd360000 : -24'sd360000; // powerup
                8: fx_voice=phase_fx[20] ? 24'sd300000 : -24'sd300000; // block
                9: fx_voice=phase_fx[19] ? 24'sd440000 : -24'sd440000; // hurt
                10: fx_voice=phase_fx[21] ? 24'sd320000 : -24'sd320000; // flag
                11: fx_voice=phase_fx[22] ? 24'sd470000 : -24'sd470000; // 1up
                12: fx_voice=phase_fx[20] ? 24'sd390000 : -24'sd390000; // fire
                13: fx_voice=noise[2] ? 24'sd360000 : -24'sd360000; // star
                14: fx_voice=phase_fx[22] ? 24'sd360000 : -24'sd360000; // item emerge
                15: fx_voice=noise[0] ? 24'sd430000 : -24'sd430000; // brick debris
                default: fx_voice=0;
            endcase
        end
    end
    always @* begin
        // C-major phrase, 32 eighth notes at 120 beats/minute.
        case(note)
            0,4,12,16,24,28: pitch=24'd91435;
            1,5,13,17,25: pitch=24'd115201;
            2,6,10,18,22,26: pitch=24'd137001;
            3,7,11,19,23,27: pitch=24'd182869;
            8,20: pitch=24'd102629;
            9,21: pitch=24'd122053;
            14,29: pitch=24'd153781;
            default: pitch=24'd137001;
        endcase
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            phase_a<=0; phase_b<=0; phase_t<=0; phase_fx<=0;
            beat<=0; note<=0; noise<=16'hace1; fx_left<=0; fx_kind<=0; pcm<=0;
        end else begin
            // Capture frame events even when they do not coincide with a sample.
            if(event_length!=0 && !paused) begin
                fx_kind<=event_code; fx_left<=event_length;
            end
            if(sample_tick) begin
                if(paused || mute) pcm<=0;
                else pcm<=(play_enable ? square_a+square_b+tri_voice : 24'sd0)+fx_voice;
                if(!paused) begin
                    if(play_enable) begin
                        phase_a<=phase_a+pitch;
                        phase_b<=phase_b+(pitch>>1);
                        phase_t<=phase_t+(pitch>>2);
                        if(beat==11999) begin beat<=0; note<=note+1'b1; end else beat<=beat+1'b1;
                    end
                    noise<={noise[14:0],noise[15]^noise[13]^noise[12]^noise[10]};
                    phase_fx<=phase_fx+fx_pitch;
                    if(fx_left!=0 && event_code==0) fx_left<=fx_left-1'b1;
                end
                if(!play_enable) begin beat<=0; note<=0; end
            end
        end
    end
endmodule

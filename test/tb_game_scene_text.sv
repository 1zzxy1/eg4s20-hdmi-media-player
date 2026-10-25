`timescale 1ns/1ps
module tb_game_scene_text;
    reg clk=0;
    reg [4:0] message_id=31,column=0;
    wire [7:0] character;
    reg [7:0] previous;
    reg [255:0] expected;
    integer m,c;
    game_scene_text dut(.*);
    always #5 clk=~clk;
    initial begin
        @(posedge clk);#1;
        for(m=0;m<32;m=m+1)begin
            // Independently retained UI copy; unassigned ROM rows are spaces.
            case(m)
                0:expected="MARIO     COIN    WORLD   TIME  ";
                1:expected="LOADING TF GAME ATLAS           ";
                2:expected="                                ";
                3:expected="CREATE YOUR PLAYER              ";
                4:expected="GAME OVER                       ";
                5:expected="TRY AGAIN                       ";
                6:expected="LEVEL COMPLETE                  ";
                7:expected="LOCAL LEADERBOARD               ";
                8:expected="HOLD KEY4 1 SEC TO START        ";
                9:expected="K4 NAME - HOLD K4 TO START      ";
                10:expected="K4 CONTINUE  K1 BACK            ";
                11:expected="SAVING - KEEP POWER ON          ";
                12:expected="FLASH UNAVAILABLE - RAM SCORES  ";
                13:expected="LOCAL SCORES SAVED IN FLASH     ";
                14:expected="CHECKING SCORE STORAGE          ";
                15:expected="K2/K3 AVATAR - K4 START         ";
                16:expected="K2/K3 EDIT K4 NEXT K1 BACK      ";
                17:expected="                                ";
                18:expected="KEY3 LEFT KEY1 RIGHT KEY2 JUMP  ";
                19:expected="SW4 RUN FIRE - SW1 MUTE         ";
                20:expected="KEEP MOVING JUMP THE GAP        ";
                21:expected="THE FINISH IS NEAR              ";
                22:expected="DEBUG TF BMP ASSET PREVIEW      ";
                23:expected="SOUND ON  SW1 MUTES             ";
                24:expected="SOUND OFF SW1 UNMUTES           ";
                26:expected="EVENT 0  WORLD X 000            ";
                default:expected={32{8'h20}};
            endcase
            for(c=0;c<32;c=c+1)begin
                @(negedge clk);previous=character;message_id=m;column=c;
                #1;if(character!==previous)$fatal(1,"scene ROM changed before clock");
                @(posedge clk);#1;
                if(character!==expected[(31-c)*8+:8])$fatal(1,"scene ROM character row=%0d col=%0d",m,c);
            end
        end
        $display("PASS scene text: 1024 synchronous character reads, fixed UI copy and blank padding");
        $finish;
    end
    initial begin #20000;$fatal(1,"scene text timeout");end
endmodule

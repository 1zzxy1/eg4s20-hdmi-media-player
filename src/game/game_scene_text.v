// One synchronous 32x32 character ROM, aligned with the map-request stage.
module game_scene_text(input wire clk,input wire [4:0] message_id,column,
    output reg [7:0] character);
    function [255:0] message(input integer id);
        begin case(id)
            0:message="MARIO     COIN    WORLD   TIME  ";
            1:message="LOADING TF GAME ATLAS           ";
            2:message="                                ";
            3:message="CREATE YOUR PLAYER              ";
            4:message="GAME OVER                       ";
            5:message="TRY AGAIN                       ";
            6:message="LEVEL COMPLETE                  ";
            7:message="LOCAL LEADERBOARD               ";
            8:message="HOLD KEY4 1 SEC TO START        ";
            9:message="K4 NAME - HOLD K4 TO START      ";
            10:message="K4 CONTINUE  K1 BACK            ";
            11:message="SAVING - KEEP POWER ON          ";
            12:message="FLASH UNAVAILABLE - RAM SCORES  ";
            13:message="LOCAL SCORES SAVED IN FLASH     ";
            14:message="CHECKING SCORE STORAGE          ";
            15:message="K2/K3 AVATAR - K4 START         ";
            16:message="K2/K3 EDIT K4 NEXT K1 BACK      ";
            17:message="                                ";
            18:message="KEY3 LEFT KEY1 RIGHT KEY2 JUMP  ";
            19:message="SW4 RUN FIRE - KEY4 CONFIRM     ";
            20:message="KEEP MOVING JUMP THE GAP        ";
            21:message="THE FINISH IS NEAR              ";
            22:message="DEBUG TF BMP ASSET PREVIEW      ";
            23:message="SOUND ON - SW4 LOBBY AUDIO      ";
            24:message="SOUND OFF - SW4 LOBBY AUDIO     ";
            26:message="EVENT 0  WORLD X 000            ";
            default:message="                                ";
        endcase end
    endfunction
    reg [7:0] text_rom[0:1023];
    reg [255:0] init_line;
    integer n,j;
    initial begin
        for(n=0;n<32;n=n+1)begin
            init_line=message(n);
            for(j=0;j<32;j=j+1)text_rom[n*32+j]=init_line[(31-j)*8+:8];
        end
    end
    always @(posedge clk)character<=text_rom[{message_id,column}];
endmodule

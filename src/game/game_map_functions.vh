`include "game_assets.vh"
// Data-driven ground route for the Pixel Quest 1-1 recreation.
// Coordinates are logical pixels: 256x240 visible area, 16x16 tiles.
// Tile ids are shared by collision and the renderer.
function [6:0] map_tile;
    input [11:0] wx;
    input [8:0] wy;
    reg [7:0] tx;
    reg [4:0] ty;
    begin
        tx=wx[11:4];
        ty=wy[8:4];
        map_tile=`GAME_TILE_EMPTY;

        // Continuous floor with the characteristic early pits and later
        // gaps. The final two rows are solid.
        if(ty>=13 && ty<15 && tx<250 &&
           !((tx>=26&&tx<30)||(tx>=63&&tx<67)||(tx>=119&&tx<123)||
             (tx>=177&&tx<181)||(tx>=218&&tx<222)))
            map_tile=`GAME_TILE_GROUND;

        // Staircase and pipe-like solid structures.
        if((ty==12&&tx>=32&&tx<36)||(ty==11&&tx>=33&&tx<36)||
           (ty==10&&tx>=34&&tx<36)) map_tile=`GAME_TILE_BRICK;
        if((ty==12&&tx>=72&&tx<76)||(ty==11&&tx>=73&&tx<76)||
           (ty==10&&tx>=74&&tx<76)) map_tile=`GAME_TILE_BRICK;
        if((ty==12&&tx>=141&&tx<145)||(ty==11&&tx>=142&&tx<145)||
           (ty==10&&tx>=143&&tx<145)) map_tile=`GAME_TILE_BRICK;
        if((ty==12&&tx>=198&&tx<202)||(ty==11&&tx>=199&&tx<202)||
           (ty==10&&tx>=200&&tx<202)) map_tile=`GAME_TILE_BRICK;

        // Question/brick formations.
        if((ty==10&&tx>=10&&tx<=13)||(ty==9&&tx>=42&&tx<=46)||
           (ty==10&&tx>=58&&tx<=62)||(ty==9&&tx>=91&&tx<=95)||
           (ty==10&&tx>=126&&tx<=130)||(ty==9&&tx>=160&&tx<=164)||
           (ty==10&&tx>=187&&tx<=191)||(ty==9&&tx>=226&&tx<=230))
            map_tile=((tx==11)||(tx==43)||(tx==60)||(tx==92)||
                      (tx==128)||(tx==161)||(tx==189)||(tx==227)) ?
                     `GAME_TILE_QUESTION : `GAME_TILE_BRICK;

        // Low floating blocks around the first pipe and late bridge.
        if((ty==11&&(tx==21||tx==22||tx==51||tx==52||tx==108||tx==109||
                     tx==154||tx==155||tx==207||tx==208)) ||
           (ty==12&&(tx==21||tx==22||tx==51||tx==52||tx==108||tx==109||
                     tx==154||tx==155||tx==207||tx==208)))
            map_tile=`GAME_TILE_BRICK;

        // Castle approach and flag support.
        if((ty>=10&&ty<13&&tx>=242&&tx<249)||
           (ty==12&&tx>=234&&tx<242)) map_tile=`GAME_TILE_BRICK;
    end
endfunction

function map_solid;
    input [11:0] wx;
    input [8:0] wy;
    begin map_solid=(map_tile(wx,wy)!=`GAME_TILE_EMPTY);end
endfunction

function map_question;
    input [11:0] wx;
    input [8:0] wy;
    begin map_question=(map_tile(wx,wy)==`GAME_TILE_QUESTION);end
endfunction

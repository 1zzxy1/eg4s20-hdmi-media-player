`include "test/tb_game_sd_audio.sv"
// Reuse the identical public SD/arbiter/PCM endpoint with position-coded songs.
module tb_game_music;
    tb_game_sd_audio #(.LIFECYCLE(1)) scenario();
endmodule

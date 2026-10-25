// Five sector-buffered voices: looping BGM plus four round-robin SFX voices.
// PCM is signed mono s16le at 48 kHz. Only the SD bridge writes this dual-port RAM.
module sd_pcm_player(input wire clk,rst,sd_clk,sd_rst,initialized,sample_tick,
    input wire play_enable,star_mode,paused,mute,event_valid,input wire [4:0] event_id,
    input wire audition,input wire [4:0] audition_id,
    input wire [1:0] master_volume,bgm_volume,sfx_volume,
    output reg signed [23:0] pcm,output reg available,error,
    output reg [15:0] underruns,dropped_events,
    output wire sd_req,output wire [31:0] sd_addr,
    input wire [7:0] sd_data,input wire sd_valid,sd_end);
    // Five voices x two 256-sample sectors, with no unused RAM tail. Boot
    // metadata reuses the last voice's second bank before any voice is active.
    wire ram_we;wire [11:0] ram_wraddr;wire [15:0] ram_wrdata;
    reg [11:0] ram_addr;
    wire [15:0] bank_q[0:4];
    reg [2:0] ram_bank;
    genvar b;
    generate for(b=0;b<5;b=b+1)begin:voice_ram
        reg [15:0] samples[0:511];
        reg [15:0] q;
        always @(posedge sd_clk)
            if(ram_we&&ram_wraddr[11:9]==b)samples[ram_wraddr[8:0]]<=ram_wrdata;
        // Keep each synchronous read before the bank mux so TD infers five
        // 512x16 embedded memories, rather than rounding one RAM to 4096x16.
        always @(posedge clk)q<=samples[ram_addr[8:0]];
        assign bank_q[b]=q;
    end endgenerate
    always @(posedge clk)ram_bank<=ram_addr[11:9];
    wire [15:0] ram_q=ram_bank<5?bank_q[ram_bank]:16'd0;
    reg request_toggle;
    reg [31:0] request_lba;
    reg [11:0] request_dest;
    wire done_toggle,failed;
    audio_sector_bridge bridge(.sd_clk(sd_clk),.sd_rst(sd_rst),.initialized(initialized),
        .request_toggle(request_toggle),.request_lba(request_lba),.request_dest(request_dest),
        .done_toggle(done_toggle),.failed(failed),.sd_req(sd_req),.sd_addr(sd_addr),
        .sd_data(sd_data),.sd_valid(sd_valid),.sd_end(sd_end),
        .ram_we(ram_we),.ram_addr(ram_wraddr),.ram_data(ram_wrdata));
    (* ASYNC_REG="TRUE" *) reg [1:0] done_sync,init_sync;
    // Single-read descriptor RAM; copy metadata only when allocating a voice.
    // Avoid 24-way asynchronous multiport muxes in the real-time path.
    reg [41:0] descriptors[0:31];
    reg [41:0] descriptor_q,meta_temp;
    reg [4:0] descriptor_addr,descriptor_wraddr;
    reg descriptor_we;
    reg [16:0] voice_lba[0:4],bgm_lba,star_lba;
    reg [23:0] voice_length[0:4],bgm_length,star_length;
    reg [4:0] voice_loop;
    reg [1:0] allocate;
    reg audition_pending;
    always @(posedge clk)begin
        if(descriptor_we)descriptors[descriptor_wraddr]<=meta_temp;
        descriptor_q<=descriptors[descriptor_addr];
    end
    reg [31:0] pak_lba;
    reg [16:0] pak_sectors;
    reg [4:0] track[0:4];
    reg [23:0] position[0:4];
    reg [15:0] fill_sector[0:4];
    reg [7:0] generation[0:4];
    reg [4:0] active,audition_voice,read_bank,next_fill_bank;
    reg [9:0] bank_valid;
    reg [2:0] scan,fill_voice;
    reg fill_bank,fill_busy;
    reg [7:0] fill_generation;
    reg [3:0] boot;
    reg [7:0] meta_index;
    reg meta_bad;
    reg [2:0] voice,mix_state;
    reg signed [19:0] mix_sum;
    reg [1:0] next_voice;
    reg [5:0] queue[0:7];
    reg [2:0] qrd,qwr;
    reg [3:0] qcount;
    // Star is a BGM mode, not an additional SFX voice. Explicit audition still
    // plays its one-shot source without changing the paused game's BGM.
    wire enqueue=(event_valid&&!paused&&event_id!=13)||audition;
    wire [5:0] incoming=audition?{1'b1,audition_id}:{1'b0,event_id};
    wire [4:0] queued_id=queue[qrd][4:0];
    wire [2:0] victim={1'b0,next_voice}+3'd1;
    wire [4:0] meta_track=meta_index[7:3]-5'd2;
    wire [16:0] meta_sectors={1'b0,meta_temp[40:25]}+(|meta_temp[24:17]);
    wire playable=active[voice]&&(!paused||audition_voice[voice])&&(voice!=0||play_enable);
    wire current_ready=bank_valid[voice*2+read_bank[voice]];
    wire signed [19:0] sample_extended={{4{ram_q[15]}},ram_q};
    function signed [19:0] volume;
        input signed [19:0] value;input [1:0] level;
        begin case(level)0:volume=0;1:volume=value>>>2;2:volume=value>>>1;default:volume=value;endcase end
    endfunction
    wire signed [19:0] output_level=volume(mix_sum,master_volume);
    wire [4:0] bgm_track=star_mode?5'd13:5'd0;
    wire [16:0] selected_lba=star_mode?star_lba:bgm_lba;
    wire [23:0] selected_length=star_mode?star_length:bgm_length;
    integer k;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            done_sync<=0;init_sync<=0;request_toggle<=0;request_lba<=0;request_dest<=0;
            available<=0;error<=0;underruns<=0;dropped_events<=0;pcm<=0;
            boot<=0;meta_index<=0;meta_bad<=0;pak_lba<=0;pak_sectors<=0;voice_loop<=0;
            meta_temp<=0;descriptor_addr<=0;descriptor_wraddr<=0;descriptor_we<=0;
            bgm_lba<=0;bgm_length<=0;star_lba<=0;star_length<=0;allocate<=0;audition_pending<=0;
            active<=0;audition_voice<=0;read_bank<=0;next_fill_bank<=0;bank_valid<=0;scan<=0;fill_busy<=0;
            fill_voice<=0;fill_bank<=0;fill_generation<=0;
            ram_addr<=0;voice<=0;mix_state<=0;mix_sum<=0;next_voice<=0;
            qrd<=0;qwr<=0;qcount<=0;
            for(k=0;k<5;k=k+1)begin track[k]<=0;position[k]<=0;fill_sector[k]<=0;generation[k]<=0;voice_lba[k]<=0;voice_length[k]<=0;end
        end else begin
            descriptor_we<=0;
            done_sync<={done_sync[0],done_toggle};init_sync<={init_sync[0],initialized};
            case(boot)
                0:if(init_sync[1])begin
                    request_lba<=1;request_dest<=12'd2304;request_toggle<=!request_toggle;boot<=1;
                end
                1:if(done_sync[1]==request_toggle)begin
                    if(failed)begin error<=1;boot<=7;end
                    else begin meta_index<=0;boot<=2;end
                end
                2:begin ram_addr<=12'd2304+meta_index;boot<=3;end
                3:boot<=4;
                4:begin
                    case(meta_index)
                        0:if(ram_q!=16'h5046)meta_bad<=1;
                        1:if(ram_q!=16'h4147)meta_bad<=1;
                        2:if(ram_q!=16'h4455)meta_bad<=1;
                        3:if(ram_q!=16'h2131)meta_bad<=1;
                        4:if(ram_q!=16'd48000)meta_bad<=1;
                        5:if(ram_q!=0)meta_bad<=1;
                        6:if(ram_q!=24)meta_bad<=1;
                        7:if(ram_q!=1)meta_bad<=1;
                        8:pak_lba[15:0]<=ram_q;
                        9:begin pak_lba[31:16]<=ram_q;if(ram_q>1)meta_bad<=1;end
                        10:pak_sectors[15:0]<=ram_q;
                        11:begin pak_sectors[16]<=ram_q[0];if(ram_q>1)meta_bad<=1;end
                    endcase
                    if(meta_index>=16&&meta_index<208)begin
                        case(meta_index[2:0])
                            0:meta_temp[15:0]<=ram_q;
                            1:begin meta_temp[16]<=ram_q[0];if(ram_q>1)meta_bad<=1;end
                            2:meta_temp[32:17]<=ram_q;
                            3:begin meta_temp[40:33]<=ram_q[7:0];if(ram_q[15:8]!=0)meta_bad<=1;end
                            4:begin meta_temp[41]<=ram_q[0];if(ram_q!=(meta_track==0?1:0))meta_bad<=1;end
                            5:begin
                                if(ram_q!={11'd0,meta_track}||meta_temp[40:17]==0||
                                   meta_temp[16:0]==0||
                                   {1'b0,meta_temp[16:0]}+{1'b0,meta_sectors}>{1'b0,pak_sectors})meta_bad<=1;
                                descriptor_wraddr<=meta_track;descriptor_we<=1;
                                if(meta_track==0)begin bgm_lba<=meta_temp[16:0];bgm_length<=meta_temp[40:17];end
                                if(meta_track==13)begin star_lba<=meta_temp[16:0];star_length<=meta_temp[40:17];end
                            end
                            6,7:if(ram_q!=0)meta_bad<=1;
                        endcase
                    end
                    if(meta_index==255)boot<=5;
                    else begin meta_index<=meta_index+1'b1;boot<=2;end
                end
                5:begin
                    available<=!meta_bad&&pak_lba!=0&&pak_sectors!=0&&pak_lba+pak_sectors<=131072;
                    error<=meta_bad||pak_lba==0||pak_sectors==0||pak_lba+pak_sectors>131072;boot<=7;
                end
            endcase
            if(available)begin
                // One outstanding sector; bus payload is stable until acknowledgement.
                if(fill_busy)begin
                    if(done_sync[1]==request_toggle)begin
                        fill_busy<=0;
                        if(failed)begin error<=1;available<=0;active<=0;bank_valid<=0;pcm<=0;end
                        else if(fill_generation==generation[fill_voice])
                            bank_valid[fill_voice*2+fill_bank]<=1;
                    end
                end else begin
                    scan<=scan==4?0:scan+1'b1;
                    if(active[scan]&&!bank_valid[scan*2+next_fill_bank[scan]]&&
                       {fill_sector[scan],8'b0}<voice_length[scan])begin
                        request_lba<=pak_lba+voice_lba[scan]+fill_sector[scan];
                        request_dest<={scan,next_fill_bank[scan],8'b0};
                        request_toggle<=!request_toggle;fill_busy<=1;
                        fill_voice<=scan;fill_bank<=next_fill_bank[scan];fill_generation<=generation[scan];
                        next_fill_bank[scan]<=!next_fill_bank[scan];
                        if(voice_loop[scan]&&({fill_sector[scan],8'b0}+24'd256>=voice_length[scan]))
                            fill_sector[scan]<=0;
                        else fill_sector[scan]<=fill_sector[scan]+1'b1;
                    end
                end
                case(mix_state)
                    0:if(sample_tick)begin voice<=0;mix_sum<=0;mix_state<=1;end
                    1:begin
                        if(playable&&current_ready)begin
                            ram_addr<={voice,read_bank[voice],position[voice][7:0]};mix_state<=2;
                        end else begin
                            if(playable&&!current_ready&&underruns!=65535)underruns<=underruns+1'b1;
                            if(voice==4)mix_state<=5;else voice<=voice+1'b1;
                        end
                    end
                    2:mix_state<=3;
                    3:begin
                        mix_sum<=mix_sum+volume(sample_extended,voice==0?bgm_volume:sfx_volume);
                        if(position[voice][7:0]==255||position[voice]+1>=voice_length[voice])begin
                            bank_valid[voice*2+read_bank[voice]]<=0;
                            read_bank[voice]<=!read_bank[voice];
                        end
                        if(position[voice]+1>=voice_length[voice])begin
                            if(voice_loop[voice])begin
                                position[voice]<=0;
                            end else active[voice]<=0;
                        end else position[voice]<=position[voice]+1'b1;
                        if(voice==4)mix_state<=5;else begin voice<=voice+1'b1;mix_state<=1;end
                    end
                    5:begin
                        if(mute)pcm<=0;
                        else if(output_level>20'sd32767)pcm<=24'h7fff00;
                        else if(output_level< -20'sd32768)pcm<=24'h800000;
                        else pcm<={output_level[15:0],8'b0};
                        mix_state<=0;
                    end
                endcase
                // Muting never changes track position. Menu pause freezes game
                // voices while explicit auditions may play over the frozen scene.
                if(mute)pcm<=0;
                // Only change BGM between samples. Death/flag/restart stops
                // voice zero but leaves the game's ending SFX free to finish.
                // Generation rejects any sector still arriving for the old song.
                if(mix_state==0&&!play_enable&&active[0])begin
                    active[0]<=0;bank_valid[1:0]<=0;
                    generation[0]<=generation[0]+1'b1;
                end else if(mix_state==0&&play_enable&&selected_length!=0&&
                            (!active[0]||track[0]!=bgm_track))begin
                    active[0]<=1;track[0]<=bgm_track;position[0]<=0;fill_sector[0]<=0;
                    voice_lba[0]<=selected_lba;voice_length[0]<=selected_length;voice_loop[0]<=1;
                    read_bank[0]<=0;next_fill_bank[0]<=0;
                    generation[0]<=generation[0]+1'b1;bank_valid[1:0]<=0;
                end
                if(enqueue)begin
                    if(incoming[4:0]!=0&&incoming[4:0]<24)begin
                        if(qcount<8)begin queue[qwr]<=incoming;qwr<=qwr+1'b1;qcount<=qcount+1'b1;end
                        else if(dropped_events!=65535)dropped_events<=dropped_events+1'b1;
                    end
                end else if(qcount!=0&&mix_state==0&&allocate==0)begin
                    descriptor_addr<=queued_id;audition_pending<=queue[qrd][5];allocate<=1;
                end
                if(allocate==1)allocate<=2;
                else if(allocate==2)allocate<=3;
                else if(allocate==3&&mix_state==0&&!enqueue)begin
                    allocate<=0;qrd<=qrd+1'b1;qcount<=qcount-1'b1;
                    if(descriptor_q[40:17]!=0)begin
                        active[victim]<=1;track[victim]<=queued_id;position[victim]<=0;
                        voice_lba[victim]<=descriptor_q[16:0];voice_length[victim]<=descriptor_q[40:17];
                        voice_loop[victim]<=descriptor_q[41];
                        audition_voice[victim]<=audition_pending;fill_sector[victim]<=0;
                        read_bank[victim]<=0;next_fill_bank[victim]<=0;
                        bank_valid[victim*2 +: 2]<=0;generation[victim]<=generation[victim]+1'b1;
                        next_voice<=next_voice+1'b1;
                    end
                end
            end
        end
    end
endmodule

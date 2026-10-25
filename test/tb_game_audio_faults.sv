`timescale 1ns/1ps
// Reject malformed SD data and quarantine a timed-out bridge through public ports.
module tb_game_audio_faults;
    reg clk=0,sd_clk=0,rst=1;
    always #20 clk=~clk;
    always #10 sd_clk=~sd_clk;
    reg sample_tick=0,play_enable=0,event_valid=0;
    reg [4:0] event_id=1;
    wire signed [23:0] pcm;
    wire available,error,sd_req;
    wire [31:0] sd_addr;
    wire [15:0] underruns,dropped_events;
    reg [7:0] sd_data=0;
    reg sd_valid=0,sd_end=0;
    integer fault=0,sector_bytes=512;
    sd_pcm_player dut(.clk(clk),.rst(rst),.sd_clk(sd_clk),.sd_rst(rst),.initialized(!rst),
        .sample_tick(sample_tick),.play_enable(play_enable),.star_mode(1'b0),.paused(1'b0),.mute(1'b0),
        .event_valid(event_valid),.event_id(event_id),.audition(1'b0),.audition_id(5'd0),
        .master_volume(2'd3),.bgm_volume(2'd3),.sfx_volume(2'd3),
        .pcm(pcm),.available(available),.error(error),.underruns(underruns),
        .dropped_events(dropped_events),.sd_req(sd_req),.sd_addr(sd_addr),
        .sd_data(sd_data),.sd_valid(sd_valid),.sd_end(sd_end));
    function [15:0] metadata(input integer w);
        integer t,f;
        begin
            metadata=0;
            case(w)
                0:metadata=fault==1?0:16'h5046;
                1:metadata=16'h4147;2:metadata=16'h4455;3:metadata=16'h2131;
                4:metadata=fault==2?44100:48000;
                6:metadata=fault==3?23:24;
                7:metadata=1;8:metadata=fault==9?0:100;
                10:metadata=97;
            endcase
            if(w>=16&&w<208)begin
                t=(w-16)/8;f=(w-16)%8;
                case(f)
                    0:metadata=fault==4&&t==23?96:1+t*4;
                    2:metadata=fault==5&&t==2?0:1021;
                    4:metadata=fault==6&&t==3?1:t==0;
                    5:metadata=fault==7&&t==4?5:t;
                    6:metadata=fault==8&&t==5?1:0;
                endcase
            end
        end
    endfunction
    reg busy=0,wait_low=0;
    integer byte_index=0,sector_lba=0,requests=0;
    reg [15:0] value;
    always @(posedge sd_clk)begin
        sd_valid<=0;sd_end<=0;
        if(rst)begin busy<=0;wait_low<=0;byte_index<=0;end
        else if(wait_low)begin if(!sd_req)wait_low<=0;end
        else if(!busy)begin
            if(sd_req)begin
                busy<=1;sector_lba<=sd_addr;byte_index<=0;requests<=requests+1;
            end
        end else begin
            value=sector_lba==1?metadata(byte_index/2):16'd1000;
            sd_data<=byte_index%2?value[15:8]:value[7:0];sd_valid<=1;
            if(byte_index==sector_bytes-1)begin busy<=0;wait_low<=1;sd_end<=1;end
            else byte_index<=byte_index+1;
        end
    end
    task boot(input integer mode,input integer length);
        begin
            rst=1;fault=mode;sector_bytes=length;play_enable=0;event_valid=0;
            repeat(5)@(negedge clk);rst=0;
            wait(available||error);repeat(5)@(negedge clk);
        end
    endtask
    task tick;
        begin
            @(negedge clk);sample_tick=1;@(negedge clk);sample_tick=0;
            repeat(519)@(negedge clk);
        end
    endtask
    // Independently drive a bridge with a short watchdog. Its RAM port is observed,
    // not its internal state, including the simultaneous last-byte/end case.
    reg bridge_rst=1,initialized=1,request_toggle=0;
    wire done_toggle,failed,bridge_req,ram_we;
    wire [31:0] bridge_addr;
    wire [11:0] ram_addr;
    wire [15:0] ram_data;
    reg [7:0] bridge_data=0;
    reg bridge_valid=0,bridge_end=0;
    integer writes=0;
    audio_sector_bridge #(.TIMEOUT_CYCLES(1024)) bridge(.sd_clk(sd_clk),.sd_rst(bridge_rst),
        .request_toggle(request_toggle),.request_lba(32'd123),.request_dest(12'd256),
        .done_toggle(done_toggle),.failed(failed),.initialized(initialized),
        .sd_req(bridge_req),.sd_addr(bridge_addr),.sd_data(bridge_data),
        .sd_valid(bridge_valid),.sd_end(bridge_end),.ram_we(ram_we),
        .ram_addr(ram_addr),.ram_data(ram_data));
    always @(posedge sd_clk)if(ram_we)begin
        if(ram_addr!=256+writes||ram_data!={8'(2*writes+1),8'(2*writes)})
            $fatal(1,"bridge RAM byte/address ordering at %0d",writes);
        writes<=writes+1;
    end
    task bridge_boot;
        begin
            bridge_rst=1;request_toggle=0;bridge_valid=0;bridge_end=0;initialized=1;
            repeat(4)@(negedge sd_clk);writes=0;bridge_rst=0;
        end
    endtask
    task bridge_request;
        begin
            @(negedge sd_clk);request_toggle=!request_toggle;wait(bridge_req);
            if(bridge_addr!=123)$fatal(1,"bridge LBA");
        end
    endtask
    integer before_requests;
    initial begin
        for(integer f=1;f<=9;f=f+1)begin
            boot(f,512);
            if(available||!error||pcm!==0)$fatal(1,"bad header accepted %0d",f);
        end
        boot(0,511);
        if(available||!error)$fatal(1,"short header accepted");
        boot(0,512);
        if(!available||error)$fatal(1,"valid header rejected");
        // Hold events high faster than the allocator can consume them.
        @(negedge clk);event_valid=1;
        repeat(20)@(negedge clk);event_valid=0;
        repeat(3000)@(negedge clk);
        if(dropped_events!=12)$fatal(1,"event queue overflow count %0d",dropped_events);
        boot(0,512);sector_bytes=511;play_enable=1;
        wait(error);repeat(30)@(negedge clk);before_requests=requests;
        repeat(3000)@(negedge clk);
        if(available||requests!=before_requests)$fatal(1,"failed fill automatically retried");

        bridge_boot;bridge_request;
        for(integer b=0;b<512;b=b+1)begin
            @(negedge sd_clk);bridge_valid=1;bridge_data=b;bridge_end=b==511;
        end
        @(negedge sd_clk);bridge_valid=0;bridge_end=0;
        repeat(3)@(negedge sd_clk);
        if(done_toggle!=request_toggle||failed||writes!=256)$fatal(1,"complete sector failed");
        bridge_request;
        @(negedge sd_clk);bridge_end=1;
        @(negedge sd_clk);bridge_end=0;
        if(done_toggle!=request_toggle||!failed)$fatal(1,"empty sector accepted");
        // Timeout, then a late completion. No new transfer may start before reset.
        bridge_request;wait(done_toggle==request_toggle);
        if(!failed||bridge_req)$fatal(1,"timeout not acknowledged");
        @(negedge sd_clk);request_toggle=!request_toggle;bridge_end=1;
        @(negedge sd_clk);bridge_end=0;
        repeat(20)begin @(negedge sd_clk);if(bridge_req)$fatal(1,"late completion reused");end
        if(done_toggle==request_toggle)$fatal(1,"quarantined mailbox acknowledged new request");
        bridge_boot;bridge_request;
        @(negedge sd_clk);initialized=0;@(negedge sd_clk);
        if(!failed||bridge_req||done_toggle!=request_toggle)$fatal(1,"card loss not isolated");
        initialized=1;request_toggle=!request_toggle;
        repeat(20)begin @(negedge sd_clk);if(bridge_req)$fatal(1,"card-loss quarantine released");end
        $display("PASS audio faults: 9 malformed headers, short sectors, queue overflow, failed-fill stop, byte order, timeout/late-completion/card-loss quarantine");
        $finish;
    end
    initial begin #20000000;$fatal(1,"audio faults timeout");end
endmodule

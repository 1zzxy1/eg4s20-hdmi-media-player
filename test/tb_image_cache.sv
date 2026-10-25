`timescale 1ns/1ps
module tb_image_cache;
    reg clk=0,rst=1,catalog=0,next_req=0,previous_req=0;
    always #5 clk=~clk;
    reg [6:0] count=6;
    reg ready=1,source_done=0,source_error=0,write_started=0,memory_done=0;
    wire load_start,commit,valid;
    wire [5:0] load_image;
    wire [1:0] load_slot,pending_slot;
    wire [6:0] image_index;
    wire [2:0] cached;
    reg ack=0,allow_ack=1,hold_memory=0;
    reg [63:0] failures=0;
    integer loads=0,age=0,ack_age=0,commits=0;
    reg model_busy=0,have_active=0;
    reg [1:0] model_slot,active_slot;
    reg [5:0] model_image;
    reg [3:0] complete=0;
    reg [5:0] contents[0:3];
    image_cache_controller dut(
        .clk(clk),.rst(rst),.catalog_ready(catalog),.catalog_count(count),.next_request(next_req),
        .previous_request(previous_req),
        .loader_ready(ready),.source_done(source_done),.source_error(source_error),
        .write_started(write_started),.memory_done(memory_done),.load_start(load_start),
        .load_image(load_image),.load_slot(load_slot),.display_ack_toggle(ack),
        .display_commit_toggle(commit),.pending_slot(pending_slot),.display_valid(valid),
        .image_index(image_index),.cache_count(cached));

    // Transaction endpoint: source completion precedes memory completion. Every
    // transfer also receives a deliberately stale finish before its write ack.
    always @(negedge clk) begin
        source_done=0;source_error=0;write_started=0;memory_done=0;
        if(rst) begin
            ready=1;model_busy=0;loads=0;age=0;ack=0;ack_age=0;
            commits=0;have_active=0;complete=0;
        end else begin
            if(load_start) begin
                if(model_busy || (have_active && load_slot==active_slot))
                    $fatal(1,"loader overlap or overwrite active slot");
                if(load_image>=count) $fatal(1,"catalog index overflow");
                ready=0;model_busy=1;age=0;loads=loads+1;
                model_slot=load_slot;model_image=load_image;complete[load_slot]=0;
                contents[load_slot]=load_image;
            end
            if(model_busy) begin
                age=age+1;
                if(age==1) memory_done=1;
                if(age==3) write_started=1;
                if(age==7 && failures[model_image]) begin
                    source_error=1;ready=1;model_busy=0;
                end else if(age==9) begin source_done=1;ready=1;end
                if(age>=18 && !hold_memory && !failures[model_image]) begin
                    memory_done=1;complete[model_slot]=1;model_busy=0;
                end
            end
            if(commit!=ack) begin
                if(!complete[pending_slot]) $fatal(1,"commit before matching memory completion");
                ack_age=ack_age+1;
                if(allow_ack && ack_age>=6) begin
                    ack=commit;active_slot=pending_slot;have_active=1;
                    ack_age=0;commits=commits+1;
                end
            end else ack_age=0;
        end
    end

    task tick;begin @(posedge clk);#1;end endtask
    task reset_case(input integer n,input [63:0] bad);
        begin
            @(posedge clk);#1;rst=1;catalog=0;next_req=0;previous_req=0;count=n;failures=bad;
            allow_ack=1;hold_memory=0;repeat(3)tick();rst=0;catalog=1;
        end
    endtask
    task request_next;begin next_req=1;tick();next_req=0;end endtask
    task request_previous;begin previous_req=1;tick();previous_req=0;end endtask
    task await_index(input integer expected);
        integer timeout;
        begin
            timeout=0;
            while(image_index!=expected && timeout<3000) begin tick();timeout=timeout+1;end
            if(image_index!=expected) $fatal(1,"expected image %0d got %0d",expected,image_index);
        end
    endtask
    task await_cache(input integer expected);
        integer timeout;
        begin
            timeout=0;
            while(cached!=expected && timeout<3000) begin tick();timeout=timeout+1;end
            if(cached!=expected) $fatal(1,"cache count %0d expected %0d",cached,expected);
        end
    endtask
    integer k,saved;
    initial begin
        reset_case(6,0);await_index(1);await_cache(4);repeat(5)tick();
        if(loads!=4) $fatal(1,"four-slot prefetch did not stop");
        allow_ack=0;saved=loads;request_next();repeat(30)tick();
        if(image_index!=1 || loads!=saved || commit==ack) $fatal(1,"old slot released before ack");
        allow_ack=1;await_index(2);await_cache(4);
        for(k=2;k<14;k=k+1) begin request_next();await_index((k%6)+1);await_cache(4);end

        reset_case(6,0);await_index(1);hold_memory=1;
        request_next();repeat(50)tick();request_next();repeat(30)tick();
        if(image_index!=1 || commit!=ack) $fatal(1,"slow prefetch changed old frame");
        hold_memory=0;await_index(2);await_cache(4);repeat(30)tick();
        if(image_index!=2) $fatal(1,"busy presses must coalesce");

        reset_case(6,0);hold_memory=1;request_next();repeat(50)tick();
        if(valid || commits!=0) $fatal(1,"startup memory stall committed an image");
        hold_memory=0;await_index(2);await_cache(4);repeat(30)tick();
        if(image_index!=2 || commits!=2) $fatal(1,"startup next request was lost or duplicated");

        reset_case(6,64'h5);await_index(2);await_cache(4);
        request_next();await_index(4);request_next();await_index(5);
        request_next();await_index(6);request_next();await_index(2);
        if(loads!=6) $fatal(1,"bad entries or four good entries repeatedly reloaded");

        reset_case(4,0);await_index(1);await_cache(4);
        for(k=1;k<13;k=k+1) begin request_next();await_index((k%4)+1);end
        if(loads!=4) $fatal(1,"small album should stay resident");

        reset_case(6,0);await_index(1);await_cache(4);
        allow_ack=0;request_previous();
        repeat(100)tick();
        if(image_index!=1 || !valid || have_active==0 || active_slot!=dut.current_slot)
            $fatal(1,"backward miss released active slot before display ack");
        if(loads!=5 || commit==ack)
            $fatal(1,"backward wrap must load uncached image six then request display");
        allow_ack=1;await_index(6);await_cache(4);
        request_previous();await_index(5);await_cache(4);
        request_next();await_index(6);await_cache(4);
        request_next();await_index(1);await_cache(4);
        request_previous();await_index(6);await_cache(4);

        reset_case(4,0);await_index(1);await_cache(4);
        for(k=0;k<8;k=k+1) begin
            request_previous();await_index(((4-k+3)%4)+1);
        end
        if(loads!=4) $fatal(1,"small album backward navigation reloaded resident image");
        reset_case(6,64'h20);await_index(1);await_cache(4);
        request_previous();await_index(5);await_cache(4);
        request_next();await_index(1);await_cache(4);
        reset_case(1,0);await_index(1);request_next();repeat(100)tick();
        if(loads!=1 || commits!=1) $fatal(1,"single image loop");
        reset_case(0,0);repeat(100)tick();
        if(loads!=0 || valid) $fatal(1,"empty catalog");
        reset_case(6,64'h3f);repeat(500)tick();
        if(loads!=6 || commits!=0 || cached!=0) $fatal(1,"all-bad catalog must stop boundedly");

        reset_case(64,0);await_index(1);await_cache(4);
        for(k=1;k<=65;k=k+1) begin request_next();await_index((k%64)+1);await_cache(4);end
        $display("PASS image cache: forward/backward wrap, resident/miss, four-slot prefetch, delayed ack/finish, bad/empty/small catalogs");
        $finish;
    end
    initial begin #2000000;$fatal(1,"cache test timeout");end
endmodule

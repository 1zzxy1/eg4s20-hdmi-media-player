`timescale 1ns/1ps
// Behavioral mode-0 NOR model. No external files or hardware accesses.
module tb_game_score_flash;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,save_req=0;wire [3:0] query_index;
    reg [95:0] rows[0:9];wire [95:0] query_record=rows[query_index];
    wire load_valid;wire [3:0] load_index;wire [95:0] load_record;
    wire busy,ready,error,persist_available,flash_cs_n,flash_sck,flash_mosi;reg flash_miso=1;
    game_score_flash #(.CLK_DIV(1),.POLL_LIMIT(32)) dut(.*);
    reg [7:0] mem[0:8191];reg [23:0] model_id=24'hef4017;
    reg [7:0] cmd,shift;reg [23:0] addr;integer bitcnt,bytes,readbit,pos;
    reg wel=0,force_busy=0;integer erases=0,programs=0,loaded=0;reg [95:0] restored[0:9];
    always @(posedge clk) if(load_valid) begin restored[load_index]<=load_record;loaded<=loaded+1;end
    function [7:0] response;
        input integer data_index;
        begin
            case(cmd)
                8'h9f:case(data_index)0:response=model_id[23:16];1:response=model_id[15:8];default:response=model_id[7:0];endcase
                8'h05:response={6'd0,wel,force_busy};
                8'h03:begin pos=addr-24'h600000+data_index;response=(pos>=0 && pos<8192)?mem[pos]:8'hff;end
                default:response=8'hff;
            endcase
        end
    endfunction
    reg [7:0] outbyte;
    always @(negedge flash_cs_n) begin cmd=0;shift=0;addr=0;bitcnt=0;bytes=0;flash_miso=1;end
    always @(posedge flash_sck) if(!flash_cs_n) begin
        shift={shift[6:0],flash_mosi};bitcnt=bitcnt+1;
        if(bitcnt==8) begin
            bitcnt=0;
            if(bytes==0)cmd=shift;
            else if((cmd==8'h03 || cmd==8'h02 || cmd==8'h20) && bytes<=3)addr={addr[15:0],shift};
            else if(cmd==8'h02 && bytes>=4 && wel) begin
                pos=addr-24'h600000+(bytes-4);
                if(pos<0 || pos>=8192)$fatal(1,"write outside reserved sectors");
                mem[pos]=mem[pos]&shift;
            end
            bytes=bytes+1;
        end
    end
    always @(negedge flash_sck) if(!flash_cs_n) begin
        if(cmd==8'h9f || cmd==8'h05)outbyte=response(bytes-1);
        else if(cmd==8'h03 && bytes>=4)outbyte=response(bytes-4);
        else outbyte=8'hff;
        flash_miso=outbyte[7-bitcnt];
    end
    always @(posedge flash_cs_n) if(!rst) begin
        if(cmd==8'h06)wel=1;
        if(cmd==8'h20 && wel && bytes==4)begin
            pos=(addr-24'h600000)&~4095;
            if(pos!=0 && pos!=4096)$fatal(1,"erase outside reserved sectors");
            for(integer j=0;j<4096;j=j+1)mem[pos+j]=8'hff;
            erases=erases+1;wel=0;
        end
        if(cmd==8'h02)begin programs=programs+1;wel=0;end
    end
    task boot;
        begin rst=1;repeat(4)@(negedge clk);loaded=0;rst=0;wait(ready);@(negedge clk);end
    endtask
    task save;
        begin @(negedge clk);save_req=1;@(negedge clk);save_req=0;wait(!busy);@(negedge clk);end
    endtask
    initial begin
        for(integer j=0;j<8192;j=j+1)mem[j]=8'hff;
        for(integer j=0;j<10;j=j+1)rows[j]={4'd0,1'b1,3'(j),48'h504c41594552+j,16'(30+j),24'(1000-j)};
        boot;if(!persist_available || loaded!=0 || error)$fatal(1,"blank boot");
        save;if(error || erases!=1 || mem[255]!=8'ha5)$fatal(1,"first commit");
        boot;if(loaded!=10 || restored[0]!=rows[0])$fatal(1,"restore first journal %d",loaded);
        for(integer j=0;j<10;j=j+1)
            if(restored[j]!=rows[j])$fatal(1,"restore all first journal records %0d",j);
        rows[0][23:0]=2000;save;boot;
        if(restored[0][23:0]!=2000 || mem[4096+255]!=8'ha5)$fatal(1,"new sequence not selected");
        for(integer j=0;j<10;j=j+1)
            if(restored[j]!=rows[j])$fatal(1,"restore all second journal records %0d",j);
        mem[4096+10]=mem[4096+10]^8'h04;boot;
        if(restored[0][23:0]!=1000)$fatal(1,"CRC fallback");
        // Tear a replacement page halfway through; old committed sector survives.
        @(negedge clk);save_req=1;@(negedge clk);save_req=0;
        wait(dut.state==28 && dut.spi.byte_number==40);boot;
        if(restored[0][23:0]!=1000)$fatal(1,"power-loss fallback");
        force_busy=1;save;if(!error)$fatal(1,"busy timeout not reported");
        force_busy=0;boot;if(restored[0][23:0]!=1000)$fatal(1,"timeout lost old commit");
        // Unknown sector contents must protect BOTH sectors from erasure.
        mem[4096]=8'h00;boot;
        if(persist_available || !error)$fatal(1,"foreign data accepted");
        begin integer before_count;before_count=erases;save;if(erases!=before_count)$fatal(1,"foreign data erased");end
        model_id=24'h123456;boot;if(persist_available || !error)$fatal(1,"unsupported chip");
        $display("PASS game_score_flash journal restore CRC power-loss timeout foreign-data JEDEC protection");$finish;
    end
    initial begin #100000000;$fatal(1,"timeout state %d",dut.state);end
endmodule

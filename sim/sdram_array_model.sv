`timescale 1ns/1ps
// Simulation ONLY. Functional SDR SDRAM device model, not an Anlogic model.
// Actual encrypted controller drives JEDEC pins. Not a speed-grade sign-off model.
module EG_PHY_SDRAM_2M_32(
    input wire clk,ras_n,cas_n,we_n,input wire [10:0] addr,input wire [1:0] ba,
    inout wire [31:0] dq,input wire cs_n,dm0,dm1,dm2,dm3,cke
);
    reg [31:0] memory[0:2097151];
    reg [10:0] open_row[0:3];reg [3:0] active=0;
    integer cl=3,bl=1,i,b,j;
    reg single_write=1;
    reg [31:0] out_data;
    reg out_enable=0;
    reg [7:0] pending=0;
    reg [20:0] pipe_addr[0:7];
    reg burst_read=0,burst_write=0,auto_close=0;
    reg [1:0] burst_bank;
    reg [7:0] column;
    integer remaining=0;
    integer trace;
    initial trace=$fopen("dram_commands.log","w");
    wire [3:0] mask={dm3,dm2,dm1,dm0};
    assign dq=out_enable?out_data:32'bz;
    task write_word(input [20:0] a);
        begin
            for(b=0;b<4;b=b+1) if(!mask[b]) begin
                if(^dq[b*8+:8]===1'bx) $fatal(1,"SDRAM write unknown/high-Z at %0d command=%b remaining=%0d",a,{ras_n,cas_n,we_n},remaining);
                memory[a][b*8+:8]=dq[b*8+:8];
            end
        end
    endtask
    always @(posedge clk) if(cke) begin
        if(!cs_n && {ras_n,cas_n,we_n}!=3'b111)
            $fwrite(trace,"%0t cmd=%b bank=%0d addr=%h active=%b remain=%0d auto=%b\n",$time,{ras_n,cas_n,we_n},ba,addr,active,remaining,auto_close);
        out_enable<=#6 pending[0];
        if(pending[0]) out_data<=#6 memory[pipe_addr[0]];
        for(i=0;i<7;i=i+1) begin pending[i]=pending[i+1];pipe_addr[i]=pipe_addr[i+1];end
        pending[7]=0;
        // ACTIVE to another bank does not interrupt the data burst. READ/WRITE,
        // PRECHARGE and BURST TERMINATE do; do not sample an obsolete data beat.
        if((burst_read||burst_write) && (cs_n || {ras_n,cas_n,we_n}==3'b111 || {ras_n,cas_n,we_n}==3'b011)) begin
            if(burst_read) begin pending[cl-1]=1;pipe_addr[cl-1]={burst_bank,open_row[burst_bank],column};end
            if(burst_write) write_word({burst_bank,open_row[burst_bank],column});
            column=column+1'b1;remaining=remaining-1;
            if(remaining==0) begin
                burst_read=0;burst_write=0;if(auto_close) active[burst_bank]=0;
            end
        end
        if(!cs_n) case({ras_n,cas_n,we_n})
            3'b000: begin
                if(addr[6:4]<2 || addr[6:4]>3) $fatal(1,"unsupported CAS latency");
                if(addr[3]) $fatal(1,"interleaved burst unsupported");
                cl=addr[6:4];bl=addr[2:0]==7?256:1<<addr[2:0];single_write=addr[9];
            end
            3'b011: begin
                if(active[ba]) $fatal(1,"ACTIVE without PRECHARGE");
                active[ba]=1;open_row[ba]=addr;
            end
            3'b010: begin
                if(addr[10]) active=0;else active[ba]=0;
                burst_read=0;burst_write=0;
            end
            3'b001: if(active!=0) $fatal(1,"REFRESH with active bank");
            3'b101,3'b100: begin
                if(!active[ba]) $fatal(1,"READ/WRITE without ACTIVE");
                if({ras_n,cas_n,we_n}==3'b101) begin
                    pending[cl-1]=1;pipe_addr[cl-1]={ba,open_row[ba],addr[7:0]};
                    remaining=bl-1;burst_read=remaining!=0;burst_write=0;
                end else begin
                    write_word({ba,open_row[ba],addr[7:0]});
                    remaining=single_write?0:bl-1;burst_write=remaining!=0;burst_read=0;
                end
                burst_bank=ba;column=addr[7:0]+1'b1;auto_close=addr[10];
                if(remaining==0 && addr[10]) active[ba]=0;
            end
            3'b110:begin burst_read=0;burst_write=0;end
        endcase
    end
endmodule

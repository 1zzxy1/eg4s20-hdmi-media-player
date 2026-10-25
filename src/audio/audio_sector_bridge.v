// One stable request mailbox, one completion toggle, and a dual-clock RAM port.
module audio_sector_bridge #(parameter integer TIMEOUT_CYCLES=67108864)(input wire sd_clk,sd_rst,
    input wire request_toggle,input wire [31:0] request_lba,input wire [11:0] request_dest,
    output reg done_toggle,output reg failed,
    input wire initialized,output reg sd_req,output reg [31:0] sd_addr,
    input wire [7:0] sd_data,input wire sd_valid,sd_end,
    output reg ram_we,output reg [11:0] ram_addr,output reg [15:0] ram_data);
    (* ASYNC_REG="TRUE" *) reg [1:0] rq;
    reg seen,busy,halted;
    reg [9:0] count;
    reg [7:0] low_byte;
    reg [11:0] dest;
    reg [$clog2(TIMEOUT_CYCLES)-1:0] watchdog;
    always @(posedge sd_clk or posedge sd_rst)
        if(sd_rst)begin
            rq<=0;seen<=0;busy<=0;halted<=0;done_toggle<=0;failed<=0;sd_req<=0;sd_addr<=0;
            ram_we<=0;ram_addr<=0;ram_data<=0;dest<=0;count<=0;low_byte<=0;watchdog<=0;
        end else begin
            rq<={rq[0],request_toggle};ram_we<=0;
            if(!busy)begin
                watchdog<=0;
                if(initialized&&!halted&&rq[1]!=seen)begin
                    seen<=rq[1];busy<=1;count<=0;dest<=request_dest;
                    sd_req<=1;sd_addr<=request_lba;failed<=0;
                end
            end else begin
                watchdog<=watchdog+1'b1;
                if(sd_valid&&count<512)begin
                    count<=count+1'b1;
                    if(!count[0])low_byte<=sd_data;
                    else begin ram_we<=1;ram_addr<=dest+count[8:1];ram_data<={sd_data,low_byte};end
                end
                if(sd_end||watchdog==TIMEOUT_CYCLES-1||!initialized)begin
                    busy<=0;sd_req<=0;done_toggle<=seen;
                    failed<=!initialized||!sd_end||(count+(sd_valid?1:0)!=512);
                    // A timeout cannot prove that the SPI controller is idle.
                    // Quarantine this mailbox until reset, never reuse a late
                    // completion as acknowledgement of another request.
                    if(!sd_end||!initialized)halted<=1;
                end
            end
        end
endmodule

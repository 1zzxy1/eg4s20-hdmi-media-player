// Sector-atomic sharing. Clients hold requests until their routed completion.
// Audio priority applies only between sectors; never preempt a BMP sector.
module sd_sector_arbiter(input wire clk,rst,initialized,
    input wire bmp_req,input wire [31:0] bmp_addr,
    input wire audio_req,input wire [31:0] audio_addr,
    output reg sd_req,output reg [31:0] sd_addr,
    input wire [7:0] sd_data,input wire sd_valid,sd_end,
    output wire [7:0] bmp_data,audio_data,
    output wire bmp_valid,bmp_end,audio_valid,audio_end);
    reg busy,owner,gap;
    assign bmp_data=sd_data;assign audio_data=sd_data;
    assign bmp_valid=busy&&!owner&&sd_valid;
    assign audio_valid=busy&&owner&&sd_valid;
    assign bmp_end=busy&&!owner&&sd_end;
    assign audio_end=busy&&owner&&sd_end;
    always @(posedge clk or posedge rst)
        if(rst)begin busy<=0;owner<=0;gap<=0;sd_req<=0;sd_addr<=0;end
        else begin
            if(gap)gap<=0;
            if(!initialized)begin busy<=0;sd_req<=0;gap<=1;end
            else if(busy)begin
                if(sd_end)begin busy<=0;sd_req<=0;gap<=1;end
            end else if(!gap)begin
                if(audio_req===1'b1)begin busy<=1;owner<=1;sd_req<=1;sd_addr<=audio_addr;end
                else if(bmp_req)begin busy<=1;owner<=0;sd_req<=1;sd_addr<=bmp_addr;end
            end
        end
endmodule

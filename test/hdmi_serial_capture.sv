`timescale 1ns/1ps
// Pin-side recovery for the actual encrypted transmitter. The expected queue
// uses only public parallel outputs, with a fixed two-pixel pipeline offset.
module hdmi_serial_capture #(
    parameter integer LAST_CYCLE=2100000
)(
    input wire pixel_clk,serial_clk,rst,
    input wire [9:0] c0,c1,c2,cc,
    input wire d0,d1,d2,ck,
    output integer checked_words=0
);
    reg [39:0] expected[0:7];
    integer cycle=0,reference_cycle,file_handle;
    reg previous_clock=0,armed=0;
    reg [39:0] recovered=0;
    integer bit_index=0;
    reg [255:0] filename;
    initial begin
        if(!$value$plusargs("SERIAL_CAPTURE=%s",filename))
            $fatal(1,"missing serial capture path");
        file_handle=$fopen(filename,"w");
        if(!file_handle)$fatal(1,"cannot open serial capture");
    end
    always @(posedge pixel_clk)begin
        #0.2;
        cycle=cycle+1;
        expected[cycle%8]={cc,c2,c1,c0};
    end
    always @(serial_clk)begin
        #0.6;
        if(rst)begin armed=0;bit_index=0;previous_clock=ck;end
        else begin
            // The clock lane's first and last bits delimit a word. Accept
            // either polarity of the standard five-high/five-low clock word.
            if(!armed && cycle>20 &&
               (cc===10'b1111100000 || cc===10'b0000011111) &&
               previous_clock===cc[9] && ck===cc[0])begin
                armed=1;bit_index=0;
            end
            if(armed)begin
                recovered[bit_index]=d0;
                recovered[10+bit_index]=d1;
                recovered[20+bit_index]=d2;
                recovered[30+bit_index]=ck;
                if(bit_index==9)begin
                    reference_cycle=cycle-2;
                    if(recovered!==expected[reference_cycle%8])
                        $fatal(1,"HDMI serial word mismatch cycle=%0d got=%h expected=%h",reference_cycle,recovered,expected[reference_cycle%8]);
                    if(reference_cycle<=LAST_CYCLE)begin
                        $fdisplay(file_handle,"%0d %03h %03h %03h",reference_cycle,
                            recovered[9:0],recovered[19:10],recovered[29:20]);
                        checked_words=checked_words+1;
                    end
                    if(reference_cycle==LAST_CYCLE)$fclose(file_handle);
                    bit_index=0;
                end else bit_index=bit_index+1;
            end
            previous_clock=ck;
        end
    end
endmodule

`timescale 1ns/1ps
module frame_fifo_read
#
(
	parameter MEM_DATA_BITS          = 32,
    parameter BANK_BITS = 2,
	parameter ADDR_BITS              = 21,
	parameter BURST_BITS             = 9,
	parameter FIFO_DEPTH             = 512,
	parameter BURST_SIZE             = 128,
    parameter REALTIME_ZOOM         = 0,
    parameter FRAME_HEIGHT          = 480,
    parameter ALIGNMENT             = 0,
    parameter FRAME_WIDTH           = 640
)               
(
	input                            rst,                  
	input                            mem_clk,                    // external memory controller user interface clock
	input							 Sdr_init_done,
	input							 Sdr_init_ref_vld,
    input							 Sdr_busy,
    input							 Sdr_rd_en,
	input							 App_wr_busy,
    output							 O_rd_busy,
	/*
    output reg                       rd_burst_req,               // to external memory controller,send out a burst read request  
	output reg[BURST_BITS - 1:0]     rd_burst_len,               // to external memory controller,data length of the burst read request, not bytes 
	output reg[ADDR_BITS - 1:0]      rd_burst_addr,              // to external memory controller,base address of the burst read request
	input                            rd_burst_data_valid,        // from external memory controller,read request data valid    
	input                            rd_burst_finish,            // from external memory controller,burst read finish
	*/
	output 							 App_rd_en,
	output  [ADDR_BITS - 1:0]		 App_rd_addr,
	
	input                            read_req,                   // data read module read request,keep '1' until read_req_ack = '1'
	output reg                       read_req_ack,               // data read module read request response
	output                           read_finish,                // data read module read request finish
	input[ADDR_BITS - 1:0]           read_addr_0,                // data read module read request base address 0, used when read_addr_index = 0
	input[ADDR_BITS - 1:0]           read_addr_1,                // data read module read request base address 1, used when read_addr_index = 1
	input[ADDR_BITS - 1:0]           read_addr_2,                // data read module read request base address 1, used when read_addr_index = 2
	input[ADDR_BITS - 1:0]           read_addr_3,                // data read module read request base address 1, used when read_addr_index = 3
    input [ADDR_BITS-1:0] read_addr_4, read_addr_5,
	input[BANK_BITS-1:0]             read_addr_index,            // select valid base address from read_addr_0 read_addr_1 read_addr_2 read_addr_3
	input[ADDR_BITS - 1:0]           read_len,                   // data read module read request data length
	output reg                       fifo_aclr,                  // to fifo asynchronous clear
	input[9:0]                      wrusedw,                    // from fifo write used words
    input wire [9:0] alignment_offset,
    input wire view_zoom,
    output reg zoom_latch,
    output reg [3:0] read_shift

);
localparam ONE                       = 256'd1;                   //256 bit '1'   you can use ONE[n-1:0] for n bit '1'
localparam ZERO                      = 256'd0;                   //256 bit '0'
//read state machine code
localparam S_IDLE                    = 0;                        //idle state,waiting for frame read
localparam S_ACK                     = 1;                        //read request response
localparam S_CHECK_FIFO              = 2;                        //check the FIFO status, ensure that there is enough space to burst read
localparam S_READ_BURST              = 3;                        //begin a burst read
localparam S_READ_BURST_END          = 4;                        //a burst read complete
localparam S_END                     = 5;                        //a frame of data is read to complete

reg                                  read_req_d0;                //asynchronous read request, synchronize to 'mem_clk' clock domain,first beat
reg                                  read_req_d1;                //second
reg                                  read_req_d2;                //third,Why do you need 3 ? Here's the design habit
reg[ADDR_BITS - 1:0]                 read_len_d0;                //asynchronous read_len(read data length), synchronize to 'mem_clk' clock domain first
reg[ADDR_BITS - 1:0]                 read_len_d1;                //second
reg[ADDR_BITS - 1:0]                 read_len_latch;             //lock read data length
reg[ADDR_BITS - 1:0]                 read_cnt;                   //read data counter
reg[3:0]                             state;                      //state machine
reg[BANK_BITS-1:0]                   read_addr_index_d0;         //synchronize to 'mem_clk' clock domain first
reg[BANK_BITS-1:0]                   read_addr_index_d1;         //synchronize to 'mem_clk' clock domain second
reg [ADDR_BITS - 1:0]	 App_rd_addr_r;
(* ASYNC_REG="TRUE" *) reg [9:0] offset_sync0,offset_sync1;
reg [9:0] offset_latch,logical_x,source_x;
reg [ADDR_BITS-1:0] row_start;
reg row_repeat;
(* ASYNC_REG="TRUE" *) reg [1:0] zoom_sync;
wire [9:0] aligned_offset={offset_sync1[9:4],4'b0000};
wire [9:0] zoom_offset=ALIGNMENT?{5'd0,offset_sync1[9:5]}<<4:10'd0;
wire [ADDR_BITS-1:0] initial_offset=(REALTIME_ZOOM&&zoom_sync[1])?
    (FRAME_HEIGHT/4)*FRAME_WIDTH+FRAME_WIDTH/4+zoom_offset:
    (ALIGNMENT?aligned_offset:0);
// The controller interleaves four BL4 banks. Its address stream must start
// on a 16-word boundary; frame_read_write rotates the residual pixels.
always @(posedge mem_clk or posedge rst)
    if(rst)begin offset_sync0<=0;offset_sync1<=0;zoom_sync<=0;end
    else begin offset_sync0<=alignment_offset;offset_sync1<=offset_sync0;zoom_sync<={zoom_sync[0],view_zoom};end

reg [BURST_BITS - 1:0]				burst_cnt;
wire								rd_burst_finish;
reg App_rd_en_r;
reg App_rd_en_d0;


wire rd_vld;
reg [3:0] rd_delay;

assign App_rd_addr = {App_rd_addr_r[ADDR_BITS - 1:0]};
assign rd_vld = (state == S_READ_BURST && burst_cnt >= BURST_SIZE);

assign O_rd_busy = (state == S_READ_BURST);//读指令期间
//burst_cnt代表发送的读指令
//但rd_burst_finish需要在发送完十个时钟后拉高，此时数据全部读出
assign rd_burst_finish = (rd_vld && rd_delay == 4'd10);
assign read_finish = (state == S_END) ? 1'b1 : 1'b0;             //read finish at state 'S_END'
assign App_rd_en = App_rd_en_d0;
always@(posedge mem_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		read_req_d0    <=  1'b0;
		read_req_d1    <=  1'b0;
		read_req_d2    <=  1'b0;
		read_len_d0    <=  ZERO[ADDR_BITS - 1:0];               //equivalent to read_len_d0 <= 0;
		read_len_d1    <=  ZERO[ADDR_BITS - 1:0];               //equivalent to read_len_d1 <= 0;
		read_addr_index_d0 <= 2'b00;
		read_addr_index_d1 <= 2'b00;
	end
	else
	begin
		read_req_d0    <=  read_req;
		read_req_d1    <=  read_req_d0;
		read_req_d2    <=  read_req_d1;     
		read_len_d0    <=  read_len;
		read_len_d1    <=  read_len_d0; 
		read_addr_index_d0 <= read_addr_index;
		read_addr_index_d1 <= read_addr_index_d0;
		
	end 
end

always @(posedge mem_clk or posedge rst)
begin
	if(rst || App_rd_en)begin
        rd_delay <= 4'd0;
    end
    else if(rd_delay < 4'd10)begin
    	rd_delay <= rd_delay + 1'b1;
    end
end
always @(posedge mem_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		burst_cnt <= ZERO[BURST_BITS - 1:0];
		App_rd_addr_r <= ZERO[ADDR_BITS - 1:0];
		App_rd_en_d0 <= 1'b0;
		offset_latch<=0;logical_x<=0;source_x<=0;read_shift<=0;zoom_latch<=0;row_start<=0;row_repeat<=0;
	end
	else begin
	
		if(state == S_CHECK_FIFO)
			burst_cnt <= ZERO[BURST_BITS - 1:0];
		else if(App_rd_en)
			burst_cnt <= burst_cnt + 1'b1;
		else
			burst_cnt <= burst_cnt;
		//
		if(state == S_ACK)
			begin
				zoom_latch<=REALTIME_ZOOM&&zoom_sync[1];row_repeat<=0;
                offset_latch<=REALTIME_ZOOM&&zoom_sync[1]?zoom_offset:(ALIGNMENT?aligned_offset:0);
                read_shift<=ALIGNMENT?(REALTIME_ZOOM&&zoom_sync[1]?offset_sync1[4:1]:offset_sync1[3:0]):0;
                logical_x<=0;
                source_x<=REALTIME_ZOOM&&zoom_sync[1]?zoom_offset:(ALIGNMENT?aligned_offset:0);
				if(read_addr_index_d1 == 2'd0)
					begin App_rd_addr_r <= read_addr_0+initial_offset;row_start<=read_addr_0+initial_offset;end
				else if(read_addr_index_d1 == 2'd1)
					begin App_rd_addr_r <= read_addr_1+initial_offset;row_start<=read_addr_1+initial_offset;end
				else if(read_addr_index_d1 == 2'd2)
					begin App_rd_addr_r <= read_addr_2+initial_offset;row_start<=read_addr_2+initial_offset;end
				else if(read_addr_index_d1 == 2'd3)
					begin App_rd_addr_r <= read_addr_3+initial_offset;row_start<=read_addr_3+initial_offset;end
				else if(read_addr_index_d1 == 3'd4)
					begin App_rd_addr_r <= read_addr_4+initial_offset;row_start<=read_addr_4+initial_offset;end
				else if(read_addr_index_d1 == 3'd5)
					begin App_rd_addr_r <= read_addr_5+initial_offset;row_start<=read_addr_5+initial_offset;end
			end
		else if(App_rd_en)
            if(REALTIME_ZOOM&&zoom_latch)begin
                // Read the center 320 pixels; repeat each source row twice.
                // All discontinuities stay on 16-word controller boundaries.
                if(logical_x==FRAME_WIDTH/2-1)begin
                    logical_x<=0;source_x<=offset_latch;row_repeat<=!row_repeat;
                    App_rd_addr_r<=row_start+(row_repeat?FRAME_WIDTH:0);
                    if(row_repeat)row_start<=row_start+FRAME_WIDTH;
                end else begin
                    logical_x<=logical_x+1'b1;
                    source_x<=source_x==FRAME_WIDTH/2-1?0:source_x+1'b1;
                    App_rd_addr_r<=source_x==FRAME_WIDTH/2-1?
                        App_rd_addr_r-(FRAME_WIDTH/2-1):App_rd_addr_r+1'b1;
                end
            end else if(ALIGNMENT)begin
                if(logical_x==FRAME_WIDTH-1)begin
                    logical_x<=0;source_x<=offset_latch;
                    App_rd_addr_r<=App_rd_addr_r+(offset_latch==0?1:FRAME_WIDTH+1);
                end else begin
                    logical_x<=logical_x+1'b1;
                    source_x<=source_x==FRAME_WIDTH-1?0:source_x+1'b1;
                    App_rd_addr_r<=source_x==FRAME_WIDTH-1?
                        App_rd_addr_r-(FRAME_WIDTH-1):App_rd_addr_r+1'b1;
                end
            end else App_rd_addr_r <= App_rd_addr_r + 1'b1;
		else
			App_rd_addr_r <= App_rd_addr_r;
		//
		if(App_rd_en_r && burst_cnt + App_rd_en < BURST_SIZE)
			App_rd_en_d0 <= 1'b1;
		else
			App_rd_en_d0 <= 1'b0;
	
	end		
end
always@(posedge mem_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		state <= S_IDLE;
		read_len_latch <= ZERO[ADDR_BITS - 1:0];
		
		//rd_burst_addr <= ZERO[ADDR_BITS - 1:0];
		//rd_burst_req <= 1'b0;
		App_rd_en_r <= 1'b0;
		
		read_cnt <= ZERO[ADDR_BITS - 1:0];
		fifo_aclr <= 1'b0;
		//rd_burst_len <= ZERO[BURST_BITS - 1:0];
		read_req_ack <= 1'b0;
	end
	else
		case(state)
			//idle state,waiting for read, read_req_d2 == '1' goto the 'S_ACK'
			S_IDLE:
			begin
				if(read_req_d2 == 1'b1 && Sdr_init_done)
				begin
					state <= S_ACK;
				end
				read_req_ack <= 1'b0;
			end
			//'S_ACK' state completes the read request response, the FIFO reset, the address latch, and the data length latch
			S_ACK:
			begin
				if(read_req_d2 == 1'b0)
				begin
					state <= S_CHECK_FIFO;
					fifo_aclr <= 1'b0;
					read_req_ack <= 1'b0;
				end
				else
				begin
					//read request response
					read_req_ack <= 1'b1;
					//FIFO reset
					fifo_aclr <= 1'b1;
					//select valid base address from read_addr_0 read_addr_1 read_addr_2 read_addr_3
					/*
					if(read_addr_index_d1 == 2'd0)
						App_rd_addr <= read_addr_0;
					else if(read_addr_index_d1 == 2'd1)
						App_rd_addr <= read_addr_1;
					else if(read_addr_index_d1 == 2'd2)
						App_rd_addr <= read_addr_2;
					else if(read_addr_index_d1 == 2'd3)
						App_rd_addr <= read_addr_3;
					*/
					//latch data length
					read_len_latch <= REALTIME_ZOOM&&zoom_sync[1]?read_len_d1>>1:read_len_d1;
				end
				//read data counter reset, read_cnt <= 0;
				read_cnt <= ZERO[ADDR_BITS - 1:0];
			end
			S_CHECK_FIFO:
			begin
				//if there is a read request at this time, enter the 'S_ACK' state
				if(read_req_d2 == 1'b1)
				begin
					state <= S_ACK;
				end
				//if the FIFO space is a burst read request, goto burst read state
				else if(wrusedw < (FIFO_DEPTH - BURST_SIZE) && ~App_wr_busy && ~Sdr_busy && ~Sdr_init_ref_vld)
				begin
					state <= S_READ_BURST;
					//rd_burst_len <= BURST_SIZE[BURST_BITS - 1:0];
					//rd_burst_req <= 1'b1;
					App_rd_en_r <= 1'b1;
				end
			end
			
			S_READ_BURST:
			begin
				//burst finish  
				if(rd_burst_finish == 1'b1)
				begin
					App_rd_en_r <= 1'b0;
					state <= S_READ_BURST_END;
					//read counter + burst length
					read_cnt <= read_cnt + BURST_SIZE[ADDR_BITS - 1:0];
					//the next burst read address is generated
					//rd_burst_addr <= rd_burst_addr + BURST_SIZE[ADDR_BITS - 1:0];
				end     
			end
			S_READ_BURST_END:
			begin
				//if there is a read request at this time, enter the 'S_ACK' state
				if(read_req_d2 == 1'b1)
				begin
					state <= S_ACK;
				end
				//if the read counter value is less than the frame length, continue read,
				//otherwise the read is complete
				else if(read_cnt < read_len_latch)
				begin
					state <= S_CHECK_FIFO;
				end
				else
				begin
					state <= S_END;
				end
			end
			S_END:
			begin
				state <= S_IDLE;
			end
			default:
				state <= S_IDLE;
		endcase
end
endmodule

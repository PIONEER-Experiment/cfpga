`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////
// Connect the module that manages reading data from the memory

module ddr3_rd_control (
	// User interface clock and reset   
	input clk,								// DDR3 domain user clock
	input reset,							// reset at startup or when requested
	input acq_enabled,						// input, writing is enabled
	// connections to the 'rd_fill' command logic
	input [22:0] ddr3_rd_burst_addr,		// input, the address of the requested 128-bit burst
	input rd_one_burst,						// input, get one 128-bit burst from the DDR3
	output reg one_burst_rdy,				// output, the requested 128-bit burst is ready
	output reg [127:0] ddr3_one_burst_data,	// output, the requested 128-bit burst
	// 'read' ports to memory
	input app_rd_data_end,					// input, last data cycle
	input app_rd_data_valid,				// input, memory data is valid	
	input [127:0] app_rd_data,				// input, memory data	
	// 'read' ports to address controller
	input rd_app_rdy,						// input, increment the 'read' address
	output [25:0] rd_addr,					// output, next 'read' address
	output reg rd_app_en					// output, request to perform a 'read'	
);

// synchronize the 'rd_one_burst' request to the DDR3 clock domain
reg rd_one_burst_sync1, rd_one_burst_sync2;
always @(posedge clk) begin
	rd_one_burst_sync1 <= rd_one_burst;
	rd_one_burst_sync2 <= rd_one_burst_sync1;
end

// shift the burst address, and then pass it  right through
assign rd_addr[25:0] = {ddr3_rd_burst_addr[22:0], 3'b000};

//  Leave the comments containing "synopsys" in your HDL code.
 
// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [1:0]
	IDLE		= 2'd0,
	SEND_ADDR	= 2'd1,
	WAIT_DATA	= 2'd2,
	DONE		= 2'd3;
	
// Declare current state and next state variables
reg [3:0] /* synopsys enum STATE_TYPE */ CS;
reg [3:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
	if (reset) begin
		CS <= 4'b0;				// set all state bits to 0
		CS[IDLE] <= 1'b1;		// set IDLE state bit to 1
	end
	else
		CS <= NS;			// set state bits to next state
end

// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or acq_enabled or rd_one_burst_sync2 or rd_app_rdy or app_rd_data_valid) 	begin
	NS = 4'b0;					// default all bits to zero; will overrride one bit

	case (1'b1) //synopsys full_case parallel_case

		// Stay in the IDLE state until a read is requested and we are not in 'write_mode'.
		CS[IDLE]: begin
			if (rd_one_burst_sync2 && !acq_enabled)
				NS[SEND_ADDR] = 1'b1;
			else
				NS[IDLE] = 1'b1;
		end

		// Stay in the SEND_ADDR state until an address ack is received.
		CS[SEND_ADDR]: begin
			if (rd_app_rdy)
				NS[WAIT_DATA] = 1'b1;
			else
				NS[SEND_ADDR] = 1'b1;
		end
		
		// Stay in the WAIT_DATA state until a data ack is received.
		CS[WAIT_DATA]: begin
			if (app_rd_data_valid)
				NS[DONE] = 1'b1;
			else
				NS[WAIT_DATA] = 1'b1;
		end
		
		// Stay in the DONE state until the read request is negated.
		CS[DONE]: begin
			if (rd_one_burst_sync2)
				NS[DONE] = 1'b1;
			else
				NS[IDLE] = 1'b1;
		end
	endcase
end // combinational always block to determine next state
	
// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
	// defaults
	rd_app_en  <= 1'b0;
	one_burst_rdy  <= 1'b0;

	// next states
	if (NS[IDLE]) begin
	end
		
	if (NS[SEND_ADDR]) begin
	   // activate the address control block 
		rd_app_en	<= 1'b1;
	end

	if (NS[WAIT_DATA]) begin
	end
		
	if (NS[DONE]) begin
	   // tell the requester that the data is ready 
		one_burst_rdy	<= 1'b1;
	end
end // output block

always @(posedge clk) begin
	if (app_rd_data_valid) ddr3_one_burst_data[127:0] <= app_rd_data[127:0];
end

endmodule


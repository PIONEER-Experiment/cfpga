`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////
// Connect the module that manages writing data to the memory

module ddr3_wr_control (
	// User interface clock and reset   
	input clk,							// DDR3 domain user clock
	input reset,
	// Connections to the FIFO from the ADC
	input [127:0] ddr3_wr_dat,			// input, next 'write' data from the ADC FIFO
	input ddr3_wr_fifo_empty,			// input, data is available when this is not asserted
	output reg ddr3_wr_fifo_rd_en,			// output, use and remove the data on the FIFO head
	// 'write' ports to memory
	output reg app_wdf_wren,				// output, request to perform a 'write'	
	input app_wdf_rdy,					// input, memory can accept data
	output reg app_wdf_end,					// output, last data cycle
	// 'write' ports to address controller
	output reg wr_mode,						// output, writing has priority
	output [25:0] ddr3_wr_addr,			// output, next 'write' address
	output reg wr_request,					// output, request to perform a 'write'	
	input wr_addr_ack,					// input, increment the 'write' address
	// 'write' ports to the fill_header_fifo
	output [127:0] fill_header_wr_dat,	// header data
	output reg fill_header_wr_en			// store header in FIFO
);
 
// Create a register to hold the header for future writing to the fill-header FIFO
reg [127:0] fill_header_wr_dat_reg;
reg latch_header;	// will be asserted by the state machine
always @ (posedge clk) begin
	if (reset) fill_header_wr_dat_reg <= 128'b0;
	else if (latch_header) fill_header_wr_dat_reg[127:0] <= ddr3_wr_dat[127:0];
end
assign fill_header_wr_dat[127:0] = fill_header_wr_dat_reg[127:0];

// Create an address counter
// Initialize it from the header
// Increment it whenever we get a 'wr_addr_ack'
reg [22:0] address_cntr;
reg init_address_cntr;	// will be asserted by the state machine
always @ (posedge clk) begin
	if (reset) address_cntr[22:0] <= 23'b0;
	if (init_address_cntr) address_cntr[22:0] <= ddr3_wr_dat[57:35];
	if (wr_addr_ack) address_cntr[22:0] <= address_cntr[22:0] + 23'b1;
end
assign ddr3_wr_addr[25:0] = {address_cntr[22:0], 3'b0};

// Create a burst counter
// Initialize it from the header
// Deccrement it whenever we get a successful write. This happens when
// we are asserting 'app_wdf_wren' and receiving 'app_wdf_rdy'.
reg [20:0] burst_cntr;
reg init_burst_cntr;	// will be asserted by the state machine
always @ (posedge clk) begin
	if (reset) burst_cntr[20:0] <= 21'b0;
	if (init_burst_cntr) burst_cntr[20:0] <= ddr3_wr_dat[84:64];
	if (app_wdf_wren & app_wdf_rdy) burst_cntr[20:0] <= burst_cntr[20:0] - 21'b1;
end

// 
//  Leave the comments containing "synopsys" in your HDL code.
 
// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [3:0]
	IDLE		= 4'd0,
	TST_HDR_TAG	= 4'd1,
	INIT		= 4'd2,
	ADJ_CNT		= 4'd3,
	WRITE		= 4'd4,
	TST_FTR_TAG	= 4'd5,
	SYNC_ERR	= 4'd6,
	DONE		= 4'd7;
	
// Declare current state and next state variables
reg [7:0] /* synopsys enum STATE_TYPE */ CS;
reg [7:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
	if (reset) begin
		CS <= 8'b0;				// set all state bits to 0
		CS[IDLE] <= 1'b1;		// set IDLE state bit to 1
	end
	else
		CS <= NS;			// set state bits to next state
end

// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or ddr3_wr_fifo_empty or ddr3_wr_dat or burst_cntr) 	begin
	NS = 8'b0;					// default all bits to zero; will overrride one bit

	case (1'b1) //synopsys full_case parallel_case

		// Stay in the IDLE state until we see that the fifo is not empty.
		// Since the FIFO runs in first-word fall-through mode, if the fifo
		// in not empty, then the data will be vaild
		CS[IDLE]: begin
			if (ddr3_wr_fifo_empty)
					// stay here if there is no data
					NS[IDLE] = 1'b1;
			else
					NS[TST_HDR_TAG] = 1'b1;
		end

		// Stay in TST_HDR_TAG state for one period.
		// If the 2 MSBs of the data are a valid header tag (2'b01), then proceed.
		// If not, then we are out of sync and need to flag an error 
		CS[TST_HDR_TAG]: begin
			if (ddr3_wr_dat[127:126] == 2'b01)
				// we have a valid header
				NS[INIT] = 1'b1;
			else
				// we are not synchronized. Go raise an error condition
				NS[SYNC_ERR] = 1'b1;
		end

		// Stay in INIT state for one period.
		// Initialize the address and data counters. Store a copy of the header
		// for writing to the fill header fifo
		CS[INIT]: begin
				NS[ADJ_CNT] = 1'b1;
		end

		// Stay in ADJ_CNT state for one period.
		// Make necessary adjustments to the burst counter to account for
		// how we determine when we are done 
		CS[ADJ_CNT]: begin
				NS[WRITE] = 1'b1;
		end

		// Stay in WRITE state until all of the data has been written to memory.
		CS[WRITE]: begin
			if (burst_cntr[20:0] == 21'b0)
				// we have written the requested number of bursts
				NS[TST_FTR_TAG] = 1'b1;
			else
				// More data to write, stay here
				NS[WRITE] = 1'b1;
		end
		
		// Stay in TST_FTR_TAG state for one period.
		// If the 2 MSBs of the data are a valid footer tag (2'b10), then proceed.
		// If not, then we are out of sync and need to flag an error 
		CS[TST_FTR_TAG]: begin
			if (ddr3_wr_dat[127:126] == 2'b10)
				// we have a valid footer
				NS[DONE] = 1'b1;
			else
				// we are not synchronized. Go raise an error condition
				NS[SYNC_ERR] = 1'b1;
		end

		// Stay in DONE state for one period.
		// Write the original header to the fill_header_fifo
		CS[DONE]: begin
               NS[IDLE] = 1'b1;
		end

	endcase
end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
	// defaults
		init_address_cntr	<= 1'b0;
		init_burst_cntr		<= 1'b0;
		latch_header		<= 1'b0;
		ddr3_wr_fifo_rd_en	<= 1'b0;
		app_wdf_wren		<= 1'b0;
		app_wdf_end			<= 1'b0;
		wr_mode				<= 1'b1;
        wr_request			<= 1'b0;
        fill_header_wr_en	<= 1'b0;

	// next states
	if (NS[IDLE]) begin
		// 'wr_mode' is asserted by default. Negate it in IDLE.
		wr_mode				<= 1'b0;
	end
	
	if (NS[TST_HDR_TAG]) begin
		// latch the header data for use later
		latch_header		<= 1'b1;
	end

	if (NS[INIT]) begin
		// initialize the address counter from the header
		init_address_cntr	<= 1'b1;
		// initialize the burst counter from the header
		init_burst_cntr	<= 1'b1;
	end
 
	if (NS[ADJ_CNT]) begin
    end

 	if (NS[WRITE]) begin
		// indicate that we want to supply an address and a command 
 		wr_request			<= 1'b1;
		// indicate that we have data to write 
		app_wdf_wren		<= 1'b1;
		// read the next FIFO data if the previous data was accepted
		ddr3_wr_fifo_rd_en	<= app_wdf_rdy;
		// assert 'app_wdf_end' with every operation
		app_wdf_end			<= 1'b1;;
	end

	if (NS[TST_FTR_TAG]) begin
	end

	if (NS[SYNC_ERR]) begin
	end

	if (NS[DONE]) begin
	    // write the header to the FIFO
		fill_header_wr_en		<= 1'b1;
	end

	
end



endmodule

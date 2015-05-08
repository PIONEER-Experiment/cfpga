`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////
// Connect the module that manages writing data to the memory

module ddr3_wr_control (
	// User interface clock and reset   
	input clk,								// DDR3 domain user clock
	input reset,
	input acq_enabled,						// input, writing is enabled
	// Connections to the FIFO from the ADC
	input [127:0] ddr3_wr_fifo_dat,			// input, next 'write' data from the ADC FIFO
	input ddr3_wr_fifo_near_empty,				// asserted at less than 4, negated at more than 10 
	input ddr3_wr_fifo_empty,				// input, data is available when this is not asserted
	output ddr3_wr_fifo_rd_en,			// output, use and remove the data on the FIFO head
	// 'write' ports to memory
	output  app_wdf_wren,				// output, request to perform a 'write'	
	input app_wdf_rdy,						// input, memory can accept data
	output  app_wdf_end,					// output, last data cycle
	// 'write' ports to address controller
	output [25:0] ddr3_wr_addr,				// output, next 'write' address
	output  wr_app_en,					// output, request to perform a 'write'	
	input wr_app_rdy,						// input, increment the 'write' address
	// 'write' ports to the fill_header_fifo
	output [127:0] fill_header_wr_dat,		// header data
	output reg fill_header_wr_en,			// store header in FIFO
	// status flag back to the ADC acquisition machine
	output reg ddr3_wr_busy,				// asserted whenever the 'ddr3_wr_control' is not idle
	// synchronization error flag
	output reg ddr3_wr_sync_err

);

// define equivalent statement for data and address acceptance
assign address_accept	= (wr_app_en & wr_app_rdy);			// we presented an address and it was accepted
assign data_accept		= (app_wdf_wren & app_wdf_rdy);		// we presented data and it was accepted
wire address_allow;		// allow attempts to write an address
 
// Create a register to hold the header for future writing to the fill-header FIFO
reg [127:0] fill_header_wr_dat_reg;
reg latch_header;	// will be asserted by the state machine
always @ (posedge clk) begin
	if (reset) fill_header_wr_dat_reg <= 128'b0;
	else if (latch_header) fill_header_wr_dat_reg[127:0] <= ddr3_wr_fifo_dat[127:0];
end
assign fill_header_wr_dat[127:0] = fill_header_wr_dat_reg[127:0];

// Create an address generator
// Initialize it from the 'start_address' in the header
// Increment it whenever we the address is accepted ( we get a 'wr_app_rdy' while asserting 'wr_app_en') 
reg [22:0] address_gen;
reg init_address_gen;	// will be asserted by the state machine
always @ (posedge clk) begin
	if (reset) address_gen[22:0] <= 23'b0;
	else if (init_address_gen) address_gen[22:0] <= ddr3_wr_fifo_dat[57:35];
	else if (address_accept) address_gen[22:0] <= address_gen[22:0] + 1;
end
assign ddr3_wr_addr[25:0] = {address_gen[22:0], 3'b0};

// Create an address counter
// Initialize it from the 'burst_cnt' in the header
// Decrement it whenever an address is accepted. This happens when
// we are asserting 'wr_app_en' and receiving 'wr_app_rdy'.
reg [20:0] address_cntr;
reg init_address_cntr;		// will be asserted by the state machine
reg adjust_address_cntr;	// add 2 to account for header and checksum
wire address_cntr_zero;		// the counter is at zero
always @ (posedge clk) begin
	if (reset) address_cntr[20:0] <= 21'b0;
	else if (init_address_cntr) address_cntr[20:0] <= ddr3_wr_fifo_dat[84:64];
	else if (adjust_address_cntr) address_cntr[20:0] <= address_cntr[20:0] + 2;
	else if (address_cntr_zero) address_cntr[20:0] <= 21'b0; 
	else if (address_accept) address_cntr[20:0] <= address_cntr[20:0] - 1;
end
// create a flag that gets set when the address counter is down to zero
assign address_cntr_zero = (address_cntr[20:0] == 21'h00_0000) ? 1'b1 : 1'b0;

// Create a burst counter
// Initialize it from the header
// Decrement it whenever we get a successful write. This happens when
// we are asserting 'wdf_wren' and receiving 'wdf_rdy'.
reg [20:0] burst_cntr;
reg init_burst_cntr;	// will be asserted by the state machine
reg adjust_burst_cntr;	// add 2 to account for header and checksum
wire burst_cntr_zero;	// the counter is at zero
always @ (posedge clk) begin
	if (reset) burst_cntr[20:0] <= 21'b0;
	else if (init_burst_cntr) burst_cntr[20:0] <= ddr3_wr_fifo_dat[84:64];
	else if (adjust_burst_cntr) burst_cntr[20:0] <= burst_cntr[20:0] + 2;
	else if (burst_cntr_zero) burst_cntr[20:0] <= 21'b0; 
	else if (data_accept) burst_cntr[20:0] <= burst_cntr[20:0] - 1;
end
// create a flag that gets set when the burst counter is down to zero
assign burst_cntr_zero = (burst_cntr[20:0] == 21'h00_0000) ? 1'b1 : 1'b0;

// Create a counter that will control when addresses are sent to the DDR3 interface.
// Since addresses come from a counter, we always have addresses available. However, when we
// send an address, we must send the data within 2 clock periods.
// With this throttle, we will never send an address until after we have sent the data
// destined for that address.
reg [4:0] address_control;
always @ (posedge clk) begin
	// set to zero when reset
	if (reset) address_control <= 0;
	// increment when data is accepted and an address is not accepted
	else if (data_accept && !address_accept) address_control <= address_control + 1;
	// decrement when address is accepted and data is not accepted
	else if (!data_accept && address_accept) address_control <= address_control - 1;
	// don't change if both are accepted or if neither is accepted
	else address_control <= address_control;
end
// attempts to write addresses are only allowed when the counter is not zero
assign address_allow = ~(address_control == 0);

// 
//  Leave the comments containing "synopsys" in your HDL code.
 
// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [3:0]
	IDLE		= 4'd0,
	TST_HDR_TAG	= 4'd1,
	SYNC_ERR	= 4'd2,
	INIT		= 4'd3,
	ADJ_CNT		= 4'd4,
	WRITE		= 4'd5,
//	FIN_WRITE1	= 4'd6,
//	TST_EMPTY	= 4'd7,
//	RD_FIFO		= 4'd8,
	DONE		= 4'd6;
	
// Declare current state and next state variables
reg [6:0] /* synopsys enum STATE_TYPE */ CS;
reg [6:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
	if (reset || !acq_enabled) begin
		CS <= 7'b0;				// set all state bits to 0
		CS[IDLE] <= 1'b1;		// set IDLE state bit to 1
	end
	else
		CS <= NS;			// set state bits to next state
end

// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or ddr3_wr_fifo_empty or ddr3_wr_fifo_dat or burst_cntr_zero or address_cntr_zero) 	begin
	NS = 7'b0;					// default all bits to zero; will overrride one bit

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
			if (ddr3_wr_fifo_dat[127:126] == 2'b01)
				// we have a valid header
				NS[INIT] = 1'b1;
			else
				// we are not synchronized. Go raise an error condition
				NS[SYNC_ERR] = 1'b1;
		end

		// Stay in SYNC_ERR state until the state machine is reset.
		// Raise the 'error' flag
		CS[SYNC_ERR]: begin
               NS[SYNC_ERR] = 1'b1;
		end

		// Stay in INIT state for one period.
		// Initialize the address and data counters. Store a copy of the header
		// for writing to the fill header fifo
		CS[INIT]: begin
				NS[ADJ_CNT] = 1'b1;
		end

		// Stay in ADJ_CNT state for one period.
		// Make necessary adjustments to the address and burst counters to account for
		// how we determine when we are done 
		CS[ADJ_CNT]: begin
				NS[WRITE] = 1'b1;
		end

		// Generally stay in WRITE state until all of the data has been written to memory.
//		// However, if the FIFO is 'near_empty', change to a mode where we finish up the
//		//current write and then test the 'empty' status every time.
		CS[WRITE]: begin
			if (burst_cntr_zero && address_cntr_zero)
				// we have written the requested number of addresses and bursts
				NS[DONE] = 1'b1;
//			else if (!burst_cntr_zero && ddr3_wr_fifo_near_empty)
//				// more data may be coming. Leave until we know that we have a new data sample
//				NS[FIN_WRITE1] = 1'b1;
			else
				// More addresses or data to write, stay here
				NS[WRITE] = 1'b1;
		end

//		// Stay in FIN_WRITE1 state for one period.
//		// Allow time for the current write operation to be accepted 
//		CS[FIN_WRITE1]: begin
//				NS[TST_EMPTY] = 1'b1;
//		end

//		// Unless we are finished with data, stay here until we know that the fifo has data.
//		// We cannot afford to test the 'empty' flag on every clock, so we only test it
//		// when we know that the fifo is low on data.
//		CS[TST_EMPTY]: begin
//			if (burst_cntr_zero)
//				// we have written the requested number of bursts, but there may still be addresses to write
//				NS[WRITE] = 1'b1;
//			else if (!ddr3_wr_fifo_empty)
//				// we have data
//				NS[RD_FIFO] = 1'b1;
//			else
//				// More data expected, but not arrived yet, so stay here
//				NS[TST_EMPTY] = 1'b1;
//		end

//		// Stay in RD_FIFO state for one period.
//		// Get new data from the FIFO
//		CS[RD_FIFO]: begin
//				NS[WRITE] = 1'b1;
//		end
		
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
		ddr3_wr_busy		<= 1'b1; // busy unless we are IDLE
		latch_header		<= 1'b0;
		init_address_gen	<= 1'b0;
		init_address_cntr	<= 1'b0;
		init_burst_cntr		<= 1'b0;
		adjust_burst_cntr	<= 1'b0;
		adjust_address_cntr	<= 1'b0;
//		wr_app_en			<= 1'b0;
//		app_wdf_wren		<= 1'b0;
//		app_wdf_end			<= 1'b0;
		//ddr3_wr_fifo_rd_en	<= 1'b0;
 		ddr3_wr_sync_err	<= 1'b0;
        fill_header_wr_en	<= 1'b0;

	// next states
	if (NS[IDLE]) begin
		ddr3_wr_busy		<= 1'b0; // only not busy when IDLE
	end
	
	if (NS[TST_HDR_TAG]) begin
		// latch the header data for use later
		latch_header		<= 1'b1;
	end

	if (NS[INIT]) begin
		// initialize the address counter from the header
		init_address_gen	<= 1'b1;
		// initialize the address counter from the header
		init_address_cntr	<= 1'b1;
		// initialize the burst counter from the header
		init_burst_cntr	<= 1'b1;
	end
 
	if (NS[ADJ_CNT]) begin
		// increment the address counter to adjust for the checksum
		adjust_address_cntr	<= 1'b1;
		// increment the burst counter to adjust for the checksum
		adjust_burst_cntr	<= 1'b1;
    end

 	if (NS[WRITE]) begin
		// maybe indicate that we want to supply an address and a command 
// 		wr_app_en <= ~address_cntr_zero;
		// indicate that we want to supply data if it is available 
// 		app_wdf_wren <= ~ddr3_wr_fifo_empty; // was: ~burst_cntr_zero;
//		app_wdf_end <= ~ddr3_wr_fifo_empty;	// was: ~burst_cntr_zero;
	end

//	if (NS[FIN_WRITE1]) begin
//		// If the previous data write was not accepted, try again
//		// ASSUME THAT 2 CLOCK PERIODS IS THE MOST THAT IS EVER NEEDED!!!
//		if (!app_wdf_rdy) begin
//			app_wdf_wren <= ~burst_cntr_zero;
//			app_wdf_end <= ~burst_cntr_zero;
//		end
//		// If the previous address write was not accepted, try again
//		// ASSUME THAT 2 CLOCK PERIODS IS THE MOST THAT IS EVER NEEDED!!!
//		if (!wr_app_rdy) begin
//			wr_app_en <= ~address_cntr_zero;
//		end 
//	end

//	if (NS[TST_EMPTY]) begin
//	end

//	if (NS[RD_FIFO]) begin
//	end

	if (NS[SYNC_ERR]) begin
		// assert an error flag
		ddr3_wr_sync_err <= 1'b1;
	end

	if (NS[DONE]) begin
	    // write the header to the FIFO
		fill_header_wr_en		<= 1'b1;
	end

	
end

// indicate that we want to supply an address if data has already been accepted
assign wr_app_en = CS[WRITE] && address_allow && !address_cntr_zero;
// indicate that we want to supply data if it is available 
assign app_wdf_wren = CS[WRITE] && !ddr3_wr_fifo_empty && !burst_cntr_zero; // was: ~burst_cntr_zero;
assign app_wdf_end = CS[WRITE] && !ddr3_wr_fifo_empty && !burst_cntr_zero;	// was: ~burst_cntr_zero;

// if the current data was accepted then bring the next FIFO data to the front 
assign ddr3_wr_fifo_rd_en	= CS[WRITE] && data_accept && !burst_cntr_zero;

endmodule

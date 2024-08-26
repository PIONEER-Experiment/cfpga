`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////
// Connect the module that manages reading data from the memory

module ddr3_rd_control (
	// User interface clock and reset   
	input clk,								// DDR3 domain user clock
	input reset,							// reset at startup or when requested
(* mark_debug = "true" *) input acq_enabled,						// input, writing is enabled
	// connections to the 'rd_fill' command logic
(* mark_debug = "true" *) input [22:0] ddr3_rd_start_addr,		// input, the address of the first requested 128-bit burst
(* mark_debug = "true" *) input [23:0] ddr3_rd_burst_cnt,         // input, the number of bursts to read
(* mark_debug = "true" *) input enable_reading,      				// input, initialize the address generator and both counters, go
	output reading_done,       				// output, reading is complete
	// 'read' ports to memory
(* mark_debug = "true" *) input app_rd_data_end,					// input, last data cycle
(* mark_debug = "true" *) input app_rd_data_valid,				// input, memory data is valid
	//input [127:0] app_rd_data,				// input, memory data
	// 'read' ports to address controller
(* mark_debug = "true" *) input rd_app_rdy,						// input, increment the 'read' address
(* mark_debug = "true" *) output [25:0] ddr3_rd_addr,				// output, next 'read' address
(* mark_debug = "true" *) output rd_app_en,					    // output, request to perform a 'read'
	// ports to the 'read' fifo
(* mark_debug = "true" *) output ddr3_rd_fifo_wr_en,             // data is valid, so put it in the READ FIFO
	//output [127:0] ddr3_rd_fifo_input_dat, // output, memory data
	input ddr3_rd_fifo_almost_full,        // there is not much room left
(* mark_debug = "true" *) output ddr3_rd_fifo_input_tlast		   // the last burst for this fill
);

// just pass the DDR3 data thru to the FIFO
// moved this assignment up 1 level to 'ddr3_intf.v' to eliminate warning meaasges about unused signals
//assign ddr3_rd_fifo_input_dat[127:0] = app_rd_data[127:0];

// synchronize the 'enable_reading' request to the DDR3 clock domain.
// Also, make a single period pulse for initialization
(* ASYNC_REG = "TRUE" *) reg enable_reading_sync1, enable_reading_sync2, enable_reading_sync3;
(* mark_debug = "true" *) reg enable_reading_pulse;
always @(posedge clk) begin
	enable_reading_sync1 <= enable_reading;
	enable_reading_sync2 <= enable_reading_sync1;
	enable_reading_sync3 <= enable_reading_sync2;
	// make single period pulse
	enable_reading_pulse <= enable_reading_sync2 & !enable_reading_sync3;
end

// define equivalent statements for address acceptance
assign address_accept = (rd_app_en & rd_app_rdy); // we presented an address and it was accepted

// Create an address generator
// Initialize it from the 'ddr3_rd_start_addr' extracted from the 'fill_header_fifo'
// Increment it whenever the address is accepted (we get a 'rd_app_rdy' while asserting 'rd_app_en') 
(* mark_debug = "true" *) reg [22:0] address_gen;
reg init_address_gen;	// will be asserted by the state machine
always @ (posedge clk) begin
	if (reset) address_gen[22:0] <= 23'b0;
	else if (enable_reading_pulse) address_gen[22:0] <= ddr3_rd_start_addr[22:0];
	else if (address_accept) address_gen[22:0] <= address_gen[22:0] + 1;
end
assign ddr3_rd_addr[25:0] = {address_gen[22:0], 3'b0};

// Create an address counter
// Initialize it from the 'burst_cnt' provided by the 'rd_fill' logic
// Decrement it whenever an address is accepted. This happens when
// we are asserting 'rd_app_en' and receiving 'rd_app_rdy'.
(* mark_debug = "true" *) reg [23:0] address_cntr;
wire address_cntr_zero;		// the counter is at zero
always @ (posedge clk) begin
	if (reset) address_cntr[23:0] <= 24'b0;
	else if (enable_reading_pulse) address_cntr[23:0] <= ddr3_rd_burst_cnt[23:0];
	else if (address_cntr_zero) address_cntr[23:0] <= 24'b0; 
	else if (address_accept) address_cntr[23:0] <= address_cntr[23:0] - 1;
end
// create a flag that gets set when the address counter is down to zero
assign address_cntr_zero = (address_cntr[23:0] == 24'b0) ? 1'b1 : 1'b0;

// Create a burst counter
// Initialize it from the 'burst_cnt' provided by the 'rd_fill' logic
// Decrement it whenever we get a successful read. This happens when
// we are receive 'app_rd_data_valid'.
(* mark_debug = "true" *) reg [23:0] burst_cntr;
wire burst_cntr_zero, burst_cntr_one;	// the counter is at zero or one
always @ (posedge clk) begin
	if (reset) burst_cntr[23:0] <= 24'b0;
	else if (enable_reading_pulse) burst_cntr[23:0] <= ddr3_rd_burst_cnt[23:0];
	else if (burst_cntr_zero) burst_cntr[23:0] <= 24'b0; 
	else if (app_rd_data_valid) burst_cntr[23:0] <= burst_cntr[23:0] - 1;
end
// create a flag that gets set when the burst counter is down to zero
assign burst_cntr_zero = (burst_cntr[23:0] == 24'd0) ? 1'b1 : 1'b0;
assign burst_cntr_one  = (burst_cntr[23:0] == 24'd1) ? 1'b1 : 1'b0;
assign ddr3_rd_fifo_input_tlast = burst_cntr_one;

// to help with debugging, create an event counter
(* mark_debug = "true" *) reg [11:0] event_ctr;
always @ (posedge clk) begin
  if (enable_reading_pulse) begin
    event_ctr[11:0] = event_ctr[11:0] + 1;
  end
  else begin
    event_ctr[11:0] = event_ctr[11:0];
  end
end


//  Leave the comments containing "synopsys" in your HDL code.
 
// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [1:0]
	IDLE = 2'd0,
	READ = 2'd1,
	DONE = 2'd2;
	
// Declare current state and next state variables
(* mark_debug = "true" *) reg [2:0] /* synopsys enum STATE_TYPE */ CS;
reg [2:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
	if (reset | !enable_reading_sync2) begin
		CS <= 3'b0;			// set all state bits to 0
		CS[IDLE] <= 1'b1;	// set IDLE state bit to 1
	end
	else
		CS <= NS;			// set state bits to next state
end

// combinational always block to determine next state (use blocking [=] assignments) 
always @ (CS or enable_reading_sync3 or burst_cntr_zero) begin
	NS = 3'b0; // default all bits to zero; will overrride one bit

	case (1'b1) //synopsys full_case parallel_case

		// Stay in the IDLE state until a read is initialized.
		CS[IDLE]: begin
			if (enable_reading_sync3)
				NS[READ] = 1'b1;
			else
				NS[IDLE] = 1'b1;
		end

		// Stay in the READ state until all data has been read.
		CS[READ]: begin
			if (burst_cntr_zero)
				NS[DONE] = 1'b1;
			else
				NS[READ] = 1'b1;
		end
		
		// Stay in the DONE state until the state machine is reset.
		CS[DONE]: begin
				NS[DONE] = 1'b1;
		end
	endcase
end // combinational always block to determine next state	
	
// indicate that we want to supply an address
// 'acq_enabled' must be negated to allow reading
// 'address_cntr_zero' must be negated, indicating that we want more data
// 'ddr3_rd_fifo_almost_full' nust be negated, indicating that there is somewhere to our the data
assign rd_app_en = CS[READ] && !acq_enabled && !address_cntr_zero && !ddr3_rd_fifo_almost_full;

// if the current data is valid then write it to the fifo 
assign ddr3_rd_fifo_wr_en = CS[READ] && app_rd_data_valid;

// assert 'reading_done' when we are in the DONE state
assign reading_done = CS[DONE];

endmodule

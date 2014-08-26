// adc_acquisition_control_sm.v
//
// 
module adc_acquisition_control_sm(
	input clk,					// 400 MHz ADC clock
	input arm,					// arm or reset the acquisition controller
	input trig,					// we have been triggered
	output done,				// acquisition for the current trigger is complete
	
	// interface to the ADC data memory and header FIFO
	output reg data_mem_wea,			// enable writing to the ADC data memory
	output reg [11:0] data_mem_addra,	// address for writing to the ADC data memory
	output reg header_fifo_wr_en,		// enable writing to the ADC header FIFO
	output reg [31:0] header_data,		// data to put in the ADC header FIFO 
 
	// data for the ADC header FIFO and/or for local control
	// The buffer_size, channel_num, post_trig_size, and initial_trig_num are from the register block/
	// They are stable during operation, so do not need synchronization. The 'initial_even_num_we' signal
	// will need to be synched. The current_trig_num is provided for register readback
	input [31:0] buffer_size,		// number of words in the data stream (2 samples per word)
	input [31:0] channel_num,		// the number for this channel
	input [31:0] post_trig_size,	// number of words to continue acquiring after a trigger
	input [31:0] initial_trig_num,	// initial value for the event number
	input trig_num_we,				// enable saving of the initial value for the event number
	output reg [31:0] current_trig_num,	// the current value for the event number
	input rst, // reset from master
	output led2 // green led
 );

 	// green led is ON only when channel is both triggered and done
 	assign led2 = ~(trig_sync2 && done) ? 1'b1 : 1'b0;

	wire post_trig_done;
	
	// synchronize 'arm' and 'trig' , and 'trig_num_we' to the ADC clock
	reg arm_sync1, arm_sync2, trig_sync1, trig_sync2, trig_num_we_sync1, trig_num_we_sync2;
	reg rst_sync1, rst_sync2;
	always @ (posedge clk) begin
		arm_sync1 <= arm;
		arm_sync2 <= arm_sync1;
		trig_sync1 <= trig;
		trig_sync2 <= trig_sync1;
		trig_num_we_sync1 <= trig_num_we;
		trig_num_we_sync2 <= trig_num_we_sync1;
		rst_sync1 <= rst;
		rst_sync2 <= rst_sync1;
	end
	
	// State machine for acquiring an event from the ADC
	//  Leave the comments containing "synopsys" in your HDL code.
 
	// Declare the symbolic names for states for the state machine
	// Simplified one-hot encoding (each constant is an index into an array of bits)
	parameter [4:0]
		IDLE			= 5'd0,
		INIT			= 5'd1,
		WAIT_TRIG		= 5'd2,
		TRIGGERED		= 5'd3,
		WAIT_POST_TRIG	= 5'd4,
		HDR_TRIG_NUM1	= 5'd5,
		HDR_TRIG_NUM2	= 5'd6,
		HDR_BUF_SIZE1	= 5'd7,
		HDR_BUF_SIZE2	= 5'd8,
		HDR_CHAN_NUM1	= 5'd9,
		HDR_CHAN_NUM2	= 5'd10,
		HDR_POST_TRIG1	= 5'd11,
		HDR_POST_TRIG2	= 5'd12,
		HDR_START_ADR1	= 5'd13,
		HDR_START_ADR2	= 5'd14,
		DONE			= 5'd15;
				
	// Declare current state and next state variables
	reg [15:0] /* synopsys enum STATE_TYPE */ CS;
	reg [15:0] /* synopsys enum STATE_TYPE */ NS;
	//synopsys state_vector CS

 
	// sequential always block for state transitions (use non-blocking [<=] assignments)
	// Reset the sm whenever we are not armed or when reset signal comes from the master
	always @ (posedge clk) begin
		if (!arm_sync2) begin
			CS <= 16'b0;			// set all state bits to 0
			CS[IDLE] <= 1'b1;		// set IDLE state bit to 1
		end
		else if (rst_sync2) begin
			CS <= 16'b0;			// set all state bits to 0
			CS[IDLE] <= 1'b1;		// set IDLE state bit to 1
		end
		else  CS <= NS;			// set state bits to next state
	end

	// combinational always block to determine next state  (use blocking [=] assignments) 
	always @ (CS or trig_sync2 or post_trig_done) begin
		NS = 16'b0;					// default all bits to zero; will overrride one bit

		case (1'b1) //synopsys full_case parallel_case

			// We will be in the IDLE state whenever we are not 'armed'.
			// Once enabled, immediately start working
			CS[IDLE]: begin
					// Go initialize stuff.
					NS[INIT] = 1'b1;
			end

			// We enter the INIT state after we have been started. We
			// We stay here for one cycle, during which the address counter is reset and the
			// post_trigger counter is initialized.
			CS[INIT]: begin
				// Go start the circular buffer and wait for a trigger.
				NS[WAIT_TRIG] = 1'b1;
			end

			// We enter the WAIT_TRIG state whenever we have been armed and completed initialization.
			// We stay here until a trigger is detected.
			// The address counter runs continuously, creating a circular pre-trigger buffer.
			CS[WAIT_TRIG]: begin
				if (trig_sync2)
					// we have been triggered, so go start post-trigger activities
					NS[TRIGGERED] = 1'b1;
				else
					// stay here until a trigger is seen
					NS[WAIT_TRIG] = 1'b1;
			end

			// We enter the TRIGGERED state after we have been triggered.
			// We stay here for one cycle, during which the address counter is latched.
			CS[TRIGGERED]: begin
				// Go wait for the post-trigger counter to get to zero.
				NS[WAIT_POST_TRIG] = 1'b1;
			end

			// We enter the WAIT_POST_TRIG state after we have seen a trigger.
			// We stay here until the post-trigger counter is down to zero
			// The address counter continues running, storing post-trigger data.
			CS[WAIT_POST_TRIG]: begin
				if (post_trig_done)
					// the post-trigger counter is down to zero, start writing the header
					NS[HDR_TRIG_NUM1] = 1'b1;
				else
					// continue collecting post-trigger data.
					NS[WAIT_POST_TRIG] = 1'b1;
			end

			// We enter the HDR_TRIG_NUM1 state after we have completed collecting data.
			// We stay here for one cycle
			// The trigger number is routed to the header FIFO
			CS[HDR_TRIG_NUM1]: begin
					// Go write to the FIFO.
					NS[HDR_TRIG_NUM2] = 1'b1;
			end

			// We enter the HDR_TRIG_NUM2 state when the trigger number has been presented to the header FIFO.
			// We stay here for one cycle, during which 'header_fifo_wr_en' is asserted to tell
			// the header FIFO that it is seeing good data.
			// The trigger number is routed to the header FIFO
			CS[HDR_TRIG_NUM2]: begin
					// Go send the buffer size
					NS[HDR_BUF_SIZE1] = 1'b1;
			end
			
			// We enter the HDR_BUF_SIZE1 state after we have written the trigger number to the header FIFO.
			// We stay here for one cycle
			// The buffer size is routed to the header FIFO
			CS[HDR_BUF_SIZE1]: begin
					// Go write to the FIFO.
					NS[HDR_BUF_SIZE2] = 1'b1;
			end

			// We enter the HDR_BUF_SIZE2 state when the buffer size has been presented to the header FIFO.
			// We stay here for one cycle, during which 'header_fifo_wr_en' is asserted to tell
			// the header FIFO that it is seeing good data.
			// The buffer size is routed to the header FIFO
			CS[HDR_BUF_SIZE2]: begin
					// Go send the buffer size
					NS[HDR_CHAN_NUM1] = 1'b1;
			end

			// We enter the HDR_CHAN_NUM1 state after we have written the buffer size to the header FIFO.
			// We stay here for one cycle
			// The channel number is routed to the header FIFO
			CS[HDR_CHAN_NUM1]: begin
					// Go write to the FIFO.
					NS[HDR_CHAN_NUM2] = 1'b1;
			end

			// We enter the HDR_CHAN_NUM2 state when the channel number has been presented to the header FIFO.
			// We stay here for one cycle, during which 'header_fifo_wr_en' is asserted to tell
			// the header FIFO that it is seeing good data.
			// The channel number is routed to the header FIFO
			CS[HDR_CHAN_NUM2]: begin
					// Go send the post trigger size
					NS[HDR_POST_TRIG1] = 1'b1;
			end

			// We enter the HDR_POST_TRIG1 state after we have written the channel number to the header FIFO.
			// We stay here for one cycle
			// The post trigger size is routed to the header FIFO
			CS[HDR_POST_TRIG1]: begin
					// Go write to the FIFO.
					NS[HDR_POST_TRIG2] = 1'b1;
			end

			// We enter the HDR_POST_TRIG2 state when the post trigger size has been presented to the header FIFO.
			// We stay here for one cycle, during which 'header_fifo_wr_en' is asserted to tell
			// the header FIFO that it is seeing good data.
			// The post trigger size is routed to the header FIFO
			CS[HDR_POST_TRIG2]: begin
					// Go send the start address
					NS[HDR_START_ADR1] = 1'b1;
			end

			// We enter the HDR_START_ADR1 state after we have written the post trigger size to the header FIFO.
			// We stay here for one cycle
			// The start address is routed to the header FIFO
			CS[HDR_START_ADR1]: begin
					// Go write to the FIFO.
					NS[HDR_START_ADR2] = 1'b1;
			end

			// We enter the HDR_START_ADR2 state when the start address has been presented to the header FIFO.
			// We stay here for one cycle, during which 'header_fifo_wr_en' is asserted to tell
			// the header FIFO that it is seeing good data.
			// The start address is routed to the header FIFO
			CS[HDR_START_ADR2]: begin
					// We are done
					NS[DONE] = 1'b1;
			end

			// We enter the DONE state whenever we have finished filling the header FIFO.
			// We stay here 'forever', until the state machine is reset by the negation of 'arm'.
			CS[DONE]: begin
				// Stay here.
				NS[DONE] = 1'b1;
			end

		endcase
	end // combinational always block to determine next state


	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// create a counter to hold the trigger number
	always @ (posedge clk) begin
		if (trig_num_we_sync2)
			current_trig_num[31:0] <= initial_trig_num[31:0];		// initialize
		else if (CS[HDR_BUF_SIZE1] == 1'b1)
			current_trig_num[31:0] <= current_trig_num[31:0] + 1;	// increment after writing to header fifo
		else
			current_trig_num[31:0] <= current_trig_num[31:0];		// hold
	end

	// create an address 'up' counter to use when writing ADC data to memory
	always @ (posedge clk) begin
		if (CS[INIT] == 1'b1)
			data_mem_addra[11:0] <= 12'b0;							// initialize
		else if (CS[WAIT_TRIG] == 1'b1 || CS[TRIGGERED] == 1'b1 || CS[WAIT_POST_TRIG] == 1'b1)
			data_mem_addra[11:0] <= data_mem_addra[11:0] + 1;		// increment
		else
			data_mem_addra[11:0] <= data_mem_addra[11:0];			// hold
	end

	// create a post-trigger counter
	reg [11:0] post_trig_cntr;
	always @ (posedge clk) begin
		if (CS[INIT] == 1'b1)
			post_trig_cntr[11:0] <= post_trig_size[11:0];			// initialize
		else if (post_trig_cntr[11:0]  == 12'b0)
			post_trig_cntr[11:0] <= 12'b0;							// stop at zero
		else if (CS[TRIGGERED] == 1'b1 || CS[WAIT_POST_TRIG] == 1'b1)
			post_trig_cntr[11:0] <= post_trig_cntr[11:0] - 1;		// decrement
		else
			post_trig_cntr[11:0] <= post_trig_cntr[11:0];			// hold
	end
	assign post_trig_done = (post_trig_cntr[11:0]  == 12'b0) ? 1'b1 : 1'b0;
	
	// calculate the start address by subtracting the buffer size from the final address
	reg [11:0] start_adr_reg;
	always @ (posedge clk) begin
		if (CS[HDR_TRIG_NUM1] == 1'b1)
			start_adr_reg[11:0] <= data_mem_addra[11:0] - buffer_size[11:0];
		else
			start_adr_reg[11:0] <= start_adr_reg[11:0];
	end
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// outputs are based on states
	// assert 'done' whenever we are in the DONE state
	assign done = (CS[DONE] == 1'b1) ? 1'b1 : 1'b0;

	// Make a MUX to route various pieces of header info to the FIFO
	always @ (posedge clk) begin
		if (CS[HDR_TRIG_NUM1] == 1'b1 || CS[HDR_TRIG_NUM2] == 1'b1)   header_data[31:0] <= current_trig_num[31:0]; 
		if (CS[HDR_BUF_SIZE1] == 1'b1 || CS[HDR_BUF_SIZE2] == 1'b1)   header_data[31:0] <= buffer_size[31:0]; 
		if (CS[HDR_CHAN_NUM1] == 1'b1 || CS[HDR_CHAN_NUM2] == 1'b1)   header_data[31:0] <= channel_num[31:0]; 
		if (CS[HDR_POST_TRIG1] == 1'b1 || CS[HDR_POST_TRIG2] == 1'b1) header_data[31:0] <= post_trig_size[31:0]; 
		if (CS[HDR_START_ADR1] == 1'b1 || CS[HDR_START_ADR2] == 1'b1) header_data[31:0] <= {20'b0, start_adr_reg[11:0]};
	end

	// write data to the header FIFO
	always @ (posedge clk) begin
		header_fifo_wr_en <= (CS[HDR_TRIG_NUM2] == 1'b1 || CS[HDR_BUF_SIZE2] == 1'b1 || CS[HDR_CHAN_NUM2] == 1'b1
						|| CS[HDR_POST_TRIG2] == 1'b1 || CS[HDR_START_ADR2] == 1'b1);
	end

	// write data to the memory
	always @ (posedge clk) begin
		data_mem_wea <= (CS[WAIT_TRIG] == 1'b1 || CS[TRIGGERED] == 1'b1 || CS[WAIT_POST_TRIG] == 1'b1);
	end

	endmodule

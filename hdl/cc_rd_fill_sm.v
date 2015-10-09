// cc_rd_fill_sm.v
//
// Read the ADC header and ADC data for the next fill.
// 	`define	CC_RD_FILL		5'd8	// Read the next fill
//
// Structure of a command packet for CC_RD_FILL:
// 1) Command Serial Number (CSN)
// 2) Command Code (CC)
// 
// Structure of a "no error" response packet:
// 1) Response Serial Number (RSN) matching the CSN
// 2) Response Code (RC) matching the CC
// 3) Header [31:0] 
// 4) Header [63:32] 
// 5) Header [95:64] 
// 6) Header [127:96] 
// 7..buffer_size+7-1) ADC data
// buffer_size+7) Checksum
//
// Structure of an "error" response packet:
// 1) Response Serial Number (RSN) matching the CSN
// 2) Response Code (RC) equals the bitwise inverse of the CC

module cc_rd_fill_sm(

	input clk,								// local clock
	input reset,							// active-hi

	input run_sm,  		 	    			// run this state machine
	output reg sm_running,					// we are running
	output reg sm_done,						// we are finished

	output reg tx_tvalid,            		// the data we are presenting is valid
    output reg tx_tlast,           			// this is the final word in the frame
    input tx_tready,             			// signal that the TX fifo has accepted the data

	output reg send_csn,					// send the CSN
	output reg send_cmd,					// send the CC
	output reg send_inv_cmd,				// send the inverse CC

	// interface to the header FIFO
	input fill_header_fifo_empty,			// a header is available when not asserted
	output reg fill_header_fifo_rd_en,		// remove the current data from the FIFO
	input [127:0] fill_header_fifo_out,		// data at the head of the FIFO
	input [22:0] fixed_ddr3_start_addr,
	input en_fixed_ddr3_start_addr,

	// interface to the DDR3 memory 
	output reg [22:0] ddr3_rd_start_addr,	// the address of the first requested 128-bit burst
	output reg [23:0] ddr3_rd_burst_cnt,	// number of bursts to read from the DDR3
	output reg enable_reading,     			// start the 'ddr3_rd_control'
	input reading_done,       				// reading is complete
	
	// interface to the AXIS 2:1 MUX
	output reg use_ddr3_data,				// the data source is the DDR3 memory
	input aurora_ddr3_accept				// DDR3 data has been accepted by the Aurora
);

// Synchronize  'reading_done'.
reg reading_done_sync1, reading_done_sync2;
always @(posedge clk) begin
	reading_done_sync1 <= reading_done;
	reading_done_sync2 <= reading_done_sync1;
end

// make a register to save the header
reg [127:0] saved_header;
	
// make a register to hold error status
reg error_found;

// make a counter to keep track of how many 32-bit DDR3 words still need to
// be accepted by the Aurora interface
reg [25:0] ddr3_words_to_send;
reg all_ddr3_words_sent;
always @(posedge clk) begin
	all_ddr3_words_sent <= (ddr3_words_to_send[25:0] == 25'b0);
end

// State machine for executing the 'rd_fill' command
//  Leave the comments containing "synopsys" in your HDL code.
 
// Declare the symbolic names for states for the state machine
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [3:0]
	IDLE				= 4'd0,
	CHK_FIFO_EMPTY		= 4'd1,
	ERROR1				= 4'd2,
	GET_FIFO_HDR		= 4'd3,
	ECHO_CSN1			= 4'd4,
	ECHO_CSN2			= 4'd5,
	ECHO_CC1			= 4'd6,
	ECHO_CC2			= 4'd7,
	GET_DDR3_DATA		= 4'd8,
	DONE				= 4'd9;
				
// Declare current state and next state variables
reg [9:0] /* synopsys enum STATE_TYPE */ CS;
reg [9:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
// Reset the sm whenever we are not enabled
always @ (posedge clk) begin
	if (!run_sm) begin
		CS <= 10'b0;			// set all state bits to 0
		CS[IDLE] <= 1'b1;		// set IDLE state bit to 1
	end
	else  CS <= NS;			// set state bits to next state
end

// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or fill_header_fifo_empty or reading_done_sync2 or tx_tready or error_found 
			or all_ddr3_words_sent) begin
	NS = 10'b0;					// default all bits to zero; will overrride one bit

	case (1'b1) //synopsys full_case parallel_case

		// We will be in the IDLE state whenever the command dispatcher does not enable us.
		// Once enabled, immediately start working. Assert 'sm_running'
		CS[IDLE]: begin
			// Prepare to get and check trigger number.
			NS[CHK_FIFO_EMPTY] = 1'b1;
		end

		// We enter the CHK_FIFO_EMPTY state after we have been started.
		// There should be a complete header in the fifo. If nothing is there, then we flag an error
		CS[CHK_FIFO_EMPTY]: begin
			// See if there is something in the header FIFO
			if (fill_header_fifo_empty)
				// We were asked for a fill, but nothing there, so go flag an error.
				// We need to somehow resync.
				NS[ERROR1] = 1'b1;
			else
				// Fetch and check the fill_fifo_header.
				NS[GET_FIFO_HDR] = 1'b1;
		end

		// We enter the ERROR1 state whenever we have detected any type of error.
		// We stay here for one cycle, during which the error flag is set.
		CS[ERROR1]: begin
			// Go start the response sequence.
			NS[ECHO_CSN1] = 1'b1;
		end

		// We enter the GET_FIFO_HDR state whenever we have started and the header FIFO
		// is not empty. The FIFO is in 'first-word fall-thru' mode, so the data is already present.
		// We stay here for one cycle, during which the header contents are latched.
		// 'fill_header_fifo_rd_en' is asserted to remove the current header word from the head of the FIFO
		CS[GET_FIFO_HDR]: begin
			// Go start the response sequence.
			NS[ECHO_CSN1] = 1'b1;
		end

		// We enter the ECHO_CSN1 state whenever we have either:
		//  1) determined that we have a valid header OR
		//  2) determined that an error has occurred
		// We stay here until the TX FIFO  is ready to accept data
		// The CSN is routed to the TX FIFO
		CS[ECHO_CSN1]: begin
			// Wait for the TX fifo to be ready, and for downstream system to be accepting data
			if (tx_tready)
				// Prepare to transmit the CSN
				NS[ECHO_CSN2] = 1'b1;
			else
				// Stay here
				NS[ECHO_CSN1] = 1'b1;
		end

		// We enter the ECHO_CSN2 state whenever the TX fifo is ready to accept the CSN.
		// We stay here for one cycle, during which we assert 'tx_tvalid'
		CS[ECHO_CSN2]: begin
			NS[ECHO_CC1] = 1'b1;
		end

		// We enter the ECHO_CC1 state whenever we have sent the CSN
		// We stay here until the TX FIFO is ready to accept data
		// The CC or its inverse is routed to the TX FIFO
		CS[ECHO_CC1]: begin
			// Wait for the TX fifo to be ready.
			if (tx_tready)
				// Prepare to transmit the CC or its inverse
				NS[ECHO_CC2] = 1'b1;
			else
				// Stay here
				NS[ECHO_CC1] = 1'b1;
		end

		// We enter the ECHO_CC2 state whenever the TX fifo is ready to accept the CC.
		// We stay here for one cycle, during which we assert 'tx_tvalid'.
		// If there were any errors, we assert 'tx_tlast' and go to DONE.
		CS[ECHO_CC2]: begin
			// Check error state
			if (error_found)
				// there was an error, so assert 'tx_tlast' and go to DONE
				NS[DONE] = 1'b1;
			else
				// there are no errors, so enable the flow of data
				NS[GET_DDR3_DATA] = 1'b1;
		end

		// We enter the GET_DDR3_DATA state when we are ready to get the data from the DDR3 memory.
		// We stay here until the DDR3 interface acknowledges the completion of the fill readout and
		// the Aurora has accepted all of the data.
		CS[GET_DDR3_DATA]: begin
			// See if we have read all of the data
			if (reading_done_sync2 && all_ddr3_words_sent)
				// Finished.
				NS[DONE] = 1'b1;
			else
				// Stay here until we are done.
				NS[GET_DDR3_DATA] = 1'b1;
		end

		// We enter the DONE state whenever we have finished this command.
		// We stay here for one cycle. Assert 'sm_done'.
		CS[DONE]: begin
			// go wait for another command.
			NS[IDLE] = 1'b1;
		end

	endcase
end // combinational always block to determine next state

///////////////////////////////////////////////////////////////////////////
// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
	// defaults
	sm_running				<= 1'b1;	// negate this when IDLE
	sm_done					<= 1'b0;
	fill_header_fifo_rd_en	<= 1'b0;
	enable_reading			<= 1'b0;
	tx_tvalid				<= 1'b0;
	tx_tlast				<= 1'b0;
	send_csn				<= 1'b0;
	send_cmd				<= 1'b0;
	send_inv_cmd			<= 1'b0;
	use_ddr3_data			<= 1'b0;
	
	// next states
	if (NS[IDLE]) begin
		sm_running <= 1'b0;	// negate this when IDLE
	end
	
	if (NS[CHK_FIFO_EMPTY]) begin
	end

	if (NS[ERROR1]) begin
	end

	if (NS[GET_FIFO_HDR]) begin
		// load the address pointer
		if (en_fixed_ddr3_start_addr) // if fixed start address is enabled
			ddr3_rd_start_addr[22:0] <= fixed_ddr3_start_addr[22:0];
		else
			ddr3_rd_start_addr[22:0] <= fill_header_fifo_out[57:35];

		// load the burst counter, add '2' for header and footer
		ddr3_rd_burst_cnt[23:0] <= fill_header_fifo_out[87:64] + 2;
		// load the words_to_send counter
		ddr3_words_to_send[25:0] <= {(fill_header_fifo_out[87:64] + 2), 2'b0};
		// remove the word from the FIFO head
 		fill_header_fifo_rd_en <= 1'b1;
	end

	if (NS[ECHO_CSN1]) begin
		send_csn <= 1'b1;
	end

	if (NS[ECHO_CSN2]) begin
		send_csn <= 1'b1;
		// enable transmission of the serial number
		tx_tvalid <= 1'b1;
	end

	if (NS[ECHO_CC1]) begin
	 	if (error_found)
	 		send_inv_cmd <= 1'b1;
	 	else
	 		send_cmd <= 1'b1;
	end

 	if (NS[ECHO_CC2]) begin
		// enable transmission of the command code
	 	tx_tvalid <= 1'b1;
	 	if (error_found) begin
	 		send_inv_cmd <= 1'b1;
		 	// if there has been an error, assert tx_last
 			tx_tlast <= 1'b1;
 		end
 		else
 			send_cmd <= 1'b1;
	end

	if (NS[GET_DDR3_DATA]) begin
		// ask DDR3 memory reader for all data 
        enable_reading <= 1'b1;
		// tell the AXIS 2:1 MUX to send DDR3 data
		use_ddr3_data			<= 1'b1;
		// decrement the words_to_send counter when data is accepted by the Aurora
		if (aurora_ddr3_accept) begin
			ddr3_words_to_send[25:0] <= ddr3_words_to_send[25:0] - 1;
		end
	end

	if (NS[DONE]) begin
		// tell the AXIS 2:1 MUX to send DDR3 data
	 	if (!error_found) begin
			use_ddr3_data			<= 1'b1;
		end
		// notify calling logic that we are done
		sm_done <= 1'b1;
	end
end

///////////////////////////////////////////////////////////////////////////////////////	
// clear the error flag when IDLE and set the error flag whenever we are sent to state ERROR1
always @ (posedge clk) begin
	if (CS[IDLE] == 1'b1)
		error_found <= 1'b0;
	else if (CS[ERROR1] == 1'b1)
		error_found <= 1'b1;
	else
		error_found <= error_found;
end

endmodule

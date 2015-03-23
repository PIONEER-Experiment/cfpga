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
	output reg [31:0] tx_data,				// 32-bit chunks of DDR3 bursts
	input readout_pause,					// stop sending fill data to the Aurora

	output reg send_csn,					// send the CSN
	output reg send_cmd,					// send the CC
	output reg send_inv_cmd,				// send the inverse CC
	output reg send_fill_data,				// send data from this module

	// interface to the header FIFO
	input fill_header_fifo_empty,			// input, a header is available when not asserted
	output reg fill_header_fifo_rd_en,		// output, remove the current data from the FIFO
	input [127:0] fill_header_fifo_out,		// input, data at the head of the FIFO

	// interface to the DDR3 memory 
	output reg [22:0] ddr3_rd_burst_addr,	// output, the address of the requested 128-bit burst
	output reg ddr3_rd_one_burst,			// output, get one 128-bit burst from the DDR3
	input ddr3_one_burst_rdy,				// input, the requested 128-bit burst is ready
	input [127:0] ddr3_one_burst_data		// input, the requested 128-bit burst
);

// Synchronize  'ddr3_one_burst_rdy'.
reg one_burst_rdy_sync1, one_burst_rdy_sync2;
always @(posedge clk) begin
	one_burst_rdy_sync1 <= ddr3_one_burst_rdy;
	one_burst_rdy_sync2 <= one_burst_rdy_sync1;
end

// Synchronize  'readout_pause'.
reg readout_pause_sync1, readout_pause_sync2;
always @(posedge clk) begin
	readout_pause_sync1 <= readout_pause;
	readout_pause_sync2 <= readout_pause_sync1;
end

// make a register to save the header
reg [127:0] saved_header;
	
// make a register to hold error status
reg error_found;

// create a counter to use when transmitting ADC memory data
reg [20:0] burst_count;
reg burst_count_zero;

// Make a comparitor status bit from the comparison of the header from the FIFO with the header from the DDR3
reg header_match;
		
// State machine for executing the 'rd_fill' command
//  Leave the comments containing "synopsys" in your HDL code.
 
// Declare the symbolic names for states for the state machine
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [4:0]
	IDLE			= 5'd0,
	CHK_FIFO_EMPTY	= 5'd1,
	ERROR1			= 5'd2,
	GET_FIFO_HDR	= 5'd3,
	GET_MEM_HEADER	= 5'd4,
	COMPARE_HDR		= 5'd5,
	ECHO_CSN1		= 5'd6,
	ECHO_CSN2		= 5'd7,
	ECHO_CC1		= 5'd8,
	ECHO_CC2		= 5'd9,
	GET_DAT_BURST	= 5'd10,
	XMIT_DAT_BURST1	= 5'd11,
	XMIT_DAT_BURST2	= 5'd12,
	XMIT_DAT_BURST3	= 5'd13,
	XMIT_DAT_BURST4	= 5'd14,
	XMIT_DAT_BURST5	= 5'd15,
	XMIT_DAT_BURST6	= 5'd16,
	XMIT_DAT_BURST7	= 5'd17,
	XMIT_DAT_BURST8	= 5'd18,
	DONE			= 5'd19;
				
// Declare current state and next state variables
reg [21:0] /* synopsys enum STATE_TYPE */ CS;
reg [21:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
// Reset the sm whenever we are not enabled
always @ (posedge clk) begin
	if (!run_sm) begin
		CS <= 22'b0;			// set all state bits to 0
		CS[IDLE] <= 1'b1;		// set IDLE state bit to 1
	end
	else  CS <= NS;			// set state bits to next state
end

// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or fill_header_fifo_empty or one_burst_rdy_sync2 or tx_tready or error_found 
			or burst_count_zero or header_match or readout_pause_sync2) begin
	NS = 22'b0;					// default all bits to zero; will overrride one bit

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
		// We stay here for one cycle, during which the header contents are latched for comparison
		// with the header that is in the memory buffer. The address and burst count counters are loaded
		// in preparation for memory readout.
		// 'fill_header_fifo_rd_en' is asserted to remove the current header word from the head of the FIFO
		CS[GET_FIFO_HDR]: begin
			// Go get the header word that is in memory.
			NS[GET_MEM_HEADER] = 1'b1;
		end

		// We enter the GET_MEM_HEADER state after we have latched the header from the FIFO.
		// We assert 'ddr3_rd_one_burst' to ask the DDR3 memory block for 1 burst. It should
		// be the memory-version of the header.
		// We stay here until the DDR3 interface acknowledges the delivery of a new burst.
		CS[GET_MEM_HEADER]: begin
			// See if we have the new burst
			if (one_burst_rdy_sync2)
				// We got the header from memory. Go compare it with the header from the FIFO.
				NS[COMPARE_HDR] = 1'b1;
			else
				// Stay here until we get the header from memory.
				NS[GET_MEM_HEADER] = 1'b1;
		end

		// We enter the COMPARE_HDR state after we have received the header from the memory.
		// Compare it to the header from the FIFO
		CS[COMPARE_HDR]: begin
			if (header_match)
				// The header from memory matches the header from the FIFO.
				// Start acknowledging the command.
				NS[ECHO_CSN1] = 1'b1;
			else
				// They don't match.
				// We need to flag an error and somehow resync
				NS[ERROR1] = 1'b1;
		end
			
		// We enter the ECHO_CSN1 state whenever we have either:
		//  1) determined that we have a valid header OR
		//  2) determined that an error has occurred
		// We stay here until the TX FIFO  is ready to accept data
		// The CSN is routed to the TX FIFO
		CS[ECHO_CSN1]: begin
			// Wait for the TX fifo to be ready, and for downstream system to be accepting data
			if (tx_tready && !readout_pause_sync2)
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
			if (tx_tready && !readout_pause_sync2)
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
				// there are no errors, so jump over GET_DATA_BURST and start to send the header
				NS[XMIT_DAT_BURST1] = 1'b1;
		end

		// We enter the GET_DAT_BURST state when we want to get a data burst from the DDR3 memory.
		// We assert 'ddr3_rd_one_burst' to ask the DDR3 memory block for 1 burst. It should
		// be ADC data or the final checksum.
		// We stay here until the DDR3 interface acknowledges the delivery of a new burst.
		CS[GET_DAT_BURST]: begin
			// See if we have the new burst
			if (one_burst_rdy_sync2)
				// We got the ADC data from memory. Send it to the Aurora.
				NS[XMIT_DAT_BURST1] = 1'b1;
			else
				// Stay here until we get the header from memory.
				NS[GET_DAT_BURST] = 1'b1;
		end

		// We enter the XMIT_DAT_BURST1 state when we have a burst of DDR3 data to send.
		// We send the first 32-bits of the 128-bit burst.
		CS[XMIT_DAT_BURST1]: begin
			// Wait for the TX fifo to be ready.
			if (tx_tready && !readout_pause_sync2)
				// Prepare to transmit the first 32-bit chunk
				NS[XMIT_DAT_BURST2] = 1'b1;
			else
				// stay here
				NS[XMIT_DAT_BURST1] = 1'b1;
		end

		// We enter the XMIT_DAT_BURST2 state whenever the TX fifo is ready to accept the first 32-bit chunk.
		// We stay here for one cycle, during which we assert 'tx_tvalid'
		// Decrement the burst counter. Increment the address counter.
		CS[XMIT_DAT_BURST2]: begin
			NS[XMIT_DAT_BURST3] = 1'b1;
		end

		// We enter the XMIT_DAT_BURST3 state when we have a burst of DDR3 data to send.
		// We send the second 32-bits of the 128-bit burst.
		CS[XMIT_DAT_BURST3]: begin
			// Wait for the TX fifo to be ready.
			if (tx_tready && !readout_pause_sync2)
				// Prepare to transmit the second 32-bit chunk
				NS[XMIT_DAT_BURST4] = 1'b1;
			else
				// stay here
				NS[XMIT_DAT_BURST3] = 1'b1;
		end

		// We enter the XMIT_DAT_BURST4 state whenever the TX fifo is ready to accept the second 32-bit chunk.
		// We stay here for one cycle, during which we assert 'tx_tvalid'
		CS[XMIT_DAT_BURST4]: begin
			NS[XMIT_DAT_BURST5] = 1'b1;
		end

		// We enter the XMIT_DAT_BURST5 state when we have a burst of DDR3 data to send.
		// We send the third 32-bits of the 128-bit burst.
		CS[XMIT_DAT_BURST5]: begin
			// Wait for the TX fifo to be ready.
			if (tx_tready && !readout_pause_sync2)
				// Prepare to transmit the third 32-bit chunk
				NS[XMIT_DAT_BURST6] = 1'b1;
			else
				// stay here
				NS[XMIT_DAT_BURST5] = 1'b1;
		end

		// We enter the XMIT_DAT_BURST6 state whenever the TX fifo is ready to accept the third 32-bit chunk.
		// We stay here for one cycle, during which we assert 'tx_tvalid'
		CS[XMIT_DAT_BURST6]: begin
			NS[XMIT_DAT_BURST7] = 1'b1;
		end

		// We enter the XMIT_DAT_BURST7 state when we have a burst of DDR3 data to send.
		// We send the fourth 32-bits of the 128-bit burst.
		CS[XMIT_DAT_BURST7]: begin
			// Wait for the TX fifo to be ready.
			if (tx_tready && !readout_pause_sync2)
				// Prepare to transmit the fourth 32-bit chunk
				NS[XMIT_DAT_BURST8] = 1'b1;
			else
				// stay here
				NS[XMIT_DAT_BURST7] = 1'b1;
		end

		// We enter the XMIT_DAT_BURST8 state whenever the TX fifo is ready to accept the fourth 32-bit chunk.
		// We stay here for one cycle, during which we assert 'tx_tvalid'
		// If the burst_count is zero, we are done. Otherwise, go read another burst from the DDR3.
		CS[XMIT_DAT_BURST8]: begin
			if (burst_count_zero)
				// The last burst has been sent.
				NS[DONE] = 1'b1;
			else 
				// More bursts to send.
				NS[GET_DAT_BURST] = 1'b1;
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
	ddr3_rd_one_burst		<= 1'b0;
	tx_tvalid				<= 1'b0;
	tx_tlast				<= 1'b0;
	send_csn				<= 1'b0;
	send_cmd				<= 1'b0;
	send_inv_cmd			<= 1'b0;
	send_fill_data			<= 1'b0;

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
		ddr3_rd_burst_addr[22:0] <= fill_header_fifo_out[57:35];
		// load the burst counter
		burst_count[20:0] <= fill_header_fifo_out[84:64];
		// latch the header
		saved_header[127:0] <= fill_header_fifo_out[127:0];
		// remove the word from the fifo head
 		fill_header_fifo_rd_en <= 1'b1;
	end

	if (NS[GET_MEM_HEADER]) begin
		// ask DDR3 memory reader for a burst, it will contain the memory copy of the header 
        ddr3_rd_one_burst <= 1'b1;
	end

	if (NS[COMPARE_HDR]) begin
	end

	if (NS[ECHO_CSN1]) begin
		send_csn				<= 1'b1;
	end

	if (NS[ECHO_CSN2]) begin
		send_csn				<= 1'b1;
		// enable transmission of the serial number
		tx_tvalid <= 1'b1;
		// increment the burst counter by two to account for the header and checksum
		burst_count[20:0] <= burst_count[20:0] + 2'b10;
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

	if (NS[GET_DAT_BURST]) begin
		// ask DDR3 memory reader for a burst, it will contain ADC data 
        ddr3_rd_one_burst <= 1'b1;
	end

	if (NS[XMIT_DAT_BURST1]) begin
		// signal 'command_top' to use data from this module
		send_fill_data	<= 1'b1;
		// ... and this is the data to send
		tx_data <= ddr3_one_burst_data[31:0];
	end

	if (NS[XMIT_DAT_BURST2]) begin
		// signal 'command_top' to use data from this module
		send_fill_data	<= 1'b1;
		tx_tvalid <= 1'b1;
		// ... and this is the data to send
		tx_data <= ddr3_one_burst_data[31:0];
		// decrement the burst counter
		burst_count[20:0] <= burst_count[20:0] - 1'b1;
		// increment the address pointer
		ddr3_rd_burst_addr[22:0] <= ddr3_rd_burst_addr[22:0] + 1'b1;
	end

	if (NS[XMIT_DAT_BURST3]) begin
		// signal 'command_top' to use data from this module
		send_fill_data	<= 1'b1;
		// ... and this is the data to send
		tx_data <= ddr3_one_burst_data[63:32];
	end

	if (NS[XMIT_DAT_BURST4]) begin
		// signal 'command_top' to use data from this module
		send_fill_data	<= 1'b1;
		tx_tvalid <= 1'b1;
		// ... and this is the data to send
		tx_data <= ddr3_one_burst_data[63:32];
	end

	if (NS[XMIT_DAT_BURST5]) begin
		// signal 'command_top' to use data from this module
		send_fill_data	<= 1'b1;
		// ... and this is the data to send
		tx_data <= ddr3_one_burst_data[95:64];
	end

	if (NS[XMIT_DAT_BURST6]) begin
		// signal 'command_top' to use data from this module
		send_fill_data	<= 1'b1;
		tx_tvalid <= 1'b1;
		// ... and this is the data to send
		tx_data <= ddr3_one_burst_data[95:64];
	end

	if (NS[XMIT_DAT_BURST7]) begin
		// signal 'command_top' to use data from this module
		send_fill_data	<= 1'b1;
		// ... and this is the data to send
		tx_data <= ddr3_one_burst_data[127:96];
	end

	if (NS[XMIT_DAT_BURST8]) begin
		// signal 'command_top' to use data from this module
		send_fill_data	<= 1'b1;
		tx_tvalid <= 1'b1;
		// ... and this is the data to send
		tx_data <= ddr3_one_burst_data[127:96];
	 	// is this the last word?
		if (burst_count_zero) tx_tlast <= 1'b1;
	end

	if (NS[DONE]) begin
		sm_done <= 1'b1;
	end
end

//////////////////////////////////////////////////////////////////////////////////////
// Set the comparitor status bit from the comparison of the header from the FIFO with the header from the DDR3
always @(posedge clk) begin
	if (ddr3_one_burst_data[127:0] == saved_header[127:0])
		header_match <= 1'b1;
	else
		header_match <= 1'b0;
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

////////////////////////////////////////////////////////////////////////////////////////
// set the flag that indicates when the burst count is down to zero
always @(posedge clk) begin
	if (burst_count[20:0] == 21'b0)
		burst_count_zero <= 1'b1;
	else
		burst_count_zero <= 1'b0;
end

endmodule

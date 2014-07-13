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
// 3) Trigger Number
// 4) Buffer Size
// 5) Channel Number
// 6) Post Trigger Count
// 7..buffer_size+7-1) ADC data
// buffer_size+7) Checksum
//
// Structure of an "error" response packet:
// 1) Response Serial Number (RSN) matching the CSN
// 2) Response Code (RC) equals the bitwise inverse of the CC

module cc_rd_fill_sm(

	input clk,					// local clock
	input reset,				// active-hi

	input run_sm,  		 	    // run this state machine
	output sm_running,			// we are running
	output sm_done,				// we are finished

	output tx_tvalid,            // the data we are presenting is valid
    output tx_tlast,             // this is the final word in the frame
    input tx_tready,             // signal that the TX fifo has accepted the data

	output send_csn,			// send the CSN
	output send_cmd,			// send the CC
	output send_inv_cmd,		// send the inverse CC
	output send_adc_header_data,	// mux source is the ADC header
	output send_adc_mem_data,	// mux source is the ADC memory

	// interface to the ADC data memory and header FIFO
	output reg [11:0] ADC_data_mem_addrb,		// output wire [11 : 0] addrb
	input [31:0] ADC_data_mem_doutb,		// input wire [31 : 0] doutb
	output ADC_header_fifo_rd_en,	// output wire rd_en
	input [31:0] ADC_header_fifo_dout,	// input wire [31 : 0] dout
	input ADC_header_fifo_empty,	// input wire empty
	output reg [31:0] adc_header_data
	);

	// make a register to hold error status
	reg error_found;

	// create a counter to use when transmitting ADC memory data
	reg [11:0] word_count;
	
	// Everything is already synchronous to the clock.

	// State machine for executing the 'rd_fill' command
	//  Leave the comments containing "synopsys" in your HDL code.
 
	// Declare the symbolic names for states for the state machine
	// Simplified one-hot encoding (each constant is an index into an array of bits)
	parameter [4:0]
		IDLE			= 5'd0,
		CHK_FIFO_EMPTY1	= 5'd1,
		ERROR1			= 5'd2,
		GET_TRIG_NUM	= 5'd3,
		CHK_TRIG_NUM	= 5'd4,
		CHK_FIFO_EMPTY2	= 5'd5,
		GET_BUF_SIZE	= 5'd6,
		CHK_BUF_SIZE	= 5'd7,
		ECHO_CSN1		= 5'd8,
		ECHO_CSN2		= 5'd9,
		ECHO_CC1		= 5'd10,
		ECHO_CC2		= 5'd11,
		XMIT_TRIG_NUM1	= 5'd12,
		XMIT_TRIG_NUM2	= 5'd13,
		XMIT_BUF_SIZE1	= 5'd14,
		XMIT_BUF_SIZE2	= 5'd15,
		XMIT_CHAN_NUM1	= 5'd16,
		XMIT_CHAN_NUM2	= 5'd17,
		XMIT_POST_TRIG1	= 5'd18,
		XMIT_POST_TRIG2	= 5'd19,
		GET_START_ADDR	= 5'd20,
		XMIT_DATA		= 5'd21,
		PAUSE1			= 5'd22,
		PAUSE2			= 5'd23,
		PAUSE3			= 5'd24,
		XMIT_CHECKSUM1	= 5'd25,
		XMIT_CHECKSUM2	= 5'd26,
		DONE			= 5'd27;
				
	// Declare current state and next state variables
	reg [27:0] /* synopsys enum STATE_TYPE */ CS;
	reg [27:0] /* synopsys enum STATE_TYPE */ NS;
	//synopsys state_vector CS

 
	// sequential always block for state transitions (use non-blocking [<=] assignments)
	// Reset the sm whenever we are not enabled
	always @ (posedge clk) begin
		if (!run_sm) begin
			CS <= 28'b0;				// set all state bits to 0
			CS[IDLE] <= 1'b1;		// set IDLE state bit to 1
		end
		else  CS <= NS;			// set state bits to next state
	end

	// combinational always block to determine next state  (use blocking [=] assignments) 
	always @ (CS or tx_tready or error_found or ADC_header_fifo_empty or word_count) begin
		NS = 28'b0;					// default all bits to zero; will overrride one bit

		case (1'b1) //synopsys full_case parallel_case

			// We will be in the IDLE state whenever the command dispatcher does not enable us.
			// Once enabled, immediately start working
			//
			CS[IDLE]: begin
					// Prepare to get and check trigger number.
					NS[CHK_FIFO_EMPTY1] = 1'b1;
			end

			// We enter the CHK_FIFO_EMPTY1 state after we have been started.
			// There should be a complete header in the fifo. If nothing is there, then we flag an error
			CS[CHK_FIFO_EMPTY1]: begin
				// See if there is something in the header FIFO
				if (ADC_header_fifo_empty)
					// Nothing there, so go flag an error. We need to somehow resync.
					NS[ERROR1] = 1'b1;
				else
					// Fetch and check the trigger number.
					NS[GET_TRIG_NUM] = 1'b1;
			end

			// We enter the ERROR1 state whenever we have detected any type of error.
			// We stay here for one cycle, during which the error flag is set.
			CS[ERROR1]: begin
				// Go start the response sequence.
				NS[ECHO_CSN1] = 1'b1;
			end

			// We enter the GET_TRIG_NUM state whenever we have started and the header FIFO
			// is not empty.
			// We stay here for one cycle, during which the trigger number is latched.
			// 'ADC_header_fifo_rd_en' is asserted to bring the next word to the head of the FIFO
			CS[GET_TRIG_NUM]: begin
				// Go check the validity of the trigger number.
				NS[CHK_TRIG_NUM] = 1'b1;
			end

			// We enter the CHK_TRIG_NUM state after we have latched the trigger number
			// TO DO: Add something to test the trigger number for validity
			CS[CHK_TRIG_NUM]: begin
				//if (illegal_trig_num)
					// The top 4 bits do not match the 'valid_trig_num' pattern.
					// We need to flag an error and somehow resync
				//	NS[ERROR1] = 1'b1;
				//else
					// The trigger number appears to be OK. Try to get and check the buffer size.
					NS[CHK_FIFO_EMPTY2] = 1'b1;
			end

			// We enter the CHK_FIFO_EMPTY2 state after we have seen a valid trigger number. Now
			// we see if there is a valid buffer size. There should be a complete header in the fifo.
			// If nothing is there, then we flag an error
			CS[CHK_FIFO_EMPTY2]: begin
				// See if there is something in the header FIFO
				if (ADC_header_fifo_empty)
					// Nothing there, so go flag an error. We need to somehow resync.
					NS[ERROR1] = 1'b1;
				else
					// Fetch and check the buffer size.
					NS[GET_BUF_SIZE] = 1'b1;
			end

			// We enter the GET_BUF_SIZE state whenever we have seen a valid trigger number and
			// the header FIFO is not empty.
			// We stay here for one cycle, during which the bufffer size is latched.
			// 'ADC_header_fifo_rd_en' is asserted to bring the next word to the head of the FIFO
			CS[GET_BUF_SIZE]: begin
				// Go check the validity of the buffer size.
				NS[CHK_BUF_SIZE] = 1'b1;
			end

			// We enter the CHK_BUF_SIZE state after we have latched the buffer size
			// TO DO: Add something to test the buffer size for validity
			CS[CHK_BUF_SIZE]: begin
				//if (illegal_buf_size)
					// The top 4 bits do not match the 'valid_buf_size' pattern, and the data from
					// the FIFO does not equal the contents of the 'buffer size' register.
					// We need to flag an error and somehow resync
				//	NS[ERROR1] = 1'b1;
				//else
					// The buffer size appears to be OK. We assume that the rest of the header is valid.
					// Start acknowledging the command.
					NS[ECHO_CSN1] = 1'b1;
			end
			
			// We enter the ECHO_CSN1 state whenever we have either:
			//  1) determined that a valid header is in the FIFO OR
			//  2) determined that an error has occurred
			// We stay here until the TX FIFO  is ready to accept data
			// The CSN is routed to the TX FIFO
			CS[ECHO_CSN1]: begin
				// Wait for the TX fifo to be ready.
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
				// 
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
					// there are no errors, so start to send the header
					NS[XMIT_TRIG_NUM1] = 1'b1;
				end

			// We enter the XMIT_TRIG_NUM1 state after we have transmitted the CC.
			// We stay here until the TX FIFO is ready to accept data.
			// The ADC header data is routed to the TX FIFO
			CS[XMIT_TRIG_NUM1]: begin
				if (tx_tready)
					// The TX FIFO is ready, send the trigger number
					NS[XMIT_TRIG_NUM2] = 1'b1;
				else
					// Stay here.
					NS[XMIT_TRIG_NUM1] = 1'b1;
			end

			// We enter the XMIT_TRIG_NUM2 state whenever we can send the trigger number.
			// We stay here for one cycle, during which 'tx_tvalid' is asserted to tell
			// the TX FIFO that it is seeing good data.
			// The ADC header data is routed to the TX FIFO
			CS[XMIT_TRIG_NUM2]: begin
					// Go send the buffer size
					NS[XMIT_BUF_SIZE1] = 1'b1;
			end
			
			// We enter the XMIT_BUF_SIZE1 state after we have transmitted the trigger number.
			// We stay here until the TX FIFO is ready to accept data.
			// The ADC header data is routed to the TX FIFO
			CS[XMIT_BUF_SIZE1]: begin
				if (tx_tready)
					// The TX FIFO is ready, send the buffer size
					NS[XMIT_BUF_SIZE2] = 1'b1;
				else
					// Stay here.
					NS[XMIT_BUF_SIZE1] = 1'b1;
			end

			// We enter the XMIT_BUF_SIZE2 state whenever we can send the buffer size.
			// We stay here for one cycle, during which 'tx_tvalid' is asserted to tell
			// the TX FIFO that it is seeing good data.
			// The ADC header data is routed to the TX FIFO
			CS[XMIT_BUF_SIZE2]: begin
					// Go send the channel number
					NS[XMIT_CHAN_NUM1] = 1'b1;
			end
			// We enter the XMIT_CHAN_NUM1 state after we have transmitted the buffer size.
			// We stay here until the TX FIFO is ready to accept data.
			// The ADC header data is routed to the TX FIFO
			CS[XMIT_CHAN_NUM1]: begin
				if (tx_tready)
					// The TX FIFO is ready, send the channel number
					NS[XMIT_CHAN_NUM2] = 1'b1;
				else
					// Stay here.
					NS[XMIT_CHAN_NUM1] = 1'b1;
			end

			// We enter the XMIT_CHAN_NUM2 state whenever we can send the channel number.
			// We stay here for one cycle, during which 'tx_tvalid' is asserted to tell
			// the TX FIFO that it is seeing good data.
			// The ADC header data is routed to the TX FIFO
			// 'ADC_header_fifo_rd_en' is asserted to bring the next word to the head of the FIFO
			CS[XMIT_CHAN_NUM2]: begin
					// Go send the post trigger count
					NS[XMIT_POST_TRIG1] = 1'b1;
			end

			// We enter the XMIT_POST_TRIG1 state after we have transmitted the channel number.
			// We stay here until the TX FIFO is ready to accept data.
			// The ADC header data is routed to the TX FIFO
			CS[XMIT_POST_TRIG1]: begin
				if (tx_tready)
					// The TX FIFO is ready, send the post trigger count
					NS[XMIT_POST_TRIG2] = 1'b1;
				else
					// Stay here.
					NS[XMIT_POST_TRIG1] = 1'b1;
			end

			// We enter the XMIT_POST_TRIG2 state whenever we can send the post trigger count.
			// We stay here for one cycle, during which 'tx_tvalid' is asserted to tell
			// the TX FIFO that it is seeing good data.
			// The ADC header data is routed to the TX FIFO
			// 'ADC_header_fifo_rd_en' is asserted to bring the next word to the head of the FIFO
			CS[XMIT_POST_TRIG2]: begin
					// Go fetch the start address
					NS[GET_START_ADDR] = 1'b1;
			end
			
			// We enter the GET_START_ADDR state whenever we have completed sending the header.
			// We stay here for one cycle, during which the buffer memory start address is latched.
			// 'ADC_header_fifo_rd_en' is asserted to (possibly) bring the next word to the head of the FIFO
			CS[GET_START_ADDR]: begin
				// Start moving the data to the TX FIFO.
				NS[XMIT_DATA] = 1'b1;
			end

			// We enter the XMIT_DATA state when we are ready to start sending data.
			// Let us assume that the TX FIFO is *ALLWAYS* ready to accept data. (COULD BE FATAL)
			// The ADC memory data is routed to the TX FIFO
			// There is a 2-clock latency on the ADC memory data, so 'tx_tvalid' will need a delay.
			// In this state, increment the address counter and decrement to word counter.
			// In this state, accumulate the checksum
			// Stay here until the word counter is zero
			CS[XMIT_DATA]: begin
				if (word_count[11:0] == 12'b0)
					// All data has been sent, go pause for 2 cycles before sending the checksum
					// to allow the data pipeline to finish
					NS[PAUSE1] = 1'b1;
				else
					// Stay here.
					NS[XMIT_DATA] = 1'b1;
			end

			// We enter the PAUSE1 state whenever we have completed retrieving the ADC data from memory .
			// We stay here for one cycle to accommodate the memory pipeline
			CS[PAUSE1]: begin
				// Pause for another cycle
				NS[PAUSE2] = 1'b1;
			end

			// We enter the PAUSE2 state whenever we have completed retrieving the ADC data from memory .
			// We stay here for one cycle to accommodate the memory pipeline
			CS[PAUSE2]: begin
				// Go send the checksum
				NS[PAUSE3] = 1'b1;
			end

			// We enter the PAUSE3 state whenever we have completed retrieving the ADC data from memory .
			// We stay here for one cycle to accommodate the memory pipeline
			CS[PAUSE3]: begin
				// Go send the checksum
				NS[XMIT_CHECKSUM1] = 1'b1;
			end

		
			// We enter the XMIT_CHECKSUM1 state after we have transmitted all of the ADC data.
			// We stay here until the TX FIFO is ready to accept data.
			// The ADC header data is routed to the TX FIFO
			CS[XMIT_CHECKSUM1]: begin
				if (tx_tready)
					// The TX FIFO is ready, send the checksum
					NS[XMIT_CHECKSUM2] = 1'b1;
				else
					// Stay here.
					NS[XMIT_CHECKSUM1] = 1'b1;
			end

			// We enter the XMIT_CHECKSUM2 state whenever we can send the checksum.
			// We stay here for one cycle, during which 'tx_tvalid' is asserted to tell
			// the TX FIFO that it is seeing good data.
			// 'tx_tlast' is also asserted.
			// The ADC header data is routed to the TX FIFO
			CS[XMIT_CHECKSUM2]: begin
					// We are done
					NS[DONE] = 1'b1;
			end

			// We enter the DONE state whenever we have finished this command.
			// We stay here for one cycle
			CS[DONE]: begin
				// go wait for another command.
				NS[IDLE] = 1'b1;
			end

		endcase
	end // combinational always block to determine next state

	
	// set the error flag whenever we are sent to state ERROR1
	always @ (posedge clk) begin
		if (CS[IDLE] == 1'b1)
			error_found <= 1'b0;
		else if (CS[ERROR1] == 1'b1)
			error_found <= 1'b1;
		else
			error_found <= error_found;
	end

	// make a delayed version of 'XMIT_DATA' to use when sending ADC data from the memory.
	// There is a 3-clock latency on the memory data.
	// The delayed signal will be used for both 'tx_tvalid' and for the checksum
	reg xmit_data_dly1, xmit_data_dly2, xmit_data_dly3;
	always @ (posedge clk) begin
		xmit_data_dly1 <= CS[XMIT_DATA];
		xmit_data_dly2 <= xmit_data_dly1;
		xmit_data_dly3 <= xmit_data_dly2;
	end

	// Create registers to hold some header data
	reg [31:0] trig_num_reg;
	always @ (posedge clk) begin
		if (CS[GET_TRIG_NUM] == 1'b1) trig_num_reg[31:0] <= ADC_header_fifo_dout[31:0];
	end
	reg [31:0] buf_size_reg;
	always @ (posedge clk) begin
		if (CS[GET_BUF_SIZE] == 1'b1) buf_size_reg[31:0] <= ADC_header_fifo_dout[31:0];
	end

	// create a register to hold the checksum
	reg [31:0] checksum_reg;
	always @ (posedge clk) begin
		if (CS[IDLE] == 1'b1)
			checksum_reg[31:0] <= 32'b0;
		else if
			(xmit_data_dly2) checksum_reg[31:0] <=  checksum_reg[31:0] ^ ADC_data_mem_doutb[31:0];
		else
			checksum_reg[31:0] <= checksum_reg[31:0];
	end

	// create an address 'up' counter to use when transmitting ADC memory data
	always @ (posedge clk) begin
		if (CS[GET_START_ADDR] == 1'b1)
			ADC_data_mem_addrb[11:0] <= ADC_header_fifo_dout[11:0];
		else if
			(CS[XMIT_DATA] == 1'b1) ADC_data_mem_addrb[11:0] <= ADC_data_mem_addrb[11:0] + 1;
		else
			ADC_data_mem_addrb[11:0] <= ADC_data_mem_addrb[11:0];
	end

	// create a counter to use when transmitting ADC memory data
	always @ (posedge clk) begin
		if (CS[XMIT_BUF_SIZE2] == 1'b1)
			word_count[11:0] <= buf_size_reg[11:0];
		else if
			(word_count[11:0]  == 12'b0) word_count[11:0] <= 12'b0;
		else if
			// there is a 1 clock delay in decrementing the word count, so we need to pre-decrement
			// it by 1 before we get into the XMIT_DATA state
			(CS[GET_START_ADDR] == 1'b1 || CS[XMIT_DATA] == 1'b1) word_count[11:0] <= word_count[11:0] - 1;
		else
			word_count[11:0] <= word_count[11:0];
	end
	
	// outputs are based on states
	// assert 'sm_running' whenever we are not in the IDLE state
	assign sm_running = !(CS[IDLE] == 1'b1);

	// assert 'sm_done' whenever we are in the DONE state
	assign sm_done = (CS[DONE] == 1'b1);

	// send the CSN
	assign send_csn = (CS[ECHO_CSN1] == 1'b1 || CS[ECHO_CSN2] == 1'b1 );

	// send either the CC or the inverse CC, depending on the error situation
	assign send_cmd     = !error_found && ((CS[ECHO_CC1] == 1'b1 || CS[ECHO_CC2] == 1'b1 ));			// send the CC
	assign send_inv_cmd =  error_found && ((CS[ECHO_CC1] == 1'b1 || CS[ECHO_CC2] == 1'b1 ));			// send the CC


	// send the ADC memory contents
	assign send_adc_mem_data  = (CS[XMIT_DATA] == 1'b1 || CS[PAUSE1] == 1'b1 || CS[PAUSE2] == 1'b1);

	// pull the next header word to the output of the FIFO
	// with first-word fall-through, we can assert 'rd_en' at the same time that we are using the data
	assign ADC_header_fifo_rd_en = (CS[GET_TRIG_NUM] == 1'b1 || CS[GET_BUF_SIZE] == 1'b1
								|| CS[XMIT_CHAN_NUM2] == 1'b1 || CS[XMIT_POST_TRIG2] == 1'b1
								|| CS[GET_START_ADDR] == 1'b1);

	// Make a MUX to route various pieces of header info to the transmitter
	always @ (posedge clk) begin
		if (CS[XMIT_TRIG_NUM1] == 1'b1 || CS[XMIT_TRIG_NUM2] == 1'b1) adc_header_data[31:0] <= trig_num_reg[31:0]; 
		if (CS[XMIT_BUF_SIZE1] == 1'b1 || CS[XMIT_BUF_SIZE2] == 1'b1) adc_header_data[31:0] <= buf_size_reg[31:0]; 
		if (CS[XMIT_CHAN_NUM1] == 1'b1 || CS[XMIT_CHAN_NUM2] == 1'b1) adc_header_data[31:0] <= ADC_header_fifo_dout[31:0]; 
		if (CS[XMIT_POST_TRIG1] == 1'b1 || CS[XMIT_POST_TRIG2] == 1'b1) adc_header_data[31:0] <= ADC_header_fifo_dout[31:0]; 
		if (CS[XMIT_CHECKSUM1] == 1'b1 || CS[XMIT_CHECKSUM2] == 1'b1) adc_header_data[31:0] <= checksum_reg[31:0]; 
	end
	// send the various words of the header
	assign send_adc_header_data  = (CS[XMIT_TRIG_NUM1] == 1'b1 || CS[XMIT_TRIG_NUM2] == 1'b1
								|| CS[XMIT_BUF_SIZE1] == 1'b1 || CS[XMIT_BUF_SIZE2] == 1'b1
								|| CS[XMIT_CHAN_NUM1] == 1'b1 || CS[XMIT_CHAN_NUM2] == 1'b1
								|| CS[XMIT_POST_TRIG1] == 1'b1 || CS[XMIT_POST_TRIG2] == 1'b1
								|| CS[XMIT_CHECKSUM1] == 1'b1 || CS[XMIT_CHECKSUM2] == 1'b1 );

	// send data to the TX FIFO
	reg xmit_hdr_dly1;
	always @ (posedge clk) begin
		// make a delayed version of tx_valid for the header data
		xmit_hdr_dly1 <= (CS[XMIT_TRIG_NUM2] == 1'b1 || CS[XMIT_BUF_SIZE2] == 1'b1 || CS[XMIT_CHAN_NUM2] == 1'b1
						|| CS[XMIT_POST_TRIG2] == 1'b1 || CS[XMIT_CHECKSUM2] == 1'b1);
	end
	assign tx_tvalid  = (CS[ECHO_CSN2] == 1'b1 || CS[ECHO_CC2] == 1'b1 || xmit_hdr_dly1 || xmit_data_dly3);

	// this is the last word to send
	reg xmit_tlast_dly1;
	always @ (posedge clk) begin
		// make a delayed version of tx_tlast for the checksum
		// We need this to match up with the delayed version of tx_tvalid
		xmit_tlast_dly1 <= (CS[XMIT_CHECKSUM2] == 1'b1);
	end
	assign tx_tlast = (!error_found && xmit_tlast_dly1)	// send with checksum
					|| (error_found && (CS[ECHO_CC2] == 1'b1));   	// send with inverse CC

	
endmodule
		// 0000001 IDLE			= 5'd0,
		// 0000002 CHK_FIFO_EMPTY1	= 5'd1,
		// 0000004 ERROR1			= 5'd2,
		// 0000008 GET_TRIG_NUM	= 5'd3,
		// 0000010 CHK_TRIG_NUM	= 5'd4,
		// 0000020 CHK_FIFO_EMPTY2	= 5'd5,
		// 0000040 GET_BUF_SIZE	= 5'd6,
		// 0000080 CHK_BUF_SIZE	= 5'd7,
		// 0000100 ECHO_CSN1		= 5'd8,
		// 0000200 ECHO_CSN2		= 5'd9,
		// 0000400 ECHO_CC1		= 5'd10,
		// 0000800 ECHO_CC2		= 5'd11,
		// 0001000 XMIT_TRIG_NUM1	= 5'd12,
		// 0002000 XMIT_TRIG_NUM2	= 5'd13,
		// 0004000 XMIT_BUF_SIZE1	= 5'd14,
		// 0008000 XMIT_BUF_SIZE2	= 5'd15,
		// 0010000 XMIT_CHAN_NUM1	= 5'd16,
		// 0020000 XMIT_CHAN_NUM2	= 5'd17,
		// 0040000 XMIT_POST_TRIG1	= 5'd18,
		// 0080000 XMIT_POST_TRIG2	= 5'd19,
		// 0100000 GET_START_ADDR	= 5'd20,
		// 0200000 XMIT_DATA		= 5'd21,
		// 0400000 PAUSE1			= 5'd22,
		// 0800000 PAUSE2			= 5'd23,
		// 1000000 PAUSE3			= 5'd24,
		// 2000000 XMIT_CHECKSUM1	= 5'd25,
		// 4000000 XMIT_CHECKSUM2	= 5'd26,
		// 8000000 DONE			= 5'd27;

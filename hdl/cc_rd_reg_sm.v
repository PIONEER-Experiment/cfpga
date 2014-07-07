// cc_rd_reg_sm.v
//
// Read one register from a channel.
// The register number must be from 0x00 thru 0x0f [0:15]
// The returned data is 32 bits
// 	`define	CC_RD_REG		5'd2	// Read a configuration register
//
// Structure of a command packet for CC_RD_REG:
// 1) Command Serial Number (CSN)
// 2) Command Code (CC)
// 3) Register Number
// 
// Structure of a "no error" response packet:
// 1) Response Serial Number (RSN) matching the CSN
// 2) Response Code (RC) matching the CC
// 3) Contents of specified register
//
// Structure of an "error" response packet:
// 1) Response Serial Number (RSN) matching the CSN
// 2) Response Code (RC) equals the bitwise inverse of the CC

module cc_rd_reg_sm(

	input clk,					// local clock
	input reset,				// active-hi

	input run_sm,  		 	    // run this state machine
	output sm_running,			// we are running
	output sm_done,				// we are finished

	input rx_tvalid,            // valid data is available
    input [31:0] rx_data,       // received data
    input [0:3] rx_tkeep,       // which bytes are valid, should always be all of them
    input rx_tlast,             // final word in the frame
    output rx_tready,           // signal that we are accepting the data from the fifo

	output tx_tvalid,            // the data we are presenting is valid
    output tx_tlast,             // this is the final word in the frame
    input tx_tready,             // signal that the TX fifo has accepted the data

	output send_csn,			// send the CSN
	output send_cmd,			// send the CC
	output send_inv_cmd,		// send the inverse CC
	output send_reg_data,		// mux source is register bank

	//local controls
	output reg_num_le,			// enable saving the register number
	output rd_en,				// enable reading of the specific register
	input illegal_reg_num		// The desired register does not exist
	);

	// make a register to hold error status
	reg error_found;

	// Everything is already synchronous to the clock.

	// State machine for executing the 'loopback' command
	//  Leave the comments containing "synopsys" in your HDL code.
 
	// Declare the symbolic names for states for the state machine
	// Simplified one-hot encoding (each constant is an index into an array of bits)
	parameter [3:0]
		IDLE			= 4'd0,
		WAIT_REG_NUM	= 4'd1,
		ERROR_TLAST		= 4'd2,
		LATCH_REG_NUM	= 4'd3,
		PAUSE1			= 4'd4,
		CHECK_REG_NUM	= 4'd5,
		ERROR_REG_NUM	= 4'd6,
		ECHO_CSN1		= 4'd7,
		ECHO_CSN2		= 4'd8,
		ECHO_CC1		= 4'd9,
		ECHO_CC2		= 4'd10,
		XMIT_REG1		= 4'd11,
		XMIT_REG2		= 4'd12,
		DONE			= 4'd13;
				
	// Declare current state and next state variables
	reg [13:0] /* synopsys enum STATE_TYPE */ CS;
	reg [13:0] /* synopsys enum STATE_TYPE */ NS;
	//synopsys state_vector CS

 
	// sequential always block for state transitions (use non-blocking [<=] assignments)
	// Reset the sm whenever we are not enabled
	always @ (posedge clk) begin
		if (!run_sm) begin
			CS <= 14'b0;				// set all state bits to 0
			CS[IDLE] <= 1'b1;		// set IDLE state bit to 1
		end
		else  CS <= NS;			// set state bits to next state
	end

	// combinational always block to determine next state  (use blocking [=] assignments) 
	always @ (CS or rx_tvalid or rx_tlast or tx_tready or illegal_reg_num or error_found) begin
		NS = 14'b0;					// default all bits to zero; will overrride one bit

		case (1'b1) //synopsys full_case parallel_case

			// We will be in the IDLE state whenever the command dispatcher does not enable us.
			// Once enabled, immediately start working
			//
			CS[IDLE]: begin
					// Get register number.
					NS[WAIT_REG_NUM] = 1'b1;
			end

			// We enter the WAIT_REG_NUM state after we have been started.
			// We stay here until data is valid.
			// rx_tlast should be asserted along with the register number
			CS[WAIT_REG_NUM]: begin
				if (rx_tvalid && !rx_tlast)
					// This is unexpected.
					// We need to flag an error and somehow resync
					NS[ERROR_TLAST] = 1'b1;
				else if (rx_tvalid && rx_tlast)
					// data is available, presumably the register number
					NS[LATCH_REG_NUM] = 1'b1;
				else
					// Stay here.
					NS[WAIT_REG_NUM] = 1'b1;
			end

			// We enter the ERROR_TLAST state whenever 'rx_tlast' was not asserted when
			// we have collected a new register number.
			// We stay here for one cycle, during which the error flag is set.
			// 'rx_tready' is asserted to tell the RX FIFO that we have used the data,
			CS[ERROR_TLAST]: begin
				// Go start the response sequence.
				NS[ECHO_CSN1] = 1'b1;
			end

			// We enter the LATCH_REG_NUM state whenever we have collected a new register number.
			// We stay here for one cycle, during which the register number is latched.
			// 'rx_tready' is asserted to tell the RX FIFO that we have used the data,
			CS[LATCH_REG_NUM]: begin
				// Go pause 1 cycle while the validity of the register number is determined.
				NS[PAUSE1] = 1'b1;
			end

			// We enter the PAUSE1 state after we have latched the register number.
			// We stay here for one cycle, during which the validity of the register number is determined
			CS[PAUSE1]: begin
				// 
				NS[CHECK_REG_NUM] = 1'b1;
			end

			// We enter the CHECK_REG_NUM state after we have determined the validity of the register number
			CS[CHECK_REG_NUM]: begin
				if (illegal_reg_num)
					// This is unexpected.
					// We need to flag an error and somehow resync
					NS[ERROR_REG_NUM] = 1'b1;
				else
					// Everything is OK.
					NS[ECHO_CSN1] = 1'b1;
			end

			// We enter the ERROR_REG_NUM state whenever we have determined that the register
			// number is illegal.
			// We stay here for one cycle, during which the error flag is set.
			CS[ERROR_REG_NUM]: begin
				// Go start the response sequence.
				NS[ECHO_CSN1] = 1'b1;
			end
			
			// We enter the ECHO_CSN1 state whenever we have either:
			//  1) determined that a valid register has been requested OR
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
			// The CC is routed to the TX FIFO
			CS[ECHO_CC1]: begin
				// Wait for the TX fifo to be ready.
				if (tx_tready)
					// Prepare to transmit the CC
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
					// there are no errors, so send the data
					NS[XMIT_REG1] = 1'b1;
				end

			// We enter the XMIT_REG1 state after we have transmitted the CC.
			// We stay here until the TX FIFO is ready to accept data.
			// The register data is routed to the TX FIFO
			CS[XMIT_REG1]: begin
				if (tx_tready)
					// The TX FIFO is ready, send the register data
					NS[XMIT_REG2] = 1'b1;
				else
					// Stay here.
					NS[XMIT_REG1] = 1'b1;
			end

			// We enter the XMIT_REG2 state whenever we can send the register data.
			// We stay here for one cycle, during which 'tx_tvalid' is asserted to tell
			// the TX FIFO that it is seeing good data.
			// The register data is routed to the TX FIFO
			CS[XMIT_REG2]: begin
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

	
	// set the error status
	always @ (posedge clk) begin
		if (CS[IDLE] == 1'b1)
			error_found <= 1'b0;
		else if (CS[ERROR_TLAST] == 1'b1 || CS[ERROR_REG_NUM] == 1'b1)
			error_found <= 1'b1;
		else
			error_found <= error_found;
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

	// mux source is register bank
	assign send_reg_data  = (CS[XMIT_REG1] == 1'b1 || CS[XMIT_REG2] == 1'b1);

	// remove data from the RX FIFO
	assign rx_tready = (CS[LATCH_REG_NUM] == 1'b1 || CS[ERROR_TLAST] == 1'b1);
	
	// send data to the TX FIFO
	assign tx_tvalid  = (CS[ECHO_CSN2] == 1'b1 || CS[ECHO_CC2] == 1'b1 || CS[XMIT_REG2] == 1'b1);

	// this is the last word to send
	assign tx_tlast = !error_found && (CS[XMIT_REG2] == 1'b1)	// send with register contents
					|| error_found && (CS[ECHO_CC2] == 1'b1);   // send with inverse CC

	// enable saving the register number
	assign reg_num_le = (CS[LATCH_REG_NUM] == 1'b1);
	
	// enable reading of the specific register
	assign rd_en = 	(CS[ECHO_CC2] == 1'b1 || CS[XMIT_REG1] == 1'b1 || CS[XMIT_REG2] == 1'b1);	
	
endmodule

// Structure of a 'command packet':
// 1) Command Serial Number (CSN)
// 2) Command Code (CC)
// 3) Command Data Count (CDC)
// 4) Command Data #1 (if needed) (CD1)
// 5..end) Additional Command Data (CD2...)
 
// Structure of a 'response packet':
// 1) Response Serial Number (RSN)
// 2) Response Code (RC)
// 3) Response Data Count (RDC)
// 4) Response Data #1 (if needed) (RD1)
// 5..end) Additional Response Parameters (RD2...)
 

module command_sm(

	input clk,					// local clock
	input reset,				// active-hi
	input rx_tvalid,            // valid data is available
    input [0:3] rx_tkeep,       // which bytes are valid, should always be all of them
    input rx_tlast,             // final word in the frame
    output rx_tready,           // signal that we are accepting the data from the fifo
	output ser_num_le,          // latch the serial number
	output command_le,          // latch the command
	output run_cmd_sm,       	// run a state machine
	input cmd_sm_running,		// someone running
	input cmd_sm_done			// someone finished
);

    // Everything is already synchronous to the clock.

	// State machine for determining what command to execute
	//  Leave the comments containing "synopsys" in your HDL code.
 
	// Declare the symbolic names for states for the state machine
	// Simplified one-hot encoding (each constant is an index into an array of bits)
	parameter [3:0]
		IDLE			= 4'd0,
		RESYNC          = 4'd1,
		LATCH_CSN		= 4'd2,
		WAIT_CC			= 4'd3,
		LATCH_CC		= 4'd4,
		START_CC		= 4'd5,
		PAUSE			= 4'd6,
		TEST_RUNNING	= 4'd7,
		WAIT_FOR_DONE	= 4'd8,
		DONE			= 4'd9,
		ILLEGAL_CC		= 4'd10;
		
	// Declare current state and next state variables
	reg [10:0] /* synopsys enum STATE_TYPE */ CS;
	reg [10:0] /* synopsys enum STATE_TYPE */ NS;
	//synopsys state_vector CS

 
	// sequential always block for state transitions (use non-blocking [<=] assignments)
	// Reset the sm whenever we get to the end of a frame
	always @ (posedge clk) begin
		if (reset) begin
			CS <= 11'b0;				// set all state bits to 0
			CS[IDLE] <= 1'b1;		// set IDLE state bit to 1
		end
		else  CS <= NS;			// set state bits to next state
	end

	// combinational always block to determine next state  (use blocking [=] assignments) 
	always @ (CS or rx_tvalid or rx_tlast or cmd_sm_running or cmd_sm_done) begin
		NS = 11'b0;					// default all bits to zero; will overrride one bit

		case (1'b1) //synopsys full_case parallel_case

			// We will be in the IDLE state whenever we have finished with a command,
			// or when we have been reset by way of seeing the last word of a frame ('rx_tlast' asserted).
			//
			CS[IDLE]: begin
				if (rx_tvalid && rx_tlast)
					// a final word is on the fifo. We need to read it and throw it away in order to resync
					NS[RESYNC] = 1'b1;
				else if (rx_tvalid && !rx_tlast)
					// data is available, presumably the start of a new command
					NS[LATCH_CSN] = 1'b1;
				else
					// Stay here.
					NS[IDLE] = 1'b1;
			end

			// We enter the RESYNC state whenever we have started and the final word of a frame is present.
			// We stay here for one cycle, during which the word is discarded
			CS[RESYNC]: begin
				// Read one word from the fifo and go back to IDLE.
				NS[IDLE] = 1'b1;
			end

			// We enter the LATCH_CSN state whenever we have started a new frame.
			// We stay here for one cycle, during which the serial number is latched
			CS[LATCH_CSN]: begin
				// Read one word from the fifo and go wait for the command.
				NS[WAIT_CC] = 1'b1;
			end

			// We enter the WAIT_CC state after we have latched the CSN.
			// We stay here until data is valid.
			CS[WAIT_CC]: begin
				if (rx_tvalid)
					// data is available, presumably the command word
					NS[LATCH_CC] = 1'b1;
				else
					// Stay here.
					NS[WAIT_CC] = 1'b1;
			end

			// We enter the LATCH_CC state whenever we have collected a new command.
			// We stay here for one cycle, during which the command word is latched
			CS[LATCH_CC]: begin
				// Read one word from the fifo and go try to execute the command.
				NS[START_CC] = 1'b1;
			end

			// We enter the START_CC state whenever we have decoded this command.
			// We stay here for one cycle, during which the state machine is started
			CS[START_CC]: begin
				// go wait for the command to complete.
				NS[PAUSE] = 1'b1;
			end

			// We enter the PAUSE state whenever we have tried to start other state
			// machines. We stay here for one cycle while the other state machines
			// get started.
			CS[PAUSE]: begin
				// go wait for the command to complete.
				NS[TEST_RUNNING] = 1'b1;
			end

			// We enter the TEST_RUNNING state after we have started one of the command
			// processing state machines. We stay here for one cycle, during which we
			// look for a sign that someone is processing the command. If not, we handle it
			// as an illegal command. 
			CS[TEST_RUNNING]: begin
				if (cmd_sm_running)
					// We see that someone is processing this command. Go wait for done.
					NS[WAIT_FOR_DONE] = 1'b1;
				else
					// No one started processing this command. Assume the command is illegal.
					NS[ILLEGAL_CC] = 1'b1;
			end

			// We enter the WAIT_FOR_DONE state after we see that one of the command
			// processing state machines has started. We stay here for until we see that it is done.
			// There should be a timer here.
			CS[WAIT_FOR_DONE]: begin
				if (cmd_sm_done)
					// We see that someone is signalling completion.
					NS[DONE] = 1'b1;
				else
					// Wait for anuone to be done.
					NS[WAIT_FOR_DONE] = 1'b1;
			end

			// We enter the DONE state whenever we have decoded this command.
			// We stay here for one cycle
			CS[DONE]: begin
				// go wait for another command.
				NS[IDLE] = 1'b1;
			end

			// We enter the ILLEGAL_CC state whenever no one has started processing this command.
			// For now, we stay here for one cycle
			CS[ILLEGAL_CC]: begin
				// go wait for another command.
				NS[DONE] = 1'b1;
			end



		endcase
	end // combinational always block to determine next state

	// outputs are based on states
	assign rx_tready  = (CS[RESYNC] == 1'b1) || (CS[LATCH_CSN] == 1'b1)  || (CS[LATCH_CC] == 1'b1);
	assign ser_num_le = (CS[LATCH_CSN] == 1'b1);
	assign command_le = (CS[LATCH_CC] == 1'b1);
	// run another state machine to process an individual command
	assign run_cmd_sm = (CS[START_CC] == 1'b1 || CS[PAUSE] == 1'b1 || CS[TEST_RUNNING] == 1'b1 || CS[WAIT_FOR_DONE] == 1'b1);

endmodule

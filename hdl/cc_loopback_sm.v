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
 
module cc_loopback_sm (
	input clk,					// local clock
	input reset,				// active-high

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
	output send_rx_data			// mux source is RX FIFO
);

	reg was_last_reg;            // remembers when 'rx_last' is received
	
    // Everything is already synchronous to the clock.

	// State machine for executing the 'loopback' command
	// Leave the comments containing "synopsys" in your HDL code.
 
	// Declare the symbolic names for states for the state machine
	// Simplified one-hot encoding (each constant is an index into an array of bits)
	parameter [2:0]
		IDLE       = 3'd0,
		ECHO_CSN1  = 3'd1,
		ECHO_CSN2  = 3'd2,
		ECHO_CC1   = 3'd3,
		ECHO_CC2   = 3'd4,
		ECHO_DATA1 = 3'd5,
		ECHO_DATA2 = 3'd6,
		DONE       = 3'd7;

	// Declare current state and next state variables
	reg [7:0] /* synopsys enum STATE_TYPE */ CS;
	reg [7:0] /* synopsys enum STATE_TYPE */ NS;
	//synopsys state_vector CS

 
	// sequential always block for state transitions (use non-blocking [<=] assignments)
	// Reset the sm whenever we are not enabled
	always @ (posedge clk) begin
		if (!run_sm) begin
			CS <= 8'd0;	  // set all state bits to 0
			CS[IDLE] <= 1'b1; // set IDLE state bit to 1
		end
		else CS <= NS;		  // set state bits to next state
	end

	// combinational always block to determine next state  (use blocking [=] assignments) 
	always @ (CS or rx_tvalid or rx_tlast or tx_tready or was_last_reg) begin
		NS = 8'd0; // default all bits to zero; will overrride one bit

		case (1'b1) //synopsys full_case parallel_case

			// We will be in the IDLE state whenever the command dispatcher does not enable us.
			// Once enabled, immediately start working
			CS[IDLE]: begin
					// Start echoing CSN.
					NS[ECHO_CSN1] = 1'b1;
			end

			// We enter the ECHO_CSN1 state whenever we have started.
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
				NS[ECHO_CC1] = 1'b1;
			end

			// We enter the ECHO_CC1 state whenever we have send the CSN
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
			// We stay here for one cycle, during which we assert 'tx_tvalid'
			CS[ECHO_CC2]: begin
				NS[ECHO_DATA1] = 1'b1;
			end

			// We enter the ECHO_DATA1 state after we have transmitted the CC.
			// We stay here until we have received valid data and the TX FIFO is
			// ready to accept data.
			// The RX data is routed to the TX FIFO
			CS[ECHO_DATA1]: begin
				if (rx_tvalid && tx_tready)
					// data is available, echo it back
					NS[ECHO_DATA2] = 1'b1;
				else
					// Stay here.
					NS[ECHO_DATA1] = 1'b1;
			end

			// We enter the ECHO_DATA2 state whenever we have data ready to loopback.
			// We stay here for one cycle, during which 'rx_tready' is asserted to
			// tell the RX FIFO that we have used the data, 'tx_tvalid' is asserted to tell
			// the TX FIFO that it is seeing good data.
			// The RX data is routed to the TX FIFO
			CS[ECHO_DATA2]: begin
				// See if LAST is asserted.
				if (rx_tlast)
					// We are done
					NS[DONE] = 1'b1;
				else
					// Go back and wait for more data
					NS[ECHO_DATA1] = 1'b1;
			end

			// We enter the DONE state whenever we have finished this command.
			// We stay here for one cycle
			CS[DONE]: begin
				// go wait for another command.
				NS[IDLE] = 1'b1;
			end

		endcase
	end // combinational always block to determine next state

	
	// outputs are based on states
	// assert 'sm_running' whenever we are not in the IDLE state
	assign sm_running = !(CS[IDLE] == 1'b1);

	// assert 'sm_done' whenever we are in the DONE state
	assign sm_done = (CS[DONE] == 1'b1);

	assign send_csn     = (CS[ECHO_CSN1]  == 1'b1 || CS[ECHO_CSN2]  == 1'b1); // send the CSN
	assign send_cmd     = (CS[ECHO_CC1]   == 1'b1 || CS[ECHO_CC2]   == 1'b1); // send the CC
	assign send_rx_data = (CS[ECHO_DATA1] == 1'b1 || CS[ECHO_DATA2] == 1'b1); // mux source is RX FIFO
	assign rx_tready    = (CS[ECHO_DATA2] == 1'b1); 
	assign tx_tvalid    = (CS[ECHO_CSN2]  == 1'b1 || CS[ECHO_CC2]   == 1'b1 || CS[ECHO_DATA2] == 1'b1);
	assign tx_tlast     = (CS[ECHO_DATA2] == 1'b1) && rx_tlast;
	
endmodule

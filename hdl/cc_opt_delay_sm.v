// cc_opt_delay_sm.v
// 
// Optimize the ADC data tap delay value for a channel.
// The returned data is 65 bits
//  `define CC_OPT_DELAY    5'd10   // Read a configuration register
// 
// Structure of a command packet for CC_OPT_DELAY:
// 1) Command Serial Number (CSN)
// 2) Command Code (CC)
// 
// Structure of a "no error" response packet:
// 1) Response Serial Number (RSN) matching the CSN
// 2) Response Code (RC) matching the CC
// 3) Contents of optimized data tap delay value
// 
// Structure of an "error" response packet:
// 1) Response Serial Number (RSN) matching the CSN
// 2) Response Code (RC) equals the bitwise inverse of the CC

module cc_opt_delay_sm (
    input  clk,             // local clock
    input  reset,           // active-high

    input  run_sm,          // run this state machine
    output sm_running,      // we are running
    output sm_done,         // we are finished

    output tx_tvalid,       // the data we are presenting is valid
    output tx_tlast,        // this is the final word in the frame
    input  tx_tready,       // signal that the TX FIFO has accepted the data

    output send_csn,        // send the CSN
    output send_cmd,        // send the CC
    output send_inv_cmd,    // send the inverse CC
    output send_data,       // mux source is delay register bank

    // local controls
    input  opt_done,        // optimization is complete
    output start_opt        // start tap delay optimization state machine
);

    // Make a register to hold error status
    reg error_found;

    // Everything is already synchronous to the clock.

    // State machine for executing the 'opt_delay' command.
    // Leave the comments containing "synopsys" in your HDL code.
 
    // Declare the symbolic names for states for the state machine
    // Simplified one-hot encoding (each constant is an index into an array of bits)
    parameter [3:0]
        IDLE        = 4'd0,
        START_OPT   = 4'd1,
        ERROR       = 4'd2,
        ECHO_CSN1   = 4'd3,
        ECHO_CSN2   = 4'd4,
        ECHO_CC1    = 4'd5,
        ECHO_CC2    = 4'd6,
        XMIT_DELAY1 = 4'd7,
        XMIT_DELAY2 = 4'd8,
        DONE        = 4'd9;

    // Declare current state and next state variables
    reg [9:0] /* synopsys enum STATE_TYPE */ CS;
    reg [9:0] /* synopsys enum STATE_TYPE */ NS;
    //synopsys state_vector CS

 
    // sequential always block for state transitions (use non-blocking [<=] assignments)
    // Reset the SM whenever we are not enabled.
    always @ (posedge clk) begin
        if (!run_sm) begin
            CS <= 10'b0;      // set all state bits to 0
            CS[IDLE] <= 1'b1; // set IDLE state bit to 1
        end
        else CS <= NS;        // set state bits to next state
    end

    // combinational always block to determine next state (use blocking [=] assignments) 
    always @ (CS or opt_done or tx_tready or error_found) begin
        NS = 10'b0; // default all bits to zero; will overrride one bit

        case (1'b1) //synopsys full_case parallel_case

            // We will be in the IDLE state whenever the command dispatcher does not enable us.
            // Once enabled, immediately start working.
            CS[IDLE] : begin
                // Start the ADC data tap delay optimatization procedure
                NS[START_OPT] = 1'b1;
            end

            // We enter the START_OPT state after we have been started.
            // We stay here until the optimization procedure is complete.
            CS[START_OPT] : begin
                if (error_found)
                    NS[ERROR] = 1'b1;
                else if (opt_done)
                    NS[ECHO_CSN1] = 1'b1;
                else
                    NS[START_OPT] = 1'b1;
            end

            // We enter the ERROR state whenever the optimization sm reports an error.
            // We stay here for one cycle, during which the error flag is set.
            CS[ERROR] : begin
                // Go start the response sequence
                NS[ECHO_CSN1] = 1'b1;
            end
            
            // We enter the ECHO_CSN1 state whenever we have either:
            //  1) determined that a valid register has been requested OR
            //  2) determined that an error has occurred
            // We stay here until the TX FIFO  is ready to accept data.
            // The CSN is routed to the TX FIFO.
            CS[ECHO_CSN1] : begin
                // Wait for the TX FIFO to be ready
                if (tx_tready)
                    // Prepare to transmit the CSN
                    NS[ECHO_CSN2] = 1'b1;
                else
                    // Stay here
                    NS[ECHO_CSN1] = 1'b1;
            end

            // We enter the ECHO_CSN2 state whenever the TX FIFO is ready to accept the CSN.
            // We stay here for one cycle, during which we assert 'tx_tvalid'.
            CS[ECHO_CSN2] : begin
                NS[ECHO_CC1] = 1'b1;
            end

            // We enter the ECHO_CC1 state whenever we have sent the CSN.
            // We stay here until the TX FIFO is ready to accept data.
            // The CC is routed to the TX FIFO.
            CS[ECHO_CC1] : begin
                // Wait for the TX FIFO to be ready
                if (tx_tready)
                    // Prepare to transmit the CC
                    NS[ECHO_CC2] = 1'b1;
                else
                    // Stay here
                    NS[ECHO_CC1] = 1'b1;
            end

            // We enter the ECHO_CC2 state whenever the TX FIFO is ready to accept the CC.
            // We stay here for one cycle, during which we assert 'tx_tvalid'.
            // If there were any errors, we assert 'tx_tlast' and go to DONE.
            CS[ECHO_CC2] : begin
                // Check error state
                if (error_found)
                    // There was an error, so assert 'tx_tlast' and go to DONE
                    NS[DONE] = 1'b1;
                else
                    // There are no errors, so send the data
                    NS[XMIT_DELAY1] = 1'b1;
            end

            // We enter the XMIT_DELAY1 state after we have transmitted the CC.
            // We stay here until the TX FIFO is ready to accept data.
            // The register data is routed to the TX FIFO.
            CS[XMIT_DELAY1] : begin
                if (tx_tready)
                    // The TX FIFO is ready, send the data
                    NS[XMIT_DELAY2] = 1'b1;
                else
                    // Stay here
                    NS[XMIT_DELAY1] = 1'b1;
            end

            // We enter the XMIT_DELAY2 state whenever we can send the register data.
            // We stay here for one cycle, during which 'tx_tvalid' is asserted to tell the TX FIFO that it is seeing good data.
            // The register data is routed to the TX FIFO.
            CS[XMIT_DELAY2] : begin
                // We're done
                NS[DONE] = 1'b1;
            end

            // We enter the DONE state whenever we have finished this command.
            // We stay here for one cycle.
            CS[DONE] : begin
                // Go wait for another command
                NS[IDLE] = 1'b1;
            end

        endcase
    end // combinational always block to determine next state


    // set the error status
    always @ (posedge clk) begin
        if (CS[IDLE] == 1'b1)
            error_found <= 1'b0;
        else if (CS[ERROR] == 1'b1)
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
    assign send_csn = (CS[ECHO_CSN1] == 1'b1 || CS[ECHO_CSN2] == 1'b1);

    // send either the CC or the inverse CC, depending on the error situation
    assign send_cmd     = !error_found && ((CS[ECHO_CC1] == 1'b1) || (CS[ECHO_CC2] == 1'b1)); // send the CC
    assign send_inv_cmd =  error_found && ((CS[ECHO_CC1] == 1'b1) || (CS[ECHO_CC2] == 1'b1)); // send the CC

    // mux source is delay register bank
    assign send_data = (CS[XMIT_DELAY1] == 1'b1 || CS[XMIT_DELAY2] == 1'b1);

    // send data to the TX FIFO
    assign tx_tvalid = (CS[ECHO_CSN2] == 1'b1 || CS[ECHO_CC2] == 1'b1 || CS[XMIT_DELAY2] == 1'b1);

    // this is the last word to send
    assign tx_tlast = !error_found && (CS[XMIT_DELAY2] == 1'b1) || // send with register contents
                       error_found && (CS[ECHO_CC2]    == 1'b1);   // send with inverse CC

    // enable optimization sm
    assign start_opt = !(CS[IDLE] == 1'b1);

endmodule

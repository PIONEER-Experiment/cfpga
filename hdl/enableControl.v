// watch the enable IO line from the master FPGA
// 32 ns pulse: toggle the enable self-triggering line
// 64 ns pulse: toggle the enable data acquisition line

module enableControl (
    input  clk125,             // local clock, 125 MHz expected
    input  reset,              // active-high
    input  master_signal,      // signal from master
    output enable_acquisition, // DDR3 i/o enabled
    output enable_triggering   // self-triggering activated
);


    // Declare the symbolic names for states for the state machine.
    // Simplified one-hot encoding (each constant is an index into an array of bits)
    parameter [1:0]
        IDLE          = 4'd0,
        COUNT         = 4'd1,
        TOGGLE        = 4'd2;

    // declare registers to hold the enables
    reg enable_acq_reg;
    reg enable_trig_reg;
    assign enable_acquisition = enable_acq_reg;
    assign enable_triggering  = enable_trig_reg;

    // a counter to determine length of signal from master
    reg [15:0] counter;
    reg zero_counter;  // will be asserted by the state machine
    reg increment_counter;     // will be asserted by the state machine
    always @ ( posedge clk125) begin
      if ( reset || zero_counter )
        counter[15:0] <= 16'd0;
      else if ( increment_counter )
        counter[15:0] = counter[15:0] + 1;
    end

    // Declare current state and next state variables
    reg [2:0] /* synopsys enum STATE_TYPE */ CS;
    reg [2:0] /* synopsys enum STATE_TYPE */ NS;
    //synopsys state_vector CS
    
    // sequential always block for state transitions (use non-blocking [<=] assignments)
    // Reset the sm whenever we get to the end of a frame
    always @ (posedge clk125) begin
        if (reset) begin
          CS <= 11'b0;        // set all state bits to 0
          CS[IDLE] <= 1'b1;   // set IDLE state bit to 1
        end
        else
          CS <= NS;          // set state bits to next state
    end

    // combinational always block to determine next state (use blocking [=] assignments)
    always @ ( CS or master_signal ) begin
        NS = 3'b0; // default all bits to zero; will overrride one bit

        case (1'b1) //synopsys full_case parallel_case

            // We will be in the IDLE state whenever we have finished with a command,
            // or when we have been reset by way of seeing the last word of a frame ('rx_tlast' asserted).
            CS[IDLE]: begin
                if (master_signal)
                  // The master FPGA is requesting an action, determine signal length to decode
                  NS[COUNT] = 1'b1;
                else
                  // Stay here
                  NS[IDLE] = 1'b1;
            end

            // Stay here while master is high
            // We stay here for one cycle, during which the word is discarded.
            CS[COUNT]: begin
                if ( master_signal )
                  // remain here counting clock pulses
                  NS[COUNT] = 1'b1;
                else
                  // go toggle the requested signal
                  NS[TOGGLE] = 1'b1;
            end

            // We stay here for one cycle, during which the requested parameter is toggled.
            CS[TOGGLE]: begin
                // Toggle and return to idle
                NS[IDLE] = 1'b1;
            end

        endcase
    end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk125) begin
  if ( reset ) begin
    // disable triggering and data acquisition
    enable_acq_reg  = 1'b0;
    enable_trig_reg = 1'b0;
  end
  else begin
    
  // defaults
    increment_counter <= 1'b0;
    zero_counter      <= 1'b0;
  
    // next states
    if (NS[IDLE]) begin
      zero_counter      <= 1'b1;
    end
  
    if (NS[IDLE]) begin
      zero_counter      <= 1'b1;
    end
  
    if (NS[COUNT]) begin
      increment_counter      <= 1'b1;
    end
  
    if (NS[TOGGLE]) begin
      if ( counter[15:0] > 6 )
        enable_acq_reg  <= ~enable_acq_reg;
      else
        enable_trig_reg <= ~enable_trig_reg;
    end
  end

end // of always block


endmodule


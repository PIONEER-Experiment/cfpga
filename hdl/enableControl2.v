// watch the enable IO line from the master FPGA
// 32 ns pulse: toggle the enable self-triggering line
// 64 ns pulse: toggle the enable data acquisition line

module enableControl2 (
    input  clk125,             // local clock, 125 MHz expected
    input  reset,              // active-high
    input  master_signal,      // signal from master
    output enable_acquisition, // DDR3 i/o enabled
    output enable_triggering   // self-triggering activated
);


    // Declare the symbolic names for states for the state machine.
    // Simplified one-hot encoding (each constant is an index into an array of bits)
    parameter [3:0]
        IDLE             = 4'd0,
        INIT_WAIT        = 4'd1,
        ENABLE_TRIG_WAIT = 4'd2,
        ACQUIRING        = 4'd3,
        DISABLE_TRIG     = 4'd4,
        ACQ_WAIT         = 4'd5;

    // declare registers to hold the enables
    reg enable_acq_reg;
    reg enable_trig_reg;
    assign enable_acquisition = enable_acq_reg;
    assign enable_triggering  = enable_trig_reg;

    // wait a microsecond before asserting triggering
    reg [15:0] counter;
    reg init_counter;  // will be asserted by the state machine
    always @ ( posedge clk125) begin
      if ( reset )
        counter[15:0] <= 16'd0;
      else if ( init_counter )
        // initialize the counter
        counter[15:0] <= 16'd125;           //   1 us in 8 ns clock ticks (125 MHz)
      else if ( counter_zero )
        // if the counter is zero, keep it there
        counter[15:0] = 16'd0;
      else
        // decrement
        counter[15:0] = counter[15:0] - 1;
    end
    assign counter_zero = (counter[15:0] == 16'd0) ? 1'b1 : 1'b0;

    // Declare current state and next state variables
    reg [5:0] /* synopsys enum STATE_TYPE */ CS;
    reg [5:0] /* synopsys enum STATE_TYPE */ NS;
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

            // Idle when master is not requesting acquisition
            CS[IDLE]: begin
                if (master_signal)
                  // The master FPGA has requested enabling acquisition
                  NS[INIT_WAIT] = 1'b1;
                else
                  // Stay here
                  NS[IDLE] = 1'b1;
            end

            // Stay here 1 cycle to initiate counter.  Also enable acquisition
            CS[INIT_WAIT]: begin
              NS[ENABLE_TRIG_WAIT] = 1'b1;
            end

            CS[ENABLE_TRIG_WAIT]: begin
              if ( counter_zero )
                NS[ACQUIRING] = 1'b1;
              else
                NS[ENABLE_TRIG_WAIT] = 1'b1;
            end

            // Stay here while master is high
            CS[ACQUIRING]: begin
                if ( master_signal )
                  // remain here counting clock pulses
                  NS[ACQUIRING] = 1'b1;
                else
                  // go toggle the requested signal
                  NS[DISABLE_TRIG] = 1'b1;
            end

            // We stay here for one cycle, turning off triggering and enabling counter for
            // delay in turning off acquisition
            CS[DISABLE_TRIG]: begin
                // Toggle and return to idle
                NS[ACQ_WAIT] = 1'b1;
            end

            CS[ACQ_WAIT]: begin
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
    enable_acq_reg  <= 1'b0;
    enable_trig_reg <= 1'b0;
  end
  else begin
    
  // defaults
    init_counter    <= 1'b0;
    enable_acq_reg  <= 1'b0;
    enable_trig_reg <= 1'b0;
  
    // next states
    if (NS[IDLE]) begin
    end
  
    if (NS[INIT_WAIT]) begin
      init_counter  <= 1'b1;
      enable_acq_reg  <= 1'b1;
    end
  
    if (NS[ENABLE_TRIG_WAIT]) begin
      enable_acq_reg  <= 1'b1;
    end
  
    if (NS[ACQUIRING]) begin
      enable_acq_reg  <= 1'b1;
      enable_trig_reg <= 1'b1;
    end
  
    if (NS[DISABLE_TRIG]) begin
      init_counter  <= 1'b1;
      enable_acq_reg  <= 1'b1;
    end
  
    if (NS[ACQ_WAIT]) begin
      enable_acq_reg  <= 1'b1;
    end
  
  end

end // of always block


endmodule


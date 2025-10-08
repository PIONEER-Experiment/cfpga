// watch the enable IO line from the master FPGA
// 32 ns pulse: toggle the enable self-triggering line
// 64 ns pulse: toggle the enable data acquisition line

module enableControl2 (
    input  logic clk125,             // local clock, 125 MHz expected
    input  logic reset,              // active-high
    input  logic master_signal,      // signal from master
    output logic enable_acquisition, // DDR3 i/o enabled
    output logic enable_triggering   // self-triggering activated
);


// =========================================================================
// One-hot FSM using enum
// =========================================================================
    typedef enum logic [7:0] {
        IDLE             = 8'b00000001, // 01
        INIT_WAIT        = 8'b00000010, // 02
        ENABLE_TRIG_WAIT = 8'b00000100, // 04
        ACQUIRING        = 8'b00001000, // 08
        DISABLE_TRIG     = 8'b00010000, // 10
        ACQ_WAIT         = 8'b00100000, // 20
        DISABLE_ACQ      = 8'b01000000, // 40
        ERROR            = 8'b10000000  // 80
    } state_t;

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

    // Synthesis hint: keep it one-hot and auto-recover to error state
    (* fsm_encoding = "one-hot", fsm_safe_state = "default_state" *)
    //(* fsm_encoding = "one-hot" *)

    // Declare current state and next state variables
(* mark_debug = "true" *)    state_t CS;
(* mark_debug = "true" *)    state_t NS;
    
    // sequential always block for state transitions (use non-blocking [<=] assignments)
    // Reset the sm whenever we get to the end of a frame
    always_ff @(posedge clk125) begin
        if (reset) CS <= IDLE;
        else       CS <= NS;          // set state bits to next state
    end

    // combinational always block to determine next state (use blocking [=] assignments)
    always_comb begin
        NS = ERROR; // default "safe" value (also covers illegal encodings via default below)

        unique case (CS) 

            // Idle when master is not requesting acquisition
            IDLE: begin
                if (master_signal)
                  // The master FPGA has requested enabling acquisition
                  NS = INIT_WAIT;
                else
                  // Stay here
                  NS = IDLE;
            end

            // Stay here 1 cycle to initiate counter.  Also enable acquisition
            INIT_WAIT: begin
              NS = ENABLE_TRIG_WAIT;
            end

            ENABLE_TRIG_WAIT: begin
              if ( counter_zero )
                NS = ACQUIRING;
              else
                NS = ENABLE_TRIG_WAIT;
            end

            // Stay here while master is high
            ACQUIRING: begin
                if ( master_signal )
                  // remain here counting clock pulses
                  NS = ACQUIRING;
                else
                  // go toggle the requested signal
                  NS = DISABLE_TRIG;
            end

            // We stay here for one cycle, turning off triggering 
            DISABLE_TRIG: begin
                // Toggle and return to idle
                NS = ACQ_WAIT;
            end

            // We stay here until we see another signal from the master indicating that it's
            // to disable acquision
            ACQ_WAIT: begin
                if ( !master_signal )
                  // Wait here
                  NS = ACQ_WAIT;
                else
                  NS = DISABLE_ACQ;
            end

            // We turn off acquisition and stay here until the master goes low 
            DISABLE_ACQ : begin
                if ( master_signal )
                  // Wait here until this master signal goes low
                  NS = DISABLE_ACQ;
                else
                  NS = IDLE;
            end

            // if an ERROR occurs, just sit here
            ERROR:
              NS = ERROR;
              
            // Recovery from illegal encodings (all-zero or multi-hot)
            default: begin
              NS = ERROR;
            end

        endcase
    end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always_ff @ (posedge clk125) begin
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
    unique case (NS)
      IDLE: begin
      end
    
      INIT_WAIT: begin
        init_counter  <= 1'b1;
        enable_acq_reg  <= 1'b1;
      end
    
      ENABLE_TRIG_WAIT: begin
        enable_acq_reg  <= 1'b1;
      end
    
      ACQUIRING: begin
        enable_acq_reg  <= 1'b1;
        enable_trig_reg <= 1'b1;
      end
    
      DISABLE_TRIG: begin
        enable_acq_reg  <= 1'b1;
      end
    
      ACQ_WAIT: begin
        enable_acq_reg  <= 1'b1;
      end
    
      DISABLE_ACQ: begin
      end
  
      default: begin
        // keep defaults; recovery handled by next-state logic
      end
    endcase
  end

end // of always block

endmodule


`timescale 1ns/10ps
`default_nettype wire

module enable_sm_selftrigc (
    input  logic         adc_clk,                    
    input  logic         enable_triggering,           // self triggers enabled and valid.    adc clk
    input  logic         enable_acquisition,          // data acquisition enabled            adc clk
    input  logic         self_trig,                   // self trigger condition has been met adc clk
    input  logic         reset_clk_adc,               // reset everything related to ADC acquisition and storage -- now just reset_clk50 synced to adc_clk
    input  logic         cbuf_rd_trig_wait,           // waiting for another trigger or the negation of 'cbuf_rd_en'. adc clk
    input  logic         ddr3_wr_done,                // asserted when the 'ddr3_wr_control' is in the DONE state.  adc clk, but sync'd
    input  logic         ddr3_selftrig_wr_active,     // enabled whenever we are actively writing a trigger to the DDR3.  adc clk
    input  logic         initial_fill_num_wr_clkadc,  // when we initialize fill number, also initialize any other needed variables.  adc clk
    input  logic         new_fill,                    // a new fill has been requested, so we need to wrap up the current fill.  from master, sync'd

    output logic         cbuf_wr_en,      // writing into the circ buf by the ADC is enabled, must extend past final trigger
    output logic         cbuf_trig_en,    // triggering of new waveforms is enabled for the current DDR3 write buffer
    output logic         cbuf_rd_en,      // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
    output logic         ddr3_wr_en,      // writing of triggered events to memory is enabled
    output logic         trig_pulse,      // a trigger passed while the system is enabled for new triggers
    output logic         adc_acq_sm_idle, // ADC acquisition state machine is idle (used for front panel LED status)
    output logic         init_ddr3_addr,  // initialize the ddr3 address for this run
    output logic         ext_done,        // external output indicating acquisition is done
    output logic [9:0]   enable_sm_state  // enable_sm current state
);

// =========================================================================
// Synchronize ddr3_wr_done into adc_clk domain
// =========================================================================
(* ASYNC_REG = "TRUE" *) logic ddr3_wr_done_sync1, ddr3_wr_done_sync2;
always_ff @(posedge adc_clk) begin
  ddr3_wr_done_sync1 <= ddr3_wr_done;
  ddr3_wr_done_sync2 <= ddr3_wr_done_sync1;
end
wire ddr3_wr_done_sync2_debug;
assign ddr3_wr_done_sync2_debug = ddr3_wr_done_sync2;

// =========================================================================
// sync the new_fill signal int adc_clk domain
// =========================================================================
(* ASYNC_REG = "TRUE" *) logic new_fill_sync1, new_fill_sync2;
always_ff @(posedge adc_clk) begin
  new_fill_sync1 <= new_fill;
  new_fill_sync2 <= new_fill_sync1;
end

// =========================================================================
// self_trig edge detect -> one-cycle pulse (already in adc_clk domain)
// =========================================================================
logic trig_sync1, trig_sync2, trig_sync3;
always_ff @(posedge adc_clk) begin
    trig_sync1 <= self_trig;
    trig_sync2 <= trig_sync1;
    trig_sync3 <= trig_sync2;
    trig_pulse <= (trig_sync2 & ~trig_sync3); // gate with cbuf_trig_en later if desired
end

// =========================================================================
// ext_done hold counter
// =========================================================================
logic [5:0] pulse_cntr;
logic       init_pulse_cntr;
logic       pulse_cntr_zero = (pulse_cntr == 6'd0);
always_ff @(posedge adc_clk) begin
    if (reset_clk_adc) begin
        // reset counter
        pulse_cntr <= 6'd0;
    end 
    else if (init_pulse_cntr) begin
        pulse_cntr <= 6'd30;           // hold for master FPGA to see, 30 = 81 nsec
    end 
    else if (!pulse_cntr_zero) begin
        pulse_cntr <= pulse_cntr - 6'd1;
    end
end

// =========================================================================
// One-hot FSM using enum
// =========================================================================
typedef enum logic [10:0] {
    IDLE              = 11'b00000000001,  // 001
    INIT_DDR3_ADDR    = 11'b00000000010,  // 002
    ENABLE_WAIT       = 11'b00000000100,  // 004
    BUFFER_FILL_START = 11'b00000001000,  // 008
    TRIG_ENABLED      = 11'b00000010000,  // 010
    CBUF_RD_ENABLED   = 11'b00000100000,  // 020
    CBUF_RD_DONE      = 11'b00001000000,  // 040
    DDR3_DONE_WAIT    = 11'b00010000000,  // 080
    DONE1             = 11'b00100000000,  // 100
    DONE2             = 11'b01000000000,  // 200
    ERROR             = 11'b10000000000   // 400
} state_t;

// Synthesis hint: keep it one-hot and auto-recover to error state
//(* fsm_encoding = "one-hot", fsm_safe_state = "default_state" *)
(* fsm_encoding = "one-hot" *)

state_t CS;
state_t NS;

assign enable_sm_state = CS;

// Sequential state update
always_ff @(posedge adc_clk) begin
    if (reset_clk_adc) CS <= IDLE;
    else               CS <= NS;
end

// Next-state logic
always_comb begin
  NS = IDLE; // default safe value (also covers illegal encodings via default below)
  
  unique case (CS)
    IDLE:  begin
      // all reset signals have been negated, so go wait for the start of a new fill
      NS = enable_acquisition ? INIT_DDR3_ADDR : IDLE;
    end
        
    // stay here one cycle to initialize the DDR3 starting address
    INIT_DDR3_ADDR: begin
        NS = ENABLE_WAIT;
    end
    
    // Stay in ENABLE_WAIT 1 cycle
    // This state used to do something in earlier designs.  Can probably just be eliminated
    ENABLE_WAIT: begin
      NS = BUFFER_FILL_START;
    end
    
    // Stay in the BUFFER_FILL_START state for one clock period.
    BUFFER_FILL_START: begin
      NS = TRIG_ENABLED;
    end
    
    // Triggers are accepted during TRIG_ENABLED. Stay in TRIG_ENABLED until either the
    // ENABLE signal from the master has been negated, or a change in ddr3 buffer has
    // been detected. Either signals the end of possible new acquisitions
    // for the current buffer. Go to CBUF_RD_ENABLED to finish writing any triggered
    // acquisitions to the DDR3 and write the final fill_header.
    // We should have completed all necessary readout when enable_acquisition deasserts,
    // so simply go to the idle state once that happens
    TRIG_ENABLED: begin
      if (!enable_acquisition )      NS = IDLE;
      // a fill of this buffer is ending, so prep the next, write buffer leave the DDR3 asserted.
      else if ( new_fill_sync2 )     NS = CBUF_RD_ENABLED;
      // filling this buffer  is still active, so stay here
      else                           NS = TRIG_ENABLED;
    end
    
    // Stay in CBUF_RD_ENABLED until the 'cbuf_rd_trig_wait' signal from the circular buf
    // reader has been asserted. This signals that all of the data for the final trigger
    // has been sent to the DDR3
    CBUF_RD_ENABLED: begin
      // If he final event has been processed, reading done. Otherwise stay here
      NS = cbuf_rd_trig_wait ? CBUF_RD_DONE : CBUF_RD_ENABLED;
    end
    
    // When we have sent the final event to the DDR3, we need to send the checksum and the
    // fill header. 
    CBUF_RD_DONE: begin
      NS = DDR3_DONE_WAIT;
    end
    
    // Stay in DDR3_DONE_WAIT until the DONE signals from the DDR3
    // has been asserted. This signals that all of the data is in the DDR3
    DDR3_DONE_WAIT: begin
      // if everything is in memory, start fill wrap up, else remain here.
      NS = ddr3_wr_done_sync2 ? DONE1 : DDR3_DONE_WAIT;
    end
    
    // initialize duration counter for asserting ext_done so that the master will see it
    DONE1: begin
      NS = DONE2;
    end
    
    // Stay in DONE2 until the pulse duration counter is zero.
    DONE2: begin
      if (pulse_cntr_zero)
        NS = (enable_acquisition ? BUFFER_FILL_START : IDLE);
      else
        NS = DONE2;
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

// Registered outputs: “on entry” driven from NS
always_ff @(posedge adc_clk) begin
    // defaults every cycle
    cbuf_wr_en      <= 1'b1; // writing into the circ buf by the ADC is enabled, must extend past final trigger
    cbuf_trig_en    <= 1'b0; // we need to communicate to circ_buf_to_ddr3_sm_selftrig to wrap up for this buffer
    cbuf_rd_en      <= 1'b0; // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
    ddr3_wr_en      <= 1'b0; // writing of triggered events to memory is enabled
    ext_done        <= 1'b0; // total acquisition is done, data is stored in DDR3
    init_pulse_cntr <= 1'b0; // initialize the pulse duration counter
    adc_acq_sm_idle <= 1'b0; // ADC acquisition state machine is idle (used for front panel LED status)
    init_ddr3_addr  <= 1'b0; // initialize the first ddr3 address for a new run

  // actions based on next states
  unique case (NS)
    IDLE: begin
      cbuf_wr_en      <= 1'b0;
      adc_acq_sm_idle <= 1'b1;
      ext_done        <= 1'b1;
    end

    INIT_DDR3_ADDR: begin
      init_ddr3_addr  <= 1'b1;
    end

    ENABLE_WAIT: begin
      adc_acq_sm_idle <= 1'b1;
      ext_done        <= 1'b1;
    end

    BUFFER_FILL_START: begin
      // (no special outputs in your original code)
      // keep defaults
    end

    TRIG_ENABLED: begin
      cbuf_rd_en      <= 1'b1;                    // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
      cbuf_trig_en    <= enable_acquisition;      // triggering of new waveforms is enabled for most states
      ddr3_wr_en      <= ddr3_selftrig_wr_active; // writing of triggered events to memory is enabled (now only during triggers)
    end

    CBUF_RD_ENABLED: begin
      cbuf_rd_en      <= 1'b1;                    // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
      ddr3_wr_en      <= ddr3_selftrig_wr_active; // writing of triggered events to memory is enabled
    end

    CBUF_RD_DONE: begin
      ddr3_wr_en      <= ddr3_selftrig_wr_active; // writing of triggered events to memory is enabled
      cbuf_rd_en      <= enable_acquisition;      // moving data from the circ buf to the DDR3 FIFO is enabled,
                                                  // -- checksum and fill header go when first negated. Disable if running has been disabled
    end

    DDR3_DONE_WAIT: begin
      ddr3_wr_en      <= ddr3_selftrig_wr_active; // writing of triggered events to memory is enabled
      cbuf_rd_en      <= enable_acquisition;      // moving data from the circ buf to the DDR3 FIFO is enabled,
                                                  // -- checksum and fill header go when first negated. Disable if running has been disabled
    end

    DONE1: begin
      init_pulse_cntr <= 1'b1;                   // start ext_done hold counter
    end

    DONE2: begin
      ext_done        <= 1'b1;                   // keep ext_done asserted while counting
    end

    default: begin
      // keep defaults; recovery handled by next-state logic
    end
  endcase
end

endmodule

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
    output logic         fill_parity,     // toggles at every fill boundary; tags each trigger with its fill
    output logic         close_forced,    // one clock: a fill was closed by the time-out, not by the reader (diagnostic count)
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
wire        pulse_cntr_zero = (pulse_cntr == 6'd0);   // continuous assignment (a 'logic' initialiser is evaluated once by the language)
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

// 'new_fill' is a ~150 ns level from the master (NEW_DDR3_BUFFER + TRANSITION).  It is taken as a
// latched rising edge rather than as a level (6.6.9): a level could be seen twice if a fill ever
// closed in less than the level's width (a second, empty fill the master did not ask for), or not
// at all if it ended before this machine was back in TRIG_ENABLED (the channel then one fill
// behind for the rest of the run).  The request is held until TRIG_ENABLED consumes it, and
// dropped at the end of the run.
logic new_fill_sync3 = 1'b0, new_fill_req = 1'b0;
wire  new_fill_edge  = new_fill_sync2 & ~new_fill_sync3;
wire  new_fill_boundary = new_fill_edge | new_fill_req;
always_ff @(posedge adc_clk) begin
  new_fill_sync3 <= new_fill_sync2;
  if (reset_clk_adc || !enable_acquisition) new_fill_req <= 1'b0;
  else if (CS == TRIG_ENABLED)             new_fill_req <= 1'b0;   // consumed (an edge in this state acts directly)
  else if (new_fill_edge)                  new_fill_req <= 1'b1;
end

// Sequential state update
always_ff @(posedge adc_clk) begin
    if (reset_clk_adc) CS <= IDLE;
    else               CS <= NS;
end

// =========================================================================
// Bound on the fill-closing states (CBUF_RD_ENABLED, DDR3_DONE_WAIT): 2^22 clocks = 10.5 ms.  A
// legitimate close drains whatever the trigger FIFO holds at 2.5 ns per sample: up to the
// back-pressure threshold of 960 waveforms (adc_acq_top_selftrigc), 1.2 ms at 1024 samples each and
// 10 ms only at ~4400 samples, so this is well clear of any real close and still inside the
// channel's own header wait (16.8 ms, cc_rd_fill_sm) and the master's wait for done (26 ms).  A
// fill that cannot close ends in a header-less fill (the master then gets a channel error for that
// event) instead of a hung channel.
// =========================================================================
logic [22:0] close_cntr = 23'd0;
wire  close_timeout = close_cntr[22];
always_ff @(posedge adc_clk) begin
    if (reset_clk_adc || !(CS == CBUF_RD_ENABLED || CS == DDR3_DONE_WAIT)) close_cntr <= 23'd0;
    else if (!close_timeout)                                               close_cntr <= close_cntr + 23'd1;
    // the time-out exit was taken (the normal exits are tested first in the case above, so a
    // close_timeout that coincides with a legitimate exit is not counted)
    close_forced <= close_timeout && (NS == DONE1) && !(!enable_acquisition && !ddr3_selftrig_wr_active) &&
                    ((CS == CBUF_RD_ENABLED && !cbuf_rd_trig_wait) || (CS == DDR3_DONE_WAIT && !ddr3_wr_done_sync2));
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
    
    // Triggers are accepted during TRIG_ENABLED. Stay in TRIG_ENABLED until either
    // enable_acquisition is negated (run end) or a new_fill boundary is detected.
    // In both cases, go to CBUF_RD_ENABLED to drain any in-flight triggered write
    // to DDR3 before signalling done. Previously, run-end jumped straight to IDLE,
    // which could abandon an in-progress DDR3 write; now both paths drain cleanly.
    TRIG_ENABLED: begin
      // Both run-end and fill-boundary go through the drain sequence.
      if (!enable_acquisition || new_fill_boundary)  NS = CBUF_RD_ENABLED;
      // filling this buffer  is still active, so stay here
      else                                        NS = TRIG_ENABLED;
    end
    
    // Stay in CBUF_RD_ENABLED until either:
    //   (a) cbuf_rd_trig_wait asserts -- the circular buffer reader has finished sending
    //       all data for the last trigger to the DDR3 (normal fill-boundary or run-end path), or
    //   (b) enable_acquisition is deasserted AND ddr3_selftrig_wr_active is low -- run-end
    //       arrived with nothing actively being written, so skip straight to wrap-up (DONE1).
    CBUF_RD_ENABLED: begin
      if (cbuf_rd_trig_wait)
        // Normal path: circular buffer reader has finished sending the last event.
        NS = CBUF_RD_DONE;
      else if (close_timeout)
        // The reader never came back to TRIG_WAIT (it should not be possible since 6.6.9, but a
        // fill that cannot be closed must not hold the master for ever): wrap up anyway.
        // 'close_forced' records that it happened.
        NS = DONE1;
      else if (!enable_acquisition && !ddr3_selftrig_wr_active)
        // Run-end escape: no active DDR3 write in progress and no more triggers
        // will arrive (enable is gone), so nothing left to drain -- skip to wrap-up.
        NS = DONE1;
      else
        NS = CBUF_RD_ENABLED;
    end    
    
    // When we have sent the final event to the DDR3, we need to send the checksum and the
    // fill header. 
    CBUF_RD_DONE: begin
      NS = DDR3_DONE_WAIT;
    end
    
    // Stay in DDR3_DONE_WAIT until the DONE signal from the DDR3 writer has
    // been asserted, i.e. the checksum and fill header are in memory.
    //
    // Run-end escape: if enable_acquisition dropped while a waveform was in
    // flight, we arrive here via the cbuf_rd_trig_wait branch, but the reader
    // (circ_buf_to_ddr3_sm) has gone to IDLE without writing a checksum or
    // header and the writer (ddr3_wr_control) has gone to IDLE without seeing
    // one, so ddr3_wr_done can never come.  Once the reader is idle
    // (ddr3_selftrig_wr_active low) there is nothing left to wait for; go to
    // DONE1 so ext_done is produced and the machine can return to IDLE.
    // (Until 6.7.x both exits also waited for self_trigger's 'line_quiet', so that the master had
    // counted every trigger-line pulse of the fill before 'done'.  There is no line any more.)
    DDR3_DONE_WAIT: begin
      if (ddr3_wr_done_sync2)
        NS = DONE1;
      else if (close_timeout)
        NS = DONE1;                    // bounded, as CBUF_RD_ENABLED
      else if (!enable_acquisition && !ddr3_selftrig_wr_active)
        NS = DONE1;
      else
        NS = DDR3_DONE_WAIT;
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

// =========================================================================
// Fill parity.
//
// At a fill boundary (new_fill while in TRIG_ENABLED with the acquisition still on) the fill
// parity toggles.  From then on every accepted trigger is tagged with the new parity (it belongs
// to the next fill: adc_acq_top_selftrigc), and circ_buf_to_ddr3_sm ends the closing fill at the
// first trigger of the other parity.  (Until 6.7.x a trigger-line hold-off and its guard counter
// lived here too, to keep the master's pulse count on the right side of 'done'; they went with
// the line in 6.8.0.)
// =========================================================================
wire boundary_ns = (CS == TRIG_ENABLED) && (NS == CBUF_RD_ENABLED) && enable_acquisition;
always_ff @(posedge adc_clk) begin
    if (reset_clk_adc)              fill_parity <= 1'b0;
    else if (NS == INIT_DDR3_ADDR)  fill_parity <= 1'b0;   // run start: the trigger FIFOs are cleared at the same time (adc_acq_top)
    else if (boundary_ns)           fill_parity <= ~fill_parity;
end

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
      // (ext_done deliberately not asserted here: a one-cycle blip of "done" at
      //  run start only confuses acq_idle / acq_done consumers)
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

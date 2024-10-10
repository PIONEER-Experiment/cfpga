`timescale 1ns / 10ps

module enable_sm_selftrig (
    // inputs
    input adc_clk,
    input enable_triggering,    // self triggers enabled and valid.
    input ddr3_buffer,          // master's request for which buffer to write to
    input self_trig,            // self trigger condition has been met
    input reset_clk50,          // synchronously negated reset all of the acquisition logic
    input reset_clk_adc,        // reset everything related to ADC acquisition and storage -- now just reset_clk50 synced to adc_clk
    input cbuf_rd_trig_wait,    // waiting for another trigger or the negation of 'cbuf_rd_en'
    input ddr3_wr_done,         // asserted when the 'ddr3_wr_control' is in the DONE state
    input ddr3_selftrig_wr_active, // enabled whenever we are actively writing a trigger to the DDR3
    input initial_fill_num_wr_clkadc, // when we initialize fill number, also initialize the ddr3_buffer-related variables
    // outputs
    output reg cbuf_wr_en,      // writing into the circ buf by the ADC is enabled, must extend past final trigger
    output reg cbuf_trig_en,    // triggering of new waveforms is enabled for the current DDR3 write buffer
    output reg cbuf_rd_en,      // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
    output reg ddr3_wr_en,      // writing of triggered events to memory is enabled
(* mark_debug = "true" *)     output reg [1:0] ddr3_range,// level of the ddr3 range bit.  Two copies because of history of other modes
    output reg trig_pulse,      // a trigger passed while the system is enabled for new triggers
    output reg adc_acq_sm_idle, // ADC acquisition state machine is idle (used for front panel LED status)
    output reg ext_done,        // external output indicating acquisition is done
//    output reg reset_timer,     // triggers reset of the 800 MHz counter used to time stamp events
(* mark_debug = "true" *)     output reg [1:0] ext_done_buffer,                // everything has been written to DDR3 and fill header FIFO
    output reg range_flip
);

///////////////////////////////////////////////////////////////////////////////////////////////////
// Sync the enable_triggering inputs to the ADC clock domain.
(* ASYNC_REG = "TRUE" *) reg trig_ready_sync1, trig_ready_sync2;
always @(posedge adc_clk) begin
    trig_ready_sync1 <= #1 enable_triggering;
    trig_ready_sync2 <= #1 trig_ready_sync1;
end

///////////////////////////////////////////////////////////////////////////////////////////////////
// Sync the ddr3_buffer bit
(* ASYNC_REG = "TRUE" *) reg ddr3_buffer_sync1, ddr3_buffer_sync2;
always @(posedge adc_clk) begin
    ddr3_buffer_sync1 <= #1 ddr3_buffer;
    ddr3_buffer_sync2 <= #1 ddr3_buffer_sync1;
end

// synchronize 'ddr3_wr_done'
(* ASYNC_REG = "TRUE" *) reg ddr3_wr_done_sync1, ddr3_wr_done_sync2;
always @(posedge adc_clk) begin
    ddr3_wr_done_sync1 <= #1 ddr3_wr_done;
    ddr3_wr_done_sync2 <= #1 ddr3_wr_done_sync1;
end

// the self trigger can be maintined for several cycles -- create a pulse when from the signal
// the signal itself is already in the ADC clock domain
reg trig_sync1, trig_sync2, trig_sync3, trig_sync4, trig_sync5;
always @ (posedge adc_clk) begin
    trig_sync1 <= #1 self_trig;
    trig_sync2 <= #1 trig_sync1;
    trig_sync3 <= #1 trig_sync2;
    // pass triggers only during the TRIG_ENABLED state
    //trig_pulse <= #1 ((trig_sync2 & ~trig_sync3) && cbuf_trig_en);
    trig_pulse <= #1 (trig_sync2 & ~trig_sync3);
 end

///////////////////////////////////////////////////////////////////////////////////////////////////
// Create a down-counter that will extend the assertion time of 'ext_done'
reg [5:0] pulse_cntr;
reg init_pulse_cntr;
wire pulse_cntr_zero;
// set a flag when the counter is equal to zero
assign pulse_cntr_zero = (pulse_cntr[5:0] == 0) ? 1'b1 : 1'b0;
always @(posedge adc_clk) begin
    if (reset_clk_adc) begin
        // reset counter
        pulse_cntr[5:0] <= #1 6'b0;
    end
    else if (init_pulse_cntr) begin
        pulse_cntr[5:0] <= #1 6'd30;    // hold for master FPGA to see, 30 = 81 nsec
    end
    else if (pulse_cntr_zero) begin
        // if zero then hold there
        pulse_cntr[5:0] <= #1 6'b0;
    end
    else begin
        // decrement the counter
        pulse_cntr[5:0] <= #1 pulse_cntr[5:0] - 1;
    end 
end
///////////////////////////////////////////////////////////////////////////////////////////////////
// Watch for the ddr3_buffer bit from the master to flip
//reg range_flip;
reg prev_ddr3_buffer;
always @ (posedge adc_clk) begin
   if ( reset_clk_adc | initial_fill_num_wr_clkadc ) begin
      range_flip <= 1'b0;
      prev_ddr3_buffer <= 1'b0;
   end
   else begin
      if ( ddr3_buffer_sync2 != prev_ddr3_buffer ) begin
         range_flip <= 1'b1;
      end
      else begin
         range_flip <= 1'b0;
      end
      prev_ddr3_buffer <= ddr3_buffer_sync2;
   end
end

///////////////////////////////////////////////////////////////////////////////////////////////////
//  Leave the comments containing "synopsys" in your HDL code.
// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [3:0]
    IDLE              = 4'd0,  // 001
    ENABLE_WAIT       = 4'd1,  // 002
    BUFFER_FILL_START = 4'd2,  // 004
    TRIG_ENABLED      = 4'd3,  // 008
    CBUF_RD_ENABLED   = 4'd4,  // 010
    CBUF_RD_DONE      = 4'd5,  // 020
    DDR3_DONE_WAIT    = 4'd6,  // 040
    DONE1             = 4'd7,  // 080
    DONE2             = 4'd8;  // 100
   
// Declare current state and next state variables
(* mark_debug = "true" *) reg [8:0] /* synopsys enum STATE_TYPE */ CS;
reg [8:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS

// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge adc_clk) begin
    if (reset_clk_adc | !trig_ready_sync2 ) begin
//    if (reset_clk_adc ) begin
        CS <= #1 {9{1'b0}}; // set all state bits to 0
        CS[IDLE] <= #1 1'b1; // set IDLE state bit to 1
    end
    else
        CS <= #1 NS;         // set state bits to next state
end

// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or trig_ready_sync2 or cbuf_rd_trig_wait or ddr3_wr_done_sync2 or pulse_cntr_zero or range_flip ) begin
    NS = {9{1'b0}}; // default all bits to zero; will overrride one bit

    case (1'b1) // synopsys full_case parallel_case

        // Stay in the IDLE state whenever we are not enabled.
        CS[IDLE]: begin
            // all reset signals have been negated, so go wait for the start of a new fill
            NS[ENABLE_WAIT] = 1'b1;
        end

        // Stay in ENABLE_WAIT until the self triggering module is enabled and ready
        CS[ENABLE_WAIT]: begin
            if (trig_ready_sync2)
                // a fill of a new buffer is starting, go latch the ddr3 buffer range bit
                NS[BUFFER_FILL_START] = 1'b1;
             else
                // wait here
                NS[ENABLE_WAIT] = 1'b1;
        end

        // Stay in the BUFFER_FILL_START state for one clock period.
        CS[BUFFER_FILL_START]: begin
            //  go enable both the ADC and the DDR3
            NS[TRIG_ENABLED] = 1'b1;
        end

       // Triggers are accepted during TRIG_ENABLED. Stay in TRIG_ENABLED until either the
       // ENABLE signal from the master has been negated, or a change in ddr3 buffer has
       // been detected. Either signals the end of possible new acquisitions
       // for the current buffer. Go to CBUF_RD_ENABLED to finish writing any triggered
       // acquisitions to the DDR3 and write the final fill_header.
        CS[TRIG_ENABLED]: begin
            if (!trig_ready_sync2 || range_flip )
                // a fill of this buffer is ending, so swap the write buffer leave the DDR3 asserted.
                NS[CBUF_RD_ENABLED] = 1'b1;
             else
                // filling this buffer  is still active, so stay here
                NS[TRIG_ENABLED] = 1'b1;
        end


       // Stay in CBUF_RD_ENABLED until the 'cbuf_rd_trig_wait' signal from the circular buf
       // reader has been asserted. This signals that all of the data for the final trigger
       // has been sent to the DDR3
        CS[CBUF_RD_ENABLED]: begin
            if (cbuf_rd_trig_wait)
                // The final event has been processed.
                NS[CBUF_RD_DONE] = 1'b1;
             else
                // still working on events, so stay here
                NS[CBUF_RD_ENABLED] = 1'b1;
        end

        // When we have sent the final event to the DDR3, we need to send the checksum and the
        // fill header. 
        CS[CBUF_RD_DONE]: begin
                NS[DDR3_DONE_WAIT] = 1'b1;
        end

       // Stay in DDR3_DONE_WAIT until the DONE signals from the DDR3
       // has been asserted. This signals that all of the data is in the DDR3
        CS[DDR3_DONE_WAIT]: begin
            if (ddr3_wr_done_sync2)
                // everything is in memory.
                NS[DONE1] = 1'b1;
             else
                // memory writing is still active, so stay here
                NS[DDR3_DONE_WAIT] = 1'b1;
        end

        // when we are done, we need to assert the ext_done for at least 40 nsec.
        // A counter will be used to determine the assertion time.
        // Initialize the counter here. 
        CS[DONE1]: begin
                NS[DONE2] = 1'b1;
        end

        // Stay in DONE2 until the pulse duration counter is zero.
        CS[DONE2]: begin
            if (pulse_cntr_zero) begin
                if ( trig_ready_sync2 )
                    NS[BUFFER_FILL_START] = 1'b1;
                else
                    NS[IDLE] = 1'b1;
            end
            else
                NS[DONE2] = 1'b1;
        end
    endcase
end // combinational always block to determine next state


// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
reg latch_ddr3_range;
always @ (posedge adc_clk) begin
    // defaults
    cbuf_wr_en             <= #1 1'b1;        // writing into the circ buf by the ADC is enabled, must extend past final trigger
    cbuf_trig_en           <= #1 1'b0;        // we need to communicate to circ_buf_to_ddr3_sm_selftrig to wrap up for this buffer
    cbuf_rd_en             <= #1 1'b0;        // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
    ddr3_wr_en             <= #1 1'b0;        // writing of triggered events to memory is enabled
    ext_done               <= #1 1'b0;        // total acquisition is done, data is stored in DDR3
    init_pulse_cntr        <= #1 1'b0;        // initialize the pulse duration counter
    latch_ddr3_range        <= #1 1'b0;        // copy level of the two 'ext_enable' bits into the 'fill_type'
    adc_acq_sm_idle        <= #1 1'b0;        // ADC acquisition state machine is idle (used for front panel LED status)
//    reset_timer            <= #1 1'b0;                 // reset the 400 MHz trigger time counter
    // next states
    if (NS[IDLE]) begin
        cbuf_wr_en             <= #1 1'b0;        // writing into the circ buf by the ADC is disabled
        adc_acq_sm_idle        <= #1 1'b1;
        ext_done    <= #1 1'b1;
    end
    
    if (NS[ENABLE_WAIT]) begin
        adc_acq_sm_idle     <= #1 1'b1;
        ext_done    <= #1 1'b1;     //
    end

    if (NS[BUFFER_FILL_START]) begin
        latch_ddr3_range        <= #1 1'b1;              // copy the ddr3 buffer range bit into the bits for 'fill_type' in the other modes
//        reset_timer             <= #1 1'b1;
    end

    if (NS[TRIG_ENABLED]) begin
        cbuf_rd_en           <= #1 1'b1;        // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
        cbuf_trig_en         <= #1 trig_ready_sync2; // triggering of new waveforms is enabled for most states
        ddr3_wr_en           <= #1 ddr3_selftrig_wr_active;        // writing of triggered events to memory is enabled (now only during triggers)
     end

    if (NS[CBUF_RD_ENABLED]) begin
        cbuf_rd_en           <= #1 1'b1;        // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
        ddr3_wr_en           <= #1 ddr3_selftrig_wr_active;  // writing of triggered events to memory is enabled
    end

    if (NS[CBUF_RD_DONE]) begin
        ddr3_wr_en           <= #1 ddr3_selftrig_wr_active;        // writing of triggered events to memory is enabled
        cbuf_rd_en           <= #1 trig_ready_sync2;    // moving data from the circ buf to the DDR3 FIFO is enabled,
                                                        // -- checksum and fill header go when first negated. Disable if running has been disabled
    end

    if (NS[DDR3_DONE_WAIT]) begin
        ddr3_wr_en           <= #1 ddr3_selftrig_wr_active;        // writing of triggered events to memory is enabled
        cbuf_rd_en           <= #1 trig_ready_sync2;        // moving data from the circ buf to the DDR3 FIFO is enabled, chec
                                                            // -- checksum and fill header go when first negated. Disable if running has been disabled
    end

    if (NS[DONE1]) begin
        init_pulse_cntr      <= #1 1'b1;        // initialize the pulse duration counter
    end

    if (NS[DONE2]) begin
        ext_done    <= #1 1'b1;     // total acquisition from cbuf -> ddr3 is done, data is stored in DDR3
    end

 
end

// keep track of when a given buffer has completed
always @(posedge adc_clk) begin
  // zero both on reset
  if ( reset_clk_adc ) begin
    ext_done_buffer[1:0] <= 2'b00;
  end
  // zero the buffer to be read out when the range flips
  else if ( range_flip ) begin
    ext_done_buffer[~ddr3_buffer] <= 1'b0;
    ext_done_buffer[ ddr3_buffer] <= ext_done_buffer[ ddr3_buffer];
  end
  // flag that the last DDR3 writing has been done for the buffer to be read out
  else if (NS[DONE2] ) begin
    ext_done_buffer[~ddr3_buffer] <= 1'b1;
    ext_done_buffer[ ddr3_buffer] <= ext_done_buffer[ ddr3_buffer];
  end
  else
    ext_done_buffer[1:0] <= ext_done_buffer[1:0];
end

// After we have been enabled, latch the value of the two 'acq_enable' signals in the 'fill_type'
// register. The fill type does not currently do anything in ASYNC mode, other than getting inserted
// the fill header. 
always @(posedge adc_clk) begin
    if (latch_ddr3_range) begin
      ddr3_range[1] <= #1 ddr3_buffer_sync2;
      ddr3_range[0] <= #1 ddr3_buffer_sync2;
    end
end

endmodule


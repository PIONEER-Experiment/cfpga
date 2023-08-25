`timescale 1ns / 1ps

///////////////////////////////////////////////////
// connect a state machine to coordinate everything

module adc_acq_sm_cbuf (
    // inputs
    input clk,                          // runs at the adc_clk speed (400 MHz)
    input acq_enable0,                  // indicates enabled for triggers, and fill type
    input acq_enable1,                  // indicates enabled for triggers, and fill type
    input acq_trig,                     // trigger the logic to start collecting data
    input reset_clk50,                  // reset from internal logic, synched to CLK50
    (* mark_debug = "true" *) input trig_fifo_empty,              // no trigger address is available for reading yet
    (* mark_debug = "true" *) input burst_cntr_zero,              // all sample bursts have been saved
    input ddr3_wr_done,                 // asserted when the 'ddr3_wr_control' is in the DONE state
    input dummy_dat_reset_mode,         // channel_tag[4] = 0 -> free-run,  1 -> reset every waveform
    // outputs
    output reg [1:0] fill_type,         // determine which burst count to use (not in cbuf mode)
    output reg address_cntr_en,         // increment the next starting address
    output reg dummy_dat_reset,         // reset the dummy data counter
    (* mark_debug = "true" *) output reg adc_mux_fill_hdr_sel,    // selects fill header
    (* mark_debug = "true" *) output reg adc_mux_wfm_hdr_sel,     // selects waveform header
    (* mark_debug = "true" *) output reg adc_mux_dat_sel,         // selects data
    (* mark_debug = "true" *) output reg adc_mux_checksum_select, // selects checksum
    (* mark_debug = "true" *) output reg adc_mux_checksum_update, // update the checksum
    output reg burst_cntr_init,         // initialize when triggered
    output reg burst_cntr_en,           // will be enabled once per burst
    (* mark_debug = "true" *) output reg fill_cntr_en,            // will be enabled once per fill
    (* mark_debug = "true" *) output reg adc_acq_out_valid,       // current data should be stored in the FIFO
    (* mark_debug = "true" *) output reg trig_pulse,
    output reg acq_enabled,             // writing triggered data to DDR3 in progress
    output reg adc_acq_full_reset,      // reset everything related to ADC acquisition and storage
    output reg acq_done,                // acquisition is done
    output reg init_circ_buf_rd_addr,   // initialize the counter with the start of the buffer area to be saved
    output reg inc_circ_buf_rd_addr,    // increment the circular buffer address
    output reg trig_addr_rd_en,         // read a trigger address from the FIFO
    (* mark_debug = "true" *) output reg latch_circ_buf_dat,      // save the current 32-bit data word from the circular buffer
    output reg sm_idle                  // signal that this state machine is idle (used for front panel LED status)
);


// synchronize ENABLE and TRIGGER inputs to this clock domain
reg acq_enable0_sync1, acq_enable0_sync2, acq_enable0_sync3;
(* mark_debug = "true" *) reg acq_enable0_sync4;
reg acq_enable1_sync1, acq_enable1_sync2, acq_enable1_sync3;
(* mark_debug = "true" *) reg acq_enable1_sync4;
reg acq_trig_sync1, acq_trig_sync2, acq_trig_sync3, acq_trig_sync5;
(* mark_debug = "true" *) reg acq_trig_sync4;
always @(posedge clk) begin
    acq_enable0_sync1 <= acq_enable0;
    acq_enable0_sync2 <= acq_enable0_sync1;
    acq_enable0_sync3 <= acq_enable0_sync2;
    acq_enable0_sync4 <= acq_enable0_sync3;

    acq_enable1_sync1 <= acq_enable1;
    acq_enable1_sync2 <= acq_enable1_sync1;
    acq_enable1_sync3 <= acq_enable1_sync2;
    acq_enable1_sync4 <= acq_enable1_sync3;

    acq_trig_sync1 <= acq_trig;
    acq_trig_sync2 <= acq_trig_sync1;
    acq_trig_sync3 <= acq_trig_sync2;
    acq_trig_sync4 <= acq_trig_sync3;
    acq_trig_sync5 <= acq_trig_sync4;
    // assert 'trig_pulse' when 'ext_trig' has gotten to the fourth register, but not the fifth
    // pass triggers only during the ACQ_ENABLED state
    trig_pulse <= #1 ((acq_trig_sync4 & ~acq_trig_sync5) && adc_acq_mode_enabled);
end

// sync and combine the external ACQ_RESET and the internal RESET_CLK50
reg reset_clk50_sync1, reset_clk50_sync2; 
always @(posedge clk) begin
    reset_clk50_sync1 <= reset_clk50;
    reset_clk50_sync2 <= reset_clk50_sync1;
    adc_acq_full_reset <= reset_clk50_sync2;
end

// synchronize 'ddr3_wr_done'
reg ddr3_wr_done_sync1;
(* mark_debug = "true" *) reg ddr3_wr_done_sync2;
always @ (posedge clk) begin
    ddr3_wr_done_sync1 <= ddr3_wr_done;
    ddr3_wr_done_sync2 <= ddr3_wr_done_sync1;
end

// We are in acquisition mode whenever the ENABLE inputs are not both zero.
// When they are both zero, we are not running.
(* mark_debug = "true" *) reg adc_acq_mode_enabled; // we are enabled to accept triggers and store data
always @(posedge clk) begin
    if (acq_enable0_sync4 | acq_enable1_sync4)
        adc_acq_mode_enabled <= 1'b1;
    else
        adc_acq_mode_enabled <= 1'b0;
end

// The fill type is determined by combining the ENABLE inputs
always @(posedge clk) begin
    fill_type[1:0] <= {acq_enable1_sync4, acq_enable0_sync4};
end
     
// delay the 'adc_acq_out_valid' signal to allow for the memory reading delay
(* mark_debug = "true" *) reg immed_adc_acq_out_valid, dlyd_adc_acq_out_valid, start_dlyd_adc_acq_out_valid;
reg delay2, delay1, delay0;
always @ (posedge clk) begin
   adc_acq_out_valid <= #1 immed_adc_acq_out_valid | dlyd_adc_acq_out_valid;
   adc_mux_checksum_update <= #1 start_dlyd_adc_acq_out_valid;
   // run the delay pipeline
   dlyd_adc_acq_out_valid <= #1 start_dlyd_adc_acq_out_valid;
   delay2 <= #1 delay1;
   delay1 <= #1 delay0;
   delay0 <= #1 start_dlyd_adc_acq_out_valid;
end

//  Leave the comments containing "synopsys" in your HDL code.
 
// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [4:0]
    IDLE            = 5'd0,
    WATCH_FOR_TRIG  = 5'd1,
    FILL_INIT1      = 5'd2,
    FILL_INIT2      = 5'd3,
    WAVEFORM_INIT1  = 5'd4,
    WAVEFORM_INIT2  = 5'd5,
    WAVEFORM_INIT3  = 5'd6,
    RUN1            = 5'd7,
    RUN2            = 5'd8,
    RUN3            = 5'd9,
    RUN4            = 5'd10,
    WAVEFORM_TST1   = 5'd11,
    WAVEFORM_TST2   = 5'd12,
    CHECKSUM1       = 5'd13,
    CHECKSUM2       = 5'd14,
    DDR3_WAIT       = 5'd15,
    DONE            = 5'd16;
    
// Declare current state and next state variables
(* mark_debug = "true" *) reg [16:0] /* synopsys enum STATE_TYPE */ CS;
(* mark_debug = "true" *) reg [16:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
    if (adc_acq_full_reset) begin
        CS <= 17'b0;      // set all state bits to 0
        CS[IDLE] <= 1'b1; // set IDLE state bit to 1
    end
    else
        CS <= NS;         // set state bits to next state
end

// lkg -- will need to update the sensitivity list
// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or adc_acq_mode_enabled or acq_trig_sync4 or burst_cntr_zero or ddr3_wr_done_sync2 )    begin
    NS = 17'b0; // default all bits to zero; will overrride one bit

    case (1'b1) // synopsys full_case parallel_case

        // Stay in the IDLE state until we are armed
        CS[IDLE]: begin
            if (adc_acq_mode_enabled)
                NS[WATCH_FOR_TRIG] = 1'b1;
            else
                NS[IDLE] = 1'b1;
        end

        // Stay in the WATCH state until we are both armed and triggered.
        // We will wait here until the circular buffer trigger address is available
        // reading of the DDR3 can occur while we are in this state
        CS[WATCH_FOR_TRIG]: begin
            if (!trig_fifo_empty)
                NS[FILL_INIT1] = 1'b1;
            else
                NS[WATCH_FOR_TRIG] = 1'b1;
        end

        // We use 2 states to initialize for a new fill.
        // This happens once per trigger
        // Stay in FILL_INIT1 state for one period.
        CS[FILL_INIT1]: begin
                NS[FILL_INIT2] = 1'b1;
        end

        // Stay in FILL_INIT2 state for one period.
        CS[FILL_INIT2]: begin
                NS[WAVEFORM_INIT1] = 1'b1;
        end

        // We use 3 states to initialize for each new waveform.
        // This happens once per waveform
         // Stay in WAVEFORM_INIT1 state for one period. 
        CS[WAVEFORM_INIT1]: begin
                NS[WAVEFORM_INIT2] = 1'b1;
        end

        // Stay in WAVEFORM_INIT2 state for one period. 
        CS[WAVEFORM_INIT2]: begin
                NS[WAVEFORM_INIT3] = 1'b1;
        end

        // Stay in WAVEFORM_INIT3 state for one period. 
        CS[WAVEFORM_INIT3]: begin
                NS[RUN1] = 1'b1;
        end

        // We use 4 states to collect and forward bursts of ADC data.
        // Two 12-bit ADC samples, packed in a 32-bit word, are collected during each RUN state.
        // At the end, the 128-bit data is forwarded and the checksum is updated.
        // Stay in RUN1 state for one period.
        CS[RUN1]: begin
                NS[RUN2] = 1'b1;
        end

        // Stay in RUN2 state for one period.
        CS[RUN2]: begin
                NS[RUN3] = 1'b1;
        end

        // Stay in RUN3 state for one period.
        CS[RUN3]: begin
                NS[RUN4] = 1'b1;
        end

        // Stay in RUN4 state for one period.
        // If we have collected all of the bursts, we are done.
        // Otherwise, loop back and get mor ADC data.
        CS[RUN4]: begin
            if (burst_cntr_zero)
                NS[WAVEFORM_TST1] = 1'b1;
            else
                NS[RUN1] = 1'b1;
        end

        // We use 2 states to update and test the waveform counter
        // as well as to latch the final data because of delay from reading from the buffer
        // Stay in WAVEFORM_TST1 state for one period. 
        CS[WAVEFORM_TST1]: begin
                NS[WAVEFORM_TST2] = 1'b1;
        end

        // Stay in WAVEFORM_TST2 state for one period.
        // If this was the last waveform, go do checksum stuff.
        // Otherwise, start a gap.
        CS[WAVEFORM_TST2]: begin
            NS[CHECKSUM1] = 1'b1;
        end
 

        // We use 2 states to store the checksum.
         // Stay in CHECKSUM1 state for one period.
        CS[CHECKSUM1]: begin
                NS[CHECKSUM2] = 1'b1;
        end

        // Stay in CHECKSUM2 state for one period.
        CS[CHECKSUM2]: begin
                NS[DDR3_WAIT] = 1'b1;
        end

        // After all data for all waveforms has been collected, we
        // stay in DDR3_WAIT state until writing to the DDR3 is done.
        CS[DDR3_WAIT]: begin
            if (ddr3_wr_done_sync2)
                NS[DONE] = 1'b1;
            else
                NS[DDR3_WAIT] = 1'b1;
        end

        // Stay in the DONE state until the trigger is negated.
        // This prevents false retriggering.
        CS[DONE]: begin
            if (adc_acq_mode_enabled && acq_trig_sync4)
                NS[DONE] = 1'b1;
            else
                NS[IDLE] = 1'b1;
        end

    endcase
end // combinational always block to determine next state


// when we await a trigger, we can read DDR3 (acq_enabled=0)
// otherwise we are writing to DDR3 (acq_enabled=1).  The naming
// convention seems backwards, but follows from history.  Also allow
// reading during NS[IDLE] so that a transition to IDLE doesn't disrupt
// any reading still to be completed.
always @ (posedge clk) begin
    if (NS[WATCH_FOR_TRIG] || NS[IDLE] )
        acq_enabled <= 1'b0;
    else
        acq_enabled <= 1'b1;
end

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
    // defaults
        address_cntr_en         <= 1'b0;
        dummy_dat_reset         <= 1'b0;
        adc_mux_fill_hdr_sel    <= 1'b0;
        adc_mux_wfm_hdr_sel     <= 1'b0;
        adc_mux_dat_sel         <= 1'b0;
        adc_mux_checksum_select <= 1'b0;
//        adc_mux_checksum_update <= 1'b0;
        burst_cntr_init         <= 1'b0;
        burst_cntr_en           <= 1'b0;
        fill_cntr_en            <= 1'b0;
        immed_adc_acq_out_valid <= 1'b0;
        start_dlyd_adc_acq_out_valid <= 1'b0; // prepare for current output from the MUX should be stored in the FIFO        acq_done                <= 1'b0;
        sm_idle                 <= 1'b0;
        init_circ_buf_rd_addr   <= 1'b0;
        inc_circ_buf_rd_addr    <= 1'b0;
        trig_addr_rd_en         <= 1'b0;
        latch_circ_buf_dat      <= 1'b0;

    // next states
    if (NS[IDLE]) begin
        sm_idle                 <= 1'b1;
    end
    
    if (NS[FILL_INIT1]) begin
        // signal the mux to output the fill header info
        adc_mux_fill_hdr_sel         <= 1'b1;
    end

    if (NS[FILL_INIT2]) begin
       // write the fill header to the FIFO
       immed_adc_acq_out_valid        <= 1'b1;
       // increment the next fill address
       address_cntr_en          <= 1'b1;
    end

    if (NS[WAVEFORM_INIT1]) begin
        // at the start of a waveform, conditionally reset the counter that provides dummy data
        // 0 -> free-run,  1 -> reset every waveform
        dummy_dat_reset         <= dummy_dat_reset_mode;
        // initialize the counter with the start address of the circular buffer area to be saved
        init_circ_buf_rd_addr   <= #1 1'b1;
        // pull the trigger address out of the FIFO; the FIFI is in FWFT mode
        trig_addr_rd_en           <= #1 1'b1;
    end

    if (NS[WAVEFORM_INIT2]) begin
        // initialize the burst counter with the current fill size
        burst_cntr_init         <= 1'b1;
        // signal the mux to output the waveform header info
        adc_mux_wfm_hdr_sel         <= 1'b1;
    end

    if (NS[WAVEFORM_INIT3]) begin
        // write the waveform header to the FIFO
        immed_adc_acq_out_valid        <= 1'b1;
        // increment the next fill address
        address_cntr_en          <= 1'b1;
        // increment the circular buffer address
        // don't latch yet because data will not be ready
        inc_circ_buf_rd_addr    <= #1 1'b1;
    end

    if (NS[RUN1]) begin
        // save the current 32-bit data word from the circular buffer
        latch_circ_buf_dat      <= #1 1'b1;
        // increment the circular buffer address
        inc_circ_buf_rd_addr    <= #1 1'b1;
        // decrement the burst counter
        burst_cntr_en           <= 1'b1;
     end

    if (NS[RUN2]) begin
       // save the current 32-bit data word from the circular buffer
       latch_circ_buf_dat      <= #1 1'b1;
       // increment the circular buffer address
       inc_circ_buf_rd_addr    <= #1 1'b1;
    end

    if (NS[RUN3]) begin
        // save the current 32-bit data word from the circular buffer
        latch_circ_buf_dat      <= #1 1'b1;
       // increment the circular buffer address
       inc_circ_buf_rd_addr    <= #1 1'b1;
       // signal the mux to continue to output the ADC data burst
       adc_mux_dat_sel         <= #1 1'b1;
    end

    if (NS[RUN4]) begin
        // save the current 32-bit data word from the circular buffer
        latch_circ_buf_dat      <= #1 1'b1;
        // write the ADC burst to the FIFO
        start_dlyd_adc_acq_out_valid       <= 1'b1;
        // increment the next fill address
        address_cntr_en          <= 1'b1;
        // increment the circular buffer address
        inc_circ_buf_rd_addr    <= #1 1'b1;
    end

    if (NS[WAVEFORM_TST1]) begin
       // save the current 32-bit data word from the circular buffer
       latch_circ_buf_dat      <= #1 1'b1;
    end
    
    if (NS[WAVEFORM_TST2]) begin
       // save the current 32-bit data word from the circular buffer
       latch_circ_buf_dat      <= #1 1'b1;
         // signal the mux to continue to output the ADC data burst
       adc_mux_dat_sel         <= #1 1'b1;
    end

    if (NS[CHECKSUM1]) begin
        // signal the mux to output the checksum
        adc_mux_checksum_select <= 1'b1;
    end

    if (NS[CHECKSUM2]) begin
        // write the checksum to the FIFO
        immed_adc_acq_out_valid       <= 1'b1;
        // increment the next fill address
        address_cntr_en         <= 1'b1;
        // increment the fill counter
        fill_cntr_en            <= 1'b1;
    end

    if (NS[DDR3_WAIT]) begin
    end

    if (NS[DONE]) begin
        // signal the master that we are done
        acq_done  <= 1'b1;
    end

end

endmodule

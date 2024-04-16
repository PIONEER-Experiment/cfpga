`timescale 1ns / 1ps

///////////////////////////////////////////////////
// connect a state machine to coordinate everything

module adc_acq_sm (
    // inputs
    input clk,
    input acq_enable0,                  // indicates enabled for triggers, and fill type
    input acq_enable1,                  // indicates enabled for triggers, and fill type
    input acq_trig,                     // trigger the logic to start collecting data
    input reset_clk50,                  // reset from internal logic, synched to CLK50
    input adc_acq_full_reset,           // reset everything related to ADC acquisition and storage -- now just reset_clk50 synced to adc_clk
    input burst_cntr_zero,              // all sample bursts have been saved
    input waveform_gap_zero,            // the idle time has elapsed
    input last_waveform,                // all waveforms have been saved
    input ddr3_wr_done,                 // asserted when the 'ddr3_wr_control' is in the DONE state
    input dummy_dat_reset_mode,         // channel_tag[4] = 0 -> free-run,  1 -> reset every waveform
    // outputs
    output reg [1:0] fill_type,         // determine which burst count to use
    output reg fill_type_mux_en,
    output reg address_cntr_en,         // increment the next starting address
    output reg dummy_dat_reset,         // reset the dummy data counter
    output reg adc_mux_fill_hdr_sel,    // selects fill header
    output reg adc_mux_wfm_hdr_sel,     // selects waveform header
    output reg adc_mux_dat_sel,         // selects data
    output reg adc_mux_checksum_select, // selects checksum 
    output reg adc_mux_checksum_update, // update the checksum 
    output reg burst_cntr_init,         // initialize when triggered
    output reg burst_cntr_en,           // will be enabled once per burst
    output reg fill_cntr_en,            // will be enabled once per fill
    output reg waveform_cntr_init,      // initialize when triggered
    output reg waveform_cntr_en,        // will be enabled once after each waveform
    output reg waveform_gap_cntr_init,  // initialize after previous waveform stored
    output reg waveform_gap_cntr_en,    // enable after each initialization
    output reg adc_acq_out_valid,       // current data should be stored in the FIFO
    output reg acq_done,                // acquisition is done
    output reg sm_idle                  // signal that this state machine is idle (used for front panel LED status)
);


// synchronize ENABLE and TRIGGER inputs to this clock domain
reg acq_enable0_sync1, acq_enable0_sync2, acq_enable0_sync3, acq_enable0_sync4;
reg acq_enable1_sync1, acq_enable1_sync2, acq_enable1_sync3, acq_enable1_sync4;
reg acq_trig_sync1, acq_trig_sync2, acq_trig_sync3, acq_trig_sync4; 
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
end

// // sync and combine the external ACQ_RESET and the internal RESET_CLK50
// reg reset_clk50_sync1, reset_clk50_sync2;
// always @(posedge clk) begin
//     reset_clk50_sync1 <= reset_clk50;
//     reset_clk50_sync2 <= reset_clk50_sync1;
//     adc_acq_full_reset <= reset_clk50_sync2;
// end

// synchronize 'ddr3_wr_done'
(* ASYNC_REG = "TRUE" *) reg ddr3_wr_done_sync1, ddr3_wr_done_sync2;
always @ (posedge clk) begin
    ddr3_wr_done_sync1 <= ddr3_wr_done;
    ddr3_wr_done_sync2 <= ddr3_wr_done_sync1;
end

// We are in acquisition mode whenever the ENABLE inputs are not both zero.
// When they are both zero, we are in readout mode.
reg adc_acq_mode_enabled; // we are enabled to accept triggers and store data
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
     
//  Leave the comments containing "synopsys" in your HDL code.
 
// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [4:0]
    IDLE			= 5'd0,
    FILL_INIT1		= 5'd1,
    FILL_INIT2		= 5'd2,
    FILL_INIT3		= 5'd3,
    WAVEFORM_INIT1	= 5'd4,
    WAVEFORM_INIT2	= 5'd5,
    WAVEFORM_INIT3	= 5'd6,
    RUN1        	= 5'd7,
    RUN2        	= 5'd8,
    RUN3        	= 5'd9,
    RUN4        	= 5'd10,
    WAVEFORM_TST1	= 5'd11,
    WAVEFORM_TST2	= 5'd12,
    WAVEFORM_GAP1	= 5'd13,
    WAVEFORM_GAP2	= 5'd14,
    CHECKSUM1   	= 5'd15,
    CHECKSUM2   	= 5'd16,
    DDR3_WAIT   	= 5'd17,
    DONE        	= 5'd18;
    
// Declare current state and next state variables
reg [18:0] /* synopsys enum STATE_TYPE */ CS;
reg [18:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
    if (adc_acq_full_reset) begin
        CS <= 19'b0;      // set all state bits to 0
        CS[IDLE] <= 1'b1; // set IDLE state bit to 1
    end
    else begin
        CS <= NS;         // set state bits to next state
    end
end


// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or adc_acq_mode_enabled or acq_trig_sync4 or burst_cntr_zero or ddr3_wr_done_sync2 or last_waveform or waveform_gap_zero)    begin
    NS = 19'b0; // default all bits to zero; will overrride one bit

    case (1'b1) // synopsys full_case parallel_case

        // Stay in the IDLE state until we are both armed and triggered.
        CS[IDLE]: begin
            if (adc_acq_mode_enabled && acq_trig_sync4)
                NS[FILL_INIT1] = 1'b1;
            else
                NS[IDLE] = 1'b1;
        end

		// We use 3 states to initialize for a new fill.
		// This happens once per trigger
        // Stay in FILL_INIT1 state for one period. 
        CS[FILL_INIT1]: begin
                NS[FILL_INIT2] = 1'b1;
        end

        // Stay in FILL_INIT2 state for one period. 
        CS[FILL_INIT2]: begin
                NS[FILL_INIT3] = 1'b1;
        end

        // Stay in FILL_INIT3 state for one period. 
        CS[FILL_INIT3]: begin
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
        // Stay in WAVEFORM_TST1 state for one period. 
        CS[WAVEFORM_TST1]: begin
                NS[WAVEFORM_TST2] = 1'b1;
        end

        // Stay in WAVEFORM_TST2 state for one period.
        // If this was the last waveform, go do checksum stuff.
        // Otherwise, start a gap.
        CS[WAVEFORM_TST2]: begin
            if (last_waveform)
            	NS[CHECKSUM1] = 1'b1;
       		else
            	NS[WAVEFORM_GAP1] = 1'b1;
    	end
 
		// We use 2 states to initialize and test the gap counter
        // Stay in WAVEFORM_GAP1 state for one period. 
    	CS[WAVEFORM_GAP1]: begin
    	        NS[WAVEFORM_GAP2] = 1'b1;
    	end

    	// Stay in WAVEFORM_GAP2 state until the gap counter is down to zero.
    	// When it gets to zero, go initialize another waveform. 
    	CS[WAVEFORM_GAP2]: begin
    	    if (waveform_gap_zero)
    	    	NS[WAVEFORM_INIT1] = 1'b1;
       		else
    	    	NS[WAVEFORM_GAP2] = 1'b1;
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

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
    // defaults
        fill_type_mux_en        <= 1'b0;
        address_cntr_en         <= 1'b0;
        dummy_dat_reset         <= 1'b0;
        adc_mux_fill_hdr_sel    <= 1'b0;
        adc_mux_wfm_hdr_sel     <= 1'b0;
        adc_mux_dat_sel         <= 1'b0;
        adc_mux_checksum_select <= 1'b0;
        adc_mux_checksum_update	<= 1'b0;
        waveform_cntr_init      <= 1'b0;
        waveform_cntr_en        <= 1'b0;
        waveform_gap_cntr_init  <= 1'b0;
        waveform_gap_cntr_en    <= 1'b0;
        burst_cntr_init         <= 1'b0;
        burst_cntr_en           <= 1'b0;
        fill_cntr_en            <= 1'b0;
        adc_acq_out_valid       <= 1'b0;
        acq_done                <= 1'b0;
        sm_idle                 <= 1'b0;

    // next states
    if (NS[IDLE]) begin
        sm_idle                 <= 1'b1;
    end
    
    if (NS[FILL_INIT1]) begin
       // latch the current fill type size 
        fill_type_mux_en        <= 1'b1;
    end

    if (NS[FILL_INIT2]) begin
       // initialize the waveform counter with the number of waveforms
        waveform_cntr_init         <= 1'b1;
        // signal the mux to output the fill header info
        adc_mux_fill_hdr_sel         <= 1'b1;
    end

    if (NS[FILL_INIT3]) begin
       // write the fill header to the FIFO
       adc_acq_out_valid        <= 1'b1;
        // increment the next fill address
       address_cntr_en          <= 1'b1;
        // at the start of a fill, unconditionally reset the counter that provides dummy data
	    dummy_dat_reset         <= 1'b1;
    end

    if (NS[WAVEFORM_INIT1]) begin
        // at the start of a waveform, conditionally reset the counter that provides dummy data
        // 0 -> free-run,  1 -> reset every waveform
	    dummy_dat_reset         <= dummy_dat_reset_mode;
    end

    if (NS[WAVEFORM_INIT2]) begin
		// initialize the burst counter with the current fill size
		burst_cntr_init         <= 1'b1;
        // signal the mux to output the waveform header info
		adc_mux_wfm_hdr_sel         <= 1'b1;
    end

    if (NS[WAVEFORM_INIT3]) begin
		// write the waveform header to the FIFO
		adc_acq_out_valid        <= 1'b1;
		// increment the next fill address
		address_cntr_en          <= 1'b1;
    end

    if (NS[RUN1]) begin
        // decrement the burst counter
        burst_cntr_en           <= 1'b1;
     end

    if (NS[RUN2]) begin
    end

    if (NS[RUN3]) begin
    	// signal the mux to output the ADC burst
        adc_mux_dat_sel         <= 1'b1;
        // update the checksum
        adc_mux_checksum_update	<= 1'b1;
    end

    if (NS[RUN4]) begin
        // write the ADC burst to the FIFO
        adc_acq_out_valid       <= 1'b1;
		// increment the next fill address
        address_cntr_en          <= 1'b1;
    end

    if (NS[WAVEFORM_TST1]) begin
    	// decrement the waveform counter
    	waveform_cntr_en <= 1'b1;
    end

    if (NS[WAVEFORM_TST2]) begin
    	// initialize the waveform gap counter
    	waveform_gap_cntr_init <= 1'b1;
    end

    if (NS[WAVEFORM_GAP1]) begin
    end

    if (NS[WAVEFORM_GAP2]) begin
    	// decrement the waveform gap counter
	    waveform_gap_cntr_en <= 1'b1;
    end

    if (NS[CHECKSUM1]) begin
        // signal the mux to output the checksum
        adc_mux_checksum_select <= 1'b1;
    end

    if (NS[CHECKSUM2]) begin
        // write the checksum to the FIFO
        adc_acq_out_valid       <= 1'b1;
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

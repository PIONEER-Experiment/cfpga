`timescale 1ns / 10ps

module circ_buf_to_ddr3_sm_selftrig (
    // inputs
	input adc_clk,
    input reset_clk_adc,				// synchronously negated reset all of the acquisition logic  
	input cbuf_rd_en,					// moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
(* mark_debug = "true" *) input cbuf_trig_en,					// triggering of new waveforms is enabled
(* mark_debug = "true" *)     input trig_fifo_empty,				// if not empty then process a waveform
    input burst_cntr_zero,              // all sample bursts have been saved
    // outputs
	output reg cbuf_rd_trig_wait,		// waiting for another trigger or the negation of 'cbuf_rd_en'	
	output reg burst_adr_cntr_init,		// initialize counter to '1'
	output reg init_circ_buf_rd_addr,	// initialize the counter with the start of the buffer area to be saved
	output reg inc_circ_buf_rd_addr,	// increment the circular buffer address
	output reg latch_circ_buf_dat,		// save the current 32-bit data word from the circular buffer
	output reg select_fill_hdr,			// selects fill header from the MUX
	output reg select_dat,				// selects data from the MUX
	output reg select_waveform_hdr,		// selects waveform header
	output reg select_checksum,			// selects checksum, send the checksum to the FIFO 
	output reg checksum_update,			// update the checksum
	output reg checksum_init,			// initialize the checksum
	output reg adc_acq_out_valid,  		// current output from the MUX should be stored in the FIFO
	output reg burst_adr_cntr_en,		// increment the next starting address
	output reg save_start_adr,			// latch the first DDR3 address for a waveform
	output reg save_last_adr,			// latch the last DDR3 address for a fill, it it the total count
	output reg trig_addr_rd_en,			// read a trigger address from the FIFO
	output reg burst_cntr_init,			// initialize when triggered
	output reg burst_cntr_en,			// will be enabled once per burst
	output reg waveform_cntr_init,      // initialize when triggered
	output reg waveform_cntr_en,        // will be enabled once after each waveform
	output reg fill_cntr_en			    // will be enabled once per fill
);      


// Leave the comments containing "synopsys" in your HDL code.

// delay the 'adc_acq_out_valid' signal to allow for the memory reading delay
reg immed_adc_acq_out_valid, dlyd_adc_acq_out_valid, start_dlyd_adc_acq_out_valid;
reg delay2, delay1, delay0;
always @ (posedge adc_clk) begin
	adc_acq_out_valid <= #1 immed_adc_acq_out_valid | dlyd_adc_acq_out_valid;
	checksum_update <= #1 delay2;
	// run the delay pipeline
	dlyd_adc_acq_out_valid <= #1 delay2;
	delay2 <= #1 delay1;
	delay1 <= #1 delay0;
	delay0 <= #1 start_dlyd_adc_acq_out_valid;
end

// create a flag to indicate whether or not a trigger was seen
reg got_trig;

// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [4:0]
    IDLE            = 5'd0,   // 00001
    FILL_INIT1      = 5'd1,   // 00002
    TRIG_WAIT       = 5'd2,   // 00004
    WAVEFORM_INIT1  = 5'd3,   // 00008
    WAVEFORM_INIT2  = 5'd4,   // 00010
    WAVEFORM_INIT3  = 5'd5,   // 00020
    LOOP1           = 5'd6,   // 00040
    LOOP2           = 5'd7,   // 00080
    LOOP3           = 5'd8,   // 00100
    LOOP4           = 5'd9,   // 00200
    WAVEFORM_DONE1  = 5'd10,  // 00400
    WAVEFORM_DONE2  = 5'd11,  // 00800
    NO_TRIGGER      = 5'd12,  // 01000
    FILL_DONE1      = 5'd13,  // 02000
    FILL_DONE2      = 5'd14,  // 04000
    FILL_DONE3      = 5'd15,  // 08000
    FILL_DONE4      = 5'd16,  // 10000
    DONE            = 5'd17;  // 20000
    
// Declare current state and next state variables
(* mark_debug = "true" *) reg [17:0] /* synopsys enum STATE_TYPE */ CS;
reg [17:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge adc_clk) begin
    if (reset_clk_adc) begin
        CS <= #1 {18{1'b0}}; // set all state bits to 0
        CS[IDLE] <= #1 1'b1; // set IDLE state bit to 1
    end
    else
        CS <= #1 NS;         // set state bits to next state
end

// combinational always block to determine next state (use blocking [=] assignments) 
always @ (CS or cbuf_rd_en or cbuf_trig_en or trig_fifo_empty or got_trig or burst_cntr_zero) begin
    NS = {18{1'b0}}; // default all bits to zero; will overrride one bit

    case (1'b1) // synopsys full_case parallel_case

        // Stay in the IDLE state whenever we are not enabled.
        CS[IDLE]: begin
            if (cbuf_rd_en)
            	// we have transitioned to 'enabled', so initialize a new fill
                NS[FILL_INIT1] = 1'b1;
            else
                NS[IDLE] = 1'b1;
       end

		// We use 1 state to initialize for a new fill.
		// This happens once per 'trig_enabled' transition
        // Stay in FILL_INIT1 state for one period. 
        CS[FILL_INIT1]: begin
                NS[TRIG_WAIT] = 1'b1;
        end

       // Stay in TRIG_WAIT until either we have been triggered (the trigger FIFO is not empty),
       // or the fill has ended (enabled negated). 
        CS[TRIG_WAIT]: begin
       		if (!trig_fifo_empty)
        		// a trigger has occurred, so go process it.
        		// This branch has top priority, so that we always process all accepted triggers.
                NS[WAVEFORM_INIT1] = 1'b1;
	        else if (!cbuf_trig_en && got_trig)
                // the fill is over, and we had at least 1 trigger, so go handle the fill header and checksum
                NS[FILL_DONE1] = 1'b1;
	        else if (!cbuf_trig_en && !got_trig)
                // the fill is over, but there were no triggers, so go clean up and end
                NS[NO_TRIGGER] = 1'b1;
       		else
				// wait here
            	NS[TRIG_WAIT] = 1'b1;
        end

		// We use 3 states to initialize for each new waveform.
		// This happens once per waveform (trigger)
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
                NS[LOOP1] = 1'b1;
        end

		// We use 4 states to collect and forward bursts of ADC data.
		// Two 12-bit ADC samples, packed in a 32-bit word, are collected from the circular
		// buffer during each LOOP state.
		// At the end, the 128-bit data is forwarded and the checksum is updated.
        // Stay in LOOP1 state for one period.
        CS[LOOP1]: begin
                NS[LOOP2] = 1'b1;
        end

        // Stay in LOOP2 state for one period.
        CS[LOOP2]: begin
                NS[LOOP3] = 1'b1;
        end

        // Stay in LOOP3 state for one period.
        CS[LOOP3]: begin
                NS[LOOP4] = 1'b1;
        end

        // Stay in LOOP4 state for one period.
        // If we have collected all of the bursts, we are done.
        // Otherwise, loop back and get more ADC data.
        CS[LOOP4]: begin
            if (burst_cntr_zero)
                NS[WAVEFORM_DONE1] = 1'b1;
            else
                NS[LOOP1] = 1'b1;
        end

		// We use 2 states to update and test the waveform counter
        // Stay in WAVEFORM_TST1 state for one period. 
        CS[WAVEFORM_DONE1]: begin
                NS[WAVEFORM_DONE2] = 1'b1;
        end

        // Stay in WAVEFORM_DONE2 state for one period.
        // Then go wait for another trigger or for the end of the fill
         CS[WAVEFORM_DONE2]: begin
             	NS[TRIG_WAIT] = 1'b1;
    	end
 
        // Stay in NO_TRIGGER state for one period.
    	// Then go end the fill. This state is needed in order to cleanly end a fill that
    	// never received a trigger.
    	CS[NO_TRIGGER]: begin
    	     	NS[FILL_DONE1] = 1'b1;
    	end

		// The fill is over. We need to build the 'fill header' and then use its value
		// to update the checksum. Then we write the checksum, and finally write the fill header.
         // Stay in FILL_DONE1 state for one period.
        CS[FILL_DONE1]: begin
                NS[FILL_DONE2] = 1'b1;
        end

         // Stay in FILL_DONE2 state for one period.
        CS[FILL_DONE2]: begin
                NS[FILL_DONE3] = 1'b1;
        end

         // Stay in FILL_DONE3 state for one period.
        CS[FILL_DONE3]: begin
                NS[FILL_DONE4] = 1'b1;
        end

         // Stay in FILL_DONE4 state for one period.
        CS[FILL_DONE4]: begin
                NS[DONE] = 1'b1;
        end

        // Stay in the DONE state for one period
       CS[DONE]: begin
               NS[IDLE] = 1'b1;
        end

    endcase
end // combinational always block to determine next state

// handle the "got_trig" flag
always @(posedge adc_clk) begin
	if (NS[FILL_INIT1])
		// clear the flag at the start of a fill
		got_trig <= 1'b0;
	else if (NS[WAVEFORM_INIT1])
		// set the flag when a trigger is received and a waveform has started
		got_trig <= 1'b1;
	else
		// hold the current value for all other cases
		got_trig <= got_trig;
end

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge adc_clk) begin
    // defaults
		cbuf_rd_trig_wait		<= #1 1'b0;	// waiting for another trigger or the negation of 'cbuf_rd_en'
		burst_adr_cntr_init		<= #1 1'b0;	// initialize counter to '1'
     	init_circ_buf_rd_addr   <= #1 1'b0;	// initialize the counter with the start of the buffer area to be saved
    	select_fill_hdr        	<= #1 1'b0;	// selects fill header from the MUX
	   	select_waveform_hdr     <= #1 1'b0;	// selects waveform header
    	select_dat        		<= #1 1'b0;	// selects data from the MUX
    	select_checksum        	<= #1 1'b0;	// selects checksum, send the checksum to the FIFO 
    	immed_adc_acq_out_valid	<= #1 1'b0;	// current output from the MUX should be stored in the FIFO
    	start_dlyd_adc_acq_out_valid <= #1 1'b0; // prepare for current output from the MUX should be stored in the FIFO
   		// checksum_update      <= #1 1'b0;	// update the checksum 
		checksum_init        	<= #1 1'b0;	// initialize the checksum
    	save_start_adr        	<= #1 1'b0;	// latch the first DDR3 address for a waveform
		save_last_adr        	<= #1 1'b0;	// latch the last DDR3 address for a fill, it it the total count
    	trig_addr_rd_en        	<= #1 1'b0;	// read a trigger address from the FIFO
    	burst_cntr_init        	<= #1 1'b0;	// initialize when triggered
    	burst_cntr_en        	<= #1 1'b0;	// will be enabled once per burst
    	waveform_cntr_init      <= #1 1'b0; // initialize when a fill starts
    	waveform_cntr_en        <= #1 1'b0; // will be enabled once after each waveform
     	inc_circ_buf_rd_addr    <= #1 1'b0;	// increment the circular buffer address
    	latch_circ_buf_dat      <= #1 1'b0;	// save the current 32-bit data word from the circular buffer
    	burst_adr_cntr_en 		<= #1 1'b0;	// increment the next starting address
    	fill_cntr_en        	<= #1 1'b0;	// will be enabled once per fill

    // next states
    if (NS[IDLE]) begin
    end
    
    if (NS[FILL_INIT1]) begin
    	// initialize the burst address counter to '0x0001', which
    	// is where the first waveform starts.
		burst_adr_cntr_init		<= #1 1'b1;
		// initialize the checksum
		checksum_init        	<= #1 1'b1;
		// initialize the waveform (trigger) counter when a fill starts
    	waveform_cntr_init      <= #1 1'b1;
    end

    if (NS[TRIG_WAIT]) begin
		cbuf_rd_trig_wait		<= #1 1'b1;	// waiting for another trigger or the negation of 'cbuf_rd_en'
     end

    if (NS[WAVEFORM_INIT1]) begin
    	// initialize the counter with the start address of the circular buffer area to be saved
     	init_circ_buf_rd_addr   <= #1 1'b1;
     	// latch the first DDR3 address for a waveform
    	save_start_adr        	<= #1 1'b1;
    	// pull the trigger address out of the FIFO; the FIFI is in FWFT mode
    	trig_addr_rd_en        	<= #1 1'b1;
    	// initialize the burst counter when triggered
    	burst_cntr_init        	<= #1 1'b1;
        // increment the waveform (trigger) number at the start of each waveform
    	waveform_cntr_en        <= #1 1'b1;
    end

    if (NS[WAVEFORM_INIT2]) begin
        // signal the mux to output the waveform header info
	   	select_waveform_hdr     <= #1 1'b1;
    end

    if (NS[WAVEFORM_INIT3]) begin
		// write the waveform header to the FIFO
		immed_adc_acq_out_valid        <= #1 1'b1;
		// increment the next burst address
    	burst_adr_cntr_en   	<= #1 1'b1;
    	// increment the circular buffer address
	   	inc_circ_buf_rd_addr    <= #1 1'b1;
   end

    if (NS[LOOP1]) begin
    	// save the current 32-bit data word from the circular buffer
    	latch_circ_buf_dat      <= #1 1'b1;
    	// increment the circular buffer address
	   	inc_circ_buf_rd_addr    <= #1 1'b1;
	   	// signal the mux to output the ADC data burst
    	select_dat        		<= #1 1'b1;
    	// decrement the burst counter
    	burst_cntr_en        	<= #1 1'b1;
     end

    if (NS[LOOP2]) begin
    	// save the current 32-bit data word from the circular buffer
	    latch_circ_buf_dat      <= #1 1'b1;
    	// increment the circular buffer address
	   	inc_circ_buf_rd_addr    <= #1 1'b1;
	   	// signal the mux to output the ADC data burst
    	select_dat        		<= #1 1'b1;
    end

    if (NS[LOOP3]) begin
    	// save the current 32-bit data word from the circular buffer
    	latch_circ_buf_dat      <= #1 1'b1;
    	// increment the circular buffer address
	   	inc_circ_buf_rd_addr    <= #1 1'b1;
	   	// signal the mux to output the ADC data burst
    	select_dat        		<= #1 1'b1;
    	// update the checksum
    	// checksum_update      <= #1 1'b1; 
    end

    if (NS[LOOP4]) begin
    	// save the current 32-bit data word from the circular buffer
    	latch_circ_buf_dat      <= #1 1'b1;
    	// increment the circular buffer address
	   	inc_circ_buf_rd_addr    <= #1 1'b1;
	   	// signal the mux to output the ADC data burst
    	select_dat        		<= #1 1'b1;
        // prepare to write the ADC burst to the FIFO
        start_dlyd_adc_acq_out_valid       <= #1 1'b1;
		// increment the next burst address
    	burst_adr_cntr_en   	<= #1 1'b1;
    end

    if (NS[WAVEFORM_DONE1]) begin
    	// save the current 32-bit data word from the circular buffer
    	latch_circ_buf_dat      <= #1 1'b1;
    	// latch the last DDR3 address,  for a fill it may be the total count
		save_last_adr        	<= #1 1'b1;
	   	// signal the mux to continue to output the ADC data burst
    	select_dat        		<= #1 1'b1;
    end

    if (NS[WAVEFORM_DONE2]) begin
    	// save the current 32-bit data word from the circular buffer
    	latch_circ_buf_dat      <= #1 1'b1;
	   	// signal the mux to continue to output the ADC data burst
    	select_dat        		<= #1 1'b1;
   end

    if (NS[NO_TRIGGER]) begin
    	// latch the last DDR3 address,  for a fill it may be the total count
		save_last_adr        	<= #1 1'b1;
    end

    if (NS[FILL_DONE1]) begin
        // signal the mux to use the fill header in the checksum calculation
    	select_fill_hdr         <= #1 1'b1;
    end

    if (NS[FILL_DONE2]) begin
        // signal the mux to output the checksum
    	select_checksum         <= #1 1'b1;
        // write the checksum to the FIFO
    	immed_adc_acq_out_valid		<= #1 1'b1;
		// increment the next burst address
    	burst_adr_cntr_en   	<= #1 1'b1;
    end

    if (NS[FILL_DONE3]) begin
        // signal the mux to output the fill header info
        select_fill_hdr         	<= #1 1'b1;
       // write the fill header to the FIFO
        immed_adc_acq_out_valid        <= #1 1'b1;
    end

    if (NS[FILL_DONE4]) begin
    end

    if (NS[DONE]) begin
    	// increment the fill counter at the end of a fill 
    	fill_cntr_en        	<= #1 1'b1;
    end

end

endmodule

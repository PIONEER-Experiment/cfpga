`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a state machine to coordinate everything

module adc_acq_sm (
    // inputs
    input clk,
    input acq_enable0,           	 // indicates enabled for triggers, and fill type
    input acq_enable1,           	 // indicates enabled for triggers, and fill type
    input acq_trig,              	 // trigger the logic to start collecting data
    input acq_reset,            	 // reset from the Master FPGA
    input reset_clk50,				 // reset from internal logic, synched to CLK50
    input burst_cntr_zero,      	 // all sample bursts have been saved
    // outputs
    output reg [1:0] fill_type,		// determine which burst count to use
    output reg fill_size_mux_en,
    output reg address_cntr_en,  	// increment the next starting address
 	output reg dummy_dat_reset,		// reset the dummy data counter
    output reg adc_mux_dat_sel,   	// '0' selects header, '1' selects data
	output reg adc_mux_checksum_select,	// '0' selects data, '1' selects checksum, send the checksum to the FIFO 
    output reg burst_cntr_init,  	// initialize when triggered
    output reg burst_cntr_en,   	// will be enabled once per burst
    output reg fill_cntr_en,      	// will be enabled once per fill
    output reg adc_acq_out_valid, 	// current data should be stored in the FIFO
	output reg adc_acq_full_reset,	// reset everything related to ADC acquisition and storage
	output reg acq_done           	// acquisition is done
);      


// synchronize ENABLE and TRIGGER inputs to this clock domain
reg acq_enable0_sync1, acq_enable0_sync2, acq_enable1_sync1, acq_enable1_sync2, acq_trig_sync1, acq_trig_sync2; 
always @(posedge clk) begin
    acq_enable0_sync1 <= acq_enable0;
    acq_enable0_sync2 <= acq_enable0_sync1;
    acq_enable1_sync1 <= acq_enable1;
    acq_enable1_sync2 <= acq_enable1_sync1;
    acq_trig_sync1 <= acq_trig;
    acq_trig_sync2 <= acq_trig_sync1;
end

// sync and combine the external ACQ_RESET and the internal RESET_CLK50
reg acq_reset_sync1, acq_reset_sync2, reset_clk50_sync1, reset_clk50_sync2; 
always @(posedge clk) begin
    acq_reset_sync1 <= acq_reset;
    acq_reset_sync2 <= acq_reset_sync1;
    reset_clk50_sync1 <= reset_clk50;
    reset_clk50_sync2 <= reset_clk50_sync1;
    adc_acq_full_reset <= acq_reset_sync2 | reset_clk50_sync2;
end

// We are in acquisition mode whenever the ENABLE inputs are not both zero.
// When they are both zero, we are in readout mode.
reg adc_acq_mode_enabled;	// we are enabled to accept triggers and store data
always @(posedge clk) begin
	if ( acq_enable0_sync2 |  acq_enable1_sync2)
		adc_acq_mode_enabled <= 1'b1;
	else
		adc_acq_mode_enabled <= 1'b0;
end

// The fill type is determined by combining the ENABLE inputs
always @(posedge clk) begin
	fill_type[1:0] <= {acq_enable1_sync2, acq_enable0_sync2};
end
	 
//  Leave the comments containing "synopsys" in your HDL code.
 
// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [3:0]
	IDLE		= 4'd0,
	INIT1		= 4'd1,
	INIT2		= 4'd2,
	INIT3		= 4'd3,
	RUN1		= 4'd4,
	RUN2		= 4'd5,
	RUN3		= 4'd6,
	RUN4		= 4'd7,
	CHECKSUM1	= 4'd8,
	CHECKSUM2	= 4'd9,
	DONE		= 4'd10;
	
// Declare current state and next state variables
reg [10:0] /* synopsys enum STATE_TYPE */ CS;
reg [10:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
	if (adc_acq_full_reset) begin
		CS <= 11'b0;				// set all state bits to 0
		CS[IDLE] <= 1'b1;		// set IDLE state bit to 1
	end
	else
		CS <= NS;			// set state bits to next state
end

// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or adc_acq_mode_enabled or acq_trig_sync2 or burst_cntr_zero) 	begin
	NS = 11'b0;					// default all bits to zero; will overrride one bit

	case (1'b1) //synopsys full_case parallel_case

		// Stay in the IDLE state until we are both armed and triggered.
		CS[IDLE]: begin
			if (adc_acq_mode_enabled && acq_trig_sync2)
					NS[INIT1] = 1'b1;
			else
					NS[IDLE] = 1'b1;
		end

		// Stay in INIT1 state for one period. 
		CS[INIT1]: begin
				NS[INIT2] = 1'b1;
		end

		// Stay in INIT2 state for one period. 
		CS[INIT2]: begin
				NS[INIT3] = 1'b1;
		end

		// Stay in INIT3 state for one period. 
		CS[INIT3]: begin
				NS[RUN1] = 1'b1;
		end

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
		CS[RUN4]: begin
			if (burst_cntr_zero)
                NS[CHECKSUM1] = 1'b1;
            else
				NS[RUN1] = 1'b1;
		end

		// Stay in CHECKSUM1 state for one period.
		CS[CHECKSUM1]: begin
				NS[CHECKSUM2] = 1'b1;
		end

		// Stay in CHECKSUM2 state for one period.
		CS[CHECKSUM2]: begin
				NS[DONE] = 1'b1;
		end

		// Stay in DONE state until the trigger is negated.
		CS[DONE]: begin
			if (adc_acq_mode_enabled && acq_trig_sync2)
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
		fill_size_mux_en		<= 1'b0;
		address_cntr_en			<= 1'b0;
		dummy_dat_reset			<= 1'b0;
		adc_mux_dat_sel			<= 1'b1;
		burst_cntr_init			<= 1'b0;
		burst_cntr_en			<= 1'b0;
        fill_cntr_en			<= 1'b0;
        adc_acq_out_valid		<= 1'b0;
		adc_mux_checksum_select	<= 1'b0;
        acq_done				<= 1'b0;

	// next states
	if (NS[IDLE]) begin
		// reset the counter that provides dummy data
		dummy_dat_reset			<= 1'b1;
	end
	
	if (NS[INIT1]) begin
	   // latch the current fill type size 
		fill_size_mux_en	<= 1'b1;
	end

	if (NS[INIT2]) begin
	   // initialize the burst counter with the current fill size
		burst_cntr_init	<= 1'b1;
		// signal the mux to output the header info
		adc_mux_dat_sel     <= 1'b0;
	end
 
	if (NS[INIT3]) begin
	   // write the header to the FIFO
       adc_acq_out_valid    <= 1'b1;
		// increment the next fill address
       address_cntr_en		<= 1'b1;
    end

 	if (NS[RUN1]) begin
 	    // decrement the burst counter
		burst_cntr_en	<= 1'b1;
		// increment the next fill address
		address_cntr_en		<= 1'b1;
	end

	if (NS[RUN2]) begin
	end

	if (NS[RUN3]) begin
	end

	if (NS[RUN4]) begin
	    // write the burst to the FIFO
		adc_acq_out_valid		<= 1'b1;
	end

	if (NS[CHECKSUM1]) begin
		// send the checksum
		adc_mux_checksum_select	<= 1'b1;
 	end

	if (NS[CHECKSUM2]) begin
	    // write the checksum burst to the FIFO
		adc_acq_out_valid		<= 1'b1;
		// increment the next fill address
		address_cntr_en		<= 1'b1;
	    // increment the fill counter
		fill_cntr_en		<= 1'b1;
	end

    if (NS[DONE]) begin
		// signal the master that we are done
		acq_done  <= 1'b1;
	end
	
end

endmodule

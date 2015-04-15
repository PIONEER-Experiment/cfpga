`timescale 1ns / 1ps
// Acquisition controller for ADC data

module adc_acq_top(
    // inputs
    input [11:0] adc_in_p,          // [11:0] array of ADC 'p' data pins
    input [11:0] adc_in_n,          // [11:0] array of ADC 'n' data pins
    input adc_ovr_p,                // ADC 'p' over-range pin
    input adc_ovr_n,                // ADC 'n' over-range pin
    input adc_clk_p,                // ADC 'p' clk pin
    input adc_clk_n,                // ADC 'n' clk pin
    input reset_clk50,              // synchronously negated  
    input clk200,                   // for input pin timing delay settings
    input [15:0] channel_tag,		// stuff about the channel to put in the header
    input [20:0] num_muon_bursts,	// number of sample bursts in a MUON fill
    input [20:0] num_laser_bursts,	// number of sample bursts in a LASER fill
    input [20:0] num_ped_bursts,	// number of sample bursts in a OPEDESTAL fill
    input [23:0] initial_fill_num,  // event number to assign to the first fill
    input initial_fill_num_wr,      // write-strobe to store the initial_fill_num
    input acq_enable0,              // indicates enabled for triggers, and fill type
    input acq_enable1,              // indicates enabled for triggers, and fill type
    input acq_trig,                 // trigger the logic to start collecting data
    input acq_reset,                // reset all of the acquisition logic
 	input adc_buf_delay_data_reset,	// use the new delay settings
	input [4:0] adc_buf_data_delay,	// 5 delay-tap-bits per line, all lines always all the same
	input ddr3_wr_busy,				// asserted whenever the 'ddr3_wr_control' is not idle
    // outputs
	output acq_enabled,				// the system is in acquisition mode, rather than readout mode
	output [64:0] adc_buf_current_data_delay, // 13 lines *5 bits/line, current tap settings
	output [23:0] fill_num,         // fill number for this fill
    output [127:0] adc_acq_out_dat, // 128-bit header or ADC data
    output adc_acq_out_valid,       // current data should be stored in the FIFO
    output adc_clk,          		// ADC clock used by the FIFO
	output adc_acq_full_reset,		// reset all aspects of data collection/storage/readout
    output acq_done                 // acquisition is done
);

wire [1:0] fill_type;          // to determine how much data to collect
wire [25:0] packed_adc_dat;    // two samples, with over-range bits,  packed in one wide-word
                                // bit[0]       = first overrange
                                // bits[11:1]   = first ADC sample
                                // bit[12]      = second overrange
                                // bits[25:13]  = second ADC sample
wire [20:0] num_fill_bursts;    // number of 8(or 10)-sample bursts in a fill
wire [22:0] burst_start_adr;    // first DDR3 burst memory location for this fill (3 LSBs = 0)

///////////////////////////////////////////////////////////////////////////////////////////////////
// Tell the DDR3 block when either 'acq_enable0' or 'acq_enable1' is not zero.
// This will switch the mode to 'write'
assign acq_enabled = acq_enable0 | acq_enable1;
                                 
///////////////////////////////////////////////////////////////////////////////////////////////////
// Connect a DDR input block that will produce an output twice-as-wide and a rising edge clock
// A good note on DDR timing
// http://forums.xilinx.com/t5/Timing-Analysis/XDC-constraints-Source-Synchronous-ADC-DDR/td-p/292807
// Use a SelectIO Wizard DDR input buffer
selectio_wiz_0 adc_dat_buf (
	.data_in_from_pins_p({adc_in_p[11:0],adc_ovr_p}),	// [12:0] array of ADC 'p' data pins and over-range
	.data_in_from_pins_n({adc_in_n[11:0],adc_ovr_n}),	// [12:0] array of ADC 'n' data pins and over-range
	.clk_in_p(adc_clk_p),								// ADC 'p' clk pin
	.clk_in_n(adc_clk_n),								// ADC 'n' clk pin
	.io_reset(adc_acq_full_reset),						// synchronously negated 
	.in_delay_reset(adc_buf_delay_data_reset),			// input wire in_delay_reset
	.in_delay_tap_in({13{adc_buf_data_delay[4:0]}}),	// 13 input lines, 5 delay-tap-bits per line, always all the same
	.in_delay_tap_out(adc_buf_current_data_delay[64:0]),// 13 lines *5 bits/line, current tap settings 
	.in_delay_data_ce({13{1'b0}}),						// 'ce' is unused
	.in_delay_data_inc({13{1'b0}}),						// 'inc' is unused
	.delay_clk(clk200),
	.ref_clock(clk200),									// 200 MHz clock required to ensure tap value settings
	.clk_out(adc_clk),									// normal rising-edge clock
	.data_in_to_device(packed_adc_dat),					// twice-as-wide SDR data
	.delay_locked()										// not used

);

///////////////////////////////////////////////////////////////////////////////////////////////////
// create a counter that can provide dummy data for checking system integrity
reg [11:0] dummy_dat;
always @(posedge adc_clk) begin
	if (dummy_dat_reset)
		// clear to zero soon after trigger. The initial count seen in the data
		// stream may be different than zero, but will uniformly increase.
		dummy_dat[11:0] <= 12'b0;
	else
		// increment on every adc_clk
		dummy_dat[11:0] <= dummy_dat[11:0] + 1;
end
		
///////////////////////////////////////////////////////////////////////////////////////////////////
// connect a pipeline of resisters to hold all data for 1 burst.
// register #0 will have the oldest data
// register #4 will have the newest data, and provide a mux for injecting dummy data
// register #4 will only be stored if 10-sample bursts are being used.
reg [25:0] adc_dat_reg4_, adc_dat_reg3_, adc_dat_reg2_, adc_dat_reg1_, adc_dat_reg0_;
always @(posedge adc_clk) begin
	// channel_tag[3] = 0 -> use real data : =  1 -> use dummy data
    if (channel_tag[3]) begin
		// use dummy data
     	adc_dat_reg4_[0]		<= 1'b0;				// over-range bit
    	adc_dat_reg4_[12:1]		<= dummy_dat[11:0];		// normal counter
    	adc_dat_reg4_[13]		<= 1'b0;				// over-range bit
  		adc_dat_reg4_[25:14]	<= ~dummy_dat[11:0];	// inverted counter
     end
    else begin
    	// use real data
    	adc_dat_reg4_[25:0] <=  packed_adc_dat[25:0];
    end
    adc_dat_reg3_[25:0] <=  adc_dat_reg4_[25:0];
    adc_dat_reg2_[25:0] <=  adc_dat_reg3_[25:0];
    adc_dat_reg1_[25:0] <=  adc_dat_reg2_[25:0];
    adc_dat_reg0_[25:0] <=  adc_dat_reg1_[25:0];
end

///////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will provide the fill size as sepecified by the fill type.
// the output will be the number of 8(or 10) sample bursts
adc_fill_size_mux adc_fill_size_mux (
    // inputs
    .fill_type(fill_type[1:0]),                 // to determine how much data to collect
    .num_muon_bursts(num_muon_bursts[20:0]),    // number of sample bursts in a MUON fill
    .num_laser_bursts(num_laser_bursts[20:0]),  // number of sample bursts in a LASER fill
    .num_ped_bursts(num_ped_bursts[20:0]),      // number of sample bursts in a PEDESTAL fill
    .clk(adc_clk),
    .enable(fill_size_mux_en),
    // outputs
    .num_fill_bursts(num_fill_bursts[20:0])     // number of 8(or 10) sample bursts
);

/////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will supply either header info or ADC data to the DDR3 write FIFO
// All bit ordering is done in this mux
adc_dat_mux adc_dat_mux (
    // inputs
    .dat4_(adc_dat_reg4_[25:0]),                // a pair of ADC samples and a pair of over-range bits
    .dat3_(adc_dat_reg3_[25:0]),                // a pair of ADC samples and a pair of over-range bits
    .dat2_(adc_dat_reg2_[25:0]),                // a pair of ADC samples and a pair of over-range bits
    .dat1_(adc_dat_reg1_[25:0]),                // a pair of ADC samples and a pair of over-range bits
    .dat0_(adc_dat_reg0_[25:0]),                // a pair of ADC samples and a pair of over-range bits
    .channel_tag(channel_tag[15:0]),			// stuff about the channel to put in the header
    .fill_type(fill_type[1:0]),                 // determine which burst count to use
    .num_fill_bursts(num_fill_bursts[20:0]),    // number of 8(or 10) sample bursts
    .burst_start_adr(burst_start_adr[22:0]),    // first DDR3 burst memory location (3 LSBs=0) for this fill
    .fill_num(fill_num[23:0]),                  // fill number for this fill
    .clk(adc_clk),
    .select_dat(adc_mux_dat_sel),               // '0' selects header, '1' selects data
	.select_checksum(adc_mux_checksum_select),	// '0' selects data, '1' selects checksum, send the checksum to the FIFO 
    // outputs
    .adc_acq_out_dat(adc_acq_out_dat[127:0])     // 128-bit header or ADC data   
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter that will calculate the DDR3 starting address of the next fill
// It will be initialized when the fill number is written.
// It will increment every time data is written to the FIFO
adc_address_cntr adc_address_cntr (
    // inputs
    .clk(adc_clk),
    .init(initial_fill_num_wr),                  // initialize to zero when the fill number is written
    .enable(address_cntr_en),	                 // increment
    // outputs
    .burst_start_adr(burst_start_adr[22:0])      // first DDR3 burst memory location for this fill
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a down-counter that will keep track of how many bursts have been saved
// It will be initialized when a trigger occurs.
// It will be enabled when each burst is sent out.
adc_burst_cntr adc_burst_cntr (
    // inputs
    .num_fill_bursts(num_fill_bursts[20:0]),    // number of 8(or 10) sample bursts
    .clk(adc_clk),
    .init(burst_cntr_init),                     // initialize when triggered
    .enable(burst_cntr_en),                     // will be enabled once per burst
    // outputs
    .at_zero(burst_cntr_zero)                   // all sample bursts have been saved
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect an up-counter that will keep track of the fill number
// It will be initialized at the start of a run, or when necessary.
// It will be enabled when each fill is done
adc_fill_cntr adc_fill_cntr (
    // inputs
    .initial_fill_num(initial_fill_num[23:0]),  // always positive
    .clk(adc_clk),
    .init(initial_fill_num_wr),                  // initialize when programmed
    .enable(fill_cntr_en),                       // will be enabled once per fill
    // outputs
   .fill_num(fill_num[23:0])                     // fill number for this fill
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a state machine to coordinate everything
adc_acq_sm adc_acq_sm (
    // inputs
    .clk(adc_clk),
	.acq_enable0(acq_enable0),             // enable the logic to accept triggers
    .acq_enable1(acq_enable1),             // enable the logic to accept triggers
    .acq_trig(acq_trig),                   // trigger the logic to start collecting data
    .acq_reset(acq_reset),		           // reset from the Master FPGA
    .reset_clk50(reset_clk50),             // synchronously negated
    .burst_cntr_zero(burst_cntr_zero),     // all sample bursts have been saved
    .ddr3_wr_busy(ddr3_wr_busy),  			// asserted whenever the 'ddr3_wr_control' is not idle
    // outputs
    .fill_type(fill_type[1:0]),				// determine which burst count to use
    .fill_size_mux_en(fill_size_mux_en),	// enable choosing one of the burst counts
    .address_cntr_en(address_cntr_en),   	// increment the next starting address
	.dummy_dat_reset(dummy_dat_reset),		// reset the dummy data counter
    .adc_mux_dat_sel(adc_mux_dat_sel),     	// '0' selects header, '1' selects data
	.adc_mux_checksum_select(adc_mux_checksum_select),		// send the checksum to the FIFO 
	.adc_acq_out_valid(adc_acq_out_valid), 	// current data should be stored in the FIFO
    .burst_cntr_init(burst_cntr_init),  	// initialize when triggered
    .burst_cntr_en(burst_cntr_en),       	// will be enabled once per burst
    .fill_cntr_en(fill_cntr_en),           	// will be enabled once per fill
 	.adc_acq_full_reset(adc_acq_full_reset),        // synchronously negated 
    .acq_done(acq_done)                    	// acquisition is done
);      

//	// create a register to hold the checksum
//	reg [31:0] checksum_reg;
//	always @ (posedge clk) begin
//		if (CS[IDLE] == 1'b1)
//			checksum_reg[31:0] <= 32'b0;
//		else if
//			(xmit_data_dly2) checksum_reg[31:0] <=  checksum_reg[31:0] ^ ADC_data_mem_doutb[31:0];
//		else
//			checksum_reg[31:0] <= checksum_reg[31:0];
//	end
    
     

endmodule

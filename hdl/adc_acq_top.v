`timescale 1ns / 1ps
// Acquisition controller for ADC data

module adc_acq_top(
    // inputs
    input [11:0] adc_in_p,          // [11:0] array of ADC 'p' data pins
    input [11:0] adc_in_n,          // [11:0] array of ADC 'n' data pins
    input adc_ovr_p,                // ADC 'p' over-range pin
    input adc_ovr_n,                // ADC 'n' over-range pin
    input adc_clk,  // ADC clock used by the FIFO
    // input adc_clk_p,                // ADC 'p' clk pin
    // input adc_clk_n,                // ADC 'n' clk pin
    input reset_clk50,              // synchronously negated
    input clk200,                   // for input pin timing delay settings
    input [11:0] channel_tag,       // stuff about the channel to put in the header
    input [22:0] muon_num_bursts,   // number of sample bursts in a MUON fill
    input [22:0] laser_num_bursts,  // number of sample bursts in a LASER fill
    input [22:0] ped_num_bursts,    // number of sample bursts in a OPEDESTAL fill
    input [23:0] initial_fill_num,  // event number to assign to the first fill
    input initial_fill_num_wr,      // write-strobe to store the initial_fill_num
    input acq_enable0,              // indicates enabled for triggers, and fill type
    input acq_enable1,              // indicates enabled for triggers, and fill type
    input acq_trig,                 // trigger the logic to start collecting data
    input adc_acq_full_reset,       // reset all aspects of data collection/storage/readout
    input adc_buf_delay_data_reset, // use the new delay settings
    input [4:0] adc_buf_data_delay, // 5 delay-tap-bits per line, all lines always all the same
    input ddr3_wr_done,             // asserted when the 'ddr3_wr_control' is in the DONE state
    input [11:0] muon_num_waveforms,// number of waveforms to store per trigger
    input [21:0] muon_waveform_gap,	// idle time between waveforms 
    input [11:0] laser_num_waveforms,	// number of waveforms to store per trigger
    input [21:0] laser_waveform_gap,	// idle time between waveforms 
    input [11:0] ped_num_waveforms,		// number of waveforms to store per trigger
    input [21:0] ped_waveform_gap,		// idle time between waveforms 
    input [3:0] xadc_alarms,
    // outputs
    output acq_enabled,             // the system is in acquisition mode, rather than readout mode
    output [64:0] adc_buf_current_data_delay, // 13 lines *5 bits/line, current tap settings
    output [23:0] fill_num,         // fill number for this fill
    output [131:0] adc_acq_out_dat, // 132-bit 4-bit tag plus 128-bit header or ADC data
    output adc_acq_out_valid,       // current data should be stored in the FIFO
    output acq_done,                // acquisition is done
    output [25:0] packed_adc_dat,   // two samples, with over-range bits, packed in one wide-word
                                    //   bit[0]      = first overrange
                                    //   bits[11:1]  = first ADC sample
                                    //   bit[12]     = second overrange
                                    //   bits[25:13] = second ADC sample
    output adc_acq_sm_idle          // ADC acquisition state machine is idle (used for front panel LED status)
);

wire [1:0] fill_type;           // to determine how much data to collect
wire [22:0] num_fill_bursts;    // number of 8 (or 10)-sample bursts in a fill
wire [11:0] num_waveforms;   	// number of waveforms to store per trigger
wire [21:0] waveform_gap;		// idle time between waveforms 
wire [22:0] burst_start_adr;    // first DDR3 burst memory location for this fill (3 LSBs = 0)
wire [11:0] current_waveform_num;// the current waveform number, to be used in header

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
    .data_in_from_pins_p({adc_in_p[11:0],adc_ovr_p}),    // [12:0] array of ADC 'p' data pins and over-range
    .data_in_from_pins_n({adc_in_n[11:0],adc_ovr_n}),    // [12:0] array of ADC 'n' data pins and over-range
    .clk_in(adc_clk),                                    // 400 MHz clock from adc
    //.clk_in_p(adc_clk_p),                                // ADC 'p' clk pin
    //.clk_in_n(adc_clk_n),                                // ADC 'n' clk pin
    .io_reset(adc_acq_full_reset),                       // synchronously negated
    .in_delay_reset(adc_buf_delay_data_reset),           // input wire in_delay_reset
    .in_delay_tap_in({13{adc_buf_data_delay[4:0]}}),     // 13 input lines, 5 delay-tap-bits per line, always all the same
    .in_delay_tap_out(adc_buf_current_data_delay[64:0]), // 13 lines *5 bits/line, current tap settings 
    .in_delay_data_ce({13{1'b0}}),                       // 'ce' is unused
    .in_delay_data_inc({13{1'b0}}),                      // 'inc' is unused
    .delay_clk(clk200),
    .ref_clock(clk200),                                  // 200 MHz clock required to ensure tap value settings
    .data_in_to_device(packed_adc_dat),                  // twice-as-wide SDR data
    .delay_locked()                                      // not used
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// Use channel_tag[4] to control whether the dummy_dat counter free-runs through a fill once started,
// or whether it gets reset for each waveform.
reg dummy_dat_reset_mode;
always @(posedge adc_clk) begin
    // channel_tag[4] = 0 -> free-run,  1 -> reset every waveform
    if (channel_tag[4]) 
    	dummy_dat_reset_mode <= 1'b1;
    else
    	dummy_dat_reset_mode <= 1'b0;
end

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
// connect a pipeline of registers to hold all data for 1 burst.
// register #0 will have the oldest data
// register #4 will have the newest data, and provide a mux for injecting dummy data
// register #4 will only be stored if 10-sample bursts are being used.
reg [25:0] adc_dat_reg4_, adc_dat_reg3_, adc_dat_reg2_, adc_dat_reg1_, adc_dat_reg0_;
always @(posedge adc_clk) begin
    // channel_tag[3] = 0 -> use real data : =  1 -> use dummy data
    if (channel_tag[3]) begin
        // use dummy data
        adc_dat_reg4_[0]        <= 1'b0;                // over-range bit
        adc_dat_reg4_[12:1]     <= dummy_dat[11:0];     // normal counter
        adc_dat_reg4_[13]       <= 1'b0;                // over-range bit
        adc_dat_reg4_[25:14]    <= ~dummy_dat[11:0];    // inverted counter
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
    .muon_num_bursts(muon_num_bursts[22:0]),    // number of sample bursts in a MUON fill
    .laser_num_bursts(laser_num_bursts[22:0]),  // number of sample bursts in a LASER fill
    .ped_num_bursts(ped_num_bursts[22:0]),      // number of sample bursts in a PEDESTAL fill
    .clk(adc_clk),
    .enable(fill_type_mux_en),
    // outputs
    .num_fill_bursts(num_fill_bursts[22:0])     // number of 8(or 10) sample bursts
);

///////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will provide the number of waveforms as sepecified by the fill type.
adc_num_waveforms_mux adc_num_waveforms_mux (
    // inputs
    .fill_type(fill_type[1:0]),                 	// to determine how much data to collect
	.muon_num_waveforms(muon_num_waveforms[11:0]),	// number of waveforms to store per trigger
    .laser_num_waveforms(laser_num_waveforms[11:0]),// number of waveforms to store per trigger
    .ped_num_waveforms(ped_num_waveforms[11:0]),	// number of waveforms to store per trigger
    .clk(adc_clk),
    .enable(fill_type_mux_en),
    // outputs
    .num_waveforms(num_waveforms[11:0])     		// number of waveforms to store per trigger
);

///////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will provide the waveform gap as sepecified by the fill type.
adc_waveform_gap_mux adc_waveform_gap_mux (
    // inputs
    .fill_type(fill_type[1:0]),                 	// to determine how much data to collect
	.muon_waveform_gap(muon_waveform_gap[21:0]),	// idle time between waveforms 
    .laser_waveform_gap(laser_waveform_gap[21:0]),	// idle time between waveforms 
    .ped_waveform_gap(ped_waveform_gap[21:0]),		// idle time between waveforms 
    .clk(adc_clk),
    .enable(fill_type_mux_en),
    // outputs
    .waveform_gap(waveform_gap[21:0])				// idle time between waveforms 
);

/////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will supply either a header, ADC data, or a checksum to the DDR3 write FIFO
// All bit ordering is done in this mux
adc_dat_mux adc_dat_mux (
    // inputs
    .dat3_(adc_dat_reg3_[25:0]),                // a pair of ADC samples and a pair of over-range bits
    .dat2_(adc_dat_reg2_[25:0]),                // a pair of ADC samples and a pair of over-range bits
    .dat1_(adc_dat_reg1_[25:0]),                // a pair of ADC samples and a pair of over-range bits
    .dat0_(adc_dat_reg0_[25:0]),                // a pair of ADC samples and a pair of over-range bits
    .channel_tag(channel_tag[11:0]),            // stuff about the channel to put in the header
    .fill_type(fill_type[1:0]),                 // determine which burst count to use
    .num_fill_bursts(num_fill_bursts[22:0]),    // number of 8(or 10) sample bursts
    .burst_start_adr(burst_start_adr[22:0]),    // first DDR3 burst memory location (3 LSBs=0) for this fill
    .num_waveforms(num_waveforms[11:0]),	    // number of waveforms to store per trigger
    .current_waveform_num(current_waveform_num[11:0]),// the current waveform number, to be used in header
    .waveform_gap(waveform_gap[21:0]),	    	// idle time between waveforms
    .fill_num(fill_num[23:0]),                  // fill number for this fill
    .xadc_alarms(xadc_alarms[3:0]),
    .clk(adc_clk),
    .select_dat(adc_mux_dat_sel),               // selects data
    .select_fill_hdr(adc_mux_fill_hdr_sel),     // selects fill header
    .select_waveform_hdr(adc_mux_wfm_hdr_sel),  // selects waveform header
    .select_checksum(adc_mux_checksum_select),  // selects checksum, send the checksum to the FIFO 
    .checksum_update(adc_mux_checksum_update),  // update the checksum 
    // outputs
    .adc_acq_out_dat(adc_acq_out_dat[131:0])    // 132-bit: 4-bit tag plus 128-bit header or ADC data   
);

wire initial_fill_num_wr_sync;
sync_2stage initial_fill_num_wr_sync_inst (
    .clk(adc_clk),
    .in(initial_fill_num_wr),
    .out(initial_fill_num_wr_sync)
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter that will calculate the DDR3 starting address of the next fill
// It will be initialized when the fill number is written.
// It will increment every time data is written to the FIFO
adc_address_cntr adc_address_cntr (
    // inputs
    .clk(adc_clk),
    .init(initial_fill_num_wr_sync),             // initialize to zero when the fill number is written
    .enable(address_cntr_en),                    // increment
    // outputs
    .burst_start_adr(burst_start_adr[22:0])      // first DDR3 burst memory location for this fill
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a down-counter that will keep track of how many bursts have been saved
// It will be initialized when a trigger occurs.
// It will be enabled when each burst is sent out.
adc_burst_cntr adc_burst_cntr (
    // inputs
    .num_fill_bursts(num_fill_bursts[22:0]),    // number of 8 (or 10) sample bursts
    .clk(adc_clk),
    .init(burst_cntr_init),                     // initialize when triggered
    .enable(burst_cntr_en),                     // will be enabled once per burst
    // outputs
    .at_zero(burst_cntr_zero)                   // all sample bursts have been saved
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect an up-counter that will keep track of the waveform number
// It will be initialized when a trigger occurs.
// It will be enabled after each waveforms is finished.
adc_waveform_cntr adc_waveform_cntr (
    // inputs
    .num_waveforms(num_waveforms[11:0]),	    // number of waveforms to store per trigger
    .clk(adc_clk),
    .init(waveform_cntr_init),                  // initialize when triggered
    .enable(waveform_cntr_en),                  // will be enabled once after each waveform
    // outputs
    .current_waveform_num(current_waveform_num[11:0]),// to be used in header
    .last(last_waveform)  				              // all waveforms have been saved
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a down-counter that will keep track of the gap between waveforms
// It will be initialized after each waveform is stored.
// It will be enabled after each waveforms is stored.
adc_waveform_gap_cntr adc_waveform_gap_cntr (
    // inputs
    .waveform_gap(waveform_gap[21:0]),	    // idle time between waveforms
    .clk(adc_clk),
    .init(waveform_gap_cntr_init),          // initialize after previous waveform stored
    .enable(waveform_gap_cntr_en),          // enable after each initialization
    // outputs
    .at_zero(waveform_gap_zero)             // the idle time has elapsed
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect an up-counter that will keep track of the fill number
// It will be initialized at the start of a run, or when necessary.
// It will be enabled when each fill is done
adc_fill_cntr adc_fill_cntr (
    // inputs
    .initial_fill_num(initial_fill_num[23:0]),  // always positive
    .clk(adc_clk),
    .init(initial_fill_num_wr_sync),            // initialize when programmed
    .enable(fill_cntr_en),                      // will be enabled once per fill
    // outputs
    .fill_num(fill_num[23:0])                   // fill number for this fill
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a state machine to coordinate everything
adc_acq_sm adc_acq_sm (
    // inputs
    .clk(adc_clk),
    .acq_enable0(acq_enable0),              // enable the logic to accept triggers
    .acq_enable1(acq_enable1),              // enable the logic to accept triggers
    .acq_trig(acq_trig),                    // trigger the logic to start collecting data
    .reset_clk50(reset_clk50),              // synchronously negated
    .adc_acq_full_reset(adc_acq_full_reset),// synchronously negated
    .burst_cntr_zero(burst_cntr_zero),      // all sample bursts have been saved
    .waveform_gap_zero(waveform_gap_zero),  // the idle time has elapsed
    .last_waveform(last_waveform),  		// all waveforms have been saved
    .ddr3_wr_done(ddr3_wr_done),            // asserted when the 'ddr3_wr_control' is in the DONE state
    .dummy_dat_reset_mode(dummy_dat_reset_mode),// channel_tag[4] = 0 -> free-run,  1 -> reset every waveform
    // outputs
    .fill_type(fill_type[1:0]),             // determine which burst count to use
    .fill_type_mux_en(fill_type_mux_en),    // enable choosing one of the burst counts
    .address_cntr_en(address_cntr_en),      // increment the next starting address
    .dummy_dat_reset(dummy_dat_reset),      // reset the dummy data counter
    .adc_mux_fill_hdr_sel(adc_mux_fill_hdr_sel),    // selects fill header
    .adc_mux_wfm_hdr_sel(adc_mux_wfm_hdr_sel),     // selects waveform header
    .adc_mux_dat_sel(adc_mux_dat_sel),      // selects data
    .adc_mux_checksum_select(adc_mux_checksum_select),      // send the checksum to the FIFO 
    .adc_mux_checksum_update(adc_mux_checksum_update),      // update the checksum 
    .adc_acq_out_valid(adc_acq_out_valid),  // current data should be stored in the FIFO
    .burst_cntr_init(burst_cntr_init),      // initialize when triggered
    .burst_cntr_en(burst_cntr_en),          // will be enabled once per burst
    .fill_cntr_en(fill_cntr_en),            // will be enabled once per fill

    .waveform_cntr_init(waveform_cntr_init),                  // initialize when triggered
    .waveform_cntr_en(waveform_cntr_en),                  // will be enabled once after each waveform
    .waveform_gap_cntr_init(waveform_gap_cntr_init),          // initialize after previous waveform stored
    .waveform_gap_cntr_en(waveform_gap_cntr_en),          // enable after each initialization

    .acq_done(acq_done),                    // acquisition is done
    .sm_idle(adc_acq_sm_idle)               // state machine is idle
);      

endmodule

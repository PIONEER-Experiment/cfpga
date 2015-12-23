`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Subset of the whole channel FPGA. It includes:
//		adc_acq_top
//		ddr3_wr_fifo
//		ddr3_intf
//////////////////////////////////////////////////////////////////////////////////

module adc_to_ddr3_block(
	// ADC acquisition
	input reset_clk50,					// synchronously negated  
	input clk200,						// for input pin timing delay settings
	input clk250,						// for DDR3 operation
	input clk125,						// for buffer readout
	input [15:0] channel_tag,			// stuff about the channel to put in the header
	input [20:0] num_muon_bursts,		// number of sample bursts in a MUON fill
	input [20:0] num_laser_bursts,		// number of sample bursts in a LASER fill
	input [20:0] num_ped_bursts,		// number of sample bursts in a PEDESTAL fill
	input [23:0] initial_fill_num,		// event number to assign to the first fill
	input initial_fill_num_wr,			// write-strobe to store the initial_fill_num
	input [11:0] num_waveforms,			// number of waveforms to store per trigger
	input [21:0] waveform_gap,			// idle time between waveforms 
	input [22:0] fixed_ddr3_start_addr,
	input en_fixed_ddr3_start_addr,
	
	// triggering
	input acq_enable0,					// indicates enabled for triggers, and fill type
	input acq_enable1,					// indicates enabled for triggers, and fill type
	input acq_trig,						// trigger the logic to start collecting data
	input acq_reset,					// reset all of the acquisition logic
	// input pin delay settings
	input adc_buf_delay_data_reset,		// use the new delay settings
	input [4:0] adc_buf_data_delay,		// 5 delay-tap-bits per line, all lines always all the same
	// ADC outputs
	output acq_enabled,					// the system is in acquisition mode, rather than readout mode
	output [64:0] adc_buf_current_data_delay,	// 13 lines *5 bits/line, current tap settings
	output [23:0] fill_num,				// fill number for this fill
	output [127:0] adc_acq_out_dat,		// 128-bit header or ADC data
	output adc_acq_out_valid,			// current data should be stored in the FIFO
	output adc_clk,						// ADC clock used by the FIFO
	output adc_acq_full_reset,			// reset all aspects of data collection/storage/readout
	output acq_done,					// acquisition is done
	output fill_header_fifo_empty,		// output, a header is available when not asserted
	output ddr3_wr_fifo_valid,		// maybe this will be ahead of 'empty'?
	output [127:0] ddr3_wr_fifo_dat,
	// header/buffer readout control
	input fill_header_fifo_rd_en,		// input, remove the current data from the FIFO
	input [22:0] ddr3_rd_burst_addr,	// input, the address of the requested 128-bit burst
	input ddr3_rd_one_burst,			// input, get one 128-bit burst from the DDR3
	// header/buffer readout results
	output [127:0] fill_header_fifo_out,	// output, data at the head of the FIFO
	output ddr3_one_burst_rdy,			// output, the requested 128-bit burst is ready
	output [127:0] ddr3_one_burst_data,	// output, the requested 128-bit burst
	// DDR Memory pins
	output [2:0] ddr3_ba,
	output [12:0] ddr3_addr,
	inout [15:0] ddr3_dq,
	output ddr3_cas_n,
	output [0:0] ddr3_cke,
	output [0:0] ddr3_ck_n, ddr3_ck_p,
	output [1:0] ddr3_dm,
	inout [1:0] ddr3_dqs_n, ddr3_dqs_p,
	output [0:0] ddr3_odt,
	output ddr3_ras_n,
	output ddr3_reset_n,
	output ddr3_we_n,
	// ADC pins
	input [11:0] adc_in_p, adc_in_n,
	input adc_clk_n, adc_clk_p,     // up to 400 MHz sample clock from ADC chip
	input adc_ovr_n, adc_ovr_p,     // over-range
	output ddr3_domain_clk,			// output, the DDR3 user-interface synchronous clock
	output app_rdy

);

////////////////////////////////////////////////////////////////////////////
// connect the ADC acquisition controller
 
adc_acq_top adc_acq_top (
	// inputs
	.adc_in_p(adc_in_p[11:0]),                  // [11:0] array of ADC 'p' data pins
	.adc_in_n(adc_in_n[11:0]),                  // [11:0] array of ADC 'n' data pins
	.adc_ovr_p(adc_ovr_p),                      // ADC 'p' over-range pin
	.adc_ovr_n(adc_ovr_n),                      // ADC 'n' over-range pin
	.adc_clk_p(adc_clk_p),                       // ADC 'p' clk pin
	.adc_clk_n(adc_clk_n),                       // ADC 'n' clk pin
	.reset_clk50(reset_clk50),                  // synchronously negated  
	.clk200(clk200),                            // for input pin timing delay settings
	.channel_tag(channel_tag[15:0]), 		   // stuff about the channel to put in the header
	.num_muon_bursts(num_muon_bursts[22:0]),  // number of sample bursts in a MUON fill
	.num_laser_bursts(num_laser_bursts[22:0]),// number of sample bursts in a LASER fill
	.num_ped_bursts(num_ped_bursts[22:0]),    // number of sample bursts in a PEDESTAL fill
	.initial_fill_num(initial_fill_num[23:0]),  // event number to assign to the first fill
	.initial_fill_num_wr(initial_fill_num_wr),  // write-strobe to store the initial_fill_num
    .acq_enable0(acq_enable0),              // indicates enabled for triggers, and fill type
	.acq_enable1(acq_enable1),              // indicates enabled for triggers, and fill type
	.acq_trig(acq_trig),                        // trigger the logic to start collecting data
	.acq_reset(acq_reset),                      // reset all of the acquisition logic
	.adc_buf_delay_data_reset(adc_buf_delay_data_reset),	// use the new delay settings
	.adc_buf_data_delay(adc_buf_data_delay[4:0]),	// 5 delay-tap-bits per line, all lines always all the same
    .ddr3_wr_done,             // asserted when the 'ddr3_wr_control' is in the DONE state
	.num_waveforms(num_waveforms[11:0]),		// number of waveforms to store per trigger
	.waveform_gap(waveform_gap[21:0]),		// idle time between waveforms 
	// outputs
	.acq_enabled(acq_enabled),					// the system is in acquisition mode, rather than readout mode
	.adc_buf_current_data_delay(adc_buf_current_data_delay[64:0]), // 13 lines *5 bits/line, current tap settings
	.fill_num(fill_num[23:0]),			         // fill number for this fill
	.adc_acq_out_dat(adc_acq_out_dat[131:0]),   // 128-bit header or ADC data
	.adc_acq_out_valid(adc_acq_out_valid),      // current data should be stored in the FIFO
	.adc_clk(adc_clk),					          // ADC clock used by the FIFO
	.adc_acq_full_reset(adc_acq_full_reset),	// reset all aspects of data collection/storage/readout
	.acq_done(acq_done),                         // acquisition is done
    .adc_acq_sm_idle(adc_acq_sm_idle)          // ADC acquisition state machine is idle (used for front panel LED status)
);
        
////////////////////////////////////////////////////////////////////////////
// Create a FIFO to buffer the data between the ADC block and the DDR3 block
ddr3_write_fifo ddr3_write_fifo (
	// inputs
	.rst(adc_acq_full_reset),       // reset at startup or when requested
	.wr_clk(adc_clk), 		       // clock extracted from ADC DDR clock
	.rd_clk(ddr3_domain_clk),       // clock extracted from DDR3 block
	.din(adc_acq_out_dat[131:0]),   // 4-bit tag plus 128-bit header or ADC data
	.wr_en(adc_acq_out_valid),      // current data should be stored in the FIFO
	.rd_en(ddr3_wr_fifo_rd_en),     // use and remove the data on the FIFO head
	.dout(ddr3_wr_fifo_dat[131:0]), // data to be written to the DDR3
	.full(ddr3_wr_fifo_full),                        // we don't currently use this
	.empty(ddr3_wr_fifo_empty)		// data is available when this is not asserted
);

////////////////////////////////////////////////////////////////////////////
// Connect the DDR3 interface
ddr3_intf ddr3_intf(
	// clocks and resets
	.refclk(clk200),							// input, 200 MHz for I/O timing adjustments
	.sysclk(clk250),							// input, drives the Xilinx DDR3 IP
	.reset(adc_acq_full_reset),					// input, reset at startup or when requested by master FPGA 
	.ddr3_domain_clk(ddr3_domain_clk),			// output, the DDR3 user-interface synchronous clock
	// writing connections
	.acq_enabled(acq_enabled),					// the system is in acquisition mode, rather than readout mode
	.ddr3_wr_fifo_empty(ddr3_wr_fifo_empty),	// input, data is available when this is not asserted
	.ddr3_wr_fifo_rd_en(ddr3_wr_fifo_rd_en),	// output, use and remove the data on the FIFO head
	.ddr3_wr_fifo_dat(ddr3_wr_fifo_dat[131:0]),			// input, data from the ddr3_write_fifo, to be written to the DDR3
    .ddr3_wr_sync_err(),                         // synchronization error flag
    .ddr3_wr_done(ddr3_wr_done),                 // asserted when the 'ddr3_wr_control' is in the DONE state
    .acq_done(acq_done),                         // input, acquisition is done
    .fixed_ddr3_start_addr(fixed_ddr3_start_addr[22:0]),
	.en_fixed_ddr3_start_addr(en_fixed_ddr3_start_addr),
	// reading connections
	.local_domain_clk(clk125),							// input, the local user synchronous clock
	.fill_header_fifo_empty(fill_header_fifo_empty),	// output, a header is available when not asserted
	.fill_header_fifo_rd_en(fill_header_fifo_rd_en),	// input, remove the current data from the FIFO
	.fill_header_fifo_out(fill_header_fifo_out[127:0]),	// output, data at the head of the FIFO
    .ddr3_rd_start_addr(ddr3_rd_start_addr[22:0]),       // input, the address of the first requested 128-bit burst
	.ddr3_rd_burst_cnt(ddr3_rd_burst_cnt[23:0]),         // input, the number of bursts to read
	.enable_reading(enable_reading),                     // input, initialize the address generator and both counters, go
	.reading_done(reading_done),                         // output, reading is complete
    // ports to the 'read' fifo
	.ddr3_rd_fifo_wr_en(ddr3_rd_fifo_wr_en),                // data is valid, so put it in the READ FIFO    
	.ddr3_rd_fifo_input_dat(ddr3_rd_fifo_input_dat[127:0]), // output, memory data
	.ddr3_rd_fifo_almost_full(ddr3_rd_fifo_almost_full),    // there is not much room left    
	.ddr3_rd_fifo_input_tlast(ddr3_rd_fifo_input_tlast),    // the last burst for this fill 
	// connections to the DDR3 chips
	.ddr3_addr(ddr3_addr[12:0]),
	.ddr3_ba(ddr3_ba[2:0]),
	.ddr3_dq(ddr3_dq[15:0]),
	.ddr3_ck_p(ddr3_ck_p[0:0]),
	.ddr3_ck_n(ddr3_ck_n[0:0]),
	.ddr3_dqs_p(ddr3_dqs_p[1:0]),
	.ddr3_dqs_n(ddr3_dqs_n[1:0]),
	.ddr3_we_n(ddr3_we_n),
	.ddr3_cke(ddr3_cke[0:0]),
	.ddr3_ras_n(ddr3_ras_n),
	.ddr3_cas_n(ddr3_cas_n),
	.ddr3_reset_n(ddr3_reset_n),
	.ddr3_dm(ddr3_dm[1:0]),
	.ddr3_odt(ddr3_odt[0:0]),
	.app_rdy(app_rdy)
);


endmodule

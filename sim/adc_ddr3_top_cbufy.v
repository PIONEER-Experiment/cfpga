`timescale 1ns / 10ps

//////////////////////////////////////////////////////////////
// Top level module to tie together the ADC controller with the DDR3 memory
// ASYNCHRONOUS MODE
//
// Notes:
//
//////////////////////////////////////////////////////////////

// as a useful reference, here's the syntax to mark signals for debug:
// (* mark_debug = "true" *) 

module adc_ddr3_top_cbuf(
  // Utility
  input clk50,
  input clk125,
  input clk200,
  input clk250,
  input acq_reset,
  input acq_trig,               // from master, asserted active-hi to start acquisition, C0_TRIG on schematic
  input acq_enable0,                       // indicates enabled for triggers, and fill type
  input acq_enable1,                       // indicates enabled for triggers, and fill type
  output acq_done,              // to master, asserted active-hi at the end of acquisition, C0_DONE on schematic
  output adc_acq_sm_idle,                    // ADC acquisition state machine is idle (used for front panel LED status)
	output acq_enabled,
	
  input [15:0] channel_tag,                // stuff about the channel to put in the header
  input [23:0] initial_fill_num,           // event number to assign to the first fill
  input initial_fill_num_wr,           // write-strobe to store the initial_fill_num
  input [10:0] async_num_bursts,           // number of 8-sample bursts in an ASYNC waveform
  input [11:0] async_pre_trig,             // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
  input adc_buf_delay_data_reset, // use the new delay settings
  input [4:0] adc_buf_data_delay,        // 5 delay-tap-bits per line, all lines always all the same

  // reading from the DDR3 memory
  output fill_header_fifo_empty,     // output, a header is available when not asserted
  input fill_header_fifo_rd_en,     // input, remove the current data from the FIFO
  output [151:0] fill_header_fifo_out,  // output, data at the head of the FIFO
  input [22:0] ddr3_rd_start_addr,       // input, the address of the first requested 128-bit burst
  input [23:0] ddr3_rd_burst_cnt,         // input, the number of bursts to read
  input enable_reading,                     // input, initialize the address generator and both counters, go
  output reading_done,                         // output, reading is complete
  // ports to the 'read' fifo
  output ddr3_rd_fifo_wr_en,                // data is valid, so put it in the READ FIFO    
  output [127:0] ddr3_rd_fifo_input_dat, // output, memory data
  input ddr3_rd_fifo_almost_full,    // there is not much room left    
  output ddr3_rd_fifo_input_tlast,    // the last burst for this fill 

  // DDR3 memory
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
  output ddr3_domain_clk,			// output, the DDR3 user-interface synchronous clock
  output app_rdy,

  // ADC
  input [11:0] adc_in_p,                           // [11:0] array of ADC 'p' data pins
  input [11:0] adc_in_n,                           // [11:0] array of ADC 'n' data pins
  input adc_clk_n, adc_clk_p,   // 400 MHz sample clock from ADC chip
  input adc_ovr_n, adc_ovr_p   // over-range bit from ADC chip
);

wire [131:0] adc_acq_out_dat;           // 132-bit 4-bit tag plus header or ADC data to 'ddr3_write_fifo'
wire adc_acq_out_valid;
wire [131:0] ddr3_wr_fifo_dat;          // 132-bit 4-bit tag plus header or ADC data from 'ddr3_write_fifo'
wire [23:0] fill_num;                   // fill number for this fill
wire [127:0] ddr3_rd_fifo_output_dat;   // memory burst headed toward 'ddr3_read_data_width_converter'
wire [22:0] ddr3_rd_burst_addr;

wire [64:0] adc_buf_current_data_delay;

// synchronous reset logic
startup_reset startup_reset(
    .rst_from_master(acq_reset),	// external reset of all acquisition logic
    .clk50(clk50),              // 50 MHz buffered clock 
    .reset_clk50(reset_clk50),  // active-high reset output, goes low after startup
    .clk125(clk125),            // buffered clock, 125 MHz
    .reset_clk125(reset_clk125) // active-high reset output, goes low after startup
);

 
////////////////////////////////////////////////////////////////////////////
// connect the ADC acquisition controller
 
adc_acq_top_ASYNC adc_acq_top_ASYNC (
    // inputs
    .adc_in_p(adc_in_p[11:0]),                           // [11:0] array of ADC 'p' data pins
    .adc_in_n(adc_in_n[11:0]),                           // [11:0] array of ADC 'n' data pins
    .adc_ovr_p(adc_ovr_p),                               // ADC 'p' over-range pin
    .adc_ovr_n(adc_ovr_n),                               // ADC 'n' over-range pin
    .adc_clk_p(adc_clk_p),                               // ADC 'p' clk pin
    .adc_clk_n(adc_clk_n),                               // ADC 'n' clk pin
    .reset_clk50(reset_clk50),                           // synchronously negated  
    .clk200(clk200),                                     // for input pin timing delay settings
    .channel_tag(channel_tag[15:0]),                     // stuff about the channel to put in the header
    .initial_fill_num(initial_fill_num[23:0]),           // event number to assign to the first fill
    .initial_fill_num_wr(initial_fill_num_wr),           // write-strobe to store the initial_fill_num
    .ext_enable0(acq_enable0),                           // indicates enabled for triggers, and fill type
    .ext_enable1(acq_enable1),                           // indicates enabled for triggers, and fill type
    .ext_trig(acq_trig),                                 // trigger the logic to start collecting data
    .adc_buf_delay_data_reset(adc_buf_delay_data_reset), // use the new delay settings
    .adc_buf_data_delay(adc_buf_data_delay[4:0]),        // 5 delay-tap-bits per line, all lines always all the same
    .ddr3_wr_done(ddr3_wr_done),                         // asserted when the 'ddr3_wr_control' is in the DONE state
	.async_num_bursts(async_num_bursts[10:0]),          // number of 8-sample bursts in an ASYNC waveform
    .async_pre_trig(async_pre_trig[11:0]),              // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
 
    // outputs
	.ddr3_wr_en(ddr3_wr_en),		// writing of triggered events to memory is enabled
    .adc_buf_current_data_delay(adc_buf_current_data_delay[64:0]), // 13 lines *5 bits/line, current tap settings
    .fill_num(fill_num[23:0]),                           // fill number for this fill
    .adc_acq_out_dat(adc_acq_out_dat[131:0]),            // 132-bit 4-bit tag plus 128-bit header or ADC data
    .adc_acq_out_valid(adc_acq_out_valid),               // current data should be stored in the FIFO
    .adc_clk(adc_clk),                                   // ADC clock used by the FIFO
    .ext_done(acq_done),                                 // acquisition is done
    .adc_acq_sm_idle(adc_acq_sm_idle)                    // ADC acquisition state machine is idle (used for front panel LED status)
);

wire ddr3_write_fifo_full;
        
////////////////////////////////////////////////////////////////////////////
// Create a FIFO to buffer the data between the ADC block and the DDR3 block
ddr3_write_fifo ddr3_write_fifo (
    // inputs
    .rst(reset_clk50),       		// reset at startup or when requested
    .wr_clk(adc_clk),               // clock extracted from ADC DDR clock
    .rd_clk(ddr3_domain_clk),       // clock extracted from DDR3 block
    .din(adc_acq_out_dat[131:0]),   // 132-bit 4-bit tag plus 128-bit header or ADC data
    .wr_en(adc_acq_out_valid),      // current data should be stored in the FIFO
    .rd_en(ddr3_wr_fifo_rd_en),     // use and remove the data on the FIFO head
    .dout(ddr3_wr_fifo_dat[131:0]), // 132-bit 4-bit tag plus 128-bit data to be written to the DDR3
    .full(ddr3_write_fifo_full),    // we don't currently use this
    .empty(ddr3_wr_fifo_empty)      // data is available when this is not asserted
);

wire [22:0] fixed_ddr3_start_addr;
wire en_fixed_ddr3_start_addr;

////////////////////////////////////////////////////////////////////////////
// Connect the DDR3 interface
ddr3_intf_ASYNC ddr3_intf_ASYNC(
    // clocks and resets
    .refclk(clk200),                    // input, 200 MHz for I/O timing adjustments
    .sysclk(clk200),                    // input, drives the Xilinx DDR3 IP
    .reset_clk50(reset_clk50),         // input, reset at startup or when requested by master FPGA 
    .ddr3_domain_clk(ddr3_domain_clk),  // output, the DDR3 user-interface synchronous clock
    .reset_ddr3_clk(reset_ddr3_clk),	// output, synched to ddr3_clk

    // writing connections
	.ddr3_wr_en(ddr3_wr_en),		// writing of triggered events to memory is enabled
    .ddr3_wr_fifo_empty(ddr3_wr_fifo_empty),     // input, data is available when this is not asserted
    .ddr3_wr_fifo_rd_en(ddr3_wr_fifo_rd_en),     // output, use and remove the data on the FIFO head
    .ddr3_wr_fifo_dat(ddr3_wr_fifo_dat[131:0]),  // input, 132-bit 4-bit tag plus 128-bit data from the ddr3_write_fifo, to be written to the DDR3
    .ddr3_wr_sync_err(),                         // synchronization error flag
    .ddr3_wr_done(ddr3_wr_done),                 // asserted when the 'ddr3_wr_control' is in the DONE state
    .acq_done(acq_done),                         // input, acquisition is done

    // reading connections
    .local_domain_clk(clk125),                           // input, the local user synchronous clock
    .fill_header_fifo_empty(fill_header_fifo_empty),     // output, a header is available when not asserted
    .fill_header_fifo_rd_en(fill_header_fifo_rd_en),     // input, remove the current data from the FIFO
    .fill_header_fifo_out(fill_header_fifo_out[151:0]),  // output, data at the head of the FIFO
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

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// G-2 WFD5 prototype Channel FPGA
//
// Notes:
// 1) The is only one link to the master. It is chan 0.
//
//////////////////////////////////////////////////////////////////////////////////
module channel_main(
  // Utility
  output [9:0] debug,           // to 10-pin header
  input [2:0] ch_addr,          // will be 3'b111, this chip's address, from pullup/pulldown
  input [2:0] power_good,       // from regulators, active-hi, #2=1.8v, #1=1.2v, #0=1.0v
  input clkin,                  // 50 MHz oscillator
  (* mark_debug = "true" *) input acq_trig,               // from master, asserted active-hi to start acquisition, C0_TRIG on schematic
  (* mark_debug = "true" *) output acq_done,              // to master, asserted active-hi at the end of acquisition, C0_DONE on schematic
  input [3:0] io,               // connections to the master FPGA
  output led1, led2,            // multi color LED, [1=0,2=0]-> , [1=0,2=1]-> , [1=1,2=0]-> , [1=1,2=1]->  
  input bbus_scl,               // I2C bus clock, from I2C master, connected to Atmel Chip, Master FPGA, and to other Channel FPGAs
  input bbus_sda, //SHOULD BE INPUT//               // I2C bus data, connected to Atmel Chip, MAster FPGA, and to other Channel FPGAs
  // serial interfaces
  input c0_rx, c0_rx_N,         // Serial data from the master for this channel
  output c0_tx, c0_tx_N,        // Serial data to the master for this channel
  input xcvr_clk, xcvr_clk_N,   // 125 MHz oscillator, connected to 'clk0' (not 'clk1') 
  // DDR Memory
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
  // ADC
  input adc_d0n, adc_d0p,
  input adc_d1n, adc_d1p,
  input adc_d2n, adc_d2p,
  input adc_d3n, adc_d3p,
  input adc_d4n, adc_d4p,
  input adc_d5n, adc_d5p,
  input adc_d6n, adc_d6p,
  input adc_d7n, adc_d7p,
  input adc_d8n, adc_d8p,
  input adc_d9n, adc_d9p,
  input adc_d10n, adc_d10p,
  input adc_d11n, adc_d11p,
  input adc_clk_n, adc_clk_p,     // 400 MHz sample clock from ADC chip
  input adc_dovrn, adc_dovrp,     // over-range
  input adc_sdo,
  output adc_sdio,
  output adc_sdclk,
  output adc_sdenb,
  output adc_sresetb,
  output adc_enable,
  input adc_syncp, adc_syncn
);

// Use io[3] for a 'acq_reset', io[2:1] for 'acq_enable', and io[0] for 'readout_pause'
wire acq_reset;
assign acq_reset = io[3];
wire acq_enable0;              // indicates enabled for triggers, and fill type
wire acq_enable1;              // indicates enabled for triggers, and fill type
assign acq_enable0 = io[1];
assign acq_enable1 = io[2];
wire readout_pause;
assign readout_pause = io[0];	// stop sending fill data to the Aurora

wire [15:0] channel_tag;			// stuff about the channel to put in the header
wire [20:0] num_muon_bursts;		// number of sample bursts in a MUON fill
wire [20:0]	num_laser_bursts;		// number of sample bursts in a LASER fill
wire [20:0]	num_ped_bursts;			// number of sample bursts in a PEDESTAL fill
wire [23:0]	initial_fill_num;		// event number to assign to the first fill
wire [127:0] adc_acq_out_dat;		// 128-bit header or ADC data to 'ddr3_write_fifo'
wire [127:0] ddr3_wr_fifo_dat;		// 128-bit header or ADC data from 'ddr3_write_fifo'
wire [127:0] ddr3_rd_dat;			// 128-bit header or ADC data from DDR3 memory
wire [23:0] fill_num;				// fill number for this fill

// Define the AXIS-fifo inputs and outputs for chan 0
wire [0:31] c0_rx_axi_tdata, c0_tx_axi_tdata;
wire [0:3] c0_rx_axi_tkeep, c0_tx_axi_tkeep;
wire c0_rx_axi_tvalid, c0_tx_axi_tvalid;
wire c0_rx_axi_tlast, c0_tx_axi_tlast;
wire c0_rx_axi_tready, c0_tx_axi_tready;

//generic register interface
wire [31:0] genreg_addr_ctrl;
wire [31:0] genreg_wr_data;
wire [31:0] genreg_rd_data;
wire [31:0] adc_intf_rd_data;
wire [31:0] adc_intf_wr_data;

wire [127:0] fill_header_fifo_out;
wire [22:0] ddr3_rd_burst_addr;
wire [127:0] ddr3_one_burst_data;

wire [4:0] adc_buf_data_delay;
wire [64:0] adc_buf_current_data_delay;

//wire [7:0] debug_wires;
//assign debug[7:0] = debug_wires[7:0];

////////////////////////////////////////////////////////////////////////////
// Clock and reset handling
// Connect an input buffer and a global clock buffer to the 50 MHz clock
wire clk50, clk200, clk250;

g2_chan_clks clk_dcm_50_200 (
	// Clock in ports
	.clk_in1(clkin),		// input, unbuffered 50 MHz from pin 
	// Clock out ports
	.clk_50M(clk50),		// output, 50 MHz
	.clk_200M(clk200),		// output, 200 MHz
	.clk_250M(clk250)		// output, 250 MHz
	// Status and control signals
	//.reset(1'b0),			// input, unused reset
	//.locked()				// output, unused locked
);

// differential clock buffer - This should get shared between the Aurora channel interfaces
// and other internal logic.
wire gt_clk125, clk125;
IBUFDS_GTE2 clk125_IBUFDS_GTE2 (.I(xcvr_clk), .IB(xcvr_clk_N), .O(gt_clk125), .CEB(1'b0), .ODIV2());
BUFG BUFG_clk125 (.I(gt_clk125), .O(clk125));

// synchronous reset logic
startup_reset startup_reset(
	.clk50(clk50),              // 50 MHz buffered clock 
	.reset_clk50(reset_clk50),  // active-high reset output, goes low after startup
	.clk125(clk125),			// buffered clock, 125 MHz
	.reset_clk125(reset_clk125)	// active-high reset output, goes low after startup
);

////////////////////////////////////////////////////////////////////////////
// dummy assignments to keep logic around
// assign led2 = ~acq_trig;
assign debug[8] = power_good;
assign debug[9] = 1'b0;

IBUFDS adc_sync_in (.I(adc_syncp), .IB(adc_syncn), .O(adc_sync));
 
////////////////////////////////////////////////////////////////////////////
// connect the ADC acquisition controller
// Combine the ADC data 'p' pins and 'n' pins into arrays.
wire [11:0] adc_in_p, adc_in_n;
assign adc_in_p = {adc_d11p, adc_d10p, adc_d9p, adc_d8p, adc_d7p, adc_d6p, adc_d5p, adc_d4p, adc_d3p, adc_d2p, adc_d1p, adc_d0p};
assign adc_in_n = {adc_d11n, adc_d10n, adc_d9n, adc_d8n, adc_d7n, adc_d6n, adc_d5n, adc_d4n, adc_d3n, adc_d2n, adc_d1n, adc_d0n};
 
adc_acq_top adc_acq_top (
	// inputs
	.adc_in_p(adc_in_p[11:0]),                  // [11:0] array of ADC 'p' data pins
	.adc_in_n(adc_in_n[11:0]),                  // [11:0] array of ADC 'n' data pins
	.adc_ovr_p(adc_dovrp),                      // ADC 'p' over-range pin
	.adc_ovr_n(adc_dovrn),                      // ADC 'n' over-range pin
	.adc_clk_p(adc_clk_p),                       // ADC 'p' clk pin
	.adc_clk_n(adc_clk_n),                       // ADC 'n' clk pin
	.reset_clk50(reset_clk50),                  // synchronously negated  
	.clk200(clk200),                            // for input pin timing delay settings
	.channel_tag(channel_tag[15:0]), 		   // stuff about the channel to put in the header
	.num_muon_bursts(num_muon_bursts[20:0]),  // number of sample bursts in a MUON fill
	.num_laser_bursts(num_laser_bursts[20:0]),// number of sample bursts in a LASER fill
	.num_ped_bursts(num_ped_bursts[20:0]),    // number of sample bursts in a PEDESTAL fill
	.initial_fill_num(initial_fill_num[23:0]),  // event number to assign to the first fill
	.initial_fill_num_wr(initial_fill_num_wr),  // write-strobe to store the initial_fill_num
    .acq_enable0(acq_enable0),              // indicates enabled for triggers, and fill type
	.acq_enable1(acq_enable1),              // indicates enabled for triggers, and fill type
	.acq_trig(acq_trig),                        // trigger the logic to start collecting data
	.acq_reset(acq_reset),                      // reset all of the acquisition logic
	.adc_buf_delay_data_reset(adc_buf_delay_data_reset),	// use the new delay settings
	.adc_buf_data_delay(adc_buf_data_delay[4:0]),	// 5 delay-tap-bits per line, all lines always all the same
	// outputs
	.acq_enabled(acq_enabled),					// the system is in acquisition mode, rather than readout mode
	.adc_buf_current_data_delay(adc_buf_current_data_delay[64:0]), // 13 lines *5 bits/line, current tap settings
	.fill_num(fill_num[23:0]),			         // fill number for this fill
	.adc_acq_out_dat(adc_acq_out_dat[127:0]),   // 128-bit header or ADC data
	.adc_acq_out_valid(adc_acq_out_valid),      // current data should be stored in the FIFO
	.adc_clk(adc_clk),					          // ADC clock used by the FIFO
	.adc_acq_full_reset(adc_acq_full_reset),	// reset all aspects of data collection/storage/readout
	.acq_done(acq_done)                         // acquisition is done
);
        
////////////////////////////////////////////////////////////////////////////
// Create a FIFO to buffer the data between the ADC block and the DDR3 block
ddr3_write_fifo ddr3_write_fifo (
	// inputs
	.rst(adc_acq_full_reset),       // reset at startup or when requested
	.wr_clk(adc_clk), 		       // clock extracted from ADC DDR clock
	.rd_clk(ddr3_domain_clk),       // clock extracted from DDR3 block
	.din(adc_acq_out_dat[127:0]),   // 128-bit header or ADC data
	.wr_en(adc_acq_out_valid),      // current data should be stored in the FIFO
	.rd_en(ddr3_wr_fifo_rd_en),     // use and remove the data on the FIFO head
	.dout(ddr3_wr_fifo_dat[127:0]), // data to be written to the DDR3
	.full(),                        // we don't currently use this
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
	.ddr3_wr_fifo_dat(ddr3_wr_fifo_dat[127:0]),			// input, data from the ddr3_write_fifo, to be written to the DDR3
	// reading connections
	.local_domain_clk(clk125),							// input, the local user synchronous clock
	.fill_header_fifo_empty(fill_header_fifo_empty),	// output, a header is available when not asserted
	.fill_header_fifo_rd_en(fill_header_fifo_rd_en),	// input, remove the current data from the FIFO
	.fill_header_fifo_out(fill_header_fifo_out[127:0]),	// output, data at the head of the FIFO
	.ddr3_rd_burst_addr(ddr3_rd_burst_addr[22:0]),		// input, the address of the requested 128-bit burst
	.ddr3_rd_one_burst(ddr3_rd_one_burst),				// input, get one 128-bit burst from the DDR3
	.ddr3_one_burst_rdy(ddr3_one_burst_rdy),			// output, the requested 128-bit burst is ready
	.ddr3_one_burst_data(ddr3_one_burst_data[127:0]),	// output, the requested 128-bit burst
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
	.ddr3_odt(ddr3_odt[0:0])
);

    

 
  ////////////////////////////////////////////////////////////////////////////
  // flash the led
  led_flasher led_flasher(.clk(clk50), .led(led1));

  ////////////////////////////////////////////////////////////////////////////
  // Connect the serial link to the Master FPGA.
  // This block may get pushed down in the hierarchy later.
  // The code below this is derived from the example design that
  // Vivado can generate. The Aurora block was set up with the "common logic" in
  // the example design, rather than in the core.
  wire reset_clk125N;
  assign reset_clk125N = !reset_clk125;
  all_channels channels(
    // clocks and reset
    .clk50(clk50),                            // Aurora 'init_clk' uses 50 MHz clock per PG046-20
    .clk50_reset(reset_clk50),                // active_hi synched to 'clk50'
    .axis_clk(clk125),                        // clock for the interconnect side of the FIFOs
    .axis_clk_resetN(reset_clk125N),          // active-lo reset for the interconnect side of the FIFOs
    .gt_refclk(gt_clk125),                    // 125 MHz oscillator(), from IBUFDS_GTE2 at a higher level
    // There is no IPbus on the CHANNEL FPGA
    // Eventually try to use I2C bus
    // For now, JTAG registers will be provided to read status 
    //
    // channel 0 connections
    // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
    // TX interface to slave side of transmit FIFO 
    .c0_s_axi_tx_tdata(c0_tx_axi_tdata[0:31]),        // note index order
    .c0_s_axi_tx_tkeep(c0_tx_axi_tkeep[0:3]),         // note index order
    .c0_s_axi_tx_tvalid(c0_tx_axi_tvalid),
    .c0_s_axi_tx_tlast(c0_tx_axi_tlast),
    .c0_s_axi_tx_tready(c0_tx_axi_tready),
    // RX Interface to master side of receive FIFO
    .c0_m_axi_rx_tdata(c0_rx_axi_tdata[0:31] ),       // note index order
    .c0_m_axi_rx_tkeep(c0_rx_axi_tkeep[0:3]),        // note index order
    .c0_m_axi_rx_tvalid(c0_rx_axi_tvalid),
    .c0_m_axi_rx_tlast(c0_rx_axi_tlast),
    .c0_m_axi_rx_tready(c0_rx_axi_tready),            // input wire m_axis_tready
    // serial I/O pins
    .c0_rxp(c0_rx), .c0_rxn(c0_rx_N),                   // receive from channel 0 FPGA
    .c0_txp(c0_tx), .c0_txn(c0_tx_N),                   // transmit to channel 0 FPGA
    .debug(debug[7:0])

  );

  // We need to swap the bit order for the RX and TX data
  wire [31:0] rx_tdata_swap, tx_tdata_swap;
  assign rx_tdata_swap[31:0] = c0_rx_axi_tdata[0:31];
  assign c0_tx_axi_tdata[0:31] = tx_tdata_swap[31:0];
  
  ///////////////////////////////////////////////////////////////////////////////////
  // Connect the command processor. This will receive commands from the Aurora serial
  // link and process them
 
  
  command_top command_top(
    // clocks and reset
	.clk50(clk50),              // 50 MHz buffered clock 
    .reset_clk50(reset_clk50),  // active-high reset output, goes low after startup
    .clk(clk125),                        // clock for the interconnect side of the FIFOs
    .resetN(reset_clk125N),          // active-lo reset for the interconnect side of the FIFOs
    // channel 0 connections
    // connections to 4-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
    // RX Interface to master side of receive FIFO for receiving from the Master FPGA
    .rx_data(rx_tdata_swap[31:0]),       // note index order
    .rx_tkeep(c0_rx_axi_tkeep[0:3]),        // note index order
    .rx_tvalid(c0_rx_axi_tvalid),
    .rx_tlast(c0_rx_axi_tlast),
    .rx_tready(c0_rx_axi_tready),            // input wire m_axis_tready
    // TX interface to slave side of transmit FIFO for sending to the Master FPGA 
    .tx_data(tx_tdata_swap[31:0]),        // note index order
    .tx_tkeep(c0_tx_axi_tkeep[0:3]),         // note index order
    .tx_tvalid(c0_tx_axi_tvalid),
    .tx_tlast(c0_tx_axi_tlast),
    .tx_tready(c0_tx_axi_tready),
	.readout_pause(readout_pause),		// stop sending fill data to the Aurora

	// interface to the ADC data memory and header FIFO
	.fill_header_fifo_empty(fill_header_fifo_empty),	// output, a header is available when not asserted
	.fill_header_fifo_rd_en(fill_header_fifo_rd_en),	// input, remove the current data from the FIFO
	.fill_header_fifo_out(fill_header_fifo_out[127:0]),	// output, data at the head of the FIFO
	.ddr3_rd_burst_addr(ddr3_rd_burst_addr[22:0]),		// input, the address of the requested 128-bit burst
	.ddr3_rd_one_burst(ddr3_rd_one_burst),				// input, get one 128-bit burst from the DDR3
	.ddr3_one_burst_rdy(ddr3_one_burst_rdy),			// output, the requested 128-bit burst is ready
	.ddr3_one_burst_data(ddr3_one_burst_data[127:0]),	// output, the requested 128-bit burst

	// Registers to/from the ADC acquisition state machine
	.fill_num(fill_num[23:0]),			         // fill number for this fill
	.channel_tag(channel_tag[15:0]), 		   // stuff about the channel to put in the header
	.num_muon_bursts(num_muon_bursts[20:0]),  // number of sample bursts in a MUON fill
	.num_laser_bursts(num_laser_bursts[20:0]),// number of sample bursts in a LASER fill
	.num_ped_bursts(num_ped_bursts[20:0]),    // number of sample bursts in a PEDESTAL fill
	.initial_fill_num(initial_fill_num[23:0]),  // event number to assign to the first fill
	.initial_fill_num_wr(initial_fill_num_wr),  // write-strobe to store the initial_fill_num
	.ch_addr(ch_addr[2:0]),						// the channel address jumpers
	.adc_buf_delay_data_reset(adc_buf_delay_data_reset),	// use the new delay settings
	.adc_buf_data_delay(adc_buf_data_delay[4:0]),	// 5 delay-tap-bits per line, all lines always all the same
	.adc_buf_current_data_delay(adc_buf_current_data_delay[64:0]), // 13 lines *5 bits/line, current tap settings
 
	.genreg_addr_ctrl(genreg_addr_ctrl[31:0]),
	.genreg_wr_data(genreg_wr_data[31:0]),
	.genreg_rd_data(genreg_rd_data[31:0])

);


gen_reg gen_reg(
	.clk(clk50),
	.reset(reset_clk50),
	.addr_ctrl(genreg_addr_ctrl[31:0]),
	.data_in(genreg_wr_data[31:0]),
	.data_out(genreg_rd_data[31:0]),
	.adc_intf_data_in(adc_intf_rd_data[31:0]),		// data word from adc serial interface
	.adc_intf_data_out(adc_intf_wr_data[31:0]),		// data word to adc serial interface
	.debug()
);

//*************************************************************************
// adc serial interface
//*************************************************************************
adc_intf adc_intf(
	.clk(clk50),
	.reset(reset_clk50),
	.data_in(adc_intf_wr_data[31:0]),
	.data_out(adc_intf_rd_data[31:0]),
	.sclk(adc_sdclk),
 	.sdio(adc_sdio),
	.sdi(adc_sdo),
  	.sdenb(adc_sdenb),
  	.sresetb(adc_sresetb),
  	.enable(adc_enable),
	.debug()
);

endmodule

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

  // Use io[3] for a 'reset' and io[2] for 'acq_arm'
  wire acq_arm;
  assign acq_arm = io[2];

  wire rst;
  assign rst = io[3];

  wire [31:0] ADC_buffer_size;		// number of words in the data stream (2 samples per word)
  wire [31:0] ADC_channel_num;		// the number for this channel
  wire [31:0] ADC_post_trig_size;	// number of words to continue acquiring after a trigger
  wire [31:0] ADC_initial_trig_num;	// initial value for the event number
  wire ADC_trig_num_we;				// enable saving of the initial value for the event number
  wire [31:0] ADC_current_trig_num;	// the current value for the event number

  // Define the AXIS-fifo inputs and outputs for chan 0
  wire [0:31] c0_rx_axi_tdata, c0_tx_axi_tdata;
  wire [0:3] c0_rx_axi_tkeep, c0_tx_axi_tkeep;
  wire c0_rx_axi_tvalid, c0_tx_axi_tvalid;
  wire c0_rx_axi_tlast, c0_tx_axi_tlast;
  wire c0_rx_axi_tready, c0_tx_axi_tready;

  // Define connection to the ADC data memory and ADC header FIFO
  wire [11:0] ADC_data_mem_addra, ADC_data_mem_addrb;
  wire [31:0] ADC_data_mem_dina, ADC_data_mem_doutb;
  wire ADC_data_mem_wea;  
  wire [31:0] ADC_header_fifo_din, ADC_header_fifo_dout;
  wire ADC_header_fifo_wr_en, ADC_header_fifo_rd_en;
  wire ADC_header_fifo_full, ADC_header_fifo_empty;

  ////////////////////////////////////////////////////////////////////////////
  // Clock and reset handling
  // Connect an input buffer and a global clock buffer to the 50 MHz clock
  wire clkin_buf, clk50;
  IBUF IBUF_clkin (.I(clkin), .O(clkin_buf));
  BUFG BUFG_clk50 (.I(clkin_buf), .O(clk50));
  
  // differential clock buffer - This should get shared between the Aurora channel interfaces
  // and other internal logic.
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
  assign debug[2:0] = acq_trig ? ch_addr[2:0] : 3'h0;
  assign debug[5:3] = acq_trig ? power_good[2:0]: 3'h0;
  assign debug[9:6] = acq_trig ? io[3:0]: 4'h0;
  IBUFDS adc_sync_in (.I(adc_syncp), .IB(adc_syncn), .O(adc_sync));
  assign adc_sdio = adc_sdo || adc_sync;
  assign adc_sdclk = 1'b0;
  assign adc_sdenb = 1'b0;
  assign adc_sresetb = 1'b1;
  assign adc_enable = 1'b1;
  //assign acq_done = acq_trig;
  
//  ////////////////////////////////////////////////////////////////////////////
//  // Connect the ADC signals
//  // assert 'adc_reset' until the clock is stable
//  adc_startup_reset adc_startup_reset(
//    .adc_clk(adc_clk),			// buffered clock, 250 MHz
//    .reset_adc_clk(reset_adc_clk)	// active-high reset output, goes low after startup
//  );

  // A good note on DDR timing
  // http://forums.xilinx.com/t5/Timing-Analysis/XDC-constraints-Source-Synchronous-ADC-DDR/td-p/292807
  // Combine the ADC data 'p' pins and 'n' pins. Put the over-range into the LSB
  wire [12:0] adc_in_p, adc_in_n;
  wire [25:0] packed_adc_dat;    // two samples packed in one wide-word
  assign adc_in_p = {adc_d11p, adc_d10p, adc_d9p, adc_d8p, adc_d7p, adc_d6p, adc_d5p, adc_d4p, adc_d3p, adc_d2p, adc_d1p, adc_d0p, adc_dovrp};
  assign adc_in_n = {adc_d11n, adc_d10n, adc_d9n, adc_d8n, adc_d7n, adc_d6n, adc_d5n, adc_d4n, adc_d3n, adc_d2n, adc_d1n, adc_d0n, adc_dovrn};
  // Use a SelectIO Wizard DDR input buffer
  selectio_wiz_0 adc_dat_buf (
    .data_in_from_pins_p(adc_in_p),             // input wire [12 : 0] data_in_from_pins_p
    .data_in_from_pins_n(adc_in_n),             // input wire [12 : 0] data_in_from_pins_n
    .clk_in_p(adc_clk_p),                        // input wire clk_in_p
    .clk_in_n(adc_clk_n),                        // input wire clk_in_n
    .io_reset(reset_clk50),                        // input wire io_reset
    //.ref_clock(adc_clk),                        // loop ADC_CLK back around for input timing delay settings
    .clk_out(real_adc_clk),                          // output wire clk_out
    .data_in_to_device(packed_adc_dat)          // output wire [25 : 0] data_in_to_device
  );
  
  // use clk125 to run the ADC memory, header FIFO, and acquisition controller
  assign adc_clk = real_adc_clk;
  // assign adc_clk = clk125;
  
  // put the packed 26-bit ADC data into a 32-bit word for writing to the memory
  // try to do sign-extension of the 13-bit words to 16-bit words (if timing allows)
  // comment out while registers are driving the memory
  assign ADC_data_mem_dina[12:0]  = packed_adc_dat[12:0];
  assign ADC_data_mem_dina[15:13] = (packed_adc_dat[12] == 1'b1) ? 3'b1: 3'b0;
  assign ADC_data_mem_dina[28:16] = packed_adc_dat[25:13];
  assign ADC_data_mem_dina[31:29] = (packed_adc_dat[25] == 1'b1) ? 3'b1: 3'b0;
 
   
  ////////////////////////////////////////////////////////////////////////////
  // Create a dual-port memory for the ADC data
  // The write-only "A" port will be connected to the ADC acquisition controller.
  // The read-only "B" port will be connected to the readout controller

  // Use registers to write to the "A" side until there is an ADC controller
  // Use 'clk125' with the registers, instead of 'adc_clk'
  ADC_data_mem ADC_data_mem (	
  .clka(adc_clk),    // input wire clka
  .wea(ADC_data_mem_wea),      // input wire [0 : 0] wea
  .addra(ADC_data_mem_addra),  // input wire [11 : 0] addra
  .dina(ADC_data_mem_dina),    // input wire [31 : 0] dina
  .clkb(clk125),    // input wire clkb
  .addrb(ADC_data_mem_addrb),  // input wire [11 : 0] addrb
  .doutb(ADC_data_mem_doutb)  // output wire [31 : 0] doutb
);

  ////////////////////////////////////////////////////////////////////////////
  // Create a FIFO for the ADC header info
  // The write port will be connected to the ADC acquisition controller.
  // The read port will be connected to the readout controller

  // Use registers to write to the FIFO until there is an ADC controller
  // Use 'clk125' with the input side, instead of 'adc_clk'

  ADC_header_fifo ADC_header_fifo (
	.rst(reset_clk125),        // input wire rst
	.wr_clk(adc_clk),  // input wire wr_clk
	.rd_clk(clk125),  // input wire rd_clk
	.din(ADC_header_fifo_din),        // input wire [31 : 0] din
	.wr_en(ADC_header_fifo_wr_en),    // input wire wr_en
	.rd_en(ADC_header_fifo_rd_en),    // input wire rd_en
	.dout(ADC_header_fifo_dout),      // output wire [31 : 0] dout
	.full(ADC_header_fifo_full),      // output wire full
	.empty(ADC_header_fifo_empty)    // output wire empty
);

  ////////////////////////////////////////////////////////////////////////////
  // Connect the ADC acquisition state machine
  adc_acquisition_control_sm adc_acquisition_control_sm(
	.clk(adc_clk),					// 400 MHz ADC clock !!! USE REAL ADC CLOCK WHEN AVAILABLE
	.arm(acq_arm),					// arm or reset the acquisition controller
	.trig(acq_trig),				// we have been triggered
	.done(acq_done),				// acquisition for the current trigger is complete
	// interface to the ADC data memory and header FIFO
	.data_mem_wea(ADC_data_mem_wea),					// enable writing to the ADC data memory
	.data_mem_addra(ADC_data_mem_addra),				// address for writing to the ADC data memory
	.header_fifo_wr_en(ADC_header_fifo_wr_en),			// enable writing to the ADC header FIFO
	.header_data(ADC_header_fifo_din),					// data to put in the ADC header FIFO 
	// data for the ADC header FIFO and/or for local control
	// The buffer_size, channel_num, post_trig_size, and initial_trig_num are from the register block/
	// They are stable during operation, so do not need synchronization. The 'initial_even_num_we' signal
	// will need to be synched. The current_trig_num is provided for register readback
	.buffer_size(ADC_buffer_size),			// number of words in the data stream (2 samples per word)
	.channel_num(ADC_channel_num),			// the number for this channel
	.post_trig_size(ADC_post_trig_size),	// number of words to continue acquiring after a trigger
	.initial_trig_num(ADC_initial_trig_num),// initial value for the event number
	.trig_num_we(ADC_trig_num_we),			// enable saving of the initial value for the event number
	.current_trig_num(ADC_current_trig_num),	// the current value for the event number
  .rst(rst), // reset from the master
  .led2(led2) // green led
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
    .c0_txp(c0_tx), .c0_txn(c0_tx_N)                   // transmit to channel 0 FPGA
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
	// interface to the ADC data memory and header FIFO
	.ADC_data_mem_addrb(ADC_data_mem_addrb),		// output wire [11 : 0] addrb
    .ADC_data_mem_doutb(ADC_data_mem_doutb),		// input wire [31 : 0] doutb
	.ADC_header_fifo_rd_en(ADC_header_fifo_rd_en),	// output wire rd_en
	.ADC_header_fifo_dout(ADC_header_fifo_dout),	// input wire [31 : 0] dout
	.ADC_header_fifo_empty(ADC_header_fifo_empty),	// input wire empty
	// temporary use of registers to write to the ADC memory and ADC header FIFO
	// Signal connection have been removed in order to use the real ADC acquisition controller
	.ADC_data_mem_wea(), 						    // WAS .ADC_data_mem_wea(ADC_data_mem_wea),
	.ADC_data_mem_addra(),                          // WAS .ADC_data_mem_addra(ADC_data_mem_addra),
	.ADC_data_mem_dina(),				    		// WAS .ADC_data_mem_dina(ADC_data_mem_dina),
	.ADC_header_fifo_din(),							// WAS .ADC_header_fifo_din(ADC_header_fifo_din),
	.ADC_header_fifo_wr_en(),						// WAS .ADC_header_fifo_wr_en(ADC_header_fifo_wr_en),
	// Registers to/from the ADC acquisition state machine
	.ADC_buffer_size(ADC_buffer_size),		// number of words in the data stream (2 samples per word)
	.ADC_channel_num(ADC_channel_num),		// the number for this channel
	.ADC_post_trig_size(ADC_post_trig_size),	// number of words to continue acquiring after a trigger
	.ADC_initial_trig_num(ADC_initial_trig_num),	// initial value for the event number
	.ADC_trig_num_we(ADC_trig_num_we),				// enable saving of the initial value for the event number
	.ADC_current_trig_num(ADC_current_trig_num)	// the current value for the event number

);

///// COMMENT OUT DDR3 MEMORY
//  // Make 200 MHz from 125 MHz, needed by the DDR3 function
//  wire clk200;
//  clk_wiz_0 clk_wiz_200 (
//   // Clock in ports
//    .clk_in1(clk125),      // input clk_in1
//    // Clock out ports
//    .clk_out1(clk200));    // output clk_out1
//
//  wire tg_compare_error, init_calib_complete;
// assign led2 = tg_compare_error | init_calib_complete;
//  ////////////////////////////////////////////////////////////////////////
//  // Connect the example DDR3 memory files.
//  // Inouts
//  example_top ddr3_example_top (
//    .ddr3_dq(ddr3_dq),
//    .ddr3_dqs_n(ddr3_dqs_n),
//    .ddr3_dqs_p(ddr3_dqs_p),
//    // Outputs
//    .ddr3_addr(ddr3_addr),
//    .ddr3_ba(ddr3_ba),
//    .ddr3_ras_n(ddr3_ras_n),
//    .ddr3_cas_n(ddr3_cas_n),
//    .ddr3_we_n(ddr3_we_n),
//    .ddr3_reset_n(ddr3_reset_n),
//    .ddr3_ck_p(ddr3_ck_p),
//    .ddr3_ck_n(ddr3_ck_n),
//    .ddr3_cke(ddr3_cke),
//    .ddr3_dm(ddr3_dm),
//    .ddr3_odt(ddr3_odt),
//    // Inputs
//    // Single-ended system clock
//   .sys_clk_i(clk125),
//    // Single-ended iodelayctrl clk (reference clock)
//    .clk_ref_i(clk200),
//    .tg_compare_error(tg_compare_error),
//    .init_calib_complete(init_calib_complete),
//    // System reset - Default polarity of sys_rst pin is Active Low.
//    // System reset polarity will change based on the option 
//    // selected in GUI.
//    .sys_rst(reset_clk125N)
//  );

  ////////////////////////////////////////////////////////////////////////////
  // dummy logic for DDR3 SDRAM
  // internal wires associated with differential buffers
  wire ddr_ckp_OBUFDS_in;
  wire ddr_ldqsp_OBUFDS_in;
  wire ddr_udqsp_OBUFDS_in;
  // differential buffers
  OBUFDS ddr_ckp_OBUFDS (.I(ddr_ckp_OBUFDS_in), .O(ddr3_ck_p), .OB(ddr3_ck_n));
  OBUFDS ddr_ldqsp_OBUFDS (.I(ddr_ldqsp_OBUFDS_in), .O(ddr3_dqs_p[0]), .OB(ddr3_dqs_n[0]));
  OBUFDS ddr_udqsp_OBUFDS (.I(ddr_udqsp_OBUFDS_in), .O(ddr3_dqs_p[1]), .OB(ddr3_dqs_n[1]));
  // assignments to keep memory chip inactive
  assign ddr3_addr[12:0] = 13'h0000;
  assign ddr3_ba[2:0] = 3'h0;
  assign ddr_ckp_OBUFDS_in = clk50;  // may not be needed, but run a clock to the memory 
  assign ddr3_cke = 1'b0;               // this should put chip in power-down mode
  assign ddr3_dm[1:0] = 2'b0;
  assign ddr3_odt[0] = 1'b0;
  assign ddr3_cas_n = 1'b1;
  assign ddr3_ras_n = 1'b1;
  assign ddr3_we_n = 1'b1;
  assign ddr3_reset_n = 1'b1;
  assign ddr3_dq[15:0] = 16'hzzzz;
  assign ddr_ldqsp_OBUFDS_in = 1'b0;
  assign ddr_udqsp_OBUFDS_in = 1'b0;


endmodule

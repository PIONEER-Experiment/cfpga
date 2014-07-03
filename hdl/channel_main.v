`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// G-2 WFD1 prototype Channel FPGA
//
// Notes:
//  1) ADC data bits D4, D6, D7, D8, and D9 were renumbered in 'ios.xdc' to conform with
//     the numbering on the schematic.
//  2) The 'adc_ovrp' and 'adc_ovrn' signals are cross-wired on the schematic, with the
//     positive signal going to the negative input, and the negative signal going to the
//     positive input. This will have the effect of inverting the OVR signal such that it
//     will be LOW when the input exceeds the full scale range. We may want to invert it
//     somewhere in the signal chain.
//  3) The 'adc_dryp' and 'adc_dryn' clock signals are cross-wired on the schematic, with the
//     positive signal going to the negative input, and the negative signal going to the
//     positive input. This will have the effect of inverting the ADC clock signal. According
//     to footnote #1 on page 9 of the ADS5463 data sheet, the ploarity of 'dry' is undetermined,
//     so this does not matter.
//  4) The ADC over-range signals were renamed from 'adc_ovrp/n' to 'adc_dovrp/n'. This was done
//     to include these signals in the wildcard grouping of the ADC data pins.
//  5) The ADC 'data ready' signals were renamed from 'adc_dryp/n' to 'adc_clk_p/n'. This was done
//     to allow wildcards in grouping the ADC data pins, and to reflect the usage of this signal
//     as the clock for bringing in the ADC data.
//  6) The 'receive' signals 'ch0' and 'ch1' were changed to 'c0' and 'c1' to conform
//     with the other two channels and with the 'transmit' signals.
//  7) A complex timing constraint setup is applied in 'timing.xdc' for the ADC data and clock. It
//     may not be correct, but it implements without errors.
//  8) All of the DDR memory signals were renamed to conform to the "Memory Interface Generator"
//     requirements. This was before discovering that the Wizard is unhappy with the pin assignments.
//  9) The DDR memory is fully disabled. Active-lo signals are high, active-hi signals are low,
//     busses are tri-state.
//  10) An attempt was made to put the IP for the Aurora serial interface into a 'shared' directory
//    (shared between master and channel). This does not work because the IP get specific part number
//    stuff embedded in it. Each different part number needs its own IP instance.
//////////////////////////////////////////////////////////////////////////////////
module channel_main(
  // Utility
  output [9:0] debug,           // to 10-pin header
  input [2:0] ch_addr,          // will be 3'b111, this chip's address, from pullup/pulldown
  input [2:0] power_good,       // from regulators, active-hi, #2=1.8v, #1=1.2v, #0=1.0v
  input clkin,                  // 50 MHz oscillator
  input acq_trig,               // from master, asserted active-hi to start acquisition, C0_TRIG on schematic
  output acq_done,              // to master, asserted active-hi at the end of acquisition, C0_DONE on schematic
  output led1, led2,            // multi color LED, [1=0,2=0]-> , [1=0,2=1]-> , [1=1,2=0]-> , [1=1,2=1]->  
  input bbus_scl,   // SHOULD BE "INOUT" I2C bus clock, from I2C master, connected to Atmel Chip, Master FPGA, and to other Channel FPGAs
  input bbus_sda,   // SHOULD BE "INOUT" I2C bus data, connected to Atmel Chip, MAster FPGA, and to other Channel FPGAs
  // serial interfaces
  // These have been commented out of "ios.xdc". They must be uncommented as they are used.
  input c0_rx, c0_rx_N,       // Serial data from the master for this channel
  //input c1_rx, c1_rx_N,       // NOT FOR PRODUCTION, connection from the master for the prototype board 
  //input c2_rx, c2_rx_N,        // NOT FOR PRODUCTION, connection from the master for the prototype board
  //input c3_rx, c3_rx_N,        // NOT FOR PRODUCTION, connection from the master for the prototype board
  output c0_tx, c0_tx_N,        // Serial data to the master for this channel
  //output c1_tx, c1_tx_N,        // NOT FOR PRODUCTION, connection to the master for the prototype board
  //output c2_tx, c2_tx_N,        // NOT FOR PRODUCTION, connection to the master for the prototype board
  //output c3_tx, c3_tx_N,        // NOT FOR PRODUCTION, connection to the master for the prototype board
  input xcvr_clk, xcvr_clk_N,   // 125 MHz oscillator, connected to 'clk0' (not 'clk1') 
  // DDR Memory
  output [2:0] ddr3_ba,
  output [12:0] ddr3_addr,
  inout [15:0] ddr3_dq,
  output ddr3_cas_n,
  output ddr3_cke,
  output ddr3_ck_n, ddr3_ck_p,
  output ddr3_cs_n,
  output [1:0] ddr3_dm,
  inout [1:0] ddr3_dqs_n, ddr3_dqs_p,
  output ddr3_odt,
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
  input adc_clk_n, adc_clk_p,     // 250 MHz sample clock from ADC chip
  input adc_dovrn, adc_dovrp      // over-range
);

    // Define the AXIS-fifo inputs and outputs for chan 0
    wire [0:31] c0_rx_axi_tdata, c0_tx_axi_tdata;
    wire [0:3] c0_rx_axi_tkeep, c0_tx_axi_tkeep;
    wire c0_rx_axi_tvalid, c0_tx_axi_tvalid;
    wire c0_rx_axi_tlast, c0_tx_axi_tlast;
    wire c0_rx_axi_tready, c0_tx_axi_tready;

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
  // Dummy synchronizers for use during partial implementation
  // make a synchronizer to bring 'acq_trig' into the 50 MHz clock domain
  (* IOB = "true" *) reg acq_trig_reg;
  always @(posedge clk50) begin
    acq_trig_reg <= acq_trig;
  end 
  wire dummy_source50;
  sync_2stage dummy1(.in(acq_trig_reg), .clk(clk50), .out(dummy_source50));


  ////////////////////////////////////////////////////////////////////////////
  // dummy assignments to keep logic around
  assign led2 = dummy_source50;
  assign acq_done = dummy_source50;
  assign debug[2:0] = dummy_source50 ? ch_addr[2:0] : 3'h0;
  assign debug[5:3] = dummy_source50 ? power_good[2:0]: 3'h0;
  assign debug[9:6] = dummy_source50 ? 4'hf : 4'h0;
  
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
  // assignments to keep000000000000000000000000000 memory chip inactive
  assign ddr3_addr[12:0] = 13'h0000;
  assign ddr3_ba[2:0] = 3'h0;
  assign ddr_ckp_OBUFDS_in = clk50;  // may not be needed, but run a clock to the memory 
  assign ddr3_cke = 1'b0;               // this should put chip in power-down mode
  assign ddr3_cs_n = 1'b1;
  assign ddr3_dm[1:0] = 2'b0;
  assign ddr3_odt = 1'b0;
  assign ddr3_cas_n = 1'b1;
  assign ddr3_ras_n = 1'b1;
  assign ddr3_we_n = 1'b1;
  assign ddr3_reset_n = 1'b1;
  assign ddr3_dq[15:0] = 16'hzzzz;
  assign ddr_ldqsp_OBUFDS_in = 1'b0;
  assign ddr_udqsp_OBUFDS_in = 1'b0;

  ////////////////////////////////////////////////////////////////////////////
  // Connect the ADC signals
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
    .clk_out(adc_clk),                          // output wire clk_out
    .data_in_to_device(packed_adc_dat)          // output wire [25 : 0] data_in_to_device
  );

  // do something to keep some packed data around
  reg [25:0] adc_temp;
  reg adc_zero_reg;
  always @(posedge adc_clk) begin
    adc_temp <= packed_adc_dat; // move the DDR output to a temporary register
    if (adc_temp[12:0] == adc_temp[25:13]) adc_zero_reg <= 1'b1;
    else adc_zero_reg <= 1'b0;
  end
 
  ////////////////////////////////////////////////////////////////////////////
  // flash the led, and temporarily consume adc_zero_reg
  led_flasher led_flasher(.clk(clk50), .led(led1), .temporary_in(adc_zero_reg));

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
    .tx_tready(c0_tx_axi_tready)
);
	

endmodule

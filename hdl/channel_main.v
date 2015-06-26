`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////
// Top-level module for g-2 WFD5 Channel FPGA
//
// Notes:
// 1) There is only one link to the Master FPGA. It is chan 0.
//
//////////////////////////////////////////////////////////////

// as a useful reference, here's the syntax to mark signals for debug:
// (* mark_debug = "true" *) 

module channel_main(
  // Utility
  output [9:0] debug,           // to 10-pin header
  input [2:0] ch_addr,          // will be 3'b111, this chip's address, from pullup/pulldown
  input [2:0] power_good,       // from regulators, active-hi, #2=1.8v, #1=1.2v, #0=1.0v
  input clkin,                  // 50 MHz oscillator
  input acq_trig,               // from master, asserted active-hi to start acquisition, C0_TRIG on schematic
  output acq_done,              // to master, asserted active-hi at the end of acquisition, C0_DONE on schematic
  input [3:0] io,               // connections to the master FPGA
  output led1, led2,            // multi color LED, [1=0,2=0]-> red + green = orange, [1=0,2=1]-> red, [1=1,2=0]-> green, [1=1,2=1]-> off 
  input bbus_scl,               // I2C bus clock, from I2C master, connected to Atmel Chip, Master FPGA, and to other Channel FPGAs
  input bbus_sda,               // I2C bus data, connected to Atmel Chip, Master FPGA, and to other Channel FPGAs

  // Serial interfaces
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
  input adc_d0n, adc_d0p,       // Sample bit  0 from ADC chip
  input adc_d1n, adc_d1p,       // Sample bit  1 from ADC chip
  input adc_d2n, adc_d2p,       // Sample bit  2 from ADC chip
  input adc_d3n, adc_d3p,       // Sample bit  3 from ADC chip
  input adc_d4n, adc_d4p,       // Sample bit  4 from ADC chip
  input adc_d5n, adc_d5p,       // Sample bit  5 from ADC chip
  input adc_d6n, adc_d6p,       // Sample bit  6 from ADC chip
  input adc_d7n, adc_d7p,       // Sample bit  7 from ADC chip
  input adc_d8n, adc_d8p,       // Sample bit  8 from ADC chip
  input adc_d9n, adc_d9p,       // Sample bit  9 from ADC chip
  input adc_d10n, adc_d10p,     // Sample bit 10 from ADC chip
  input adc_d11n, adc_d11p,     // Sample bit 11 from ADC chip
  input adc_clk_n, adc_clk_p,   // 400 MHz sample clock from ADC chip
  input adc_dovrn, adc_dovrp,   // over-range bit from ADC chip
  input adc_sdo,
  output adc_sdio,
  output adc_sdclk,
  output adc_sdenb,
  output adc_sresetb,
  output adc_enable,
  input adc_syncp, adc_syncn
);

// Assignments for 'io' lines:
//   io[0]   : 'readout_pause'
//   io[1:2] : 'acq_enable'
//   io[3]   : 'acq_reset'
wire acq_reset;
assign acq_reset = io[3];
wire acq_enable0;                       // indicates enabled for triggers, and fill type
wire acq_enable1;                       // indicates enabled for triggers, and fill type
assign acq_enable0 = io[1];
assign acq_enable1 = io[2];
wire readout_pause;
assign readout_pause = io[0];           // stop sending fill data to the Aurora

wire [15:0] channel_tag;                // stuff about the channel to put in the header
wire [20:0] num_muon_bursts;            // number of sample bursts in a MUON fill
wire [20:0] num_laser_bursts;           // number of sample bursts in a LASER fill
wire [20:0] num_ped_bursts;             // number of sample bursts in a PEDESTAL fill
wire [23:0] initial_fill_num;           // event number to assign to the first fill
wire [127:0] adc_acq_out_dat;           // 128-bit header or ADC data to 'ddr3_write_fifo'

wire adc_acq_out_valid;
wire [127:0] ddr3_wr_fifo_dat;          // 128-bit header or ADC data from 'ddr3_write_fifo'
wire [127:0] ddr3_rd_dat;               // 128-bit header or ADC data from DDR3 memory
wire [23:0] fill_num;                   // fill number for this fill
wire [127:0] ddr3_rd_fifo_input_dat;    // memory burst headed toward 'ddr3_read_fifo'
wire [127:0] ddr3_rd_fifo_output_dat;   // memory burst headed toward 'ddr3_read_data_width_converter'
wire [31:0] ddr3_32bit_tx_tdata;        // 32-bit chunks of memory burst headed toward 'axis_interconnect'
wire [22:0] ddr3_rd_start_addr;         // the address of the first requested 128-bit burst
wire [20:0] ddr3_rd_burst_cnt;          // number of bursts to read from the DDR3
wire [31:0] command_tx_tdata;           // data to Aurora from 'command_top'
wire [31:0] rx_tdata_swap;              // bit-reversed data from Aurora

// Define the AXIS FIFO inputs and outputs for chan 0
wire [0:31] c0_rx_axi_tdata, c0_tx_axi_tdata;
wire [0:3] c0_rx_axi_tkeep;
wire c0_rx_axi_tvalid, c0_tx_axi_tvalid;
wire c0_rx_axi_tlast, c0_tx_axi_tlast;
wire c0_rx_axi_tready, c0_tx_axi_tready;

// Generic register interface
wire [31:0] genreg_addr_ctrl;
wire [31:0] genreg_wr_data;
wire [31:0] genreg_rd_data;
wire [31:0] adc_intf_rd_data;
wire [31:0] adc_intf_wr_data;

wire [127:0] fill_header_fifo_out;
wire [22:0] ddr3_rd_burst_addr;

wire [4:0] adc_buf_data_delay;
wire [64:0] adc_buf_current_data_delay;

//wire [7:0] debug_wires;
//assign debug[7:0] = debug_wires[7:0];

// status signals for front panel LED
wire aurora_channel_up;
wire adc_acq_sm_idle;
wire command_sm_idle;

////////////////////////////////////////////////////////////////////////////
// Clock and reset handling
// Connect an input buffer and a global clock buffer to the 50 MHz clock
wire clk50, clk200, clk250;

g2_chan_clks clk_dcm_50_200 (
    // Clock in ports
    .clk_in1(clkin),        // input, unbuffered 50 MHz from pin 
    // Clock out ports
    .clk_50M(clk50),        // output, 50 MHz
    .clk_200M(clk200),      // output, 200 MHz
    .clk_250M(clk250)       // output, 250 MHz
    // Status and control signals
    //.reset(1'b0),         // input, unused reset
    //.locked()             // output, unused locked
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
    .clk125(clk125),            // buffered clock, 125 MHz
    .reset_clk125(reset_clk125) // active-high reset output, goes low after startup
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
    .adc_in_p(adc_in_p[11:0]),                           // [11:0] array of ADC 'p' data pins
    .adc_in_n(adc_in_n[11:0]),                           // [11:0] array of ADC 'n' data pins
    .adc_ovr_p(adc_dovrp),                               // ADC 'p' over-range pin
    .adc_ovr_n(adc_dovrn),                               // ADC 'n' over-range pin
    .adc_clk_p(adc_clk_p),                               // ADC 'p' clk pin
    .adc_clk_n(adc_clk_n),                               // ADC 'n' clk pin
    .reset_clk50(reset_clk50),                           // synchronously negated  
    .clk200(clk200),                                     // for input pin timing delay settings
    .channel_tag(channel_tag[15:0]),                     // stuff about the channel to put in the header
    .num_muon_bursts(num_muon_bursts[20:0]),             // number of sample bursts in a MUON fill
    .num_laser_bursts(num_laser_bursts[20:0]),           // number of sample bursts in a LASER fill
    .num_ped_bursts(num_ped_bursts[20:0]),               // number of sample bursts in a PEDESTAL fill
    .initial_fill_num(initial_fill_num[23:0]),           // event number to assign to the first fill
    .initial_fill_num_wr(initial_fill_num_wr),           // write-strobe to store the initial_fill_num
    .acq_enable0(acq_enable0),                           // indicates enabled for triggers, and fill type
    .acq_enable1(acq_enable1),                           // indicates enabled for triggers, and fill type
    .acq_trig(acq_trig),                                 // trigger the logic to start collecting data
    .acq_reset(acq_reset),                               // reset all of the acquisition logic
    .adc_buf_delay_data_reset(adc_buf_delay_data_reset), // use the new delay settings
    .adc_buf_data_delay(adc_buf_data_delay[4:0]),        // 5 delay-tap-bits per line, all lines always all the same
    .ddr3_wr_done(ddr3_wr_done),                         // asserted when the 'ddr3_wr_control' is in the DONE state

    // outputs
    .acq_enabled(acq_enabled),                           // the system is in acquisition mode, rather than readout mode
    .adc_buf_current_data_delay(adc_buf_current_data_delay[64:0]), // 13 lines *5 bits/line, current tap settings
    .fill_num(fill_num[23:0]),                           // fill number for this fill
    .adc_acq_out_dat(adc_acq_out_dat[127:0]),            // 128-bit header or ADC data
    .adc_acq_out_valid(adc_acq_out_valid),               // current data should be stored in the FIFO
    .adc_clk(adc_clk),                                   // ADC clock used by the FIFO
    .adc_acq_full_reset(adc_acq_full_reset),             // reset all aspects of data collection/storage/readout
    .acq_done(acq_done),                                 // acquisition is done
    .adc_acq_sm_idle(adc_acq_sm_idle)                    // ADC acquisition state machine is idle (used for front panel LED status)
);

wire ddr3_write_fifo_full;
        
////////////////////////////////////////////////////////////////////////////
// Create a FIFO to buffer the data between the ADC block and the DDR3 block
ddr3_write_fifo ddr3_write_fifo (
    // inputs
    .rst(adc_acq_full_reset),       // reset at startup or when requested
    .wr_clk(adc_clk),               // clock extracted from ADC DDR clock
    .rd_clk(ddr3_domain_clk),       // clock extracted from DDR3 block
    .din(adc_acq_out_dat[127:0]),   // 128-bit header or ADC data
    .wr_en(adc_acq_out_valid),      // current data should be stored in the FIFO
    .rd_en(ddr3_wr_fifo_rd_en),     // use and remove the data on the FIFO head
    .dout(ddr3_wr_fifo_dat[127:0]), // data to be written to the DDR3
    .full(ddr3_write_fifo_full),    // we don't currently use this
    .empty(ddr3_wr_fifo_empty)      // data is available when this is not asserted
);

////////////////////////////////////////////////////////////////////////////
// Connect the DDR3 interface
ddr3_intf ddr3_intf(

    // clocks and resets
    .refclk(clk200),                    // input, 200 MHz for I/O timing adjustments
    .sysclk(clk200),                    // input, drives the Xilinx DDR3 IP
    .reset(adc_acq_full_reset),         // input, reset at startup or when requested by master FPGA 
    .ddr3_domain_clk(ddr3_domain_clk),  // output, the DDR3 user-interface synchronous clock

    // writing connections
    .acq_enabled(acq_enabled),                   // the system is in acquisition mode, rather than readout mode
    .ddr3_wr_fifo_empty(ddr3_wr_fifo_empty),     // input, data is available when this is not asserted
    .ddr3_wr_fifo_rd_en(ddr3_wr_fifo_rd_en),     // output, use and remove the data on the FIFO head
    .ddr3_wr_fifo_dat(ddr3_wr_fifo_dat[127:0]),  // input, data from the ddr3_write_fifo, to be written to the DDR3
    .ddr3_wr_sync_err(),                         // synchronization error flag
    .ddr3_wr_done(ddr3_wr_done),                 // asserted when the 'ddr3_wr_control' is in the DONE state
    .acq_done(acq_done),                         // input, acquisition is done

    // reading connections
    .local_domain_clk(clk125),                           // input, the local user synchronous clock
    .fill_header_fifo_empty(fill_header_fifo_empty),     // output, a header is available when not asserted
    .fill_header_fifo_rd_en(fill_header_fifo_rd_en),     // input, remove the current data from the FIFO
    .fill_header_fifo_out(fill_header_fifo_out[127:0]),  // output, data at the head of the FIFO
    .ddr3_rd_start_addr(ddr3_rd_start_addr[22:0]),       // input, the address of the first requested 128-bit burst
    .ddr3_rd_burst_cnt(ddr3_rd_burst_cnt[20:0]),         // input, the number of bursts to read
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
    .app_rdy()
);

////////////////////////////////////////////////////////////////////////////
// Create a FIFO to buffer the data from the DDR3 block
ddr3_read_fifo ddr3_read_fifo(
    .m_aclk(clk125),
    .s_aclk(ddr3_domain_clk),
    .s_aresetn(~adc_acq_full_reset),
    .s_axis_tvalid(ddr3_rd_fifo_wr_en),
    .s_axis_tready(),
    .s_axis_tlast(ddr3_rd_fifo_input_tlast),
    .s_axis_tdata(ddr3_rd_fifo_input_dat[127:0]),
    .m_axis_tvalid(ddr3_rd_fifo_output_tvalid),
    .m_axis_tready(ddr3_rd_fifo_output_tready),
    .m_axis_tdata(ddr3_rd_fifo_output_dat[127:0]),
    .m_axis_tlast(ddr3_rd_fifo_output_tlast),
    .axis_prog_full(ddr3_rd_fifo_almost_full)
);

// Create a width converter to change the 128-bit data to 32-bit data
ddr3_read_data_width_converter ddr3_read_data_width_converter(
    .aclk(clk125),
    .aresetn(~adc_acq_full_reset),
    .s_axis_tvalid(ddr3_rd_fifo_output_tvalid),
    .s_axis_tready(ddr3_rd_fifo_output_tready),
    .s_axis_tdata(ddr3_rd_fifo_output_dat[127:0]),  // 128-bit
    .s_axis_tlast(ddr3_rd_fifo_output_tlast),
    .m_axis_tvalid(ddr3_32bit_tvalid),
    .m_axis_tready(ddr3_32bit_tready),
    .m_axis_tdata(ddr3_32bit_tx_tdata[31:0]),       // 32-bit
    .m_axis_tlast(ddr3_32bit_tlast)
);

// COMMENT OUT THE "AXIS_INTERCONNECT AND REPLACE IT WITH A COMBINATORIAL 2:1 MUX
// Create an AXI interconnect to merge the 'command' data with the DDR3 data.
// 'command' data on port 'S00'
// DDR3 data on port 'S01' 
// This is configured in "fixed mode arbitration", where S00 has priority. This should prevent
// the situation where the 'rd_fill' sm has sent out the CSN and CC, but they are not consumed
// by the Aurora. Then the DDR3 data arrives and gets ahead of the CSN/CC.
// The slave FIFO has been enabled for each port.
//axis_interconnect_0 axis_interconnect (
//  .ACLK(clk125),                                  // input wire ACLK
//  .ARESETN(~adc_acq_full_reset),                            // input wire ARESETN
//  .S00_AXIS_ACLK(clk125),                // input wire S00_AXIS_ACLK
//  .S01_AXIS_ACLK(clk125),                // input wire S01_AXIS_ACLK
//  .S00_AXIS_ARESETN(adc_acq_full_reset),          // input wire S00_AXIS_ARESETN
//  .S01_AXIS_ARESETN(adc_acq_full_reset),          // input wire S01_AXIS_ARESETN
//  .S00_AXIS_TVALID(command_tx_tvalid),            // input wire S00_AXIS_TVALID
//  .S01_AXIS_TVALID(ddr3_32bit_tvalid),            // input wire S01_AXIS_TVALID
//  .S00_AXIS_TREADY(command_tx_tready),            // output wire S00_AXIS_TREADY
//  .S01_AXIS_TREADY(ddr3_32bit_tready),            // output wire S01_AXIS_TREADY
//  .S00_AXIS_TDATA(command_tx_tdata[31:0]),              // input wire [31 : 0] S00_AXIS_TDATA
//  .S01_AXIS_TDATA(ddr3_32bit_tx_tdata[31:0]),              // input wire [31 : 0] S01_AXIS_TDATA
//  .S00_AXIS_TLAST(command_tx_tlast),              // input wire S00_AXIS_TLAST
//  .S01_AXIS_TLAST(ddr3_32bit_tlast),              // input wire S01_AXIS_TLAST
//  .M00_AXIS_ACLK(clk125),                // input wire M00_AXIS_ACLK
//  .M00_AXIS_ARESETN(adc_acq_full_reset),          // input wire M00_AXIS_ARESETN
//  .M00_AXIS_TVALID(c0_tx_axi_tvalid),            // output wire M00_AXIS_TVALID
//  .M00_AXIS_TREADY(c0_tx_axi_tready),            // input wire M00_AXIS_TREADY
//  .M00_AXIS_TDATA(tx_tdata_swap[31:0]),              // output wire [31 : 0] M00_AXIS_TDATA
//  .M00_AXIS_TLAST(c0_tx_axi_tlast),              // output wire M00_AXIS_TLAST
//  .S00_ARB_REQ_SUPPRESS(1'b0),  // input wire S00_ARB_REQ_SUPPRESS
//  .S01_ARB_REQ_SUPPRESS(1'b0),  // input wire S01_ARB_REQ_SUPPRESS
//  .S00_FIFO_DATA_COUNT(),    // output wire [31 : 0] S00_FIFO_DATA_COUNT
//  .S01_FIFO_DATA_COUNT()    // output wire [31 : 0] S01_FIFO_DATA_COUNT
//);

// Synchronize  'readout_pause' to 'clk125'.
reg readout_pause_sync1, readout_pause_sync2;
always @(posedge clk125) begin
    readout_pause_sync1 <= readout_pause;
    readout_pause_sync2 <= readout_pause_sync1;
end

// We really want a 2:1 MUX to route data to the Aurora. It will normally send data from
// 'command_top', but will switch to sending data from the DDR3 memory during 'rd_fill'.
// We need to avoid causing changes in the order of data, or truncating a stream by switching
// prematurely.
// Switch 'tvalid' and 'tlast' between the DDR3 source and the 'command' source.
// Do not pass 'tvalid' to the Aurora if 'readout_pause' is asserted
assign c0_tx_axi_tvalid = use_ddr3_data ? (ddr3_32bit_tvalid && !readout_pause_sync2) : (command_tx_tvalid && !readout_pause_sync2);
assign c0_tx_axi_tlast  = use_ddr3_data ? ddr3_32bit_tlast : command_tx_tlast;

// Switch 'tdata[]' between the DDR3 source and the 'command' source
// Swap the bit-order along the way
assign c0_tx_axi_tdata[0:31] = use_ddr3_data ? ddr3_32bit_tx_tdata[31:0] : command_tx_tdata[31:0];

// Only send 'tready' back to the active source.
assign ddr3_32bit_tready = use_ddr3_data ? (c0_tx_axi_tready && !readout_pause_sync2) : 1'b0;
assign command_tx_tready = use_ddr3_data ? 1'b0 : (c0_tx_axi_tready && !readout_pause_sync2);

// make an 'aurora_ddr3_accept' signal that is asserted whenever the Aurora accepts DDR3 data.
// It will be sent to the 'rd_fill' state machine, which needs to know when to negate 'use_ddr3_data'
assign aurora_ddr3_accept = use_ddr3_data & (c0_tx_axi_tready && !readout_pause_sync2) & c0_tx_axi_tvalid;
 
////////////////////////////////////////////////////////////////////////////
// status LED
led_status led_status(
    .clk(clk50),
    .red_led(led1),
    .green_led(led2),
    .aurora_channel_up(aurora_channel_up),
    .adc_acq_sm_idle(adc_acq_sm_idle),
    .command_sm_idle(command_sm_idle)
);

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

    // There is no IPbus on the Channel FPGA
    // Eventually try to use I2C bus
    // For now, JTAG registers will be provided to read status 

    // channel 0 connections
    // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
    // TX interface to slave side of transmit FIFO 
    .c0_s_axi_tx_tdata(c0_tx_axi_tdata[0:31]),       // note index order
    .c0_s_axi_tx_tkeep(4'b1111),			         // always 1's
    .c0_s_axi_tx_tvalid(c0_tx_axi_tvalid),
    .c0_s_axi_tx_tlast(c0_tx_axi_tlast),

    .c0_s_axi_tx_tready(c0_tx_axi_tready),
    // RX Interface to master side of receive FIFO
    .c0_m_axi_rx_tdata(c0_rx_axi_tdata[0:31] ),      // note index order
    .c0_m_axi_rx_tkeep(c0_rx_axi_tkeep[0:3]),        // note index order
    .c0_m_axi_rx_tvalid(c0_rx_axi_tvalid),
    .c0_m_axi_rx_tlast(c0_rx_axi_tlast),
    .c0_m_axi_rx_tready(c0_rx_axi_tready),           // input wire m_axis_tready

    // serial I/O pins
    .c0_rxp(c0_rx), .c0_rxn(c0_rx_N),                // receive from channel 0 FPGA
    .c0_txp(c0_tx), .c0_txn(c0_tx_N),                // transmit to channel 0 FPGA
    .debug(debug[7:0]),
    .channel_up(aurora_channel_up)
);

// We need to swap the bit order for the RX data
assign rx_tdata_swap[31:0] = c0_rx_axi_tdata[0:31];
  
///////////////////////////////////////////////////////////////////////////////////
// Connect the command processor. This will receive commands from the Aurora serial
// link and process them
command_top command_top(
    // clocks and reset
    .clk50(clk50),              // 50 MHz buffered clock 
    .reset_clk50(reset_clk50),  // active-high reset output, goes low after startup
    .clk(clk125),               // clock for the interconnect side of the FIFOs
    .resetN(reset_clk125N),     // active-lo reset for the interconnect side of the FIFOs

    // channel 0 connections
    // connections to 4-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
    // RX Interface to master side of receive FIFO for receiving from the Master FPGA
    .rx_data(rx_tdata_swap[31:0]),       // note index order
    .rx_tkeep(c0_rx_axi_tkeep[0:3]),     // note index order
    .rx_tvalid(c0_rx_axi_tvalid),
    .rx_tlast(c0_rx_axi_tlast),
    .rx_tready(c0_rx_axi_tready),        // input wire m_axis_tready

    // TX interface to slave side of transmit FIFO for sending to the Master FPGA 
    .tx_data(command_tx_tdata[31:0]),    // note index order
    .tx_tvalid(command_tx_tvalid),
    .tx_tlast(command_tx_tlast),
    .tx_tready(command_tx_tready),

    // interface to the ADC data memory and header FIFO
    .fill_header_fifo_empty(fill_header_fifo_empty),    // output, a header is available when not asserted
    .fill_header_fifo_rd_en(fill_header_fifo_rd_en),    // input, remove the current data from the FIFO
    .fill_header_fifo_out(fill_header_fifo_out[127:0]), // output, data at the head of the FIFO
    .ddr3_rd_start_addr(ddr3_rd_start_addr[22:0]),      // input, the address of the first requested 128-bit burst
    .ddr3_rd_burst_cnt(ddr3_rd_burst_cnt[20:0]),        // input, the number of bursts to read
    .enable_reading(enable_reading),                    // input, initialize the address generator and both counters, go
    .reading_done(reading_done),                        // output, reading is complete

    // Registers to/from the ADC acquisition state machine
    .fill_num(fill_num[23:0]),                                     // fill number for this fill
    .channel_tag(channel_tag[15:0]),                               // stuff about the channel to put in the header
    .num_muon_bursts(num_muon_bursts[20:0]),                       // number of sample bursts in a MUON fill
    .num_laser_bursts(num_laser_bursts[20:0]),                     // number of sample bursts in a LASER fill
    .num_ped_bursts(num_ped_bursts[20:0]),                         // number of sample bursts in a PEDESTAL fill
    .initial_fill_num(initial_fill_num[23:0]),                     // event number to assign to the first fill
    .initial_fill_num_wr(initial_fill_num_wr),                     // write-strobe to store the initial_fill_num
    .ch_addr(ch_addr[2:0]),                                        // the channel address jumpers
    .adc_buf_delay_data_reset(adc_buf_delay_data_reset),           // use the new delay settings
    .adc_buf_data_delay(adc_buf_data_delay[4:0]),                  // 5 delay-tap-bits per line, all lines always all the same
    .adc_buf_current_data_delay(adc_buf_current_data_delay[64:0]), // 13 lines *5 bits/line, current tap settings

    .genreg_addr_ctrl(genreg_addr_ctrl[31:0]),
    .genreg_wr_data(genreg_wr_data[31:0]),
    .genreg_rd_data(genreg_rd_data[31:0]),

    // interface to the AXIS 2:1 mux
    .use_ddr3_data(use_ddr3_data),              // the data source is the DDR3 memory
    .aurora_ddr3_accept(aurora_ddr3_accept),    // DDR3 data has been accepted by the Aurora
    
  // Status signal for front panel LED
  .command_sm_idle(command_sm_idle)
);


gen_reg gen_reg(
    .clk(clk50),
    .reset(reset_clk50),
    .addr_ctrl(genreg_addr_ctrl[31:0]),
    .data_in(genreg_wr_data[31:0]),
    .data_out(genreg_rd_data[31:0]),
    .adc_intf_data_in(adc_intf_rd_data[31:0]),      // data word from adc serial interface
    .adc_intf_data_out(adc_intf_wr_data[31:0]),     // data word to adc serial interface
    .debug()
);

// ====================
// ADC serial interface
// ====================
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

`timescale 1ns / 1ps
`include "constants.txt"

//////////////////////////////////////////////////////////////
// Top-level module for g-2 WFD5 Channel FPGA
// ASYNCHRONOUS MODE
//
// Notes:
// 1) There is only one link to the Master FPGA. It is chan 0.
//
//////////////////////////////////////////////////////////////

// as a useful reference, here's the syntax to mark signals for debug:
// (* mark_debug = "true" *) 

module channel_main_async (
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

wire [22:0] current_waveform_num;

// Assignments for 'io' lines:
//   io[0]   : 'readout_pause'
wire readout_pause;
assign readout_pause = io[0];           // stop sending fill data to the Aurora
//   io[1:2] : 'acq_enable'
wire acq_enable0;                       // indicates enabled for triggers, and fill type
wire acq_enable1;                       // indicates enabled for triggers, and fill type
assign acq_enable0 = io[1];
assign acq_enable1 = io[2];
//   io[3]   : 'rst_from_master'
wire rst_from_master;
assign rst_from_master = io[3];

wire evt_cnt_reset;
wire full_reset;

wire [11:0] channel_tag;                // stuff about the channel to put in the header
wire [22:0] muon_num_bursts;            // number of sample bursts in a MUON fill
wire [22:0] laser_num_bursts;           // number of sample bursts in a LASER fill
wire [22:0] ped_num_bursts;             // number of sample bursts in a PEDESTAL fill
wire [23:0] initial_fill_num;           // event number to assign to the first fill
wire [131:0] adc_acq_out_dat;           // 132-bit 4-bit tag plus header or ADC data to 'ddr3_write_fifo'
wire [11:0] muon_num_waveforms;         // number of waveforms to store per trigger
wire [21:0] muon_waveform_gap;          // idle time between waveforms
wire [11:0] laser_num_waveforms;        // number of waveforms to store per trigger
wire [21:0] laser_waveform_gap;         // idle time between waveforms
wire [11:0] ped_num_waveforms;          // number of waveforms to store per trigger
wire [21:0] ped_waveform_gap;           // idle time between waveforms
wire [13:0] async_num_bursts;           // number of 8-sample bursts in an ASYNC waveform
wire [15:0] async_pre_trig;             // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform

wire adc_acq_out_valid;
wire [131:0] ddr3_wr_fifo_dat;          // 132-bit 4-bit tag plus header or ADC data from 'ddr3_write_fifo'
wire [127:0] ddr3_rd_dat;               // 128-bit header or ADC data from DDR3 memory
wire [23:0] fill_num;                   // fill number for this fill
wire [127:0] ddr3_rd_fifo_input_dat;    // memory burst headed toward 'ddr3_read_fifo'
wire [127:0] ddr3_rd_fifo_output_dat;   // memory burst headed toward 'ddr3_read_data_width_converter'
wire [31:0] ddr3_32bit_tx_tdata;        // 32-bit chunks of memory burst headed toward 'axis_interconnect'
wire [22:0] ddr3_rd_start_addr;         // the address of the first requested 128-bit burst
wire [23:0] ddr3_rd_burst_cnt;          // number of bursts to read from the DDR3
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

wire [151:0] fill_header_fifo_out;
wire [22:0] ddr3_rd_burst_addr;

wire [4:0] adc_buf_data_delay;
wire [64:0] adc_buf_current_data_delay;

// status signals for front panel LED
wire aurora_channel_up;
wire adc_acq_sm_idle;
wire command_sm_idle;

////////////////////////////////////////////////////////////////////////////
// Clock and reset handling
// Connect an input buffer and a global clock buffer to the 50 MHz clock
wire clk50, clk200, clk250, clk8;

g2_chan_clks clk_dcm_50_200 (
    // Clock in ports
    .clk_in1(clkin),        // input, unbuffered 50 MHz from pin 
    // Clock out ports
    .clk_50M(clk50),        // output, 50 MHz
    .clk_200M(clk200),      // output, 200 MHz
    .clk_250M(clk250),      // output, 250 MHz
    .clk_8M(clk8),          // output,   8 MHz
    .adc_sdclk(adc_sdclk)   // output,   8 MHz 180 deg phase shift
    // Status and control signals
    //.reset(1'b0),         // input, unused reset
    //.locked()             // output, unused locked
);

// differential clock buffer - This should get shared between the Aurora channel interfaces
// and other internal logic.
wire gt_clk125, clk125;
IBUFDS_GTE2 clk125_IBUFDS_GTE2 (.I(xcvr_clk), .IB(xcvr_clk_N), .O(gt_clk125), .CEB(1'b0), .ODIV2());
BUFG BUFG_clk125 (.I(gt_clk125), .O(clk125));

// differential clock buffer for the adc clock
//wire adc_clk;
IBUFDS adc_clk_IBUFDS_inst (
   .O(adc_clk),     // 1-bit output: Buffer output
   .I(adc_clk_p),   // 1-bit input: Diff_p buffer input (connect directly to top-level port)
   .IB(adc_clk_n)   // 1-bit input: Diff_n buffer input (connect directly to top-level port)
);

wire reset_clk50, reset_clk125, adc_acq_full_reset;

// synchronous reset logic
startup_reset startup_reset(
    // inputs
    .rst_from_master(full_reset), // external reset of all acquisition logic
    .clk50(clk50),                // 50 MHz buffered clock 
    .clk125(clk125),              // buffered clock, 125 MHz
    .adc_clk(adc_clk),            // clock from the ADC
    // outputs
    .reset_clk50(reset_clk50),    // active-high reset output, goes low after startup
    .reset_clk125(reset_clk125),  // active-high reset output, goes low after startup
    .adc_acq_full_reset(adc_acq_full_reset) // active-high reset output, goes low after startup
);


wire rst_from_master_sync;
sync_2stage rst_from_master_sync_inst (
    .clk(clk50),
    .in(rst_from_master),
    .out(rst_from_master_sync)
);

// reset from master logic
master_reset master_reset (
  .clk(clk50),
  .rst(reset_clk50),
  .rst_from_master(rst_from_master_sync),
  .short_reset(evt_cnt_reset),
  .long_reset(full_reset)
);


// ======== communicate with FPGA XADC ========

wire [15:0] xadc_temp;
wire [15:0] xadc_vccint;
wire [15:0] xadc_vccaux;
wire [15:0] xadc_vccbram;

wire xadc_over_temp;
wire xadc_alarm_temp;
wire xadc_alarm_vccint;
wire xadc_alarm_vccaux;
wire xadc_alarm_vccbram;
wire xadc_eoc;
wire xadc_eos;

wire [3:0] xadc_alarms;
assign xadc_alarms = {xadc_alarm_temp, xadc_alarm_vccint, xadc_alarm_vccaux, xadc_alarm_vccbram};

// XADC interface
xadc_interface xadc_interface (
  .dclk(clk125),
  .reset(reset_clk125),
  .measured_temp(xadc_temp[15:0]),
  .measured_vccint(xadc_vccint[15:0]),
  .measured_vccaux(xadc_vccaux[15:0]),
  .measured_vccbram(xadc_vccbram[15:0]),
  .over_temp(xadc_over_temp),
  .alarm_temp(xadc_alarm_temp),
  .alarm_vccint(xadc_alarm_vccint),
  .alarm_vccaux(xadc_alarm_vccaux),
  .alarm_vccbram(xadc_alarm_vccbram),
  .eoc(xadc_eoc),
  .eos(xadc_eos)
);


////////////////////////////////////////////////////////////////////////////
// dummy assignments to keep logic around
assign debug[8] = power_good[2] & power_good[1] & power_good[0];
assign debug[9] = bbus_scl & bbus_sda;

IBUFDS adc_sync_in (.I(adc_syncp), .IB(adc_syncn), .O(adc_sync));
 
////////////////////////////////////////////////////////////////////////////
// connect the ADC acquisition controller
// Combine the ADC data 'p' pins and 'n' pins into arrays.
wire [11:0] adc_in_p, adc_in_n;
assign adc_in_p = {adc_d11p, adc_d10p, adc_d9p, adc_d8p, adc_d7p, adc_d6p, adc_d5p, adc_d4p, adc_d3p, adc_d2p, adc_d1p, adc_d0p};
assign adc_in_n = {adc_d11n, adc_d10n, adc_d9n, adc_d8n, adc_d7n, adc_d6n, adc_d5n, adc_d4n, adc_d3n, adc_d2n, adc_d1n, adc_d0n};

wire [25:0] packed_adc_dat;

adc_acq_top_ASYNC adc_acq_top_ASYNC (
    // inputs
    .adc_in_p(adc_in_p[11:0]),                           // [11:0] array of ADC 'p' data pins
    .adc_in_n(adc_in_n[11:0]),                           // [11:0] array of ADC 'n' data pins
    .adc_ovr_p(adc_dovrp),                               // ADC 'p' over-range pin
    .adc_ovr_n(adc_dovrn),                               // ADC 'n' over-range pin
    .adc_clk(adc_clk),                                   // ADC clock used by the FIFO
    //.adc_clk_p(adc_clk_p),                               // ADC 'p' clk pin
    //.adc_clk_n(adc_clk_n),                               // ADC 'n' clk pin
    .reset_clk50(reset_clk50),                           // synchronously negated
    .clk200(clk200),                                     // for input pin timing delay settings
    .channel_tag(channel_tag[11:0]),                     // stuff about the channel to put in the header
    .initial_fill_num(initial_fill_num[23:0]),           // event number to assign to the first fill
    .initial_fill_num_wr(initial_fill_num_wr),           // write-strobe to store the initial_fill_num
    .ext_enable0(acq_enable0),                           // external 'enable' for triggers, and fill type
    .ext_enable1(acq_enable1),                           // external 'enable' for triggers, and fill type
    .ext_trig(acq_trig),                                 // external trigger to start collecting data
    .adc_acq_full_reset(adc_acq_full_reset),             // reset all aspects of data collection/storage/readout
    .adc_buf_delay_data_reset(adc_buf_delay_data_reset), // use the new delay settings
    .adc_buf_data_delay(adc_buf_data_delay[4:0]),        // 5 delay-tap-bits per line, all lines always all the same
    .ddr3_wr_done(ddr3_wr_done),                         // asserted when the 'ddr3_wr_control' is in the DONE state
    .async_num_bursts(async_num_bursts[13:0]),           // number of 8-sample bursts in an ASYNC waveform
    .async_pre_trig(async_pre_trig[15:0]),               // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    .xadc_alarms(xadc_alarms[3:0]),
 
    // outputs
    .ddr3_wr_en(ddr3_wr_en),                     // writing of triggered events to memory is enabled
    .adc_buf_current_data_delay(adc_buf_current_data_delay[64:0]), // 13 lines *5 bits/line, current tap settings
    .fill_num(fill_num[23:0]),                           // fill number for this fill
    .adc_acq_out_dat(adc_acq_out_dat[131:0]),            // 132-bit 4-bit tag plus 128-bit header or ADC data
    .adc_acq_out_valid(adc_acq_out_valid),               // current data should be stored in the FIFO
    .ext_done(acq_done),                                 // assert external acquisition is done
    .adc_acq_sm_idle(adc_acq_sm_idle),                    // ADC acquisition state machine is idle (used for front panel LED status)
    .current_waveform_num(current_waveform_num[22:0]),
    .packed_adc_dat(packed_adc_dat[25:0])
);

wire ddr3_write_fifo_full;
        
////////////////////////////////////////////////////////////////////////////
// Create a FIFO to buffer the data between the ADC block and the DDR3 block
ddr3_write_fifo ddr3_write_fifo (
    // inputs
    .rst(reset_clk50),             // reset at startup or when requested
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

wire enable_reading;
wire reading_done;

////////////////////////////////////////////////////////////////////////////
// Connect the DDR3 interface
ddr3_intf_ASYNC ddr3_intf_ASYNC(
    // clocks and resets
    .refclk(clk200),                    // input, 200 MHz for I/O timing adjustments
    .sysclk(clk200),                    // input, drives the Xilinx DDR3 IP
    .reset_clk50(reset_clk50),            // input, reset at startup or when requested by master FPGA 
    .ddr3_domain_clk(ddr3_domain_clk),  // output, the DDR3 user-interface synchronous clock
    .reset_ddr3_clk(reset_ddr3_clk),   // output, synched to ddr3_clk

    // writing connections
    .ddr3_wr_en(ddr3_wr_en),               // writing of triggered events to memory is enabled
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
    .app_rdy(),
    .xadc_temp(xadc_temp[11:0])
);

////////////////////////////////////////////////////////////////////////////
// Create a FIFO to buffer the data from the DDR3 block
ddr3_read_fifo ddr3_read_fifo(
    .m_aclk(clk125),
    .s_aclk(ddr3_domain_clk),
    .s_aresetn(~reset_ddr3_clk),
    .s_axis_tvalid(ddr3_rd_fifo_wr_en),
    .s_axis_tready(),
    .s_axis_tlast(ddr3_rd_fifo_input_tlast),
    .s_axis_tdata(ddr3_rd_fifo_input_dat[127:0]),
    .m_axis_tvalid(ddr3_rd_fifo_output_tvalid),
    .m_axis_tready(ddr3_rd_fifo_output_tready),
    .m_axis_tdata(ddr3_rd_fifo_output_dat[127:0]),
    .m_axis_tlast(ddr3_rd_fifo_output_tlast),
    .axis_prog_full(ddr3_rd_fifo_almost_full),
    .wr_rst_busy(),        // output wire wr_rst_busy
    .rd_rst_busy()         // output wire rd_rst_busy
);

// Create a width converter to change the 128-bit data to 32-bit data
ddr3_read_data_width_converter ddr3_read_data_width_converter(
    .aclk(clk125),
    .aresetn(~reset_clk50),
    .s_axis_tvalid(ddr3_rd_fifo_output_tvalid),
    .s_axis_tready(ddr3_rd_fifo_output_tready),
    .s_axis_tdata(ddr3_rd_fifo_output_dat[127:0]),  // 128-bit
    .s_axis_tlast(ddr3_rd_fifo_output_tlast),
    .m_axis_tvalid(ddr3_32bit_tvalid),
    .m_axis_tready(ddr3_32bit_tready),
    .m_axis_tdata(ddr3_32bit_tx_tdata[31:0]),       // 32-bit
    .m_axis_tlast(ddr3_32bit_tlast)
);

// Synchronize  'readout_pause' to 'clk125'.
(* ASYNC_REG = "TRUE" *) reg readout_pause_sync1, readout_pause_sync2;
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
led_status_async led_status_async (
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
    .c0_s_axi_tx_tkeep(4'b1111),                  // always 1's
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
wire [3:0] image_type;
assign image_type = `ASYNC_MODE;
command_top command_top (
    // clocks and reset
    .clk50(clk50),             // 50 MHz buffered clock 
    .reset_clk50(reset_clk50), // active-high reset output, goes low after startup
    .clk(clk125),              // clock for the interconnect side of the FIFOs
    .resetN(reset_clk125N),    // active-lo reset for the interconnect side of the FIFOs
    .cnt_reset(evt_cnt_reset), // reset, for fill number count
    .adc_clk(adc_clk),         // ADC clock
    .tap_clk(clk200),          // tap delay clock used by selectio

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
    .fill_header_fifo_out(fill_header_fifo_out[151:0]), // output, data at the head of the FIFO
    .ddr3_rd_start_addr(ddr3_rd_start_addr[22:0]),      // input, the address of the first requested 128-bit burst
    .ddr3_rd_burst_cnt(ddr3_rd_burst_cnt[23:0]),        // input, the number of bursts to read
    .enable_reading(enable_reading),                    // input, initialize the address generator and both counters, go
    .reading_done(reading_done),                        // output, reading is complete

    // registers to/from the ADC acquisition state machine
    .fill_num(fill_num[23:0]),                                     // fill number for this fill
    .channel_tag(channel_tag[11:0]),                               // stuff about the channel to put in the header
    .muon_num_bursts(muon_num_bursts[22:0]),                       // number of sample bursts in a MUON fill
    .laser_num_bursts(laser_num_bursts[22:0]),                     // number of sample bursts in a LASER fill
    .ped_num_bursts(ped_num_bursts[22:0]),                         // number of sample bursts in a PEDESTAL fill
    .initial_fill_num(initial_fill_num[23:0]),                     // event number to assign to the first fill
    .initial_fill_num_wr(initial_fill_num_wr),                     // write-strobe to store the initial_fill_num
    .ch_addr(ch_addr[2:0]),                                        // the channel address jumpers
    .adc_buf_delay_data_reset(adc_buf_delay_data_reset),           // use the new delay settings
    .adc_buf_data_delay(adc_buf_data_delay[4:0]),                  // 5 delay-tap-bits per line, all lines always all the same
    .adc_buf_current_data_delay(adc_buf_current_data_delay[64:0]), // 13 lines *5 bits/line, current tap settings
    .fixed_ddr3_start_addr(fixed_ddr3_start_addr[22:0]),
    .en_fixed_ddr3_start_addr(en_fixed_ddr3_start_addr),
     .muon_num_waveforms(muon_num_waveforms[11:0]),      // number of waveforms to store per trigger
    .muon_waveform_gap(muon_waveform_gap[21:0]),      // idle time between waveforms 
    .laser_num_waveforms(laser_num_waveforms[11:0]),   // number of waveforms to store per trigger
    .laser_waveform_gap(laser_waveform_gap[21:0]),      // idle time between waveforms 
    .ped_num_waveforms(ped_num_waveforms[11:0]),      // number of waveforms to store per trigger
    .ped_waveform_gap(ped_waveform_gap[21:0]),         // idle time between waveforms 
     .async_num_bursts(async_num_bursts[13:0]),          // number of 8-sample bursts in an ASYNC waveform
     .async_pre_trig(async_pre_trig[15:0]),              // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    .packed_adc_dat(packed_adc_dat[25:0]),
    .current_waveform_num(current_waveform_num[22:0]),

    .xadc_temp(xadc_temp[15:0]),
    .xadc_vccint(xadc_vccint[15:0]),
    .xadc_vccaux(xadc_vccaux[15:0]),
    .xadc_vccbram(xadc_vccbram[15:0]),

    .genreg_addr_ctrl(genreg_addr_ctrl[31:0]),
    .genreg_wr_data(genreg_wr_data[31:0]),
    .genreg_rd_data(genreg_rd_data[31:0]),

    // interface to the AXIS 2:1 mux
    .use_ddr3_data(use_ddr3_data),              // the data source is the DDR3 memory
    .aurora_ddr3_accept(aurora_ddr3_accept),    // DDR3 data has been accepted by the Aurora
    
    // status signals
    .command_sm_idle(command_sm_idle),
    .image_type(image_type)
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
    .slow_clk(clk8),
    .sclk(adc_sdclk),
    .sdio(adc_sdio),
    .sdi(adc_sdo),
    .sdenb(adc_sdenb),
    .sresetb(adc_sresetb),
    .enable(adc_enable),
    .debug()
);

endmodule

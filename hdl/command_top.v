`timescale 1ns / 1ps
`include "constants.txt"

// command_top.v
//
// This module executed commands received on the Aurora interface.

module command_top (
    // clocks and reset
    input  clk50,                             // 50 MHz buffered clock 
    input  reset_clk50,                       // active-high reset output, goes low after startup
    input  clk,                               // 125 MHz, clock for the interconnect side of the FIFOs
    input  resetN,                            // active-low reset for the interconnect side of the FIFOs
    input  cnt_reset,                         // reset, for fill number count
    input  adc_clk,
    input  tap_clk,

    // channel connections
    // connections to 4-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
    // RX Interface to master side of receive FIFO for receiving from the Master FPGA
    input  [31:0] rx_data,                    // note index order
    input  [ 0:3] rx_tkeep,                   // note index order
    input  rx_tvalid,
    input  rx_tlast,
    output rx_tready,                         // input wire m_axis_tready
    // TX interface to slave side of transmit FIFO for sending to the Master FPGA 
    output [31:0] tx_data,                    // note index order
    output tx_tvalid,
    output tx_tlast,
    input  tx_tready,

    // interface to the ADC data memory and header FIFO
    input  fill_header_fifo_empty,              // input, a header is available when not asserted
    output fill_header_fifo_rd_en,              // output, remove the current data from the FIFO
    input  [151:0] fill_header_fifo_out,      // input, data at the head of the FIFO
    output [ 22:0] ddr3_rd_start_addr,          // the address of the first requested 128-bit burst
    output [ 23:0] ddr3_rd_burst_cnt,         // input, the number of bursts to read
    output enable_reading,                    // input, initialize the address generator and both counters, go
    input  acq_done_latch,                     // input, last self-trigger safely processed (default to 1 in other modes)
    input  reading_done,                       // input, reading is complete

    // register to/from the ADC acquisition state machine
    input  [23:0] fill_num,                      // fill number for this fill
    output [11:0] channel_tag,                  // stuff about the channel to put in the header
    output [22:0] muon_num_bursts,              // number of sample bursts in a MUON fill
    output [22:0] laser_num_bursts,              // number of sample bursts in a LASER fill
    output [22:0] ped_num_bursts,              // number of sample bursts in a PEDESTAL fill
    output [23:0] initial_fill_num,           // event number to assign to the first fill
    output initial_fill_num_wr,               // write-strobe to store the initial_fill_num
    input  [ 2:0] ch_addr,                      // the channel address jumpers
    output adc_buf_delay_data_reset,          // use the new delay settings
    output [ 4:0] adc_buf_data_delay,          // 5 delay-tap-bits per line, all lines always all the same
    input  [64:0] adc_buf_current_data_delay, // 13 lines *5 bits/line, current tap settings
    output [22:0] fixed_ddr3_start_addr,
    output en_fixed_ddr3_start_addr,
    output [11:0] muon_num_waveforms,          // number of waveforms to store per trigger
    output [21:0] muon_waveform_gap,          // idle time between waveforms 
    output [11:0] laser_num_waveforms,          // number of waveforms to store per trigger
    output [21:0] laser_waveform_gap,          // idle time between waveforms 
    output [11:0] ped_num_waveforms,          // number of waveforms to store per trigger
    output [21:0] ped_waveform_gap,              // idle time between waveforms 
    output [13:0] async_num_bursts,           // number of 8-sample bursts in an ASYNC waveform
    output [15:0] async_pre_trig,             // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    input  [25:0] packed_adc_dat,
    input  [22:0] current_waveform_num,
    output read_fill_done,                    // read fill state machine finished

    input  [15:0] xadc_temp,
    input  [15:0] xadc_vccint,
    input  [15:0] xadc_vccaux,
    input  [15:0] xadc_vccbram,

    output [31:0] genreg_addr_ctrl,              // generic register address and control output
    output [31:0] genreg_wr_data,              // generic register data written from Master FPGA 
    input  [31:0] genreg_rd_data,              // generic register data read by Master FPGA

    // interface to the AXIS 2:1 MUX
    output use_ddr3_data,                      // the data source is the DDR3 memory
    input  aurora_ddr3_accept,                  // DDR3 data has been accepted by the Aurora

    // status signals
    output command_sm_idle,
    input [3:0] image_type
);

    wire ser_num_le, command_le;
    // make active-hi reset
    wire reset;
    assign reset = ~resetN;
    
    wire [31:0] reg_data;
    wire [ 4:0] data_delay_from_reg_block;
    wire [ 4:0] data_delay_from_map_sm;
    wire data_reset_from_reg_block;
    wire data_reset_from_map_sm;

    wire [13:0] async_num_bursts_reg;   // number of 8-sample bursts in an ASYNC waveform, from reg block
    wire [15:0] async_pre_trig_reg;     // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform, , from reg block

    wire start_map;
    wire map_sm_error;

    ///////////////////////////////////////////////////////////////////////////////////////////
    // correct 'channel address' for channel 3 (hardware jumpers are set to 110 instead of 011)
    reg [2:0] ch_addr_corrected;
    always @ (posedge clk) begin
        if (ch_addr[2:0] == 3'b110)
            ch_addr_corrected[2:0] <= 3'b011;
        else
            ch_addr_corrected[2:0] <= ch_addr[2:0];
    end
    
    ///////////////////////////////////////////////////////////////////
    // connect registers to hold the incoming serial number and command
   reg [31:0] command_reg;
   reg [4:0] command_type;
   reg [31:0] serial_num_reg;
    always @ (posedge clk) begin
        if (reset) 
            serial_num_reg <= 32'b0;
        else if (ser_num_le) 
            serial_num_reg[31:0] <= rx_data[31:0];
        else
            serial_num_reg[31:0] <= serial_num_reg[31:0];
    end
    always @ (posedge clk) begin
        if (reset) begin
            command_reg <= 32'b0;
         command_type <= 5'b0;
      end
        else if (command_le) begin
            command_reg[31:0] <= rx_data[31:0];
         command_type[4:0] <= rx_data[ 4:0];
      end
        else begin
            command_reg[31:0] <= command_reg[31:0];
         command_type[4:0] <= command_type[ 4:0];
      end
    end

    ////////////////////////////////////////////////////////////////////////////////
    // generate 'run' signals for the state machines that handle individual commands
    // start with 'run_cmd_sm' which is a 'run someone' from the command sm.
    // Use the actual command from the command register to activate 1 particular sm.
    (* mark_debug = "true" *) wire run_cmd_sm;
    wire run_cc_loopback, run_cc_rd_reg, run_cc_wr_reg, run_cc_map_delay;
    wire run_cc_rd_fill;

    assign run_cc_loopback  = (run_cmd_sm && (command_reg[4:0] == `CC_LOOPBACK));
    assign run_cc_rd_reg    = (run_cmd_sm && (command_reg[4:0] == `CC_RD_REG));
    assign run_cc_wr_reg    = (run_cmd_sm && (command_reg[4:0] == `CC_WR_REG));
    assign run_cc_rd_fill   = (run_cmd_sm && (command_reg[4:0] == `CC_RD_FILL));
    assign run_cc_map_delay = (run_cmd_sm && (command_reg[4:0] == `CC_MAP_DELAY));

    reg s1, s2, s3;
    wire run_cc_rd_fill_pulse;
    always @(posedge clk) begin
        s1 <= run_cc_rd_fill;
        s2 <= s1;
        s3 <= s2;
    end
    assign run_cc_rd_fill_pulse = ~s3 & s2;

    reg [11:0] event_ctr;
    always @ (posedge clk) begin
      if ( reset ) begin
        event_ctr[11:0] = 12'b0;
      end
      else if (run_cc_rd_fill_pulse) begin
        event_ctr[11:0] = event_ctr[11:0] + 1;
      end
      else begin
        event_ctr[11:0] = event_ctr[11:0];
      end
    end


    //////////////////////////////////////////////////////////////////////////////////////////////
    // merge 'running' and 'done' signals from the state machines that handle individual commands.
    // only 1 of each, from the activated sm, should ever be active at the same time
    wire cmd_sm_running, map_sm_running;
    wire cc_loopback_running, cc_rd_reg_running, cc_wr_reg_running, cc_rd_fill_running, cc_map_delay_running;
    assign cmd_sm_running = cc_loopback_running || cc_rd_reg_running || cc_wr_reg_running || cc_rd_fill_running || cc_map_delay_running;

    wire cmd_sm_done, map_sm_done;
    wire cc_loopback_done, cc_rd_reg_done, cc_wr_reg_done, cc_rd_fill_done, cc_map_delay_done;
    assign cmd_sm_done = cc_loopback_done || cc_rd_reg_done || cc_wr_reg_done || cc_rd_fill_done || cc_map_delay_done;
    assign read_fill_done = cc_rd_fill_done;

    ////////////////////////////////////////////////////////////////////
    // every state machine will need to drive certain FIFO control lines
    wire command_top_sm_rx_tready, loopback_sm_rx_tready, rd_reg_sm_rx_tready, wr_reg_sm_rx_tready;
    assign rx_tready = command_top_sm_rx_tready || loopback_sm_rx_tready || rd_reg_sm_rx_tready || wr_reg_sm_rx_tready;
         
    wire loopback_sm_tx_tvalid, rd_reg_sm_tx_tvalid, wr_reg_sm_tx_tvalid, rd_fill_sm_tx_tvalid, map_delay_sm_tx_tvalid;
    assign tx_tvalid = loopback_sm_tx_tvalid || rd_reg_sm_tx_tvalid || wr_reg_sm_tx_tvalid || rd_fill_sm_tx_tvalid || map_delay_sm_tx_tvalid;

    wire loopback_sm_tx_tlast, rd_reg_sm_tx_tlast, wr_reg_sm_tx_tlast, rd_fill_sm_tx_tlast, map_delay_sm_tx_tlast;
    assign tx_tlast = loopback_sm_tx_tlast || rd_reg_sm_tx_tlast || wr_reg_sm_tx_tlast || rd_fill_sm_tx_tlast || map_delay_sm_tx_tlast;

    /////////////////////////////////////////////////
    // connect a big mux to steer data to the TX FIFO
    wire send_csn, send_cmd, send_inv_cmd, send_rx_data, send_reg_data, send_delay_data;
    wire [31:0] map_data_integrity;
    reg [31:0] tx_data_reg;

    // synchronize data integrity map
    wire [31:0] map_data_out;
    sync_2stage #(
        .WIDTH(32)
    ) map_data_sync (
        .clk(clk),
        .in(map_data_integrity),
        .out(map_data_out)
    );

//    // synchronize the async/cbuf burst and presample parameters
//    sync_2stage #(
//        .WIDTH(14)
//    ) num_bursts_sync (
//        .clk(adc_clk),
//        .in(async_num_bursts_reg),
//        .out(async_num_bursts)
//    );
//    sync_2stage #(
//        .WIDTH(16)
//    ) presample_sync (
//        .clk(adc_clk),
//        .in(async_pre_trig_reg),
//        .out(async_pre_trig)
//    );

    always @ (posedge clk) begin
        if (send_csn)           tx_data_reg[31:0] <= serial_num_reg[31:0]; // serial number
        if (send_cmd)           tx_data_reg[31:0] <= command_reg[31:0];    // command
        if (send_inv_cmd)       tx_data_reg[31:0] <= ~command_reg[31:0];   // inverse of command
        if (send_rx_data)       tx_data_reg[31:0] <= rx_data[31:0];        // loopback
        if (send_reg_data)      tx_data_reg[31:0] <= reg_data[31:0];           // reading from a register
        if (send_delay_data) tx_data_reg[31:0] <= map_data_out[31:0];   // reading tap delay validity
    end
    assign tx_data[31:0] = tx_data_reg[31:0];
    
    // Create the mux control signals
    // All state machines need to send the CSN
    wire loopback_sm_send_csn, rd_reg_sm_send_csn, wr_reg_sm_send_csn, rd_fill_sm_send_csn, map_delay_sm_send_csn;
    assign send_csn = loopback_sm_send_csn || rd_reg_sm_send_csn || wr_reg_sm_send_csn || rd_fill_sm_send_csn || map_delay_sm_send_csn;
    
    // All state machines need to send the CC
    wire loopback_sm_send_cmd, rd_reg_sm_send_cmd, wr_reg_sm_send_cmd, rd_fill_sm_send_cmd, map_delay_sm_send_cmd;
    assign send_cmd = loopback_sm_send_cmd || rd_reg_sm_send_cmd || wr_reg_sm_send_cmd || rd_fill_sm_send_cmd || map_delay_sm_send_cmd;

    // Only a few state machines need to send the inverse CC
    wire rd_reg_sm_send_inv_cmd, wr_reg_sm_send_inv_cmd, rd_fill_sm_send_inv_cmd, map_delay_sm_send_inv_cmd;
    assign send_inv_cmd = rd_reg_sm_send_inv_cmd || wr_reg_sm_send_inv_cmd || rd_fill_sm_send_inv_cmd || map_delay_sm_send_inv_cmd;
    
    // Only the loopback state machine send RX DATA directly
    wire loopback_sm_send_rx_data;
    assign send_rx_data = loopback_sm_send_rx_data;
    
    // Only the read_register state machine sends register data
    assign send_reg_data = rd_reg_sm_send_reg_data;


    assign adc_buf_data_delay[4:0] = (map_sm_running) ? data_delay_from_map_sm[4:0] : data_delay_from_reg_block[4:0];
    assign adc_buf_delay_data_reset = (map_sm_running) ? data_reset_from_map_sm : data_reset_from_reg_block;
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // connect the state machine that receives and dispatches commands
    // This state machine never drives the transmit FIFO 
    command_sm command_sm (
        .clk(clk),                              // local clock
        .reset(reset),
        // RX FIFO interface
        .rx_tvalid(rx_tvalid),                // valid data is available
        .rx_tkeep(rx_tkeep[0:3]),             // which bytes are valid, should always be all of them
        .rx_tlast(rx_tlast),                  // final word in the frame
        .rx_tready(command_top_sm_rx_tready), // signal that we are accepting the data from the FIFO
        // control outputs
        .ser_num_le(ser_num_le),              // latch the serial number
        .command_le(command_le),              // latch the command
        .run_cmd_sm(run_cmd_sm),                 // run a state machine
        // control inputs
        .cmd_sm_running(cmd_sm_running),      // someone is running
        .cmd_sm_done(cmd_sm_done),              // someone is finished
        .sm_idle(command_sm_idle)             // state machine is idle
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // connect the state machine that processes the CC_LOOPBACK command
    cc_loopback_sm cc_loopback_sm (
        .clk(clk),                                // local clock
        .reset(reset),                            // active-hi reset
        // state machine control
        .run_sm(run_cc_loopback),               // run this state machine
        .sm_running(cc_loopback_running),        // we are running
        .sm_done(cc_loopback_done),                // we are finished
        // RX FIFO
        .rx_tvalid(rx_tvalid),                    // valid data is available
        .rx_data(rx_data[31:0]),                 // received data
        .rx_tkeep(rx_tkeep),                    // which bytes are valid, should always be all of them
        .rx_tlast(rx_tlast),                    // final word in the frame
        .rx_tready(loopback_sm_rx_tready),        // signal that we are accepting the data from the FIFO
        // TX FIFO
        .tx_tvalid(loopback_sm_tx_tvalid),        // the data we are presenting is valid
        .tx_tlast(loopback_sm_tx_tlast),        // this is the final word in the frame
        .tx_tready(tx_tready),                    // the TX FIFO is ready to accepted data
        // TX mux control
        .send_csn(loopback_sm_send_csn),        // send the CSN
        .send_cmd(loopback_sm_send_cmd),        // send the CC
        .send_rx_data(loopback_sm_send_rx_data)    // mux source is RX FIFO
    );
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // connect the state machine that processes the CC_RD_REG command
    cc_rd_reg_sm cc_rd_reg_sm (
        .clk(clk),                                 // local clock
        .reset(reset),                             // active-high
        // state machine control
        .run_sm(run_cc_rd_reg),                    // run this state machine
        .sm_running(cc_rd_reg_running),             // we are running
        .sm_done(cc_rd_reg_done),                 // we are finished
        // RX FIFO
        .rx_tvalid(rx_tvalid),                     // valid data is available
        .rx_data(rx_data[31:0]),                  // received data
        .rx_tkeep(rx_tkeep),                     // which bytes are valid, should always be all of them
        .rx_tlast(rx_tlast),                     // final word in the frame
        .rx_tready(rd_reg_sm_rx_tready),         // signal that we are accepting the data from the FIFO
        // TX FIFO
        .tx_tvalid(rd_reg_sm_tx_tvalid),         // the data we are presenting is valid
        .tx_tlast(rd_reg_sm_tx_tlast),                  // this is the final word in the frame
        .tx_tready(tx_tready),                     // the TX FIFO is ready to accepted data
        // TX mux control
        .send_csn(rd_reg_sm_send_csn),           // send the CSN
        .send_cmd(rd_reg_sm_send_cmd),           // send the CC
        .send_inv_cmd(rd_reg_sm_send_inv_cmd),   // send the inverse CC
        .send_reg_data(rd_reg_sm_send_reg_data), // mux source is the register bank
        // local controls
        .reg_num_le(rd_reg_sm_reg_num_le),         // enable saving the register number
        .rd_en(rd_reg_sm_reg_rd_en),             // enable reading the specific register
        .illegal_reg_num(illegal_reg_num)         // the desired register does not exist
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // connect the state machine that processes the CC_WR_REG command
    cc_wr_reg_sm cc_wr_reg_sm (
        .clk(clk),                               // local clock
        .reset(reset),                           // active-high
        // state machine control
        .run_sm(run_cc_wr_reg),                  // run this state machine
        .sm_running(cc_wr_reg_running),           // we are running
        .sm_done(cc_wr_reg_done),               // we are finished
        // RX FIFO
        .rx_tvalid(rx_tvalid),                   // valid data is available
        .rx_data(rx_data[31:0]),                // received data
        .rx_tkeep(rx_tkeep),                   // which bytes are valid, should always be all of them
        .rx_tlast(rx_tlast),                   // final word in the frame
        .rx_tready(wr_reg_sm_rx_tready),       // signal that we are accepting the data from the FIFO
        // TX FIFO
        .tx_tvalid(wr_reg_sm_tx_tvalid),       // the data we are presenting is valid
        .tx_tlast(wr_reg_sm_tx_tlast),           // this is the final word in the frame
        .tx_tready(tx_tready),                   // the TX FIFO is ready to accepted data
        // TX mux control
        .send_csn(wr_reg_sm_send_csn),         // send the CSN
        .send_cmd(wr_reg_sm_send_cmd),         // send the CC
        .send_inv_cmd(wr_reg_sm_send_inv_cmd), // send the inverse CC
        // local controls
        .reg_num_le(wr_reg_sm_reg_num_le),       // enable saving the register number
        .wr_en(wr_reg_sm_reg_wr_en),           // enable writing to the specific register
        .illegal_reg_num(illegal_reg_num)       // the desired register does not exist
    );
    
    wire reg_num_le;
    assign reg_num_le = rd_reg_sm_reg_num_le || wr_reg_sm_reg_num_le;
    register_block register_block (
        // clocks and reset
        .clk50(clk50),                                                 // 50 MHz buffered clock 
        .reset_clk50(reset_clk50),                                     // active-high reset output, goes low after startup
        .clk(clk),                                                     // 125 MHz, clock for the interconnect side of the FIFOs
        .reset(reset),                                                 // reset
        .cnt_reset(cnt_reset),                                         // reset, for fill number count
        // incoming and outgoing data
        .rx_data(rx_data[31:0]),                                       // note index order
        .tx_data(reg_data[31:0]),
        // controls
        .rd_en(rd_reg_sm_reg_rd_en),                                   // enable reading of the specific register
        .wr_en(wr_reg_sm_reg_wr_en),                                   // enable writing to the specific register
        .reg_num_le(reg_num_le),                                       // enable saving of the selected register number
        .illegal_reg_num(illegal_reg_num),                             // the desired register does not exist
        // register to/from the ADC acquisition state machine
        .fill_num(fill_num[23:0]),                                     // fill number for this fill
        .channel_tag(channel_tag[11:0]),                               // stuff about the channel to put in the header
        .muon_num_bursts(muon_num_bursts[22:0]),                       // number of sample bursts in a MUON fill
        .laser_num_bursts(laser_num_bursts[22:0]),                     // number of sample bursts in a LASER fill
        .ped_num_bursts(ped_num_bursts[22:0]),                         // number of sample bursts in a PEDESTAL fill
        .initial_fill_num(initial_fill_num[23:0]),                     // event number to assign to the first fill
        .initial_fill_num_wr(initial_fill_num_wr),                     // write-strobe to store the initial_fill_num
        .ch_addr(ch_addr_corrected[2:0]),                              // the channel address jumpers
        .adc_buf_delay_data_reset(data_reset_from_reg_block),          // use the new delay settings
        .adc_buf_data_delay(data_delay_from_reg_block[4:0]),           // 5 delay-tap-bits per line, all lines always all the same
        .adc_buf_current_data_delay(adc_buf_current_data_delay[64:0]), // 13 lines *5 bits/line, current tap settings
        .fixed_ddr3_start_addr(fixed_ddr3_start_addr[22:0]),
        .en_fixed_ddr3_start_addr(en_fixed_ddr3_start_addr),
        .muon_num_waveforms(muon_num_waveforms[11:0]),                 // number of waveforms to store per trigger
        .muon_waveform_gap(muon_waveform_gap[21:0]),                   // idle time between waveforms 
        .laser_num_waveforms(laser_num_waveforms[11:0]),               // number of waveforms to store per trigger
        .laser_waveform_gap(laser_waveform_gap[21:0]),                 // idle time between waveforms
        .ped_num_waveforms(ped_num_waveforms[11:0]),                   // number of waveforms to store per trigger
        .ped_waveform_gap(ped_waveform_gap[21:0]),                     // idle time between waveforms
        .async_num_bursts(async_num_bursts[13:0]),                     // number of 8-sample bursts in an ASYNC waveform
        .async_pre_trig(async_pre_trig[15:0]),                         // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
        .current_waveform_num(current_waveform_num[22:0]),
        // slow control
        .xadc_temp(xadc_temp[15:0]),
        .xadc_vccint(xadc_vccint[15:0]),
        .xadc_vccaux(xadc_vccaux[15:0]),
        .xadc_vccbram(xadc_vccbram[15:0]),
        // generic register block
        .genreg_addr_ctrl(genreg_addr_ctrl[31:0]),
        .genreg_wr_data(genreg_wr_data[31:0]),
        .genreg_rd_data(genreg_rd_data[31:0]),
        .map_data_integrity(map_data_integrity[31:0]),
        .image_type(image_type)
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // connect the state machine that processes the CC_RD_FILL command
    cc_rd_fill_sm cc_rd_fill_sm (
        .clk(clk),                                             // local clock
        .reset(reset),                                         // active-high reset
        // state machine control
        .run_sm(run_cc_rd_fill),                                // run this state machine
        .sm_running(cc_rd_fill_running),                        // we are running
        .sm_done(cc_rd_fill_done),                             // we are finished
        // RX FIFO - this sm does not get anything from the RX FIFO
        // TX FIFO
        .tx_tvalid(rd_fill_sm_tx_tvalid),                     // the data we are presenting is valid
        .tx_tlast(rd_fill_sm_tx_tlast),                         // this is the final word in the frame
        .tx_tready(tx_tready),                                 // the TX FIFO is ready to accepted data
        // TX mux control
        .send_csn(rd_fill_sm_send_csn),                       // send the CSN
        .send_cmd(rd_fill_sm_send_cmd),                       // send the CC
        .send_inv_cmd(rd_fill_sm_send_inv_cmd),               // send the inverse CC
        // local controls
        // interface to the header FIFO
        .fill_header_fifo_empty(fill_header_fifo_empty),     // a header is available when not asserted
        .fill_header_fifo_rd_en(fill_header_fifo_rd_en),     // remove the current data from the FIFO
        .fill_header_fifo_out(fill_header_fifo_out[151:0]),     // data at the head of the FIFO
        .fixed_ddr3_start_addr(fixed_ddr3_start_addr[22:0]),
        .en_fixed_ddr3_start_addr(en_fixed_ddr3_start_addr),
        // interface to the DDR3 memory 
        .ddr3_rd_start_addr(ddr3_rd_start_addr[22:0]),         // the address of the requested 128-bit burst
        .ddr3_rd_burst_cnt(ddr3_rd_burst_cnt[23:0]),           // number of bursts to read from the DDR3
        .enable_reading(enable_reading),                       // start the 'ddr3_rd_control'
        .reading_done(reading_done),                           // reading is complete
        .acq_done_latch(acq_done_latch),                       // input, last self-trigger safely processed (default to 1 in other modes)
        // interface to the AXIS 2:1 MUX
        .use_ddr3_data(use_ddr3_data),                         // the data source is the DDR3 memory
        .aurora_ddr3_accept(aurora_ddr3_accept),               // DDR3 data has been accepted by the Aurora
        // for debugging
        .initial_fill_num_wr(initial_fill_num_wr)              // tells the debugging event counter to reset to zero

    );

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // connect the state machine that processes the CC_MAP_DELAY command
    cc_map_delay_sm cc_map_delay_sm (
        .clk(clk),                                  // local clock
        .reset(reset),                              // active-high
        // state machine control
        .run_sm(run_cc_map_delay),                 // run this state machine
        .sm_running(cc_map_delay_running),          // we are running
        .sm_done(cc_map_delay_done),              // we are finished
        // TX FIFO
        .tx_tvalid(map_delay_sm_tx_tvalid),          // the data we are presenting is valid
        .tx_tlast(map_delay_sm_tx_tlast),             // this is the final word in the frame
        .tx_tready(tx_tready),                    // the TX FIFO is ready to accepted data
        // TX mux control
        .send_csn(map_delay_sm_send_csn),            // send the CSN
        .send_cmd(map_delay_sm_send_cmd),            // send the CC
        .send_inv_cmd(map_delay_sm_send_inv_cmd), // send the inverse CC
        .send_data(send_delay_data),              // mux source is the delay register bank
        // local controls
        .map_done(map_sm_done),
        .start_map(start_map)
    );
    
    map_adc_delay map_adc_delay (
        .clk(adc_clk),                                   // adc clock
        .tap_clk(tap_clk),                               // tap delay clock for selectio
        .reset(reset),                                   // active-high
        .run_sm(start_map),                              // run this state machine
        .sm_running(map_sm_running),                     // we are running
        .sm_done(map_sm_done),                           // we are finished
        .error_found(map_sm_error),                      // error status
        .packed_adc_dat(packed_adc_dat[25:0]),           // ADC data
        .current_delay(adc_buf_current_data_delay[4:0]), // current data delay
        .ipbus_delay(data_delay_from_reg_block[4:0]),    // data delay setting from IPbus
        .data_delay(data_delay_from_map_sm[4:0]),        // data delay to set
        .delay_reset(data_reset_from_map_sm),            // reset to SelectIO Wizard
        .data_integrity(map_data_integrity[31:0])
    );

endmodule

// file: all_channels.v
//
// Connect all of the serial links to the channel FPGAs that use the Aurora interface.
// Implement and distribute any shared signals that are not passed from above.

module all_channels(
  // clocks and reset
  input clk50,                            // Aurora 'init_clk' uses 50 MHz clock per PG046-20
  input clk50_reset,                      // active_hi synched to 'clk50'
  input axis_clk,                         // clock for the interconnect side of the FIFOs
  input axis_clk_resetN,                  // active-lo reset for the interconnect side of the FIFOs
  input gt_refclk,                        // 125 MHz oscillator, from IBUFDS_GTE2 at a higher level
  // channel 0 connections
  // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
  // TX interface to slave side of transmit FIFO 
  input [0:31] c0_s_axi_tx_tdata,        // note index order
  input [0:3] c0_s_axi_tx_tkeep,         // note index order
  input c0_s_axi_tx_tvalid,
  input c0_s_axi_tx_tlast,
  output c0_s_axi_tx_tready,
  // RX Interface to master side of receive FIFO
  output [0:31] c0_m_axi_rx_tdata,       // note index order
  output [0:3] c0_m_axi_rx_tkeep,        // note index order
  output c0_m_axi_rx_tvalid,
  output c0_m_axi_rx_tlast,
  input c0_m_axi_rx_tready,            // input wire m_axis_tready
  // serial I/O pins
  input c0_rxp, c0_rxn,                   // receive from channel 0 FPGA
  output c0_txp, c0_txn,                   // transmit to channel 0 FPGA

  // channel 1 connections
  // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
  // TX interface to slave side of transmit FIFO 
  input [0:31] c1_s_axi_tx_tdata,        // note index order
  input [0:3] c1_s_axi_tx_tkeep,         // note index order
  input c1_s_axi_tx_tvalid,
  input c1_s_axi_tx_tlast,
  output c1_s_axi_tx_tready,
  // RX Interface to master side of receive FIFO
  output [0:31] c1_m_axi_rx_tdata,       // note index order
  output [0:3] c1_m_axi_rx_tkeep,        // note index order
  output c1_m_axi_rx_tvalid,
  output c1_m_axi_rx_tlast,
  input c1_m_axi_rx_tready,            // input wire m_axis_tready
  // serial I/O pins
  input c1_rxp, c1_rxn,                   // receive from channel 0 FPGA
  output c1_txp, c1_txn                   // transmit to channel 0 FPGA
 );

  wire [8:0] c0_live_status, c1_live_status;  // packed status bits from channels
  
  ///////////////////////////////////////////////////////////////////////////////////////////////////
  // Chan 0
  one_channel chan0 (
    // clocks and reset
    .clk50(clk50),                                 // Aurora 'init_clk' uses 50 MHz clock per PG046-20
    .clk50_reset(clk50_reset),                     // active_hi synched to 'clk50'
    .gt_refclk(gt_refclk),                         // 125 MHz oscillator, from IBUFDS_GTE2 at a higher level
    // the slave side of the transmit FIFO
    .s_axis_aresetn(axis_clk_resetN),              // input wire s_axis_aresetn
    .s_axis_aclk(axis_clk),                        // input wire s_axis_aclk
    .s_axis_tx_tvalid(c0_s_axi_tx_tvalid),            // input wire s_axis_tvalid
    .s_axis_tx_tready(c0_s_axi_tx_tready),            // output wire s_axis_tready
    .s_axis_tx_tdata(c0_s_axi_tx_tdata),              // input wire [15 : 0] s_axis_tdata
    .s_axis_tx_tkeep(c0_s_axi_tx_tkeep),              // input wire [1 : 0] s_axis_tkeep
    .s_axis_tx_tlast(c0_s_axi_tx_tlast),              // input wire s_axis_tlast
    // the master side of the receive FIFO
    .m_axis_aresetn(axis_clk_resetN),              // input wire m_axis_aresetn
    .m_axis_aclk(axis_clk),                        // input wire m_axis_aclk
    .m_axis_rx_tvalid(c0_m_axi_rx_tvalid),            // output wire m_axis_tvalid
    .m_axis_rx_tdata(c0_m_axi_rx_tdata),              // output wire [15 : 0] m_axis_tdata
    .m_axis_rx_tkeep(c0_m_axi_rx_tkeep),              // output wire [1 : 0] m_axis_tkeep
    .m_axis_rx_tlast(c0_m_axi_rx_tlast),              // output wire m_axis_tlast
    .m_axis_rx_tready(c0_m_axi_rx_tready),            // input wire m_axis_tready
    // serial I/O pins
    .rxp(c0_rxp), .rxn(c0_rxn),                    // receive from channel 0 FPGA
    .txp(c0_txp), .txn(c0_txn),                    // transmit to channel 0 FPGA
    // QPLL Ports
    // Channel 0 is in MGT bank 115, while the QPLL that is initialized in this block is in
    // MGT bank 116. The ethernet module should be initializing the QPLL in MGT band 115.
    // Try setting the following signals to default values, since they should not affect the
    // optimization of MGT bank 115. 
    .gt0_qplllock(1'b1),                   // input
    .gt0_qpllrefclklost(1'b0),       // input
    .gt_qpllclk_quad2(1'b0),           // input
    .gt_qpllrefclk_quad2(1'b0),     // input
    .gt0_qpllreset(),                               // output
    .live_status(c0_live_status)         // status bits
  );
 
  ///////////////////////////////////////////////////////////////////////////////////////////////////
  // Chan 1
  one_channel chan1 (
    // clocks and reset
    .clk50(clk50),                                 // Aurora 'init_clk' uses 50 MHz clock per PG046-20
    .clk50_reset(clk50_reset),                     // active_hi synched to 'clk50'
    .gt_refclk(gt_refclk),                         // 125 MHz oscillator, from IBUFDS_GTE2 at a higher level
    // the slave side of the transmit FIFO
    .s_axis_aresetn(axis_clk_resetN),              // input wire s_axis_aresetn
    .s_axis_aclk(axis_clk),                        // input wire s_axis_aclk
    .s_axis_tx_tvalid(c1_s_axi_tx_tvalid),            // input wire s_axis_tvalid
    .s_axis_tx_tready(c1_s_axi_tx_tready),            // output wire s_axis_tready
    .s_axis_tx_tdata(c1_s_axi_tx_tdata),              // input wire [15 : 0] s_axis_tdata
    .s_axis_tx_tkeep(c1_s_axi_tx_tkeep),              // input wire [1 : 0] s_axis_tkeep
    .s_axis_tx_tlast(c1_s_axi_tx_tlast),              // input wire s_axis_tlast
    // the master side of the receive FIFO
    .m_axis_aresetn(axis_clk_resetN),              // input wire m_axis_aresetn
    .m_axis_aclk(axis_clk),                        // input wire m_axis_aclk
    .m_axis_rx_tvalid(c1_m_axi_rx_tvalid),            // output wire m_axis_tvalid
    .m_axis_rx_tdata(c1_m_axi_rx_tdata),              // output wire [15 : 0] m_axis_tdata
    .m_axis_rx_tkeep(c1_m_axi_rx_tkeep),              // output wire [1 : 0] m_axis_tkeep
    .m_axis_rx_tlast(c1_m_axi_rx_tlast),              // output wire m_axis_tlast
    .m_axis_rx_tready(c1_m_axi_rx_tready),            // input wire m_axis_tready
     // serial I/O pins
    .rxp(c1_rxp), .rxn(c1_rxn),                    // receive from channel 0 FPGA
    .txp(c1_txp), .txn(c1_txn),                    // transmit to channel 0 FPGA
    // QPLL Ports
    .gt0_qplllock(gt0_qplllock),                   // input
    .gt0_qpllrefclklost(gt0_qpllrefclklost),       // input
    .gt_qpllclk_quad2(gt_qpllclk_quad2),           // input
    .gt_qpllrefclk_quad2(gt_qpllrefclk_quad2),     // input
    .gt0_qpllreset(c1_gt0_qpllreset),               // output
    .live_status(c1_live_status)         // status bits
  );
 
  ///////////////////////////////////////////////////////////////////////////////////////////////////
  // qpll stuff for channels 1-4. The qpll in the other MGT is set up by the Ethernet module
  aurora_8b10b_0_gt_common_wrapper gt_common_support_MGT116 (
    // inputs
    .gt0_gtrefclk0_common_in(gt_refclk),            // 125 MHz oscillator
    .gt0_qplllockdetclk_in(clk50),                  // 50 MHz oscillator
    .gt0_qpllreset_in(c1_gt0_qpllreset),            // reset from an Aurora. Do we need to 'OR' all of them?
     // outputs
    .gt_qpllclk_quad2_i(gt_qpllclk_quad2),
    .gt_qpllrefclk_quad2_i(gt_qpllrefclk_quad2),
    .gt0_qplllock_out(gt0_qplllock),
    .gt0_qpllrefclklost_out(gt0_qpllrefclklost)
  );

  ///////////////////////////////////////////////////////////////////////////////////////////////////
  // connect a register readable by JTAG
  // wire clk50_resetN;
  // assign clk50_resetN = !clk50_reset;
  // wire [31:0] jtag_reg;
  // assign jtag_reg[8:0] = c0_live_status[8:0];
  // assign jtag_reg[17:9] = c1_live_status[8:0];
  // assign jtag_reg[31:18] = 14'b0;
  // jtag_register jtag_register_i(
  //   .clk(clk50),
  //   .jtag_reg(jtag_reg[31:0]),
  //   .resetN(clk50_resetN)
  // );

endmodule

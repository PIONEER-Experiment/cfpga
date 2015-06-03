// file: all_channels.v
//
// Connect the chan 0 serial link.
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
  output [7:0] debug,
  output channel_up 
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
    .debug(debug[7:0]),         // debug bits
    .channel_up(channel_up)
  );
 
endmodule

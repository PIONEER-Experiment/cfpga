// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2.2 (lin64) Build 4126759 Thu Feb  8 23:52:05 MST 2024
// Date        : Tue Sep 30 09:02:56 2025
// Host        : lkgVivadoContainer running 64-bit unknown
// Command     : write_verilog -force -mode synth_stub /home/user/cfpga_stc/ip/fill_address_fifo/fill_address_fifo_stub.v
// Design      : fill_address_fifo
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7k70tfbg484-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_2_9,Vivado 2023.2.2" *)
module fill_address_fifo(rst, wr_clk, rd_clk, din, wr_en, rd_en, dout, full, 
  empty, wr_rst_busy, rd_rst_busy)
/* synthesis syn_black_box black_box_pad_pin="rst,din[22:0],wr_en,rd_en,dout[22:0],full,empty,wr_rst_busy,rd_rst_busy" */
/* synthesis syn_force_seq_prim="wr_clk" */
/* synthesis syn_force_seq_prim="rd_clk" */;
  input rst;
  input wr_clk /* synthesis syn_isclock = 1 */;
  input rd_clk /* synthesis syn_isclock = 1 */;
  input [22:0]din;
  input wr_en;
  input rd_en;
  output [22:0]dout;
  output full;
  output empty;
  output wr_rst_busy;
  output rd_rst_busy;
endmodule

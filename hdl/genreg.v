`timescale 1ns / 1ps

// provides a 16 bit address space for read and write registers to rest of
// chip.
//
//addr_cntl
// A15,A14,A13,A12,A11,A10,A9,A8,A7,A6,A5,A4,A3,A2,A1,A0,{bits15:2 not presently used} Read/Wr,Select
//Read/Wr = 1 for Read and 0 for Write
//
//*******************************************************************
// map
// ******************************************************************
// r1 = adc_intf_data_rd (read only)
// r0 = adc_intf_data_wr



module gen_reg (
  input clk,
  input reset,
  input [31:0] addr_ctrl,	//[31:16] = address, [15:0] = controls
  input [31:0] data_in,		//data to be written out to rest of chip
  output reg [31:0] data_out,	//data to be read from rest of chip
  input [31:0] adc_intf_data_in,
  output [31:0] adc_intf_data_out,
  output [7:0] debug		//duh
);

//control lines
wire reg_wr;
assign reg_wr = !addr_ctrl[1];	//will equal 1 when writing to a register

wire all_reg_sel;
assign all_reg_sel = addr_ctrl[0];  //will equal 1 when registers are being accessed

wire [255:0] reg_sel;
assign reg_sel[7] = all_reg_sel && (addr_ctrl[31:16] == 16'h0007);
assign reg_sel[6] = all_reg_sel && (addr_ctrl[31:16] == 16'h0006);
assign reg_sel[5] = all_reg_sel && (addr_ctrl[31:16] == 16'h0005);
assign reg_sel[4] = all_reg_sel && (addr_ctrl[31:16] == 16'h0004);
assign reg_sel[3] = all_reg_sel && (addr_ctrl[31:16] == 16'h0003);
assign reg_sel[2] = all_reg_sel && (addr_ctrl[31:16] == 16'h0002);
assign reg_sel[1] = all_reg_sel && (addr_ctrl[31:16] == 16'h0001);
assign reg_sel[0] = all_reg_sel && (addr_ctrl[31:16] == 16'h0000);

//registers
wire [31:0] reg_out0, reg_out1, reg_out2, reg_out3, reg_out4, reg_out5, reg_out6, reg_out7;

reg32_ce2 s7_reg(.in(data_in[31:0]), .reset(reset), .out(reg_out7[31:0]), .clk(clk), .clk_en1(reg_wr), .clk_en2(reg_sel[7]));
reg32_ce2 s6_reg(.in(data_in[31:0]), .reset(reset), .out(reg_out6[31:0]), .clk(clk), .clk_en1(reg_wr), .clk_en2(reg_sel[6]));
reg32_ce2 s5_reg(.in(data_in[31:0]), .reset(reset), .out(reg_out5[31:0]), .clk(clk), .clk_en1(reg_wr), .clk_en2(reg_sel[5]));
reg32_ce2 s4_reg(.in(data_in[31:0]), .reset(reset), .out(reg_out4[31:0]), .clk(clk), .clk_en1(reg_wr), .clk_en2(reg_sel[4]));
reg32_ce2 s3_reg(.in(data_in[31:0]), .reset(reset), .out(reg_out3[31:0]), .clk(clk), .clk_en1(reg_wr), .clk_en2(reg_sel[3]));
reg32_ce2 s2_reg(.in(data_in[31:0]), .reset(reset), .out(reg_out2[31:0]), .clk(clk), .clk_en1(reg_wr), .clk_en2(reg_sel[2]));
//read only
reg32_ce2 s1_reg(.in(adc_intf_data_in[31:0]), .reset(reset), .out(reg_out1[31:0]), .clk(clk), .clk_en1(1'b1), .clk_en2(1'b1));
reg32_ce2 s0_reg(.in(data_in[31:0]), .reset(reset), .out(reg_out0[31:0]), .clk(clk), .clk_en1(reg_wr), .clk_en2(reg_sel[0]));

//read mux
always @ (posedge clk)
begin
	if (reg_sel[7]) data_out[31:0] <= reg_out7[31:0];
	if (reg_sel[6]) data_out[31:0] <= reg_out6[31:0];
	if (reg_sel[5]) data_out[31:0] <= reg_out5[31:0];
	if (reg_sel[4]) data_out[31:0] <= reg_out4[31:0];
	if (reg_sel[3]) data_out[31:0] <= reg_out3[31:0];
	if (reg_sel[2]) data_out[31:0] <= reg_out2[31:0];
	if (reg_sel[1]) data_out[31:0] <= reg_out1[31:0];
	if (reg_sel[0]) data_out[31:0] <= reg_out0[31:0];
end

//to chip
assign adc_intf_data_out[31:0] = reg_out0[31:0];

//debug
assign debug[7:4] = reg_out0[3:0];
assign debug[3:0] = reg_out1[3:0];

endmodule

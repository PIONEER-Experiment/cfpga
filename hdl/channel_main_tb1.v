`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   17:15:01 01/15/2015
// Design Name:   channel_main
// Module Name:   C:/USER_LOCAL/crs/7104_016_LLRF_DSP_Board/Xilinx/CESR_V1/channel_main_tb1.v
// Project Name:  CESR_llrf_fpga
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: channel_main
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module channel_main_tb1;

	// Inputs
	reg [2:0] ch_addr;
	reg [2:0] power_good;
	reg clkin;
	reg acq_trig;
	reg [3:0] io;
	reg bbus_scl;
	reg bbus_sda;
	reg c0_rx;
	reg c0_rx_N;
	reg xcvr_clk;
	reg xcvr_clk_N;
	reg adc_d0n;
	reg adc_d0p;
	reg adc_d1n;
	reg adc_d1p;
	reg adc_d2n;
	reg adc_d2p;
	reg adc_d3n;
	reg adc_d3p;
	reg adc_d4n;
	reg adc_d4p;
	reg adc_d5n;
	reg adc_d5p;
	reg adc_d6n;
	reg adc_d6p;
	reg adc_d7n;
	reg adc_d7p;
	reg adc_d8n;
	reg adc_d8p;
	reg adc_d9n;
	reg adc_d9p;
	reg adc_d10n;
	reg adc_d10p;
	reg adc_d11n;
	reg adc_d11p;
	reg adc_clk_n;
	reg adc_clk_p;
	reg adc_dovrn;
	reg adc_dovrp;
	reg adc_sdo;
	reg adc_syncp;
	reg adc_syncn;

	// Outputs
	wire [9:0] debug;
	wire acq_done;
	wire led1;
	wire led2;
	wire c0_tx;
	wire c0_tx_N;
	wire [2:0] ddr3_ba;
	wire [12:0] ddr3_addr;
	wire ddr3_cas_n;
	wire [0:0] ddr3_cke;
	wire [0:0] ddr3_ck_n;
	wire [0:0] ddr3_ck_p;
	wire [1:0] ddr3_dm;
	wire [0:0] ddr3_odt;
	wire ddr3_ras_n;
	wire ddr3_reset_n;
	wire ddr3_we_n;
	wire adc_sdio;
	wire adc_sdclk;
	wire adc_sdenb;
	wire adc_sresetb;
	wire adc_enable;

	// Bidirs
	wire [15:0] ddr3_dq;
	wire [1:0] ddr3_dqs_n;
	wire [1:0] ddr3_dqs_p;

	// Instantiate the Unit Under Test (UUT)
	channel_main uut (
		.debug(debug), 
		.ch_addr(ch_addr), 
		.power_good(power_good), 
		.clkin(clkin), 
		.acq_trig(acq_trig), 
		.acq_done(acq_done), 
		.io(io), 
		.led1(led1), 
		.led2(led2), 
		.bbus_scl(bbus_scl), 
		.bbus_sda(bbus_sda), 
		.c0_rx(c0_rx), 
		.c0_rx_N(c0_rx_N), 
		.c0_tx(c0_tx), 
		.c0_tx_N(c0_tx_N), 
		.xcvr_clk(xcvr_clk), 
		.xcvr_clk_N(xcvr_clk_N), 
		.ddr3_ba(ddr3_ba), 
		.ddr3_addr(ddr3_addr), 
		.ddr3_dq(ddr3_dq), 
		.ddr3_cas_n(ddr3_cas_n), 
		.ddr3_cke(ddr3_cke), 
		.ddr3_ck_n(ddr3_ck_n), 
		.ddr3_ck_p(ddr3_ck_p), 
		.ddr3_dm(ddr3_dm), 
		.ddr3_dqs_n(ddr3_dqs_n), 
		.ddr3_dqs_p(ddr3_dqs_p), 
		.ddr3_odt(ddr3_odt), 
		.ddr3_ras_n(ddr3_ras_n), 
		.ddr3_reset_n(ddr3_reset_n), 
		.ddr3_we_n(ddr3_we_n), 
		.adc_d0n(adc_d0n), 
		.adc_d0p(adc_d0p), 
		.adc_d1n(adc_d1n), 
		.adc_d1p(adc_d1p), 
		.adc_d2n(adc_d2n), 
		.adc_d2p(adc_d2p), 
		.adc_d3n(adc_d3n), 
		.adc_d3p(adc_d3p), 
		.adc_d4n(adc_d4n), 
		.adc_d4p(adc_d4p), 
		.adc_d5n(adc_d5n), 
		.adc_d5p(adc_d5p), 
		.adc_d6n(adc_d6n), 
		.adc_d6p(adc_d6p), 
		.adc_d7n(adc_d7n), 
		.adc_d7p(adc_d7p), 
		.adc_d8n(adc_d8n), 
		.adc_d8p(adc_d8p), 
		.adc_d9n(adc_d9n), 
		.adc_d9p(adc_d9p), 
		.adc_d10n(adc_d10n), 
		.adc_d10p(adc_d10p), 
		.adc_d11n(adc_d11n), 
		.adc_d11p(adc_d11p), 
		.adc_clk_n(adc_clk_n), 
		.adc_clk_p(adc_clk_p), 
		.adc_dovrn(adc_dovrn), 
		.adc_dovrp(adc_dovrp), 
		.adc_sdo(adc_sdo), 
		.adc_sdio(adc_sdio), 
		.adc_sdclk(adc_sdclk), 
		.adc_sdenb(adc_sdenb), 
		.adc_sresetb(adc_sresetb), 
		.adc_enable(adc_enable), 
		.adc_syncp(adc_syncp), 
		.adc_syncn(adc_syncn)
	);

	initial begin
		// Initialize Inputs
		ch_addr = 0;
		power_good = 0;
		clkin = 0;
		acq_trig = 0;
		io = 0;
		bbus_scl = 0;
		bbus_sda = 0;
		c0_rx = 0;
		c0_rx_N = 1;
		xcvr_clk = 0;
		xcvr_clk_N = 1;
		adc_d0n = 1;
		adc_d0p = 0;
		adc_d1n = 1;
		adc_d1p = 0;
		adc_d2n = 1;
		adc_d2p = 0;
		adc_d3n = 1;
		adc_d3p = 0;
		adc_d4n = 1;
		adc_d4p = 0;
		adc_d5n = 1;
		adc_d5p = 0;
		adc_d6n = 1;
		adc_d6p = 0;
		adc_d7n = 1;
		adc_d7p = 0;
		adc_d8n = 1;
		adc_d8p = 0;
		adc_d9n = 1;
		adc_d9p = 0;
		adc_d10n = 1;
		adc_d10p = 0;
		adc_d11n = 1;
		adc_d11p = 0;
		adc_clk_n = 1;
		adc_clk_p = 0;
		adc_dovrn = 1;
		adc_dovrp = 0;
		adc_sdo = 0;
		adc_syncp = 0;
		adc_syncn = 1;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here

	end

    //setup loopback
    always @ (c0_tx) c0_rx = c0_tx;
    always @ (c0_tx_N) c0_rx_N = c0_tx_N;
 
	always begin
        #10 clkin = ~clkin;   // 50 MHz
   end
      
	always begin
       #4 xcvr_clk = ~xcvr_clk; xcvr_clk_N = ~xcvr_clk_N;  // 125 MHz
  end

endmodule


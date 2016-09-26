`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   14:53:20 09/21/2016
// Design Name:   ddr3_intf_ASYNC
// Module Name:   C:/USER_LOCAL/crs/7104_016_LLRF_DSP_Board/Xilinx/current/ddr3_intf_ASYNC_tb1.v
// Project Name:  llrf_fpga
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: ddr3_intf_ASYNC
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module ddr3_intf_ASYNC_tb1;

	// Inputs
	reg refclk;
	reg sysclk;
	reg reset_clk50;
	reg ddr3_wr_en;
	reg ddr3_wr_fifo_empty;
	reg [131:0] ddr3_wr_fifo_dat;
	reg acq_done;
	reg local_domain_clk;
	reg fill_header_fifo_rd_en;
	reg [22:0] ddr3_rd_start_addr;
	reg [23:0] ddr3_rd_burst_cnt;
	reg enable_reading;
	reg ddr3_rd_fifo_almost_full;
	reg [23:0] calc_total_burst_count;

	// Outputs
	wire ddr3_domain_clk;
	wire reset_ddr3_clk;
	wire ddr3_wr_fifo_rd_en;
	wire ddr3_wr_sync_err;
	wire ddr3_wr_done;
	wire fill_header_fifo_empty;
	wire [151:0] fill_header_fifo_out;
	wire reading_done;
	wire ddr3_rd_fifo_wr_en;
	wire [127:0] ddr3_rd_fifo_input_dat;
	wire ddr3_rd_fifo_input_tlast;
	wire [12:0] ddr3_addr;
	wire [2:0] ddr3_ba;
	wire [0:0] ddr3_ck_p;
	wire [0:0] ddr3_ck_n;
	wire [1:0] ddr3_dqs_p;
	wire [1:0] ddr3_dqs_n;
	wire ddr3_we_n;
	wire [0:0] ddr3_cke;
	wire ddr3_ras_n;
	wire ddr3_cas_n;
	wire ddr3_reset_n;
	wire [1:0] ddr3_dm;
	wire [0:0] ddr3_odt;
	wire app_rdy;

	// Bidirs
	wire [15:0] ddr3_dq;

	reg [31:0] count;			// dummy counter to make all data words be unique

	// Connect the DDR3 memory model
	ddr3_model u_comp_ddr3(
		.rst_n   (ddr3_reset_n),
		.ck      (ddr3_ck_p),
		.ck_n    (ddr3_ck_n),
		.cke     (ddr3_cke),
		.cs_n    (1'b0),
		.ras_n   (ddr3_ras_n),
		.cas_n   (ddr3_cas_n),
		.we_n    (ddr3_we_n),
		.ba      (ddr3_ba),
		.dm_tdqs (ddr3_dm),
		.addr    (ddr3_addr),
		.dq      (ddr3_dq),
		.dqs     (ddr3_dqs_p),
		.dqs_n   (ddr3_dqs_n),
		.tdqs_n  (),
		.odt     (ddr3_odt)	
	);

	// Instantiate the Unit Under Test (UUT)
	ddr3_intf_ASYNC uut (
		.refclk(refclk), 
		.sysclk(sysclk), 
		.reset_clk50(reset_clk50), 
		.ddr3_domain_clk(ddr3_domain_clk), 
		.reset_ddr3_clk(reset_ddr3_clk), 
		.ddr3_wr_en(ddr3_wr_en), 
		.ddr3_wr_fifo_empty(ddr3_wr_fifo_empty), 
		.ddr3_wr_fifo_rd_en(ddr3_wr_fifo_rd_en), 
		.ddr3_wr_fifo_dat(ddr3_wr_fifo_dat), 
		.ddr3_wr_sync_err(ddr3_wr_sync_err), 
		.ddr3_wr_done(ddr3_wr_done), 
		.acq_done(acq_done), 
		.local_domain_clk(local_domain_clk), 
		.fill_header_fifo_empty(fill_header_fifo_empty), 
		.fill_header_fifo_rd_en(fill_header_fifo_rd_en), 
		.fill_header_fifo_out(fill_header_fifo_out), 
		.ddr3_rd_start_addr(ddr3_rd_start_addr), 
		.ddr3_rd_burst_cnt(ddr3_rd_burst_cnt), 
		.enable_reading(enable_reading), 
		.reading_done(reading_done), 
		.ddr3_rd_fifo_wr_en(ddr3_rd_fifo_wr_en), 
		.ddr3_rd_fifo_input_dat(ddr3_rd_fifo_input_dat), 
		.ddr3_rd_fifo_almost_full(ddr3_rd_fifo_almost_full), 
		.ddr3_rd_fifo_input_tlast(ddr3_rd_fifo_input_tlast), 
		.calc_total_burst_count(calc_total_burst_count), 
		.ddr3_addr(ddr3_addr), 
		.ddr3_ba(ddr3_ba), 
		.ddr3_dq(ddr3_dq), 
		.ddr3_ck_p(ddr3_ck_p), 
		.ddr3_ck_n(ddr3_ck_n), 
		.ddr3_dqs_p(ddr3_dqs_p), 
		.ddr3_dqs_n(ddr3_dqs_n), 
		.ddr3_we_n(ddr3_we_n), 
		.ddr3_cke(ddr3_cke), 
		.ddr3_ras_n(ddr3_ras_n), 
		.ddr3_cas_n(ddr3_cas_n), 
		.ddr3_reset_n(ddr3_reset_n), 
		.ddr3_dm(ddr3_dm), 
		.ddr3_odt(ddr3_odt), 
		.app_rdy(app_rdy)
	);

	initial begin
		// Initialize Inputs
		refclk = 0;
		sysclk = 0;
		reset_clk50 = 1;
		ddr3_wr_en = 0;
		ddr3_wr_fifo_empty = 1;
		ddr3_wr_fifo_dat = 0;
		acq_done = 0;
		local_domain_clk = 0;
		fill_header_fifo_rd_en = 0;
		ddr3_rd_start_addr = 0;
		ddr3_rd_burst_cnt = 0;
		enable_reading = 0;
		ddr3_rd_fifo_almost_full = 0;
		calc_total_burst_count = 0;
		count = 0;

		// Wait 100 ns for global reset to finish
		#100;
	    #50 reset_clk50 = 0;
	end
        
		// Add stimulus here
    	// clocks
		always begin
		    #2.5 sysclk = ~sysclk;   // was 250 MHz, now 200 MHz
		end
		always begin
		    #2.5 refclk = ~refclk;   // 200 MHz
		end
		always begin
		    #7 local_domain_clk = ~local_domain_clk;   // 72 MHz
		end

	always @(posedge ddr3_domain_clk) begin
		ddr3_wr_fifo_dat <= {100'h1_4002_0003_0000_0004_0000_0100, count[31:0]};
		if (ddr3_wr_fifo_rd_en) count[31:0] <= count[31:0] + 1;
	end

	initial begin
		#1500 	ddr3_wr_fifo_empty <= 0;// input, data is available when this is not asserted
				ddr3_wr_en = 1;
 
		//#10000		acq_enabled <= 0;
		//#1000		ddr3_rd_burst_addr[22:0] <= 23'h00_0020;
		//			ddr3_rd_one_burst <= 1;
		//#6000		ddr3_rd_one_burst <= 0;	     
		//#1000		ddr3_rd_burst_addr[22:0] <= 23'h00_0021;
		//			ddr3_rd_one_burst <= 1;
		//#6000		ddr3_rd_one_burst <= 0;	     
	end

      
endmodule


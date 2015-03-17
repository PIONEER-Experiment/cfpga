`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   10:39:01 12/12/2014
// Design Name:   ddr3_intf
// Module Name:   C:/USER_LOCAL/crs/7104_016_LLRF_DSP_Board/Xilinx/CESR_V1/ddr3_intf_tb1.v
// Project Name:  CESR_llrf_fpga
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: ddr3_intf
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
// connections to the DDR3 chips
module ddr3_intf_tb1;

	// Inputs
	reg refclk;// input, 200 MHz for I/O timing adjustments
	reg sysclk;// input, drives the Xilinx DDR3 IP
	reg reset;// input, reset at startup or when requested by master FPGA 
	reg acq_enabled;						// the system is in acquisition mode, ratehr than readout mode
	reg ddr3_wr_fifo_empty;					// input, data is available when this is not asserted
	reg [127:0] ddr3_wr_fifo_dat;			// input, data from the ddr3_write_fifo, to be written to the DDR3
	reg local_domain_clk;						// input, the local interface synchronous clock
	reg fill_header_fifo_rd_en;				// input, remove the current data from the FIFO
	reg [22:0] ddr3_rd_burst_addr;			// input, the address of the requested 128-bit burst
	reg ddr3_rd_one_burst;					// input, get one 128-bit burst from the DDR3

	// Outputs
	wire ddr3_domain_clk;						// output, the DDR3 user-interface synchronous clock
	wire fill_header_fifo_empty;				// output, a header is available when not asserted
	wire [127:0] fill_header_fifo_out;		// output, data at the head of the FIFO
	wire ddr3_one_burst_rdy;					// output, the requested 128-bit burst is ready
	wire [127:0] ddr3_one_burst_data;			// output, the requested 128-bit burst
	wire ddr3_wr_fifo_rd_en;					// output, use and remove the data on the FIFO head
	wire [7:0] debug;
	wire ddr3_wr_sync_err;
	
	// DDR3 chip connections
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
	// Bidirs
	wire [15:0] ddr3_dq;
	wire app_rdy;				// output, PHY calibration is done

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
	ddr3_intf uut (
		.refclk(refclk), 
		.sysclk(sysclk), 
		.reset(reset), 
		.ddr3_domain_clk(ddr3_domain_clk),			// output, the DDR3 user-interface synchronous clock
		.acq_enabled(acq_enabled),							// the system is in acquisition mode, ratehr than readout mode
		.ddr3_wr_fifo_empty(ddr3_wr_fifo_empty),	// input, data is available when this is not asserted
		.ddr3_wr_fifo_rd_en(ddr3_wr_fifo_rd_en),	// output, use and remove the data on the FIFO head
		.ddr3_wr_fifo_dat(ddr3_wr_fifo_dat[127:0]),			// input, data from the ddr3_write_fifo, to be written to the DDR3
		.ddr3_wr_sync_err(ddr3_wr_sync_err),
		// reading connections
		.local_domain_clk(local_domain_clk),						// input, the local interface synchronous clock
		.fill_header_fifo_empty(fill_header_fifo_empty),				// output, a header is available when not asserted
		.fill_header_fifo_rd_en(fill_header_fifo_rd_en),				// input, remove the current data from the FIFO
		.fill_header_fifo_out(fill_header_fifo_out[127:0]),		// output, data at the head of the FIFO
		.ddr3_rd_burst_addr(ddr3_rd_burst_addr[22:0]),			// input, the address of the requested 128-bit burst
		.ddr3_rd_one_burst(ddr3_rd_one_burst),					// input, get one 128-bit burst from the DDR3
		.ddr3_one_burst_rdy(ddr3_one_burst_rdy),					// output, the requested 128-bit burst is ready
		.ddr3_one_burst_data(ddr3_one_burst_data[127:0]),			// output, the requested 128-bit burst

		// connections to the DDR3 chips
		.ddr3_dq(ddr3_dq),
		.ddr3_addr(ddr3_addr), 
		.ddr3_ba(ddr3_ba), 
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
		.app_rdy(app_rdy)		// output, PHY calibration is done
	);

	initial begin
		// Initialize Inputs
		refclk = 0;
		sysclk = 0;
		reset = 1;
		acq_enabled = 0;
		ddr3_wr_fifo_empty = 1;					// input, data is available when this is not asserted
		ddr3_wr_fifo_dat = 128'h4002_0003_0000_0004_0000_0100_0000_0001;					// input, data from the ddr3_write_fifo, to be written to the DDR3
		local_domain_clk = 0;
		fill_header_fifo_rd_en = 0;
		ddr3_rd_burst_addr[22:0] = 23'h00_0000;
		ddr3_rd_one_burst = 0;
		count[31:0] = 32'h0000_0000;
				
		// Wait 100 ns for global reset to finish
		#100;
	    #50 reset = 1'b0;
     
    end        

	// Add stimulus here
    // clocks
    always begin
        #2 sysclk = ~sysclk;   // 250 MHz
    end
    always begin
        #2.5 refclk = ~refclk;   // 200 MHz
    end
    always begin
        #7 local_domain_clk = ~local_domain_clk;   // 72 MHz
    end

	always @(posedge ddr3_domain_clk) begin
		ddr3_wr_fifo_dat <= {96'h4002_0003_0000_0004_0000_0100, count[31:0]};
		if (ddr3_wr_fifo_rd_en) count[31:0] <= count[31:0] + 1;
	end

	initial begin
		#200000 	acq_enabled <= 1;
					ddr3_wr_fifo_empty <= 0;// input, data is available when this is not asserted 
		#10000		acq_enabled <= 0;
		#1000		ddr3_rd_burst_addr[22:0] <= 23'h00_0020;
					ddr3_rd_one_burst <= 1;
		#6000		ddr3_rd_one_burst <= 0;	     
		#1000		ddr3_rd_burst_addr[22:0] <= 23'h00_0021;
					ddr3_rd_one_burst <= 1;
		#6000		ddr3_rd_one_burst <= 0;	     
	end
	     
endmodule


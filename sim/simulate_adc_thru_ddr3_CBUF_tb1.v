`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   09:42:22 09/23/2016
// Design Name:   simulate_adc_thru_ddr3_ASYNC
// Module Name:   C:/USER_LOCAL/crs/7104_016_LLRF_DSP_Board/Xilinx/current/simulate_adc_thru_ddr3_ASYNC_tb1.v
// Project Name:  llrf_fpga
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: simulate_adc_thru_ddr3_ASYNC
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module simulate_adc_thru_ddr3_CBUF_tb1;

	// Inputs
	reg [15:0] channel_tag;
	reg [23:0] initial_fill_num;
	reg initial_fill_num_wr;
	reg [2:0] ch_addr;
	reg adc_buf_delay_data_reset;
	reg [4:0] adc_buf_data_delay;
	reg [10:0] async_num_bursts;
	reg [11:0] async_pre_trig;
	reg clk50;
	reg clk125;
	reg clk200;
	reg clk250;
	reg rst_from_master;
	reg acq_trig;
	reg acq_enable0;
	reg acq_enable1;
	reg [11:0] adc_in_p;
	reg [11:0] adc_in_n;
	reg adc_clk_n;
	reg adc_clk_p;
	reg adc_dovrn;
	reg adc_dovrp;
	reg [22:0] ddr3_rd_start_addr;
	reg [23:0] ddr3_rd_burst_cnt;
	reg enable_reading;

	// Outputs
	wire [23:0] fill_num;
	wire [64:0] adc_buf_current_data_delay;
	wire acq_done;
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
	wire [127:0] ddr3_rd_fifo_input_dat;
	wire [151:0] fill_header_fifo_out;
	wire reading_done;

	// Bidirs
	wire [15:0] ddr3_dq;
	wire [1:0] ddr3_dqs_n;
	wire [1:0] ddr3_dqs_p;

	// Instantiate the Unit Under Test (UUT)
	simulate_adc_thru_ddr3_ASYNC uut (
		.fill_num(fill_num), 
		.channel_tag(channel_tag), 
		.initial_fill_num(initial_fill_num), 
		.initial_fill_num_wr(initial_fill_num_wr), 
		.ch_addr(ch_addr), 
		.adc_buf_delay_data_reset(adc_buf_delay_data_reset), 
		.adc_buf_data_delay(adc_buf_data_delay), 
		.adc_buf_current_data_delay(adc_buf_current_data_delay), 
		.async_num_bursts(async_num_bursts), 
		.async_pre_trig(async_pre_trig), 
		.clk50(clk50), 
		.clk125(clk125), 
		.clk200(clk200), 
		.clk250(clk250), 
		.rst_from_master(rst_from_master), 
		.acq_trig(acq_trig), 
		.acq_done(acq_done), 
		.acq_enable0(acq_enable0), 
		.acq_enable1(acq_enable1), 
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
		.adc_in_p(adc_in_p), 
		.adc_in_n(adc_in_n), 
		.adc_clk_n(adc_clk_n), 
		.adc_clk_p(adc_clk_p), 
		.adc_dovrn(adc_dovrn), 
		.adc_dovrp(adc_dovrp), 
		.ddr3_rd_fifo_input_dat(ddr3_rd_fifo_input_dat), 
		.ddr3_rd_start_addr(ddr3_rd_start_addr), 
		.ddr3_rd_burst_cnt(ddr3_rd_burst_cnt), 
		.fill_header_fifo_out(fill_header_fifo_out), 
		.enable_reading(enable_reading), 
		.reading_done(reading_done)
	);

	initial begin
		// Initialize Inputs
		adc_in_p[11:0] = 12'h000;          // [11:0] array of ADC 'p' data pins
		adc_in_n[11:0] = 12'hfff;          // [11:0] array of ADC 'n' data pins
		adc_dovrp = 1'b0;                // ADC 'p' over-range pin
		adc_dovrn = 1'b1;                // ADC 'n' over-range pin
		adc_clk_p = 1'b0;                // ADC 'p' clk pin
		adc_clk_n = 1'b1;                // ADC 'n' clk pin
		rst_from_master = 1'b1;              // synchronously negated  
		clk50 = 1'b0;
		clk125 = 1'b0;
		clk200 = 1'b0;
		clk250 = 1'b0;
		channel_tag[15:0] = 16'h0000;   // stuff about the channel to put in the header
		initial_fill_num[23:0] = 24'h000000;  // event number to assign to the first fill
		initial_fill_num_wr = 1'b0;      // write-strobe to store the initial_fill_num
		adc_buf_delay_data_reset = 1'b0;
		adc_buf_data_delay[4:0] = 5'h00;
		async_num_bursts[10:0] = 11'h000;  // number of 8-sample bursts in an ASYNC waveform
		async_pre_trig[11:0] = 12'h000;    // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
		acq_enable0 = 1'b0;                  // arm the logic to accept triggers
		acq_enable1 = 1'b0;                  // arm the logic to accept triggers
		acq_trig = 1'b0;                 // trigger the logic to start collecting data

		ch_addr = 0;
		ddr3_rd_start_addr = 0;
		ddr3_rd_burst_cnt = 0;
		enable_reading = 0;

		// Wait 100 ns for global reset to finish
		#100;
	    #20 rst_from_master = 1'b0;
		
		// wait for startup_reset to finish
		#5500
		    
		#20 initial_fill_num[23:0] = 24'h000001;  // event number to assign to the first fill
            channel_tag[15:0] = 16'h0008;   // stuff about the channel to put in the header
			async_num_bursts[10:0] = 11'h00a;  // number of 8-sample bursts in an ASYNC waveform
			async_pre_trig[11:0] = 12'h000;    // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
        #10 initial_fill_num_wr = 1'b1;      // write-strobe to store the initial_fill_num
        #10 initial_fill_num_wr = 1'b0;      // write-strobe to store the initial_fill_num

        #20 acq_enable0 = 1'b1;              // arm the logic to accept triggers
			acq_enable1 = 1'b0;              // arm the logic to accept triggers

        #20 acq_trig = 1'b1;                 // trigger the logic to start collecting data
        #40 acq_trig = 1'b0;                 // trigger the logic to start collecting data

        //#100 acq_trig = 1'b1;                // trigger the logic to start collecting data
        //#40 acq_trig = 1'b0;                 // trigger the logic to start collecting data

        #1400 acq_enable0 = 1'b0;             // end the fill
			acq_enable1 = 1'b0;              // end the fill
      
		// reset before another fill
		//#1500
	    //#20 rst_from_master = 1'b1;
	    //#20 rst_from_master = 1'b0;
		//#20 initial_fill_num[23:0] = 24'h000002;  // event number to assign to the first fill
        //    channel_tag[15:0] = 16'h0008;   // stuff about the channel to put in the header
	    //	async_num_bursts[10:0] = 11'h004;  // number of 8-sample bursts in an ASYNC waveform
	    //	async_pre_trig[11:0] = 12'h000;    // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
        //#10 initial_fill_num_wr = 1'b1;      // write-strobe to store the initial_fill_num
        //#10 initial_fill_num_wr = 1'b0;      // write-strobe to store the initial_fill_num

		#500
				
        #20 acq_enable0 = 1'b1;              // arm the logic to accept triggers
			acq_enable1 = 1'b0;              // arm the logic to accept triggers

		#20 acq_trig = 1'b1;                 // trigger the logic to start collecting data
		#40 acq_trig = 1'b0;                 // trigger the logic to start collecting data

			//#100 acq_trig = 1'b1;                // trigger the logic to start collecting data
			//#40 acq_trig = 1'b0;                 // trigger the logic to start collecting data

		#200 acq_enable0 = 1'b0;             // end the fill
		acq_enable1 = 1'b0;              // end the fill

	end

    // clocks
	always begin
        #10 clk50 = ~clk50;   // 50 MHz
    end
	always begin
        #4 clk125 = ~clk125;   // 125 MHz
    end
	always begin
        #2.5 clk200 = ~clk200;   // 200 MHz
    end
	always begin
        #2 clk250 = ~clk250;   // 250 MHz
    end
   	always begin
       #1.25 adc_clk_p = ~adc_clk_p; adc_clk_n = ~adc_clk_n;  // 400 MHz
    end

    // ADC DDR input
    always @ (negedge adc_clk_p or posedge adc_clk_p) begin
        adc_in_p[11:0] <= adc_in_p[11:0] + 12'h001;
        adc_in_n[11:0] <= adc_in_n[11:0] - 12'h001;
    end
      
endmodule


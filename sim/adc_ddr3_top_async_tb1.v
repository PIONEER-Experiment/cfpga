`timescale 1ns / 10ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/28/2015 08:45:18 AM
// Design Name: 
// Module Name: adc_acq_top_tb1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module adc_ddr3_top_async_tb1;

    // inputs
    reg [11:0] adc_in_p;          // [11:0] array of ADC 'p' data pins
    reg [11:0] adc_in_n;          // [11:0] array of ADC 'n' data pins
    reg adc_ovr_p;                // ADC 'p' over-range pin
    reg adc_ovr_n;                // ADC 'n' over-range pin
    reg adc_clk_p;                // ADC 'p' clk pin
    reg adc_clk_n;                // ADC 'n' clk pin
	reg clk50;
    reg clk200;                   // for input pin timing delay settings
	reg clk250;						// for DDR3 operation
    reg clk125;						// for buffer readout
    reg [15:0] channel_tag;   // stuff about the channel to put in the header
    reg [10:0] async_num_bursts;  // number of sample bursts in a ASYNC fill
    reg [11:0] async_pre_trig; // number of sample from before the trigger time
    reg [23:0] initial_fill_num;  // event number to assign to the first fill
    reg initial_fill_num_wr;      // write-strobe to store the initial_fill_num
	reg acq_reset;
	reg acq_enable0;              // indicates enabled for triggers, and fill type
    reg acq_enable1;              // indicates enabled for triggers, and fill type
    reg acq_trig;                 // trigger the logic to start collecting data
 	reg adc_buf_delay_data_reset;	// use the new delay settings
	reg [4:0] adc_buf_data_delay;	// 5 delay-tap-bits per line, all lines always all the same
	reg fill_header_fifo_rd_en;		// input, remove the current data from the FIFO
	reg [22:0] ddr3_rd_start_addr;      // input, the address of the first requested 128-bit burst
	reg [23:0] ddr3_rd_burst_cnt;        // input, the number of bursts to read
	reg enable_reading;                     // input, initialize the address generator and both counters, go
	reg ddr3_rd_fifo_almost_full;    // there is not much room left    
    // outputs
    wire acq_done;                 // acquisition is done
	wire acq_enabled;					// the system is in acquisition mode, rather than readout mode
	wire fill_header_fifo_empty;		// output, a header is available when not asserted
	wire [151:0] fill_header_fifo_out;	// output, data at the head of the FIFO
	wire [127:0] ddr3_rd_fifo_input_dat; // output, memory data
	wire reading_done;                         // output, reading is complete
	wire ddr3_rd_fifo_input_tlast;
	
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
	wire ddr3_domain_clk;
	reg measure_eff;	
	reg [31:0] app_rdy_cnt;		// count the number of DDR3 burst periods where 'app_rdy' is asserted
			
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

adc_ddr3_top_async uut(
    // inputs
    .adc_in_p(adc_in_p ),          // [11:0] array of ADC 'p' data pins
    .adc_in_n(adc_in_n),          // [11:0] array of ADC 'n' data pins
    .adc_ovr_p( adc_ovr_p),                // ADC 'p' over-range pin
    .adc_ovr_n(adc_ovr_n ),                // ADC 'n' over-range pin
    .adc_clk_p( adc_clk_p),                // ADC 'p' clk pin
    .adc_clk_n(adc_clk_n ),                // ADC 'n' clk pin
    .acq_reset(acq_reset ),              // synchronously negated  
    .clk200(clk200 ),                   // for input pin timing delay settings
    .clk50(clk50 ),                   // 
    .clk250(clk250 ),                   // 
    .clk125(clk125 ),                   // 
    .channel_tag(channel_tag ),   // stuff about the channel to put in the header
  	.async_num_bursts(async_num_bursts[10:0]),           // number of 8-sample bursts in an ASYNC waveform
    .async_pre_trig(async_pre_trig[11:0]),             // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    .initial_fill_num( initial_fill_num),  // event number to assign to the first fill
    .initial_fill_num_wr(initial_fill_num_wr ),      // write-strobe to store the initial_fill_num
	.acq_enable0(acq_enable0),
	.acq_enable1(acq_enable1),
    .acq_trig(acq_trig ),                 // trigger the logic to start collecting data
	.acq_done(acq_done),
	.adc_acq_sm_idle(adc_acq_sm_idle),
 	.adc_buf_delay_data_reset(adc_buf_delay_data_reset),	// use the new delay settings
	.adc_buf_data_delay(adc_buf_data_delay[4:0]),	// 5 delay-tap-bits per line, all lines always all the same
	.fill_header_fifo_rd_en(fill_header_fifo_rd_en),		// input, remove the current data from the FIFO
    .ddr3_rd_start_addr(ddr3_rd_start_addr[22:0]),      // input, the address of the first requested 128-bit burst
	.ddr3_rd_burst_cnt(ddr3_rd_burst_cnt[23:0]),        // input, the number of bursts to read
	.enable_reading(enable_reading),                     // input, initialize the address generator and both counters, go
	.ddr3_rd_fifo_almost_full(ddr3_rd_fifo_almost_full),    // there is not much room left    
   // outputs
    .ddr3_rd_fifo_input_tlast(ddr3_rd_fifo_input_tlast),    // the last burst for this fill 
	.acq_enabled(acq_enabled),					// the system is in acquisition mode, rather than readout mode
    .fill_header_fifo_empty(fill_header_fifo_empty),		// output, a header is available when not asserted
	.fill_header_fifo_out(fill_header_fifo_out[151:0]),	// output, data at the head of the FIFO
	.ddr3_rd_fifo_input_dat(ddr3_rd_fifo_input_dat[127:0]), // output, memory data
	.reading_done(reading_done),                         // output, reading is complete
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
   .ddr3_domain_clk(ddr3_domain_clk),			// output, the DDR3 user-interface synchronous clock
   .app_rdy(app_rdy)
 
);

	initial begin
		// Initialize Inputs
        adc_in_p[11:0] = 12'h000;          // [11:0] array of ADC 'p' data pins
        adc_in_n[11:0] = 12'hfff;          // [11:0] array of ADC 'n' data pins
        adc_ovr_p = 1'b0;                // ADC 'p' over-range pin
        adc_ovr_n = 1'b1;                // ADC 'n' over-range pin
        adc_clk_p = 1'b0;                // ADC 'p' clk pin
        adc_clk_n = 1'b1;                // ADC 'n' clk pin
        clk50 = 1'b0;                   // 
        clk200 = 1'b0;                   // for input pin timing delay settings
        clk250 = 1'b0;                   // 
        clk125 = 1'b0;                   // 
        channel_tag[15:0] = 16'h0000;   // stuff about the channel to put in the header
        initial_fill_num[23:0] = 24'h000000;  // event number to assign to the first fill
        initial_fill_num_wr = 1'b0;      // write-strobe to store the initial_fill_num
    	async_num_bursts[10:0] = 3;  // number of sample bursts in a ASYNC fill
        async_pre_trig[11:0] = 5; // number of sample from before the trigger time
        acq_enable0 = 1'b0;                  // arm the logic to accept triggers
        acq_enable1 = 1'b0;                  // arm the logic to accept triggers
        acq_trig = 1'b0;                 // trigger the logic to start collecting data
        acq_reset = 1'b1;                // reset all of the acquisition logic
		adc_buf_delay_data_reset = 1'b0;
		adc_buf_data_delay[4:0] = 5'h00;
		fill_header_fifo_rd_en = 1'b0;
		measure_eff = 1'b0;
		ddr3_rd_start_addr[22:0] = 23'b0;      // input, the address of the first requested 128-bit burst
		ddr3_rd_burst_cnt[23:0] = 24'b0;        // input, the number of bursts to read
		enable_reading = 1'b0;
		ddr3_rd_fifo_almost_full= 1'b0;    // there is not much room left    

		// Wait 100 ns for global reset to finish
		#100;
	    #20	acq_reset = 1'b0;                // reset all of the acquisition logic

		// wait 6 usec for statrtup_reset block to finish
		#6000 initial_fill_num[23:0] = 24'h000055;  // event number to assign to the first fill
            channel_tag[15:0] = 16'h0008;   // stuff about the channel to put in the header
        #10 initial_fill_num_wr = 1'b1;      // write-strobe to store the initial_fill_num
        #10 initial_fill_num_wr = 1'b0;      // write-strobe to store the initial_fill_num

        #20 acq_enable0 = 1'b1;                  // arm the logic to accept triggers
			acq_enable1 = 1'b0;                  // arm the logic to accept triggers

		#20 acq_trig = 1'b1;                 // trigger the logic to start collecting data
		#40 acq_trig = 1'b0;                 // trigger the logic to start collecting data

		#100 acq_trig = 1'b1;                // trigger the logic to start collecting data
		#40 acq_trig = 1'b0;                 // trigger the logic to start collecting data

		#10 acq_enable0 = 1'b0;             // end the fill
			acq_enable1 = 1'b0;              // end the fill


     end        

    // clocks
	always begin
        #2.5 clk200 = ~clk200;   // 200 MHz
    end
	always begin
        #2.5 clk250 = ~clk250;   // !!! set to 200 MHz for now!!! 250 MHz
    end
	always begin
        #4.0 clk125 = ~clk125;   // 125 MHz
    end
	always begin
        #10 clk50 = ~clk50;   // 50 MHz
    end
	always begin
       #1.25 adc_clk_p = ~adc_clk_p; adc_clk_n = ~adc_clk_n;  // 400 MHz
       //#2.0 adc_clk_p = ~adc_clk_p; adc_clk_n = ~adc_clk_n;  // 250 MHz
    end

    // ADC DDR input
    always @ (negedge adc_clk_p or posedge adc_clk_p) begin
        adc_in_p[11:0] <= adc_in_p[11:0] + 12'h001;
        adc_in_n[11:0] <= adc_in_n[11:0] - 12'h001;
    end

	// count ddr3 periods when memory can accept new addresses
	always @ (posedge ddr3_domain_clk) begin
		if (!measure_eff) app_rdy_cnt[31:0] <= 0;
		else if (app_rdy) app_rdy_cnt[31:0] <= app_rdy_cnt[31:0] + 1;
	end
	  
//	initial begin
//		// start an acquisition
//		#105000 acq_trig = 1'b1; measure_eff=1'b1;                 // trigger the logic to start collecting data
//		#100	acq_trig = 1'b0;

//		// start another acquisition
//		#500    acq_trig = 1'b1;                  // trigger the logic to start collecting data
//		#100	acq_trig = 1'b0;

// 		// disable triggers and enable readout
//		#2000	acq_enable0 = 1'b0;                  // change to readout mode
//				acq_enable1 = 1'b0;                  // 

////		// start a readout
//		#1000	ddr3_rd_start_addr[22:0] = fill_header_fifo_out[75:53];      // input, the address of the first requested 128-bit burst
//				ddr3_rd_burst_cnt[23:0] = 24'd10;        // input, the number of bursts to read
				
//		#100	enable_reading = 1'b1;

//		// see what else is in the fill_header_fifo
//		#1000 	fill_header_fifo_rd_en = 1'b1;
//		#20		fill_header_fifo_rd_en = 1'b0;
		
				
    
//    end
    
endmodule

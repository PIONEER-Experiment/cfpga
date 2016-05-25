`timescale 1ns / 1ps

module adc_to_circ_buf_ASYNC_tb1;

	// Inputs
	reg [11:0] adc_in_p;
	reg [11:0] adc_in_n;
	reg adc_ovr_p;
	reg adc_ovr_n;
	reg adc_clk_p;
	reg adc_clk_n;
	reg reset_clk50;
	reg clk200;
	reg extend_acq_enabled;
	reg acq_trig;
	reg acq_reset;
	reg adc_buf_delay_data_reset;
	reg [4:0] adc_buf_data_delay;
	reg dummy_data_reset;
	reg use_dummy_data;

	// Outputs
	wire adc_clk;
	wire [64:0] adc_buf_current_data_delay;
	wire [15:0] circ_buf_wr_addr;
	wire [25:0] circ_buf_wr_dat;

	// Instantiate the Unit Under Test (UUT)
	adc_to_circ_buf_ASYNC uut (
		.adc_in_p(adc_in_p), 
		.adc_in_n(adc_in_n), 
		.adc_ovr_p(adc_ovr_p), 
		.adc_ovr_n(adc_ovr_n), 
		.adc_clk_p(adc_clk_p), 
		.adc_clk_n(adc_clk_n), 
		.reset_clk50(reset_clk50), 
		.clk200(clk200), 
		.extend_acq_enabled(extend_acq_enabled), 
		.acq_trig(acq_trig), 
		.acq_reset(acq_reset), 
		.adc_buf_delay_data_reset(adc_buf_delay_data_reset), 
		.adc_buf_data_delay(adc_buf_data_delay), 
		.dummy_data_reset(dummy_data_reset), 
		.use_dummy_data(use_dummy_data), 
		.adc_clk(adc_clk), 
		.adc_buf_current_data_delay(adc_buf_current_data_delay), 
		.circ_buf_wr_addr(circ_buf_wr_addr), 
		.circ_buf_wr_dat(circ_buf_wr_dat)
	);

	initial begin
		// Initialize Inputs
		adc_in_p[11:0] = 12'h000;
		adc_in_n[11:0] = 12'hfff;
		adc_ovr_p = 1'b0;
		adc_ovr_n = 1'b1;
		adc_clk_p = 1'b0;
		adc_clk_n = 1'b1;
		reset_clk50 = 1'b1;
		clk200 = 1'b0;
		extend_acq_enabled = 1'b0;
		acq_trig = 1'b0;
		acq_reset = 1'b1;
		adc_buf_delay_data_reset = 1'b0;
		adc_buf_data_delay[4:0] = 5'h00;
		dummy_data_reset = 1'b1;
		use_dummy_data = 1'b0;

		// Wait 100 ns for global reset to finish
		#100;
	    #20 reset_clk50 = 1'b0;
        
        #20 acq_reset = 1'b0;                // reset all of the acquisition logic
			dummy_data_reset = 1'b0;
			use_dummy_data = 1'b1;
	    #20 extend_acq_enabled = 1'b1;         // arm the logic to accept triggers
	    //#20 acq_trig = 1'b1;                 // trigger the logic to start collecting data

	end

    // clocks
	always begin
        #2.5 clk200 = ~clk200;   // 200 MHz
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


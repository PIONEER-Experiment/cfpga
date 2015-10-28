`timescale 1ns / 1ps
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
module adc_acq_top_tb1;

    // inputs
    reg [11:0] adc_in_p;          // [11:0] array of ADC 'p' data pins
    reg [11:0] adc_in_n;          // [11:0] array of ADC 'n' data pins
    reg adc_ovr_p;                // ADC 'p' over-range pin
    reg adc_ovr_n;                // ADC 'n' over-range pin
    reg adc_clk_p;                // ADC 'p' clk pin
    reg adc_clk_n;                // ADC 'n' clk pin
    reg reset_clk50;              // synchronously negated  
    reg clk200;                   // for input pin timing delay settings
    reg [15:0] channel_tag;   // stuff about the channel to put in the header
    reg [22:0] num_muon_bursts;  // number of sample bursts in a MUON fill
    reg [22:0] num_laser_bursts; // number of sample bursts in a LASER fill
    reg [22:0] num_ped_bursts;   // number of sample bursts in a PEDESTAL fill
    reg [23:0] initial_fill_num;  // event number to assign to the first fill
    reg initial_fill_num_wr;      // write-strobe to store the initial_fill_num
	reg acq_enable0;              // indicates enabled for triggers, and fill type
    reg acq_enable1;              // indicates enabled for triggers, and fill type
     reg acq_trig;                 // trigger the logic to start collecting data
    reg acq_reset;                // reset all of the acquisition logic
 	reg adc_buf_delay_data_reset;	// use the new delay settings
	reg [4:0] adc_buf_data_delay;	// 5 delay-tap-bits per line, all lines always all the same
	reg ddr3_wr_done;             // asserted when the 'ddr3_wr_control' is in the DONE state
	reg [11:0] num_waveforms;		// number of waveforms to store per trigger
	reg [21:0] waveform_gap;		// idle time between waveforms 
    // outputs
	wire [64:0] adc_buf_current_data_delay; // 13 lines *5 bits/line, current tap settings
	wire [23:0] fill_num;         // fill number for this fill
    wire [127:0] adc_acq_out_dat; // 128-bit header or ADC data
    wire adc_acq_out_valid;       // current data should be stored in the FIFO
    wire adc_clk;		         // ADC clock used by the FIFO
    wire acq_done;                 // acquisition is done
	wire adc_acq_full_reset;		// reset all aspects of data collection/storage/readout
	wire acq_enabled;             // the system is in acquisition mode, rather than readout mode
	wire adc_acq_sm_idl;          // ADC acquisition state machine is idle (used for front panel LED status)

adc_acq_top uut(
    // inputs
    .adc_in_p(adc_in_p ),          // [11:0] array of ADC 'p' data pins
    .adc_in_n(adc_in_n),          // [11:0] array of ADC 'n' data pins
    .adc_ovr_p( adc_ovr_p),                // ADC 'p' over-range pin
    .adc_ovr_n(adc_ovr_n ),                // ADC 'n' over-range pin
    .adc_clk_p( adc_clk_p),                // ADC 'p' clk pin
    .adc_clk_n(adc_clk_n ),                // ADC 'n' clk pin
    .reset_clk50(reset_clk50 ),              // synchronously negated  
    .clk200(clk200 ),                   // for input pin timing delay settings
    .channel_tag(channel_tag ),   // stuff about the channel to put in the header
    .num_muon_bursts(num_muon_bursts ),  // number of sample bursts in a MUON fill
    .num_laser_bursts( num_laser_bursts), // number of sample bursts in a LASER fill
    .num_ped_bursts(num_ped_bursts ),   // number of sample bursts in a PEDESTAL fill
    .initial_fill_num( initial_fill_num),  // event number to assign to the first fill
    .initial_fill_num_wr(initial_fill_num_wr ),      // write-strobe to store the initial_fill_num
	.acq_enable0(acq_enable0),
	.acq_enable1(acq_enable1),
    .acq_trig(acq_trig ),                 // trigger the logic to start collecting data
    .acq_reset( acq_reset),                // reset all of the acquisition logic
 	.adc_buf_delay_data_reset(adc_buf_delay_data_reset),	// use the new delay settings
	.adc_buf_data_delay(adc_buf_data_delay[4:0]),	// 5 delay-tap-bits per line, all lines always all the same
    .ddr3_wr_done(ddr3_wr_done),             // asserted when the 'ddr3_wr_control' is in the DONE state
	.num_waveforms(num_waveforms),		// number of waveforms to store per trigger
	.waveform_gap(waveform_gap),		// idle time between waveforms 
    // outputs
	.adc_buf_current_data_delay(adc_buf_current_data_delay), // 13 lines *5 bits/line, current tap settings
    .fill_num(fill_num),         // fill number for this fill
     .adc_acq_out_dat(adc_acq_out_dat ), // 128-bit header or ADC data
    .adc_acq_out_valid(adc_acq_out_valid ),       // current data should be stored in the FIFO
    .adc_clk(adc_clk ),         // ADC clock used by the FIFO
 	.adc_acq_full_reset(adc_acq_full_reset),		// reset all aspects of data collection/storage/readout
   .acq_done(acq_done )                 // acquisition is done
);

	initial begin
		// Initialize Inputs
        adc_in_p[11:0] = 12'h000;          // [11:0] array of ADC 'p' data pins
        adc_in_n[11:0] = 12'hfff;          // [11:0] array of ADC 'n' data pins
        adc_ovr_p = 1'b0;                // ADC 'p' over-range pin
        adc_ovr_n = 1'b1;                // ADC 'n' over-range pin
        adc_clk_p = 1'b0;                // ADC 'p' clk pin
        adc_clk_n = 1'b1;                // ADC 'n' clk pin
        reset_clk50 = 1'b1;              // synchronously negated  
        clk200 = 1'b0;                   // for input pin timing delay settings
        channel_tag[15:0] = 16'h0000;   // stuff about the channel to put in the header
       num_muon_bursts[22:0] = 23'h000000;  // number of sample bursts in a MUON fill
        num_laser_bursts[22:0] = 23'h000000; // number of sample bursts in a LASER fill
        num_ped_bursts[22:0] = 23'h000000;   // number of sample bursts in a PEDESTAL fill
        initial_fill_num[23:0] = 24'h000000;  // event number to assign to the first fill
        initial_fill_num_wr = 1'b0;      // write-strobe to store the initial_fill_num
		ddr3_wr_done = 1'b0;
		num_waveforms[11:0] = 12'h000;		// number of waveforms to store per trigger
        waveform_gap[21:0] = 22'h000000;		// idle time between waveforms 
        acq_enable0 = 1'b0;                  // arm the logic to accept triggers
        acq_enable1 = 1'b0;                  // arm the logic to accept triggers
        acq_trig = 1'b0;                 // trigger the logic to start collecting data
        acq_reset = 1'b1;                // reset all of the acquisition logic
		adc_buf_delay_data_reset = 1'b0;
		adc_buf_data_delay[4:0] = 5'h00;
		
		// Wait 100 ns for global reset to finish
		#100;
	    #20 reset_clk50 = 1'b0;
	        
	    #20 num_muon_bursts[22:0] = 23'h000005;  // number of sample bursts in a MUON fill
            num_laser_bursts[22:0] = 23'h000008; // number of sample bursts in a LASER fill
            num_ped_bursts[22:0] = 23'h00000b;   // number of sample bursts in a PEDESTAL fill
            initial_fill_num[23:0] = 24'h000055;  // event number to assign to the first fill
            channel_tag[15:0] = 16'h0008;   // stuff about the channel to put in the header
			num_waveforms[11:0] = 12'h003;		// number of waveforms to store per trigger
    	    waveform_gap[21:0] = 22'h000001;		// idle time between waveforms 
        #10 initial_fill_num_wr = 1'b1;      // write-strobe to store the initial_fill_num
        #10 initial_fill_num_wr = 1'b0;      // write-strobe to store the initial_fill_num

        #20 acq_reset = 1'b0;                // reset all of the acquisition logic
        #20 acq_enable0 = 1'b1;                  // arm the logic to accept triggers
			acq_enable1 = 1'b0;                  // arm the logic to accept triggers
        #20 acq_trig = 1'b1;                 // trigger the logic to start collecting data

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

`timescale 1ns / 10ps
// Acquisition controller for ADC data

module adc_acq_top_ASYNC(
    // inputs
    input [11:0] adc_in_p,          // [11:0] array of ADC 'p' data pins
    input [11:0] adc_in_n,          // [11:0] array of ADC 'n' data pins
    input adc_ovr_p,                // ADC 'p' over-range pin
    input adc_ovr_n,                // ADC 'n' over-range pin
    input adc_clk_p,                // ADC 'p' clk pin
    input adc_clk_n,                // ADC 'n' clk pin
    input reset_clk50,              // synchronously negated  
    input clk200,                   // for input pin timing delay settings
    input [15:0] channel_tag,       // stuff about the channel to put in the header
    input [23:0] initial_fill_num,  // event number to assign to the first fill
    input initial_fill_num_wr,      // write-strobe to store the initial_fill_num
    input ext_enable0,              // external 'enable' for triggers, and fill type
    input ext_enable1,              // external 'enable' for triggers, and fill type
    input ext_trig,                 // external trigger to start collecting data
    input adc_buf_delay_data_reset, // use the new delay settings
    input [4:0] adc_buf_data_delay, // 5 delay-tap-bits per line, all lines always all the same
    input ddr3_wr_done,             // asserted when the 'ddr3_wr_control' is in the DONE state
    input [10:0] async_num_bursts,  // number of 8-sample bursts in an ASYNC waveform
	input [11:0] async_pre_trig,    // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform

    // outputs
    output ddr3_wr_en,				// writing of triggered events to memory is enabled
    output [64:0] adc_buf_current_data_delay, // 13 lines *5 bits/line, current tap settings
    output [23:0] fill_num,         // fill number for this fill
    output [131:0] adc_acq_out_dat, // 132-bit 4-bit tag plus 128-bit header or ADC data
    output adc_acq_out_valid,       // current data should be stored in the FIFO
    output adc_clk,                 // ADC clock used by the FIFO
    output ext_done,                // external output indicating acquisition is done
    output adc_acq_sm_idle,          // ADC acquisition state machine is idle (used for front panel LED status)
    output [23:0] calc_total_burst_count
);

wire [25:0] packed_adc_dat;     // two samples, with over-range bits,  packed in one wide-word
                                // bit[0]       = first overrange
                                // bits[11:1]   = first ADC sample
                                // bit[12]      = second overrange
                                // bits[25:13]  = second ADC sample
wire [22:0] burst_start_adr;    // first DDR3 burst memory location for this fill (3 LSBs = 0)
wire [22:0] current_waveform_num;// the current waveform number, to be used in header

wire [25:0] circ_buf_wr_dat;	// data to write to the circular buffer
wire [15:0] circ_buf_wr_addr;	// address to write to the circular buffer
wire [25:0] circ_buf_rd_dat;	// data read from the circular buffer
wire [15:0] circ_buf_rd_addr;	// address to read from the circular buffer
wire [15:0] circ_buf_trig_addr;	// circular buffer address corresponding to a trigger, FIFO output

//////////////////////////////////////////////////////////////////////////////////////////////////
// Use channel_tag[3] to select either real ADC data or dummy data from a counter
reg use_dummy_data;
always @(posedge adc_clk) begin
    // channel_tag[3] = 0 -> use real data : =  1 -> use dummy data
    if (channel_tag[3])
    	use_dummy_data <= #1 1'b1;
    else
    	use_dummy_data <= #1 1'b0;
end
 
// Use channel_tag[4] to control whether the dummy_dat counter free-runs through a fill once started,
// or whether it gets reset for each waveform.
reg dummy_dat_reset_mode;
always @(posedge adc_clk) begin
    // channel_tag[4] = 0 -> free-run,  1 -> reset every waveform
    if (channel_tag[4]) 
    	dummy_dat_reset_mode <= #1 1'b1;
    else
    	dummy_dat_reset_mode <= #1 1'b0;
end

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a module that handles the ENABLE, TRIGGER, and RESET signals
wire [1:0] fill_type;		// level of the two 'ext_enable' bits
wire trig_enabled;
enable_sm_ASYNC enable_sm_ASYNC (
	// inputs
	.adc_clk(adc_clk),				// run the sm in this clock domain
    .ext_enable0(ext_enable0),      // external 'enable' for triggers, and fill type
	.ext_enable1(ext_enable1),      // external 'enable' for triggers, and fill type
	.ext_trig(ext_trig),            // external trigger to start collecting data
    .reset_clk50(reset_clk50),      // synchronously negated  
	.cbuf_rd_trig_wait(cbuf_rd_trig_wait),	// waiting for another trigger or the negation of 'cbuf_rd_en'	
    .ddr3_wr_done(ddr3_wr_done),    // asserted when the 'ddr3_wr_control' is in the DONE state
	// outputs
    .cbuf_wr_en(cbuf_wr_en),		// writing into the circ buf by the ADC is enabled, must extend past final trigger
	.cbuf_trig_en(cbuf_trig_en),	// triggering of new waveforms is enabled
	.cbuf_rd_en(cbuf_rd_en),		// moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
	.ddr3_wr_en(ddr3_wr_en),		// writing of triggered events to memory is enabled
	.fill_type(fill_type[1:0]),		// level of the two 'ext_enable' bits
	.trig_pulse(trig_pulse),		// a trigger passed while the system is enabled for new triggers
    .reset_clk_adc(reset_clk_adc),	// synched to adc_clk
    .adc_acq_sm_idle(adc_acq_sm_idle),	// ADC acquisition state machine is idle (used for front panel LED status)
    .ext_done(ext_done)             // assert external acquisition is done
);


///////////////////////////////////////////////////////////////////////////////////////////////////
// Connect a module that handles the incoming ADC data and prepares it for writing to
// the circular buffer
adc_to_circ_buf_ASYNC adc_to_circ_buf_ASYNC(
    // inputs passed from outside
    .adc_in_p(adc_in_p[11:0]),            		// [11:0] array of ADC 'p' data pins
    .adc_in_n(adc_in_n[11:0]),           		// [11:0] array of ADC 'n' data pins
    .adc_ovr_p(adc_ovr_p),                		// ADC 'p' over-range pin
    .adc_ovr_n(adc_ovr_n),                		// ADC 'n' over-range pin
    .adc_clk_p(adc_clk_p),                		// ADC 'p' clk pin
    .adc_clk_n(adc_clk_n),                		// ADC 'n' clk pin
    .reset_clk_adc(reset_clk_adc),				// synched to adc_clk
    .clk200(clk200),                      		// for input pin timing delay settings
    .adc_buf_delay_data_reset(adc_buf_delay_data_reset), // use the new delay settings
    .adc_buf_data_delay(adc_buf_data_delay[4:0]), // 5 delay-tap-bits per line, all lines always all the same
    // inputs created in this module
    .cbuf_wr_en(cbuf_wr_en),		// writing into the circ buf by the ADC is enabled, must extend past final trigger
	.dummy_dat_reset_mode(dummy_dat_reset_mode),// if true, reset the dummy data source for each trigger
	.use_dummy_data(use_dummy_data),			// if true, use counter instead of ADC
	.trig_pulse(trig_pulse),					// single-period pulse from 'acq_trig' input
    // outputs
    .adc_clk(adc_clk),                 			// 400 MHz ADC clock
    .adc_buf_current_data_delay(adc_buf_current_data_delay), // 13 lines *5 bits/line, current tap settings
	.circ_buf_wr_addr(circ_buf_wr_addr[15:0]),	// address to store data in circular buffer
	.circ_buf_wr_dat(circ_buf_wr_dat[25:0])		// data to store in the circular buffer 
);
                                 
/////////////////////////////////////////////////////////////////////////////////////////////////
// connect a dual-port circular buffer. It is 26-bits wide and 64k deep. Both sides are clocked
// by the 'adc_clk'.
circular_buffer circular_buffer (
  .clka(adc_clk),					// 400 MHz ADC DDR clock
  .wea(cbuf_wr_en),				// enable writing
  .addra(circ_buf_wr_addr[15:0]),	// write address
  // for debug, apply the address to the data port as well
  .dina(circ_buf_wr_dat[25:0]),		// 26-bit wide input data
  //.dina({9'b0,circ_buf_wr_addr[15:0],1'b0}),		// address used to create the 26-bit wide input data
  .clkb(adc_clk),					// 400 MHz ADC DDR clock
  .addrb(circ_buf_rd_addr[15:0]),	// read address
  .doutb(circ_buf_rd_dat[25:0])		// 26-bit wide output data
);

/////////////////////////////////////////////////////////////////////////////////////////////////
// Connect a FIFO that will hold the value of the 'write' address for each trigger point.
circ_buf_fifo circ_buf_fifo (
  .clk(adc_clk),					// 400 MHz ADC DDR clock
  .rst(reset_clk_adc), 				// reset from the Master FPGA
  .din(circ_buf_wr_addr[15:0]),		// current 'write' address
  .wr_en(trig_pulse),				// single-period pulse from 'acq_trig' input
  .rd_en(trig_addr_rd_en),			// read a trigger address from the FIFO
  .dout(circ_buf_trig_addr[15:0]),	// circular bufferr address corresponding to a trigger
  .full(),							// 'full' is not used
  .empty(trig_fifo_empty)			// no triggers available when asserted
);

/////////////////////////////////////////////////////////////////////////////////////////////////
// Connect a module that moves data from the circular buffer to the DDR3 'write' FIFO.
circ_buf_to_ddr3_ASYNC circ_buf_to_ddr3_ASYNC(
    // inputs
    .adc_clk(adc_clk),                 				// ADC clock used by the FIFO
    .reset_clk_adc(reset_clk_adc),								// either 'ext_reset' or 'reset_clk50' is asserted
    .channel_tag(channel_tag[15:0]),       			// stuff about the channel to put in the header
    .initial_fill_num(initial_fill_num[23:0]),  	// event number to assign to the first fill
    .initial_fill_num_wr(initial_fill_num_wr),      // write-strobe to store the initial_fill_num
	.cbuf_rd_en(cbuf_rd_en),		// moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
	.cbuf_trig_en(cbuf_trig_en),	// triggering of new waveforms is enabled
    .async_num_bursts(async_num_bursts[10:0]),		// number of 8-sample bursts in an ASYNC waveform
	.async_pre_trig(async_pre_trig[11:0]),			// number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
	.circ_buf_rd_dat(circ_buf_rd_dat[25:0]),		// 26-bit wide data from the circular buffer 
	.circ_buf_trig_addr(circ_buf_trig_addr[15:0]),	// circular buffer address corresponding to a trigger, FIFO output
	.trig_fifo_empty(trig_fifo_empty),				// no triggers available when asserted
	.fill_type(fill_type[1:0]),						// the levels on the 'acq_enable[1:0]' inputs
    // outputs
	.cbuf_rd_trig_wait(cbuf_rd_trig_wait),	// waiting for another trigger or the negation of 'cbuf_rd_en'	
	.trig_addr_rd_en(trig_addr_rd_en),				// read a trigger address from the FIFO
	.fill_num(fill_num[23:0]),         				// fill number for this fill
	.circ_buf_rd_addr(circ_buf_rd_addr[15:0]),		// read address for the circular buffer
    .adc_acq_out_dat(adc_acq_out_dat[131:0]), 		// 132-bit 4-bit tag plus 128-bit header or ADC data
    .adc_acq_out_valid(adc_acq_out_valid),       	// current data should be stored in the FIFO
    .calc_total_burst_count(calc_total_burst_count[23:0])
);

  

endmodule

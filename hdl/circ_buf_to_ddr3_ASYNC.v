`timescale 1ns / 10ps
// Move data from the circular buffer to the DDR3 input FIFO

module circ_buf_to_ddr3_ASYNC(
    // inputs
    input adc_clk,                 	// ADC clock used by the FIFO
    input reset_clk_adc,			// either 'ext_reset' or 'reset_clk50' is asserted
	input cbuf_rd_en,				// moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
	input cbuf_trig_en,				// triggering of new waveforms is enabled
    input [11:0] channel_tag,       // stuff about the channel to put in the header
    input [23:0] initial_fill_num,  // event number to assign to the first fill
    input initial_fill_num_wr,      // write-strobe to store the initial_fill_num
    input [10:0] async_num_bursts,  // number of 8-sample bursts in an ASYNC waveform
	input [11:0] async_pre_trig,    // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
	input [25:0] circ_buf_rd_dat,	// 26-bit wide data from the circular buffer 
	input [15:0] circ_buf_trig_addr, // circular buffer address corresponding to a trigger, FIFO output
	input trig_fifo_empty,			// no triggers available when asserted
	input [1:0] fill_type,			// the levels on the 'acq_enable[1:0]' inputs
    input [3:0] xadc_alarms,

    // outputs
	output cbuf_rd_trig_wait,	// waiting for another trigger or the negation of 'cbuf_rd_en'	
	output trig_addr_rd_en,			// read a trigger address from the FIFO
	output [23:0] fill_num,         // fill number for this fill
	output reg [15:0] circ_buf_rd_addr,	// read address for the circular buffer
    output [131:0] adc_acq_out_dat, // 132-bit 4-bit tag plus 128-bit header or ADC data
    output adc_acq_out_valid,       	// current data should be stored in the FIFO
    output [23:0] calc_total_burst_count
);

wire [22:0] current_waveform_num;	// the current waveform number, to be used in header
wire [22:0] burst_adr;				// DDR3 burst memory location (3 LSBs=0) for a waveform
reg [22:0] waveform_start_adr;		// DDR3 burst memory location (3 LSBs=0) for a waveform
reg [22:0] num_fill_bursts;			// total number of bursts in a fill

assign calc_total_burst_count[23:0] = (async_num_bursts[10:0]+1)*current_waveform_num[22:0]+2;

wire initial_fill_num_wr_sync;
sync_2stage initial_fill_num_wr_sync_inst (
    .clk(adc_clk),
    .in(initial_fill_num_wr),
    .out(initial_fill_num_wr_sync)
);

/////////////////////////////////////////////////////////////////////////////////////////////////                            
// Subtract the pre-trigger count from the trigger address coming out of the FIFO. The FIFO is in
// FWFT mode, but beware of latency from when 'trig_addr_rd_en' is asserted until the subtracted value is valid.
reg [15:0] circ_buf_start_addr;
always @(posedge adc_clk) begin
	circ_buf_start_addr[15:0] <= #1 circ_buf_trig_addr[15:0] - {{4{1'b0}}, async_pre_trig[11:0]};
end 		 
  
/////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter to generate the circular buffer 'read' address
always @(posedge adc_clk) begin
	if (init_circ_buf_rd_addr)
		// initialize the counter with the start of the buffer area to be saved
		circ_buf_rd_addr[15:0] <= #1 circ_buf_start_addr[15:0];
	else if (inc_circ_buf_rd_addr)
		// increment the address
		circ_buf_rd_addr[15:0] <= #1 circ_buf_rd_addr[15:0] + 1;
	else
		// leave the address unchanged
		circ_buf_rd_addr[15:0] <= #1 circ_buf_rd_addr[15:0];
end

/////////////////////////////////////////////////////////////////////////////////////////////////
// connect 4 registers that will hold 4 consecutive values from the circular buffer. They will be filled
// like a wide shift register.
reg [25:0] circ_buf_dat_reg3_, circ_buf_dat_reg2_, circ_buf_dat_reg1_, circ_buf_dat_reg0_;
always @(posedge adc_clk) begin
	if (latch_circ_buf_dat) begin
		circ_buf_dat_reg3_[25:0] <= #1 circ_buf_rd_dat[25:0];
		circ_buf_dat_reg2_[25:0] <= #1 circ_buf_dat_reg3_[25:0];
		circ_buf_dat_reg1_[25:0] <= #1 circ_buf_dat_reg2_[25:0];
		circ_buf_dat_reg0_[25:0] <= #1 circ_buf_dat_reg1_[25:0];
	end
end

/////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will supply either a fill header, a waveform header, ADC data, or a checksum
// to the DDR3 write FIFO. All bit ordering is done in this mux
adc_dat_mux_ASYNC adc_dat_mux_ASYNC (
    // inputs
    .dat3_(circ_buf_dat_reg3_[25:0]),            // a pair of ADC samples and a pair of over-range bits
    .dat2_(circ_buf_dat_reg2_[25:0]),            // a pair of ADC samples and a pair of over-range bits
    .dat1_(circ_buf_dat_reg1_[25:0]),            // a pair of ADC samples and a pair of over-range bits
    .dat0_(circ_buf_dat_reg0_[25:0]),            // a pair of ADC samples and a pair of over-range bits
    .channel_tag(channel_tag[11:0]),            // stuff about the channel to put in the header
    .fill_type(fill_type[1:0]),                 // determine which burst count to use
    .num_fill_bursts(num_fill_bursts[22:0]),    // number of bursts of any type (header, data, checksum)
    .waveform_start_adr(waveform_start_adr[22:0]), // DDR3 burst memory location (3 LSBs=0) for a waveform
	.current_waveform_num(current_waveform_num[22:0]),// the current waveform number, to be used in header
	.fill_num(fill_num[23:0]),                  // fill number for this fill
    .async_num_bursts(async_num_bursts[10:0]),  // number of 8-sample bursts in an ASYNC waveform
	.async_pre_trig(async_pre_trig[11:0]),    // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    .xadc_alarms(xadc_alarms[3:0]),
    .clk(adc_clk),
    .select_dat(adc_mux_dat_sel),               // selects data
    .select_fill_hdr(adc_mux_fill_hdr_sel),     // selects fill header
    .select_waveform_hdr(adc_mux_wfm_hdr_sel),  // selects waveform header
    .select_checksum(adc_mux_checksum_select),  // selects checksum, send the checksum to the FIFO 
	.checksum_init(checksum_init),				// initialize the checksum
    .checksum_update(adc_mux_checksum_update),  // update the checksum 
    // outputs
    .adc_acq_out_dat(adc_acq_out_dat[131:0])    // 132-bit: 4-bit tag plus 128-bit header or ADC data   
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter that will keep track of the DDR3 burst address 
// It will be preset to '0x0001' when 'mem_enabled' is negated.
// Its content will be put in the waveform headers.
// It will increment every time data is written to the FIFO
burst_address_cntr_ASYNC burst_address_cntr_ASYNC (
    // inputs
    .clk(adc_clk),
    .init(burst_adr_cntr_init),			// initialize to '1' at the start of a fill
    .enable(burst_adr_cntr_en),			// increment
    // outputs
    .burst_adr(burst_adr[22:0])					// current DDR3 burst memory location
);
// latch the start address for a waveform
always @(posedge adc_clk) begin
	if (save_start_adr)
		waveform_start_adr[22:0] <= #1 burst_adr[22:0];
end
// add '1' to the final address to get the total count
always @(posedge adc_clk) begin
	if (save_last_adr)
		num_fill_bursts[22:0] <= #1 burst_adr[22:0] + 1;
end

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a down-counter that will keep track of how many bursts have been saved
// It will be initialized when saving from a trigger starts.
// It will be enabled when each data burst is sent out.
burst_cntr_ASYNC burst_cntr_ASYNC (
    // inputs
    .async_num_bursts(async_num_bursts[10:0]),	// number of 8 sample bursts
    .clk(adc_clk),
    .init(burst_cntr_init),                     // initialize when triggered
    .enable(burst_cntr_en),                     // will be enabled once per burst
    // outputs
    .at_zero(burst_cntr_zero)                   // all sample bursts have been saved
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect an up-counter that will keep track of the waveform (trigger) number
// It will be cleared to zero when 'mem_enabled' is negated.
// It will be enabled at the start of moving each waveform to DDR3 memory.
waveform_cntr_ASYNC waveform_cntr_ASYNC (
    // inputs
    .clk(adc_clk),
    .init(waveform_cntr_init),              // initialize when triggered
    .enable(waveform_cntr_en),             	// will be enabled once for each waveform
    // outputs
    .current_waveform_num(current_waveform_num[22:0])// to be used in header
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect an up-counter that will keep track of the fill number
// It will be initialized at the start of a run, or when necessary.
// It will be enabled when each fill is done
adc_fill_cntr adc_fill_cntr (
    // inputs
    .initial_fill_num(initial_fill_num[23:0]),  // always positive
    .clk(adc_clk),
    .init(initial_fill_num_wr_sync),            // initialize when programmed
    .enable(fill_cntr_en),                      // will be enabled once per fill
    // outputs
   .fill_num(fill_num[23:0])                    // fill number for this fill
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a state machine to coordinate everything
circ_buf_to_ddr3_sm_ASYNC circ_buf_to_ddr3_sm_ASYNC (
    // inputs
    .adc_clk(adc_clk),
	.cbuf_rd_en(cbuf_rd_en),		// moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
	.cbuf_trig_en(cbuf_trig_en),	// triggering of new waveforms is enabled
    .trig_fifo_empty(trig_fifo_empty),      	// if not empty then process a waveform
    .reset_clk_adc(reset_clk_adc),		// either 'ext_reset' or 'reset_clk50' is asserted
    .burst_cntr_zero(burst_cntr_zero),      	// all sample bursts have been saved
    // outputs
	.cbuf_rd_trig_wait(cbuf_rd_trig_wait),	// waiting for another trigger or the negation of 'cbuf_rd_en'	
	.burst_adr_cntr_init(burst_adr_cntr_init),	// initialize counter to '1'
	.checksum_init(checksum_init),				// initialize the checksum
	.trig_addr_rd_en(trig_addr_rd_en),			// read a trigger address from the FIFO
	.save_start_adr(save_start_adr),			// latch the first DDR3 address for a waveform
	.save_last_adr(save_last_adr),			// latch the last DDR3 address for a fill, it it the total count
    .adc_acq_out_valid(adc_acq_out_valid),  // current data should be stored in the FIFO
	.init_circ_buf_rd_addr(init_circ_buf_rd_addr), // initialize the counter with the start of the buffer area to be saved
    .inc_circ_buf_rd_addr(inc_circ_buf_rd_addr), 	// increment the address
	.latch_circ_buf_dat(latch_circ_buf_dat),	// save the current 32-bit data word from the circular buffer
    .select_dat(adc_mux_dat_sel),               // selects data
	.select_fill_hdr(adc_mux_fill_hdr_sel),     // selects fill header
	.select_waveform_hdr(adc_mux_wfm_hdr_sel),  // selects waveform header
	.select_checksum(adc_mux_checksum_select),  // selects checksum, send the checksum to the FIFO 
	.checksum_update(adc_mux_checksum_update),  // update the checksum 
    .burst_adr_cntr_en(burst_adr_cntr_en),      // increment the next starting address
    .burst_cntr_init(burst_cntr_init),      // initialize when triggered
    .burst_cntr_en(burst_cntr_en),          // will be enabled once per burst
    .fill_cntr_en(fill_cntr_en),            // will be enabled once per fill
    .waveform_cntr_init(waveform_cntr_init),                  // initialize when triggered
    .waveform_cntr_en(waveform_cntr_en)                  // will be enabled once after each waveform
);      

endmodule

`timescale 1ns / 10ps
// Move data from the circular buffer to the DDR3 input FIFO

module circ_buf_to_ddr3_CBUF (
    // inputs
    input adc_clk,                  // ADC clock used by the FIFO
    input reset_clk_adc,            // either 'ext_reset' or 'reset_clk50' is asserted
//    input cbuf_rd_en,               // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
//    input cbuf_trig_en,             // triggering of new waveforms is enabled
    input [11:0] channel_tag,       // stuff about the channel to put in the header
    input [23:0] initial_fill_num,  // event number to assign to the first fill
    input initial_fill_num_wr,      // write-strobe to store the initial_fill_num
    input [13:0] async_num_bursts,  // number of 8-sample bursts in an ASYNC waveform
    input [15:0] async_pre_trig,    // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    input [25:0] circ_buf_rd_dat,    // 26-bit wide data from the circular buffer
    input [15:0] circ_buf_trig_addr, // circular buffer address corresponding to a trigger, FIFO output
    input trig_fifo_empty,            // no triggers available when asserted
    input [1:0] fill_type,            // the levels on the 'acq_enable[1:0]' inputs
    input [3:0] xadc_alarms,

    // outputs
    output cbuf_to_ddr3_done,    // waiting for another trigger or the negation of 'cbuf_rd_en'
    output trig_addr_rd_en,            // read a trigger address from the FIFO
    output [23:0] fill_num,         // fill number for this fill
    output reg [15:0] circ_buf_rd_addr,    // read address for the circular buffer
    output [131:0] adc_acq_out_dat, // 132-bit 4-bit tag plus 128-bit header or ADC data
    output adc_acq_out_valid,           // current data should be stored in the FIFO
    output [22:0] current_waveform_num
);

wire [22:0] burst_adr;            // DDR3 burst memory location (3 LSBs=0) for a waveform
reg  [22:0] waveform_start_adr; // DDR3 burst memory location (3 LSBs=0) for a waveform
reg  [22:0] num_fill_bursts;    // total number of bursts in a fill

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
    circ_buf_start_addr[15:0] <= #1 circ_buf_trig_addr[15:0] - async_pre_trig[15:0];
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

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter that will calculate the DDR3 starting address of the next fill
// It will be initialized when the fill number is written.
// It will increment every time data is written to the FIFO
adc_address_cntr adc_address_cntr (
    // inputs
    .clk(adc_clk),
    .init(initial_fill_num_wr_sync), // initialize to '1' at the start of a fill
    .enable(burst_adr_cntr_en), // increment
    // outputs
    .burst_start_adr(burst_adr[22:0]) // current DDR3 burst memory location
);
// lkg -- do I need these two latches still?
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
    .async_num_bursts(async_num_bursts[13:0]), // number of 8 sample bursts
    .clk(adc_clk),
    .init(burst_cntr_init),                    // initialize when triggered
    .enable(burst_cntr_en),                    // will be enabled once per burst
    // outputs
    .at_zero(burst_cntr_zero)                  // all sample bursts have been saved
);

// lkg -- I should also review if I need to modify this modules behaviour
//////////////////////////////////////////////////////////////////////////////////////////////////
// connect an up-counter that will keep track of the waveform (trigger) number
// It will be cleared to zero when 'mem_enabled' is negated.
// It will be enabled at the start of moving each waveform to DDR3 memory.
waveform_cntr_ASYNC waveform_cntr_ASYNC (
    // inputs
    .clk(adc_clk),
    .init(waveform_cntr_init),                        // initialize when triggered
    .enable(waveform_cntr_en),                           // will be enabled once for each waveform
    // outputs
    .current_waveform_num(current_waveform_num[22:0]) // to be used in header
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect an up-counter that will keep track of the fill number
// It will be initialized at the start of a run, or when necessary.
// It will be enabled when each fill is done
adc_fill_cntr adc_fill_cntr (
    // inputs
    .initial_fill_num(initial_fill_num[23:0]), // always positive
    .clk(adc_clk),
    .init(initial_fill_num_wr_sync),           // initialize when programmed
    .enable(fill_cntr_en),                     // will be enabled once per fill
    // outputs
   .fill_num(fill_num[23:0])                   // fill number for this fill
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a state machine to coordinate everything
circ_buf_to_ddr3_sm_CBUF circ_buf_to_ddr3_sm_CBUF (
    // inputs
    .adc_clk(adc_clk),
    .reset_clk_adc(reset_clk_adc),        // either 'ext_reset' or 'reset_clk50' is asserted
//    .cbuf_rd_en(cbuf_rd_en),        // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
//    .cbuf_trig_en(cbuf_trig_en),    // triggering of new waveforms is enabled
    .trig_fifo_empty(trig_fifo_empty),          // if not empty then process a waveform
    .burst_cntr_zero(burst_cntr_zero),          // all sample bursts have been saved
    // outputs
    .cbuf_to_ddr3_done(cbuf_to_ddr3_done),    // waiting for another trigger or the negation of 'cbuf_rd_en'
    .burst_adr_cntr_init(burst_adr_cntr_init),    // initialize counter to '1'
    .init_circ_buf_rd_addr(init_circ_buf_rd_addr), // initialize the counter with the start of the buffer area to be saved
    .inc_circ_buf_rd_addr(inc_circ_buf_rd_addr),   // increment the address
    .latch_circ_buf_dat(latch_circ_buf_dat),    // save the current 32-bit data word from the circular buffer
    .select_fill_hdr(adc_mux_fill_hdr_sel),     // selects fill header
    .select_dat(adc_mux_dat_sel),               // selects data
    .select_waveform_hdr(adc_mux_wfm_hdr_sel),  // selects waveform header
    .select_checksum(adc_mux_checksum_select),  // selects checksum, send the checksum to the FIFO
    .checksum_update(adc_mux_checksum_update),  // update the checksum
    .checksum_init(checksum_init),                // initialize the checksum
    .adc_acq_out_valid(adc_acq_out_valid),  // current data should be stored in the FIFO
    .burst_adr_cntr_en(burst_adr_cntr_en),      // increment the next starting address
    .save_start_adr(save_start_adr),            // latch the first DDR3 address for a waveform
    .save_last_adr(save_last_adr),            // latch the last DDR3 address for a fill, it it the total count
    .trig_addr_rd_en(trig_addr_rd_en),            // read a trigger address from the FIFO
    .burst_cntr_init(burst_cntr_init),      // initialize when triggered
    .burst_cntr_en(burst_cntr_en),          // will be enabled once per burst
    .waveform_cntr_init(waveform_cntr_init),                  // initialize when triggered
    .waveform_cntr_en(waveform_cntr_en)                  // will be enabled once after each waveform
    .fill_cntr_en(fill_cntr_en),            // will be enabled once per fill
);

endmodule

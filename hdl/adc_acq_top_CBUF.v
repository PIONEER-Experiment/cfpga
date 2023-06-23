`timescale 1ns / 1ps
// Acquisition controller for ADC data

module adc_acq_top_cbuf(
    // inputs
    input [11:0] adc_in_p,  // [11:0] array of ADC 'p' data pins
    input [11:0] adc_in_n,  // [11:0] array of ADC 'n' data pins
    input adc_ovr_p,// ADC 'p' over-range pin
    input adc_ovr_n,// ADC 'n' over-range pin
    input adc_clk_p,// ADC 'p' clk pin
    input adc_clk_n,// ADC 'n' clk pin
    input reset_clk50,  // synchronously negated
    input clk200,   // for input pin timing delay settings
    input [11:0] channel_tag,   // stuff about the channel to put in the header
    input [23:0] initial_fill_num,  // event number to assign to the first fill
    input initial_fill_num_wr,  // write-strobe to store the initial_fill_num
    input acq_enable0,  // indicates enabled for triggers, and fill type
    input acq_enable1,  // indicates enabled for triggers, and fill type
    input acq_trig, // trigger the logic to start collecting data
    input adc_buf_delay_data_reset, // use the new delay settings
    input [4:0] adc_buf_data_delay, // 5 delay-tap-bits per line, all lines always all the same
    input ddr3_wr_done, // asserted when the 'ddr3_wr_control' is in the DONE state
    input [13:0] async_num_bursts,  // number of 8-sample bursts in an ASYNC waveform
    input [15:0] async_pre_trig,	   // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    input [3:0] xadc_alarms,
    // outputs
    output acq_enabled, // the system is in acquisition mode, rather than readout mode
    output [64:0] adc_buf_current_data_delay, // 13 lines *5 bits/line, current tap settings
    output [23:0] fill_num, // fill number for this fill
    output [131:0] adc_acq_out_dat, // 132-bit 4-bit tag plus 128-bit header or ADC data
    output adc_acq_out_valid,   // current data should be stored in the FIFO
    output adc_clk, // ADC clock used by the FIFO
    output adc_acq_full_reset,  // reset all aspects of data collection/storage/readout
    output acq_done,// acquisition is done
    output [25:0] packed_adc_dat,   // two samples, with over-range bits, packed in one wide-word
    //   bit[0]  = first overrange
    //   bits[11:1]  = first ADC sample
    //   bit[12] = second overrange
    //   bits[25:13] = second ADC sample
    output adc_acq_sm_idle  // ADC acquisition state machine is idle (used for front panel LED status)
);

wire [22:0] burst_start_adr;// first DDR3 burst memory location for this fill (3 LSBs = 0)
wire [25:0] circ_buf_wr_dat;   // data to write to the circular buffer
wire [15:0] circ_buf_wr_addr;   // address to write to the circular buffer
wire [25:0] circ_buf_rd_dat;   // data read from the circular buffer
wire [15:0] circ_buf_rd_addr;   // address to read from the circular buffer
wire [15:0] circ_buf_trig_addr;   // circular buffer address corresponding to a trigger, FIFO output
wire [11:0] current_waveform_num;// the current waveform number, to be used in header

///////////////////////////////////////////////////////////////////////////////////////////////////
// Tell the DDR3 block when either 'acq_enable0' or 'acq_enable1' is not zero.
// This will switch the mode to 'write'

///////////////////////////////////////////////////////////////////////////////////////////////////
// Writing to the circular buffer is enabled as long as acquisition is enabled
assign cbuf_enabled = acq_enable0 | acq_enable1;

///////////////////////////////////////////////////////////////////////////////////////////////////
// synchronize 'cbuf_enabled' to the adc_clock.  Writing to the circular buffer valid as long as
// acq_enabled is high.
reg cbuf_sync1, cbuf_sync2, cbuf_wr_en;
always @ (posedge adc_clk) begin
    cbuf_sync2       <= #1 acq_sync1;
    cbuf_wr_en <= #1 acq_sync2;
end


///////////////////////////////////////////////////////////////////////////////////////////////////
// synchronize 'acq_trig' and create a pulse when it is asserted
// copied from enable_sm_ASYNC -- not clear why 5 stages needed...
reg trig_pulse, trig_sync1, trig_sync2, trig_sync3, trig_sync4, trig_sync5;
always @ (posedge adc_clk) begin
    trig_sync1 <= #1 acq_trig;
    trig_sync2 <= #1 trig_sync1;
    trig_sync3 <= #1 trig_sync2;
    trig_sync4 <= #1 trig_sync3;
    trig_sync5 <= #1 trig_sync4;
    // assert 'trig_pulse' when 'ext_trig' has gotten to the fourth register, but not the fifth
    // pass triggers only during the ACQ_ENABLED state (cbuf_wr_en is synched to that state in the adc_clk domain)
    trig_pulse <= #1 ((trig_sync4 & ~trig_sync5) && cbuf_wr_en);
end

// synchronize the 'reset_clk50' signal to the 'adc_clk'
reg reset_sync1, reset_sync2;
wire reset_clk_adc;
always @ (posedge adc_clk) begin
    reset_sync1 <= #1 reset_clk50;
    reset_sync2 <= #1 reset_sync1;
end
assign reset_clk_adc = reset_sync2;

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
 
//////////////////////////////////////////////////////////////////////////////////////////////////
// Use channel_tag[4] to control whether the dummy_dat counter free-runs through a fill once started,
// or whether it gets reset for each waveform.
reg dummy_dat_reset_mode;
always @(posedge adc_clk) begin
// channel_tag[4] = 0 -> free-run,  1 -> reset every waveform
if (channel_tag[4])
    dummy_dat_reset_mode <= 1'b1;
else
    dummy_dat_reset_mode <= 1'b0;
end


///////////////////////////////////////////////////////////////////////////////////////////////////
// Connect a module that handles the incoming ADC data and prepares it for writing to
// the circular buffer.  The original ASYNC code works fine here.
adc_to_circ_buf_ASYNC adc_to_circ_buf_ASYNC (
// inputs passed from outside
    .adc_in_p(adc_in_p[11:0]),  // [11:0] array of ADC 'p' data pins
    .adc_in_n(adc_in_n[11:0]), // [11:0] array of ADC 'n' data pins
    .adc_ovr_p(adc_ovr_p),  // ADC 'p' over-range pin
    .adc_ovr_n(adc_ovr_n),  // ADC 'n' over-range pin
    .adc_clk_p(adc_clk_p),  // ADC 'p' clk pin
    .adc_clk_n(adc_clk_n),  // ADC 'n' clk pin
    .reset_clk_adc(reset_clk_adc),// synched to adc_clk
    .clk200(clk200),// for input pin timing delay settings
    .adc_buf_delay_data_reset(adc_buf_delay_data_reset), // use the new delay settings
    .adc_buf_data_delay(adc_buf_data_delay[4:0]), // 5 delay-tap-bits per line, all lines always all the same
     // inputs created in this module
    .cbuf_wr_en(cbuf_wr_en),  // writing into the circ buf by the ADC is enabled
    .dummy_dat_reset_mode(dummy_dat_reset_mode),// if true, reset the dummy data source for each trigger
    .use_dummy_data(use_dummy_data), // if true, use counter instead of ADC
    .trig_pulse(trig_pulse),   // single-period pulse from 'acq_trig' input
    // outputs
    .adc_clk(adc_clk),  // 400 MHz ADC clock
    .packed_adc_dat(packed_adc_dat[25:0]),
    .adc_buf_current_data_delay(adc_buf_current_data_delay), // 13 lines *5 bits/line, current tap settings
    .circ_buf_wr_addr(circ_buf_wr_addr[15:0]),   // address to store data in circular buffer
    .circ_buf_wr_dat(circ_buf_wr_dat[25:0])  // data to store in the circular buffer
);


/////////////////////////////////////////////////////////////////////////////////////////////////
// connect a dual-port circular buffer. It is 26-bits wide and 64k deep. Both sides are clocked
// by the 'adc_clk'.
circular_buffer circular_buffer (
    .clka(adc_clk),               // 400 MHz ADC DDR clock
    .wea(cbuf_wr_en),            // enable writing
    .addra(circ_buf_wr_addr[15:0]),   // write address
    // for debug, apply the address to the data port as well
    .dina(circ_buf_wr_dat[25:0]),      // 26-bit wide input data
    //.dina({9'b0,circ_buf_wr_addr[15:0],1'b0}),      // address used to create the 26-bit wide input data
    .clkb(adc_clk),               // 400 MHz ADC DDR clock
    .addrb(circ_buf_rd_addr[15:0]),   // read address
    .doutb(circ_buf_rd_dat[25:0])      // 26-bit wide output data
);


/////////////////////////////////////////////////////////////////////////////////////////////////
// Connect a FIFO that will hold the value of the 'write' address for each trigger point.
circ_buf_fifo circ_buf_fifo (
    .clk(adc_clk),               // 400 MHz ADC DDR clock
    .rst(reset_clk_adc),             // reset from the Master FPGA
    .din(circ_buf_wr_addr[15:0]),      // current 'write' address
    .wr_en(trig_pulse),             // single-period pulse from 'acq_trig' input
    .rd_en(trig_addr_rd_en),         // read a trigger address from the FIFO
    .dout(circ_buf_trig_addr[15:0]),   // circular bufferr address corresponding to a trigger
    .full(),                     // 'full' is not used
    .empty(trig_fifo_empty)         // no triggers available when asserted
);

wire initial_fill_num_wr_sync;
sync_2stage initial_fill_num_wr_sync_inst (
    .clk(adc_clk),
    .in(initial_fill_num_wr),
    .out(initial_fill_num_wr_sync)
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter that will calculate the DDR3 starting address of the next fill
// It will be initialized when the fill number is written.
// It will increment every time data is written to the FIFO
adc_address_cntr adc_address_cntr (
    // inputs
    .clk(adc_clk),
    .init(initial_fill_num_wr_sync),             // initialize to zero when the fill number is written
    .enable(address_cntr_en),                    // increment
    // outputs
    .burst_start_adr(burst_start_adr[22:0])      // first DDR3 burst memory location for this fill
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


/////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will supply either a fill header, a waveform header, ADC data, or a checksum
// to the DDR3 write FIFO. All bit ordering is done in this mux
adc_dat_mux_CBUF adc_dat_mux_CBUF (
    // inputs
    .dat3_(circ_buf_dat_reg3_[25:0]),            // a pair of ADC samples and a pair of over-range bits
    .dat2_(circ_buf_dat_reg2_[25:0]),            // a pair of ADC samples and a pair of over-range bits
    .dat1_(circ_buf_dat_reg1_[25:0]),            // a pair of ADC samples and a pair of over-range bits
    .dat0_(circ_buf_dat_reg0_[25:0]),            // a pair of ADC samples and a pair of over-range bits
    .channel_tag(channel_tag[11:0]),            // stuff about the channel to put in the header
    .fill_type(fill_type[1:0]),                 // determine which burst count to use
    .waveform_start_adr(waveform_start_adr[22:0]), // DDR3 burst memory location (3 LSBs=0) for a waveform
    .fill_num(fill_num[23:0]),                  // fill number for this fill
    .xadc_alarms(xadc_alarms[3:0]),
    .clk(adc_clk),
    .async_num_bursts(async_num_bursts[13:0]),  // number of 8-sample bursts in an ASYNC waveform
    .async_pre_trig(async_pre_trig[15:0]),    // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    .select_fill_hdr(adc_mux_fill_hdr_sel),     // selects fill header
    .select_waveform_hdr(adc_mux_wfm_hdr_sel),  // selects waveform header
    .select_dat(adc_mux_dat_sel),               // selects data
    .select_checksum(adc_mux_checksum_select),  // selects checksum, send the checksum to the FIFO
    .checksum_update(adc_mux_checksum_update),  // update the checksum
    // outputs
    .adc_acq_out_dat(adc_acq_out_dat[131:0])    // 132-bit: 4-bit tag plus 128-bit header or ADC data
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter that will calculate the DDR3 starting address of the next fill
// It will be initialized when the fill number is written.
// It will increment every time data is written to the FIFO
adc_address_cntr adc_address_cntr (
    // inputs
    .clk(adc_clk),
    .init(initial_fill_num_wr_sync), // initialize to zero when the fill number is written
    .enable(address_cntr_en),// increment
    // outputs
    .burst_start_adr(burst_start_adr[22:0])  // first DDR3 burst memory location for this fill
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a down-counter that will keep track of how many bursts have been saved
// It will be initialized when a trigger occurs.
// It will be enabled when each burst is sent out.
burst_cntr_ASYNC burst_cntr_ASYNC (
    // inputs
    .async_num_bursts(async_num_bursts[13:0]), // number of 8 sample bursts
    .clk(adc_clk),
    .init(burst_cntr_init),                    // initialize when triggered
    .enable(burst_cntr_en),                    // will be enabled once per burst
    // outputs
    .at_zero(burst_cntr_zero)                  // all sample bursts have been saved
);


//////////////////////////////////////////////////////////////////////////////////////////////////
// connect an up-counter that will keep track of the fill number
// It will be initialized at the start of a run, or when necessary.
// It will be enabled when each fill is done
adc_fill_cntr adc_fill_cntr (
    // inputs
    .initial_fill_num(initial_fill_num[23:0]),  // always positive
    .clk(adc_clk),
    .init(initial_fill_num_wr_sync),// initialize when programmed
    .enable(fill_cntr_en),  // will be enabled once per fill
    // outputs
    .fill_num(fill_num[23:0])   // fill number for this fill
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a state machine to coordinate everything
adc_acq_sm_cbuf adc_acq_sm_cbuf (
    // inputs
    .clk(adc_clk),
    .acq_enable0(acq_enable0),  // enable the logic to accept triggers
    .acq_enable1(acq_enable1),  // enable the logic to accept triggers
    .acq_trig(acq_trig),// trigger the logic to start collecting data
    .reset_clk50(reset_clk50),  // synchronously negated
    .burst_cntr_zero(burst_cntr_zero),  // all sample bursts have been saved
    .ddr3_wr_done(ddr3_wr_done),// asserted when the 'ddr3_wr_control' is in the DONE state
    .dummy_dat_reset_mode(dummy_dat_reset_mode),// channel_tag[4] = 0 -> free-run,  1 -> reset every waveform
    // outputs
    .fill_type(fill_type[1:0]), // determine which burst count to use
    .address_cntr_en(address_cntr_en),  // increment the next starting address
    .dummy_dat_reset(dummy_dat_reset),  // reset the dummy data counter
    .adc_mux_fill_hdr_sel(adc_mux_fill_hdr_sel),// selects fill header
    .adc_mux_wfm_hdr_sel(adc_mux_wfm_hdr_sel), // selects waveform header
    .adc_mux_dat_sel(adc_mux_dat_sel),  // selects data
    .adc_mux_checksum_select(adc_mux_checksum_select),  // send the checksum to the FIFO
    .adc_mux_checksum_update(adc_mux_checksum_update),  // update the checksum
    .burst_cntr_init(burst_cntr_init),  // initialize when triggered
    .burst_cntr_en(burst_cntr_en),  // will be enabled once per burst
    .fill_cntr_en(fill_cntr_en),// will be enabled once per fill
    .adc_acq_out_valid(adc_acq_out_valid),  // current data should be stored in the FIFO
    .acq_enabled(acq_enabled),  // writing triggered data to DDR3 in progress
    .adc_acq_full_reset(adc_acq_full_reset),// synchronously negated
    .acq_done(acq_done),// acquisition is done
    .sm_idle(adc_acq_sm_idle)   // state machine is idle
);

endmodule

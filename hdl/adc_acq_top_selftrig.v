`timescale 1ns / 10ps
// Acquisition controller for ADC data

module adc_acq_top_selftrig (
    // inputs
    input [11:0] adc_in_p,          // [11:0] array of ADC 'p' data pins
    input [11:0] adc_in_n,          // [11:0] array of ADC 'n' data pins
    input adc_ovr_p,                // ADC 'p' over-range pin
    input adc_ovr_n,                // ADC 'n' over-range pin
    input adc_clk,                  // ADC clock used by the FIFO
    input reset_clk50,              // synchronously negated
    input adc_acq_full_reset,       // reset all aspects of data collection/storage/readout
    input clk200,                   // for input pin timing delay settings
    input [11:0] channel_tag,       // stuff about the channel to put in the header
    input [23:0] initial_fill_num,  // event number to assign to the first fill
    input initial_fill_num_wr,      // write-strobe to store the initial_fill_num
    (* mark_debug = "true" *) input enable_triggering,        // master FPGA has enabled triggering
    (* mark_debug = "true" *) input ddr3_buffer,              // ddr3 buffer (lower half or upper half of memory) to write events to
    input adc_buf_delay_data_reset, // use the new delay settings
    input [4:0] adc_buf_data_delay, // 5 delay-tap-bits per line, all lines always all the same
    input ddr3_wr_done,             // asserted when the 'ddr3_wr_control' is in the DONE state
    input [13:0] async_num_bursts,  // number of 8-sample bursts in an ASYNC waveform
    input [15:0] async_pre_trig,    // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    input [11:0] selftrig_threshold,// the amount by which the sample average must exceed the average pedestal to trigger
    input [3:0] xadc_alarms,

    // outputs
    (* mark_debug = "true" *) output self_trig,                          // self-triggering conditions have been met
    (* mark_debug = "true" *) output ddr3_wr_en,                         // writing of triggered events to memory is enabled
    output [ 64:0] adc_buf_current_data_delay, // 13 lines *5 bits/line, current tap settings
    output [ 23:0] fill_num,                   // fill number for this fill
    output [131:0] adc_acq_out_dat,            // 132-bit 4-bit tag plus 128-bit header or ADC data
    (* mark_debug = "true" *) output adc_acq_out_valid,                  // current data should be stored in the FIFO
    (* mark_debug = "true" *) output ext_done,                           // external output indicating acquisition is done
    output adc_acq_sm_idle,                    // ADC acquisition state machine is idle (used for front panel LED status)
    output [ 22:0] current_waveform_num,       // the current waveform number, to be used in header
    output [ 25:0] packed_adc_dat              // two samples, with over-range bits, packed in one wide-word
                                               // bit[0]      = first overrange
                                               // bits[11:1]  = first ADC sample
                                               // bit[12]     = second overrange
                                               // bits[25:13] = second ADC sample
);

wire [22:0] burst_start_adr;    // first DDR3 burst memory location for this fill (3 LSBs = 0)
wire [25:0] circ_buf_wr_dat;    // data to write to the circular buffer
wire [15:0] circ_buf_wr_addr;    // address to write to the circular buffer
(* mark_debug = "true" *) wire [25:0] circ_buf_rd_dat;    // data read from the circular buffer
(* mark_debug = "true" *) wire [15:0] circ_buf_rd_addr;    // address to read from the circular buffer
(* mark_debug = "true" *) wire [15:0] circ_buf_trig_addr;    // circular buffer address corresponding to a trigger, FIFO output

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
    // channel_tag[4] = 0 -> free-run, 1 -> reset every waveform
    if (channel_tag[4]) 
        dummy_dat_reset_mode <= #1 1'b1;
    else
        dummy_dat_reset_mode <= #1 1'b0;
end

/////////////////////////////////////////////////////////////////////////////////////////////////
// create a 400 MHz counter that we latch when we get a trigger
wire reset_timer;
reg  [41:0] timing_counter;
wire [41:0] trigger_time;
always @(posedge adc_clk) begin
    if ( reset_timer ) begin
       timing_counter <= 42'd0;
    end
    else begin
       timing_counter <= timing_counter + 1;
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////
// explicitly sync the capture settings into the adc clk domain
wire [15:0] async_pre_trig_adcclk;
sync_2stage #(
  .WIDTH(16)
) pretrig_sync (
   .clk(adc_clk),
   .in(async_pre_trig),
   .out(async_pre_trig_adcclk)
);
wire [13:0] async_num_bursts_adcclk;
sync_2stage #(
  .WIDTH(14)
) numbursts_sync (
   .clk(adc_clk),
   .in(async_num_bursts),
   .out(async_num_bursts_adcclk)
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a module that handles the ENABLE, TRIGGER, and RESET signals
wire [1:0] ddr3_range;        // level of the ddr3 range bit.  Two copies because of history of other modes
wire trig_enabled;
wire trig_pulse;
wire self_trig_ready;
enable_sm_selftrig enable_sm_selftrig (
    // inputs
    .adc_clk(adc_clk),                       // run the sm in this clock domain
    .enable_triggering(enable_triggering),   // a run has started and enabled triggers
    .ddr3_buffer(ddr3_buffer),               // which buffer to write to
    .self_trig(self_trig),                   // self trigger to start collecting data
    .reset_clk50(reset_clk50),               // synchronously negated
    .reset_clk_adc(adc_acq_full_reset),      // synchronously negated
    .cbuf_rd_trig_wait(cbuf_rd_trig_wait),   // waiting for another trigger or the negation of 'cbuf_rd_en'
    .ddr3_wr_done(ddr3_wr_done),             // asserted when the 'ddr3_wr_control' is in the DONE state
    // outputs
    .cbuf_wr_en(cbuf_wr_en),                 // writing into the circ buf by the ADC is enabled, must extend past final trigger
    .cbuf_trig_en(cbuf_trig_en),             // triggering of new waveforms is enabled
    .cbuf_rd_en(cbuf_rd_en),                 // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
    .ddr3_wr_en(ddr3_wr_en),                 // writing of triggered events to memory is enabled
    .ddr3_range(ddr3_range[1:0]),            // // level of the ddr3 range bit.  Two copies because of history of other modes
    .trig_pulse(trig_pulse),                 // a trigger passed while the system is enabled for new triggers
    .adc_acq_sm_idle(adc_acq_sm_idle),       // ADC acquisition state machine is idle (used for front panel LED status)
    .ext_done(ext_done),                     // assert external acquisition is done
    .reset_timer(reset_timer)                // triggers reset of the 800 MHz counter used to time stamp events
);


///////////////////////////////////////////////////////////////////////////////////////////////////
// Connect a module that handles the incoming ADC data and prepares it for writing to
// the circular buffer
adc_to_circ_buf_ASYNC adc_to_circ_buf_ASYNC (
    // inputs passed from outside
    .adc_in_p(adc_in_p[11:0]),                      // [11:0] array of ADC 'p' data pins
    .adc_in_n(adc_in_n[11:0]),                      // [11:0] array of ADC 'n' data pins
    .adc_ovr_p(adc_ovr_p),                          // ADC 'p' over-range pin
    .adc_ovr_n(adc_ovr_n),                          // ADC 'n' over-range pin
    .adc_clk(adc_clk),                              // 400 MHz ADC clock
    //.adc_clk_p(adc_clk_p),                        // ADC 'p' clk pin
    //.adc_clk_n(adc_clk_n),                        // ADC 'n' clk pin
    .reset_clk_adc(adc_acq_full_reset),             // synched to adc_clk
    .clk200(clk200),                                // for input pin timing delay settings
    .adc_buf_delay_data_reset(adc_buf_delay_data_reset), // use the new delay settings
    .adc_buf_data_delay(adc_buf_data_delay[4:0]),   // 5 delay-tap-bits per line, all lines always all the same
    // inputs created in this module
    .cbuf_wr_en(cbuf_wr_en),                        // writing into the circ buf by the ADC is enabled, must extend past final trigger
    .dummy_dat_reset_mode(dummy_dat_reset_mode),    // if true, reset the dummy data source for each trigger
    .use_dummy_data(use_dummy_data),                // if true, use counter instead of ADC
    .trig_pulse(trig_pulse),                        // single-period pulse from 'acq_trig' input
    // outputs
    .packed_adc_dat(packed_adc_dat[25:0]),
    .adc_buf_current_data_delay(adc_buf_current_data_delay), // 13 lines *5 bits/line, current tap settings
    .circ_buf_wr_addr(circ_buf_wr_addr[15:0]),    // address to store data in circular buffer
    .circ_buf_wr_dat(circ_buf_wr_dat[25:0])        // data to store in the circular buffer 
);

// XXX this needs to come from a register!!
wire signal_polarity;
assign signal_polarity = 1'b0;
////////////////////////////////////////////////////////////////////////////
// Self-trigger module
// A trigger will be established when a pulse exceeds a set threshold above a
// running-average pedestal
self_trigger self_trigger(
    .clk(adc_clk),
    .rst(adc_acq_full_reset),
    .adcdat(packed_adc_dat),                  // a pair of ADC samples and a pair of over-range bits
    .threshold(selftrig_threshold),           // threshold for average - pedestal to trigger a trigger pulse
    .polarity(signal_polarity),               // 1 => positive going signal, 0 => negative going
    .enable(enable_triggering),               // start looking for triggers
    .self_trig_ready(self_trig_ready),        // enough cycles have passed for self-triggering to be valid
    .trigger(self_trig)                       // a trigger has been found
);



/////////////////////////////////////////////////////////////////////////////////////////////////
// connect 13 dual-port circular buffers, each 2-bits wide and 64k deep. Both sides are clocked
// by the 'adc_clk'.  The write information is pipelined
genvar i;
generate
    for (i = 0; i < 13; i = i + 1 ) begin : loop
        pipelined_circular_buffer pipelined_circular_buffer_inst (
           .adc_clk(adc_clk),                            // 400 MHz ADC DDR clock
           .cbuf_wr_en(cbuf_wr_en),                      // enable writing
           .circ_buf_wr_addr(circ_buf_wr_addr[15:0]),    // write address
           .circ_buf_wr_dat(circ_buf_wr_dat[2*i+1:2*i]), // 2-bit wide input data
           .circ_buf_rd_addr(circ_buf_rd_addr[15:0]),    // read address
           .circ_buf_rd_dat(circ_buf_rd_dat[2*i+1:2*i])  // 2-bit wide output data
        );
    end
endgenerate

/////////////////////////////////////////////////////////////////////////////////////////////////
// Connect a FIFO that will hold the value of the 'write' address for each trigger point.
(* mark_debug = "true" *) wire trig_addr_rd_en;
circ_buf_fifo circ_buf_fifo (
  .clk(adc_clk),                    // 400 MHz ADC DDR clock
  .rst(adc_acq_full_reset),                 // reset from the Master FPGA
  .din(circ_buf_wr_addr[15:0]),        // current 'write' address
  .wr_en(trig_pulse),                // single-period pulse from 'acq_trig' input
  .rd_en(trig_addr_rd_en),            // read a trigger address from the FIFO
  .dout(circ_buf_trig_addr[15:0]),    // circular bufferr address corresponding to a trigger
  .full(),                            // 'full' is not used
  .empty(trig_fifo_empty)            // no triggers available when asserted
);

/////////////////////////////////////////////////////////////////////////////////////////////////
// Connect a FIFO that will hold the value of the trigger time.  It will be driven by the same
// signals that control the fifo for the circ buf trigger address
trigger_time_fifo trigger_time_fifo (
  .clk(adc_clk),                    // 400 MHz ADC DDR clock
  .rst(adc_acq_full_reset),         // reset from the Master FPGA
  .din(timing_counter[41:0]),       // current 'write' address
  .wr_en(trig_pulse),               // single-period pulse from 'acq_trig' input
  .rd_en(trig_addr_rd_en),          // read a trigger address from the FIFO
  .dout(trigger_time[41:0]),        // circular bufferr address corresponding to a trigger
  .full(),                          // 'full' is not used
  .empty()                          // we'll assume everything in lockstep with above
);

/////////////////////////////////////////////////////////////////////////////////////////////////
// Connect a module that moves data from the circular buffer to the DDR3 'write' FIFO.
circ_buf_to_ddr3_selftrig circ_buf_to_ddr3_selftrig(
    // inputs
    .adc_clk(adc_clk),                             // ADC clock used by the FIFO
    .reset_clk_adc(adc_acq_full_reset),            // either 'ext_reset' or 'reset_clk50' is asserted
    .channel_tag(channel_tag[11:0]),               // stuff about the channel to put in the header
    .initial_fill_num(initial_fill_num[23:0]),     // event number to assign to the first fill
    .initial_fill_num_wr(initial_fill_num_wr),     // write-strobe to store the initial_fill_num
    .cbuf_rd_en(cbuf_rd_en),                       // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
    .cbuf_trig_en(cbuf_trig_en),                   // triggering of new waveforms is enabled
    .async_num_bursts(async_num_bursts_adcclk[13:0]),     // number of 8-sample bursts in an ASYNC waveform
    .async_pre_trig(async_pre_trig_adcclk[15:0]),         // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    .circ_buf_rd_dat(circ_buf_rd_dat[25:0]),       // 26-bit wide data from the circular buffer
    .circ_buf_trig_addr(circ_buf_trig_addr[15:0]), // circular buffer address corresponding to a trigger, FIFO output
    .trig_fifo_empty(trig_fifo_empty),             // no triggers available when asserted
    .ddr3_range(ddr3_range[1:0]),                  // level of the ddr3 range bit.  Two copies because of history of other modes
    .trigger_time(trigger_time[41:0]),                     // the time of the most recent data trigger
    .xadc_alarms(xadc_alarms[3:0]),
    // outputs
    .cbuf_rd_trig_wait(cbuf_rd_trig_wait),         // waiting for another trigger or the negation of 'cbuf_rd_en'
    .trig_addr_rd_en(trig_addr_rd_en),             // read a trigger address from the FIFO
    .fill_num(fill_num[23:0]),                     // fill number for this fill
    .circ_buf_rd_addr(circ_buf_rd_addr[15:0]),     // read address for the circular buffer
    .adc_acq_out_dat(adc_acq_out_dat[131:0]),      // 132-bit 4-bit tag plus 128-bit header or ADC data
    .adc_acq_out_valid(adc_acq_out_valid),         // current data should be stored in the FIFO
    .current_waveform_num(current_waveform_num[22:0])
);

endmodule


`timescale 1ns / 10ps
// Logic to fill the circular buffer with ADC/dummy data

module adc_to_circ_buf_ASYNC (
    // inputs
    input [11:0] adc_in_p,          // [11:0] array of ADC 'p' data pins
    input [11:0] adc_in_n,          // [11:0] array of ADC 'n' data pins
    input adc_ovr_p,                // ADC 'p' over-range pin
    input adc_ovr_n,                // ADC 'n' over-range pin
    input adc_clk,                  // 400 MHz ADC clock
    //input adc_clk_p,                // ADC 'p' clk pin
    //input adc_clk_n,                // ADC 'n' clk pin
    input reset_clk_adc,            // synchronously negated reset all of the acquisition logic
    input clk200,                   // for input pin timing delay settings
    input cbuf_wr_en,               // writing into the circ buf by the ADC is enabled, must extend past final trigger
    input adc_buf_delay_data_reset, // use the new delay settings
    input [4:0] adc_buf_data_delay, // 5 delay-tap-bits per line, all lines always all the same
    input dummy_dat_reset_mode,     // if true, reset the dummy data source for each trigger
    input use_dummy_data,           // if true, use counter instead of ADC
    input trig_pulse,               // single-period pulse from 'acq_trig' input
    // outputs
    output [25:0] packed_adc_dat,   // two samples, with over-range bits,  packed in one wide-word
                                    // bit[0]      = first overrange
                                    // bits[11:1]  = first ADC sample
                                    // bit[12]     = second overrange
                                    // bits[25:13] = second ADC sample
    output [64:0] adc_buf_current_data_delay, // 13 lines *5 bits/line, current tap settings
    output reg [15:0] circ_buf_wr_addr,	      // address to store data in circular buffer
    output reg [25:0] circ_buf_wr_dat	      // data to store in the circular buffer
);
                                 
// We need a node called 'adc_acq_full_reset' in order to use the same timin constraint file for
// both SYNC and ASYNC projects.
reg adc_acq_full_reset;
always @(posedge adc_clk) begin
    adc_acq_full_reset <= reset_clk_adc;
end
///////////////////////////////////////////////////////////////////////////////////////////////////
// Connect a DDR input block that will produce an output twice-as-wide and a rising edge clock
// A good note on DDR timing
// http://forums.xilinx.com/t5/Timing-Analysis/XDC-constraints-Source-Synchronous-ADC-DDR/td-p/292807
// Use a SelectIO Wizard DDR input buffer
selectio_wiz_0 adc_dat_buf (
    .data_in_from_pins_p({adc_in_p[11:0],adc_ovr_p}),   // [12:0] array of ADC 'p' data pins and over-range
    .data_in_from_pins_n({adc_in_n[11:0],adc_ovr_n}),   // [12:0] array of ADC 'n' data pins and over-range
    .clk_in(adc_clk),                                   // 400 MHz clock from adc
    //.clk_in_p(adc_clk_p),                               // ADC 'p' clk pin
    //.clk_in_n(adc_clk_n),                               // ADC 'n' clk pin
    .io_reset(adc_acq_full_reset),                      // synchronously negated
    .in_delay_reset(adc_buf_delay_data_reset),          // input wire in_delay_reset
    .in_delay_tap_in({13{adc_buf_data_delay[4:0]}}),    // 13 input lines, 5 delay-tap-bits per line, always all the same
    .in_delay_tap_out(adc_buf_current_data_delay[64:0]),// 13 lines *5 bits/line, current tap settings 
    .in_delay_data_ce({13{1'b0}}),                      // 'ce' is unused
    .in_delay_data_inc({13{1'b0}}),                     // 'inc' is unused
    .delay_clk(clk200),
    .ref_clock(clk200),                                 // 200 MHz clock required to ensure tap value settings
    .data_in_to_device(packed_adc_dat),                 // twice-as-wide SDR data
    .delay_locked()                                     // not used
);

//// Connect the 'adc_clk' output to a global clock buffer
//   BUFG adc_clk_bufg (
//   .O(adc_clk), // 1-bit output: Clock output
//   .I(adc_clk_nobuf)  // 1-bit input: Clock input
//);

///////////////////////////////////////////////////////////////////////////////////////////////////
// create a counter that can provide dummy data for checking system integrity
reg [11:0] dummy_data;
always @(posedge adc_clk) begin
    if (reset_clk_adc || (dummy_dat_reset_mode & trig_pulse))
        // clear to zero at full reset, or when triggered and in dummy_data_reset' mode.
        // The initial count seen in the data stream may be different than zero, but will uniformly increase.
        dummy_data[11:0] <= #1 12'b0;
    else if (use_dummy_data && cbuf_wr_en)
        // increment on every adc_clk
        dummy_data[11:0] <= #1 dummy_data[11:0] + 1;
    else
        // hold
        dummy_data[11:0] <= #1 dummy_data[11:0];
end
        
///////////////////////////////////////////////////////////////////////////////////////////////////
// connect a register to hold 2 ADC samples coming from either the DDR input register or the dummy counter.
always @(posedge adc_clk) begin
    if (use_dummy_data) begin
        // use dummy data
        circ_buf_wr_dat[0]        <= #1 1'b0;                // over-range bit
        circ_buf_wr_dat[12:1]     <= #1 dummy_data[11:0];     // normal counter
        circ_buf_wr_dat[13]       <= #1 1'b0;                // over-range bit
        circ_buf_wr_dat[25:14]    <= #1 ~dummy_data[11:0];    // inverted counter
    end
	else begin
        // use real data
        circ_buf_wr_dat[25:0] <= #1  packed_adc_dat[25:0];
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter for the circular buffer 'write' address
always @(posedge adc_clk) begin
	if (reset_clk_adc || !cbuf_wr_en)
		// clear to zero at full reset, keep the counter at zero when not enabled
		circ_buf_wr_addr[15:0] <= #1 16'b0;
	else
		// otherwise continue incrementing, with wrap-around
		circ_buf_wr_addr[15:0] <= #1 circ_buf_wr_addr[15:0] + 1;
end

endmodule

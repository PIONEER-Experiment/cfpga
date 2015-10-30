`timescale 1ns / 1ps

// connect a down-counter that will keep track of the gap between waveforms
// It will be initialized after each waveform is stored.
// It will be enabled after each waveforms is stored.

module adc_waveform_gap_cntr (
    // inputs
    input [21:0] waveform_gap,		// idle time between waveforms
    input clk,
    input init,                     // initialize after previous waveform stored
    input enable,                   // enable after each initialization
    // outputs
    output reg at_zero              // the idle time has elapsed
);

reg [21:0] waveform_gap_cntr;

// set the 'at_zero' flag when the count is zero
always @(posedge clk) begin
    if (waveform_gap_cntr[21:0] == 22'd0) at_zero <= 1'b1;
    else at_zero <= 1'b0;
end

// count down when enabled and not at zero
always @(posedge clk) begin
    if (init) begin
        waveform_gap_cntr[21:0] <= waveform_gap[21:0];
    end
   else if (enable && !at_zero) begin
        waveform_gap_cntr[21:0] <= waveform_gap_cntr[21:0] - 1;
   end
end
    
endmodule

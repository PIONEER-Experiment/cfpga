`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////////////////////
// connect an up-counter that will keep track of the waveform number
// It will be initialized when a trigger occurs.
// It will be enabled after each waveforms is finished.
module adc_waveform_cntr (
    // inputs
    input [11:0] num_waveforms,	    // number of waveforms to store per trigger
    input clk,
    input init,                  // initialize when triggered
    input enable,                  // will be enabled once after each waveform
    // outputs
    output reg [11:0] current_waveform_num,// to be used in header
    output reg last			              // all waveforms have been saved
);

// count up when enabled, 
always @(posedge clk) begin
	if (init) begin
		current_waveform_num[11:0] <= 12'h001;
	end
	else if (enable) begin
		current_waveform_num[11:0] <= current_waveform_num[11:0] + 1;
	end
end

// set a flag when ww are at the last waveform
always @(posedge clk) begin
	if (current_waveform_num[11:0] == num_waveforms[11:0]) begin
		last <= 1'b1;
	end
	else begin
		last <= 1'b0;
	end
end

endmodule

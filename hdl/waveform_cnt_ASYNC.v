`timescale 1ns / 10ps

////////////////////////////////////////////////////////////////////
// connect an up-counter that will keep track of the waveform number
// It will be initialized to zero between fills.
// It will be enabled when processing starts for each waveforms.
module waveform_cntr_ASYNC (
    // inputs
    input clk,
    input init,                  		   // held at zero between fills
    input enable,                  		   // will be enabled once for each waveform
    // outputs
    output reg [22:0] current_waveform_num // to be used in header
);

// count up when enabled
always @(posedge clk) begin
	if (init) begin
		current_waveform_num[22:0] <= #1 23'h000000;
	end
	else if (enable) begin
		current_waveform_num[22:0] <= #1 current_waveform_num[22:0] + 1;
	end
end

endmodule

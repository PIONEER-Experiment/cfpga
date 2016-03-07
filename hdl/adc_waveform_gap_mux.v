`timescale 1ns / 1ps

///////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will provide the waveform gap as sepecified by the fill type.
// the output will be the number of 8 (or 10) sample bursts
module adc_waveform_gap_mux(
    // inputs
    input [1:0] fill_type,            // to determine how much data to collect
    input [21:0] muon_waveform_gap,		// idle time between waveforms 
    input [21:0] laser_waveform_gap,	// idle time between waveforms 
    input [21:0] ped_waveform_gap,		// idle time between waveforms 
    input clk,
    input enable,
    // outputs
    output reg [21:0] waveform_gap		// idle time between waveforms 
);

always @(posedge clk) begin
    if (enable) begin
        case (fill_type[1:0])
            2'b00  : begin
                        waveform_gap[21:0] <= 22'h00000;
                     end
            2'b01  : begin
                        waveform_gap[21:0] <= muon_waveform_gap[21:0];
                     end
            2'b10  : begin
                        waveform_gap[21:0] <= laser_waveform_gap[21:0];
                     end
            2'b11  : begin
                        waveform_gap[21:0] <= ped_waveform_gap[21:0];
                    end
		endcase
    end
end                  
endmodule

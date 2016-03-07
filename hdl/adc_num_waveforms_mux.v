`timescale 1ns / 1ps

///////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will provide the number of waveforms as specified by the fill type.
module adc_num_waveforms_mux(
    // inputs
    input [1:0] fill_type,            	// to determine how much data to collect
    input [11:0] muon_num_waveforms,	// number of waveforms to store per trigger
    input [11:0] laser_num_waveforms,	// number of waveforms to store per trigger
    input [11:0] ped_num_waveforms,		// number of waveforms to store per trigger
    input clk,
    input enable,
    // outputs
    output reg [11:0] num_waveforms // number of 8 (or 10) sample bursts
);

always @(posedge clk) begin
    if (enable) begin
        case (fill_type[1:0])
            2'b00  : begin
                        num_waveforms[11:0] <= 23'h00000;
                     end
            2'b01  : begin
                        num_waveforms[11:0] <= muon_num_waveforms[11:0];
                     end
            2'b10  : begin
                        num_waveforms[11:0] <= laser_num_waveforms[11:0];
                     end
            2'b11  : begin
                        num_waveforms[11:0] <= ped_num_waveforms[11:0];
                    end
		endcase
    end
end                  
endmodule



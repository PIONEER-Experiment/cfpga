`timescale 1ns / 1ps

///////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will provide the fill size as sepecified by the fill type.
// the output will be the number of 8 (or 10) sample bursts
module adc_fill_size_mux(
    // inputs
    input [1:0] fill_type,            // to determine how much data to collect
    input [22:0] muon_num_bursts,     // number of sample bursts in a MUON fill
    input [22:0] laser_num_bursts,    // number of sample bursts in a LASER fill
    input [22:0] ped_num_bursts,      // number of sample bursts in a PEDESTAL fill
    input clk,
    input enable,
    // outputs
    output reg [22:0] num_fill_bursts // number of 8 (or 10) sample bursts
);

always @(posedge clk) begin
    if (enable) begin
        case (fill_type[1:0])
            2'b00  : begin
                        num_fill_bursts[22:0] <= 23'h00000;
                     end
            2'b01  : begin
                        num_fill_bursts[22:0] <= muon_num_bursts[22:0];
                     end
            2'b10  : begin
                        num_fill_bursts[22:0] <= laser_num_bursts[22:0];
                     end
            2'b11  : begin
                        num_fill_bursts[22:0] <= ped_num_bursts[22:0];
                    end
		endcase
    end
end                  
endmodule

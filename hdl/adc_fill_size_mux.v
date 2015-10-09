`timescale 1ns / 1ps

///////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will provide the fill size as sepecified by the fill type.
// the output will be the number of 8 (or 10) sample bursts
module adc_fill_size_mux(
    // inputs
    input [1:0] fill_type,            // to determine how much data to collect
    input [23:0] num_muon_bursts,     // number of sample bursts in a MUON fill
    input [23:0] num_laser_bursts,    // number of sample bursts in a LASER fill
    input [23:0] num_ped_bursts,      // number of sample bursts in a PEDESTAL fill
    input clk,
    input enable,
    // outputs
    output reg [23:0] num_fill_bursts // number of 8 (or 10) sample bursts
);

always @(posedge clk) begin
    if (enable) begin
        case (fill_type)
            2'b00  : begin
                        num_fill_bursts[23:0] <= 20'h00000;
                     end
            2'b01  : begin
                        num_fill_bursts[23:0] <= num_muon_bursts[23:0];
                     end
            2'b10  : begin
                        num_fill_bursts[23:0] <= num_laser_bursts[23:0];
                     end
            2'b11  : begin
                        num_fill_bursts[23:0] <= num_ped_bursts[23:0];
                    end
        endcase
    end
end                  
endmodule

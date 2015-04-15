`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a down-counter that will keep track of how many bursts have been saved
// It will be initialized when a trigger occurs.
// It will be enabled when each burst is sent out.

module adc_burst_cntr (
    // inputs
    input [20:0] num_fill_bursts,       // number of 8(or 10) sample bursts
    input clk,
    input init,                     // initialize when triggered
    input enable,                   // will be enabled once per burst
    // outputs
    output reg at_zero              // all sample bursts have been saved
);

reg [20:0] burst_cntr;

// set the 'at_zero' flag when the count is zero
always @(posedge clk) begin
    if (burst_cntr[20:0] == 21'h00_0000) at_zero <= 1'b1;
    else at_zero <= 1'b0;
end

// count down when enabled and not at zero
always @(posedge clk) begin
    if (init) begin
        burst_cntr[20:0] <= num_fill_bursts[20:0];
    end
   else if (enable && !at_zero) begin
         burst_cntr[20:0] <= burst_cntr[20:0] - 1;
   end
end
    
endmodule

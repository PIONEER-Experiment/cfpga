`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter that will calculate the DDR3 starting address of the next fill
// It will be initialized when the fill number is written.
// It will increment each time data is written to the FIFO

module adc_address_cntr (
    // inputs
    input clk,
    input init,                   // initialize to zero when the fill number is written
    input enable,                 // will be enabled at the end of a fill
    // outputs
    output reg [22:0] burst_start_adr   // first DDR3 burst memory location for this fill
);

always @(posedge clk) begin
    if (init) begin
        // clear to zero when initialized
        burst_start_adr[22:0] <= 23'b0;
    end
    else if (enable) begin
        // increment 
        burst_start_adr[22:0] <= burst_start_adr[22:0] + 1;
    end
end
endmodule

`timescale 1ns / 10ps
//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter that will keep track of the DDR3 address
// It will be initialized when a fill is enabled.
// It will increment each time data is written to the FIFO

module burst_address_cntr_ASYNC (
    // inputs
    input clk,
    input init,                   // initialize to zero when the fill number is written
    input enable,                 // will be enabled at the end of a fill
    // outputs
    output reg [22:0] burst_adr   // current DDR3 burst memory location for this fill
);

always @(posedge clk) begin
    if (init) begin
        // set to 0x0001 when initialized
        burst_adr[22:0] <= #1 23'h000001;
    end
    else if (enable) begin
        // increment 
        burst_adr[22:0] <= #1 burst_adr[22:0] + 1;
    end
end
endmodule

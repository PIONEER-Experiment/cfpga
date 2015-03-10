`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////////////////////
// connect an up-counter that will keep track of the fill number
// It will be initialized at the start of a run, or when necessary.
// It will be enabled when each fill is done
module adc_fill_cntr (
    // inputs
    input [23:0] initial_fill_num,  // always positive
    input clk,
    input init,                     // initialize when programmed
    input enable,                   // will be enabled once per fill
    // outputs
   output reg [23:0] fill_num           // fill number for this fill
);

// sync 'init' to this clock
reg init_temp, init_sync;
always @(posedge clk) begin
    init_temp <= init;
    init_sync <= init_temp;
end

// count up when enabled, 
always @(posedge clk) begin
    if (init_sync) begin
        fill_num[23:0] <= initial_fill_num[23:0];
    end
   else if (enable) begin
         fill_num[23:0] <= fill_num[23:0] + 1'b1;
   end
end

endmodule

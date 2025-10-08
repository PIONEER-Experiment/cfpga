`timescale 1ns / 10ps
//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter that will keep track of the DDR3 address
// It will be initialized when a fill is enabled.
// It will increment each time data is written to the FIFO

module burst_address_cntr_selftrigc (
    // inputs
    input clk,
    input init_run,               // initialize address to zero (+1) when the run has started
    input init_fill,              // initialize counter to zero (+1) when the fill number is written
    input enable,                 // will be enabled at the end of a fill
    // outputs
    output reg [22:0] burst_adr,  // current DDR3 burst memory location
    output reg [22:0] burst_cnt_fill
);

always @(posedge clk) begin
    // manage the burst address
    if (init_run) begin
        // set to 0x0000. When the init_fill comes, the address will get bumped so that
        //  the fill header has a slot reserved
        // The extra init_fill is necessary to get the waveform header address slotted on
        // burst address after the fill header address.  
        burst_adr[22:0] <= #1 23'h000000;
    end
    else if (enable ||  init_fill ) begin
        // increment 
        burst_adr[22:0] <= #1 burst_adr[22:0] + 1;
    end

    // manage the burst count for this fill
    if (init_fill || init_run ) begin
        // set to 0x0001 when initialized
        burst_cnt_fill[22:0] <= #1 23'h000001;
    end
    else if (enable  ) begin
        // increment.  
        burst_cnt_fill[22:0] <= #1 burst_adr[22:0] + 1;
    end
end
endmodule

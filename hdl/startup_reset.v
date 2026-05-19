// startup_reset
//
// This module generates clocks and reset signals that will be asserted when the chip is
// initially configured. After some time, the reset signals will be negated synchronously
// with the appropriate clock. A clock must be present to negate the output.

module startup_reset (
    input  clk50,            // buffered clock, 50 MHz
    input  rst_from_master,  // external reset of all acquisition logic
    input  clk125,           // buffered clock, 125 MHz
    input  adc_clk,          // 400 MHz DDR clock from ADC
    output reset_clk50,      // active-high reset output, goes low after startup
    output reset_clk125,     // active-high reset output, goes low after startup
    output adc_acq_full_reset // active-high reset output, goes low after startup
);

    // Connect a counter that will count up once the chip comes out of reset, until it reaches its maximum value.
    // At that time, disable counting. Reset the counter anytime lock is lost.
    // Use the output as a reset signal. This counter is clocked from the input pin.
    reg [7:0] cnt = 8'h00;            // current counter output
    wire at_max;                    // counter is at maximum value
    assign at_max = (cnt == 8'hff) ? 1'b1 : 1'b0;
    always @(posedge clk50) begin
        if (!at_max) cnt <= cnt + 1;
        else cnt <= cnt;
    end        
 
    // Make a synchronous 'reset' signal from either the startup clock or the reset signal
    // from the master FPGA. Pass the signal thru a 2 stage synchronizer that is clocked by 'clk50'
    (* ASYNC_REG = "TRUE" *) reg clk50_sync1, clk50_sync2;    // registers for 2 stage synchronizers
    always @(posedge clk50) begin
        clk50_sync1 <= !at_max | rst_from_master;
        clk50_sync2 <= clk50_sync1;
    end
    // drive the 'reset' output
    assign reset_clk50 = clk50_sync2;
    
    // now pass the 'reset_clk50' signal thru a 2 stage synchronizer
    // that is clocked by 'clk125'.
    (* ASYNC_REG = "TRUE" *) reg clk125_sync1, clk125_sync2;    // registers for 2 stage synchronizers
    always @(posedge clk125) begin
        clk125_sync1 <= reset_clk50;
        clk125_sync2 <= clk125_sync1;
    end
    // drive the 'reset' output
    assign reset_clk125 = clk125_sync2;

    // now pass the 'reset_clk50' signal thru a 2 stage synchronizer
    // that is clocked by 'adc_clk'.
    (* ASYNC_REG = "TRUE" *) reg adc_clk_sync1, adc_clk_sync2;    // registers for 2 stage synchronizers
    always @(posedge adc_clk) begin
        adc_clk_sync1 <= reset_clk50;
        adc_clk_sync2 <= adc_clk_sync1;
    end
    // drive the 'reset' output
    assign adc_acq_full_reset = adc_clk_sync2;


endmodule

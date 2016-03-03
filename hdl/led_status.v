`timescale 1ns / 1ps

// Module to control front panel LED
//
// Robin Bjorkquist, June 2015

module led_status(
  input clk,
  output red_led,
  output green_led,
  input aurora_channel_up,
  input adc_acq_sm_idle,
  input command_sm_idle
);

// the LEDs are active low:
//    0 = LED on
//    1 = LED off

// Assignments right now:
//    green LED is on when aurora link is up AND both the ADC acquisition and command state machines are idle
//              e.g., green means "ready"
//    red LED is on otherwise
//              e.g., red means "error" or "busy"

assign green_led = ~(aurora_channel_up && adc_acq_sm_idle && command_sm_idle);
assign red_led = ~green_led;


// ===== old flasher code =====

// // Make a counter to flash an LED
// reg [23:0] led_cntr;
// reg led_toggle;
// always @ (posedge clk) begin
//   led_cntr <= led_cntr + 1;
// end
// 
// always @ (posedge clk) begin
//   if (led_cntr == 24'b0) begin
//     led_toggle <= ~led_toggle;
//   end
// end
// 
// assign led = led_toggle; 

endmodule

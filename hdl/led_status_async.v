`timescale 1ns / 1ps

// Module to control front panel LED

module led_status_async (
  input  clk,
  output red_led,
  output green_led,
  input  aurora_channel_up,
  input  adc_acq_sm_idle,
  input  command_sm_idle,
  input  ddr3_wr_control_sm_idle
);

// the LEDs are active low:
//    0 = LED on
//    1 = LED off

// Assignments right now:
//    green  LED is on when ready and not enabled
//    orange LED is on when idle and enabled
//    red    LED is on otherwise

assign green_led =  (aurora_channel_up &  adc_acq_sm_idle & command_sm_idle) ? 1'b0 : 
				    (aurora_channel_up & ~adc_acq_sm_idle & command_sm_idle) ? 1'b0 : 1'b1;
assign red_led   = ~(aurora_channel_up &  adc_acq_sm_idle & command_sm_idle) ? 1'b0 :
                    (aurora_channel_up & ~adc_acq_sm_idle & command_sm_idle) ? 1'b0 : 1'b1;

endmodule

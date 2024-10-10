`timescale 1ns / 10ps

///////////////////////////////////////////////////////////////////////////////////////
// Watch for a signal that exceeds a pedestal measurement and issue a trigger pulse when seen
//  - comparison will be based on average of four samples for signal and pedestal
//  - a polarity bit will indicate the size of difference that we are taking
//  - the pedestal value for reference will be for 4 ADC clock cycles earlier than the last sample in the sum
//  - the clock will be the 400 MHz DDR3 clock with a pair of samples input per clock cycle
//  - the trigger pulse will remain high as long as the pedestal-subtracted value exceeds the threshold
//  - the trigger pulse will also remain high for at least 25 ns so that the master fpga can sense
//    the trigger with the 40 MHz clock

module self_trigger (
    // inputs
    input clk,                     // the 400 MHz adc/ddr3 clock
    input rst,                     // reset
    input [25:0] adcdat,           // a pair of ADC samples and a pair of over-range bits
    input [41:0] timing_counter,   // counter of 400 MHz clock ticks
    input signed [11:0] threshold, // threshold for average - pedestal to trigger a trigger pulse.
    input polarity,                // 1 => positive going signal, 0 => negative going
    input enable,                  // start looking for triggers
    // outputs
    output reg self_trig_ready,    // enough post-enable cycles have passed for trigger calc's to be valid
    output reg [41:0] timestamp,   // timing_counter latched at trigger time
    output reg trigger
);

// add two stages of pipelining
// The format of the adcdat is
// bit 0   :            over-range bit of 1st sample
// bit 1-12:            adc data of 1st sample
// bit 13  :            over-range bit of 1st sample
// bit 14-25:            adc data of 1st sample
reg [13:0] p1_0, p1_1;
always @(posedge clk) begin
  p1_0 <= {adcdat[12],adcdat[12],adcdat[12: 1]};
  p1_1 <= {adcdat[25],adcdat[25],adcdat[25:14]};
end
reg [13:0] p2_0, p2_1;
always @(posedge clk) begin
  p2_0 <= p1_0;
  p2_1 <= p1_1;
end

///////////////////////////////////////////////////////////////////////////////////////////////////
// accumulate the sums and test for the trigger condition
wire signed [13:0] dat0, dat1;
assign dat0[13:0] = p2_0[13:0];
assign dat1[13:0] = p2_1[13:0];

// the variables for accumulating and buffering the sums
reg signed [13:0] input_sum, updating_sum, updating_sum_reg1, updating_sum_reg2;
reg signed [11:0] ped_buffer1;
reg signed [11:0] ped_buffer2;
reg signed [13:0] sum_buffer0, sum_buffer1;

// the average signal.  4 samples, so bitshift by 2
wire signed [11:0] signal_average;
assign signal_average[11:0] = updating_sum[13:2];

// the running average and delayed average
reg holding_trigger, init_hold_counter;
wire local_trigger_wire;
assign local_trigger_wire = self_trig_ready ? polarity ? signal_average > (threshold + ped_buffer2) : ped_buffer2 > (threshold + signal_average) : 0;
reg local_trigger_reg;
reg local_trigger;
always @(posedge clk ) begin
  if (rst) begin
     input_sum        <= 14'sd0;
     updating_sum     <= 14'sd0;
     sum_buffer0      <= 14'sd0;
     sum_buffer1      <= 14'sd0;
     ped_buffer1      <= 12'sd0;
     ped_buffer2      <= 12'sd0;
  end 
  else begin
     // update the running sum with the newest two samples, dropping the older two samples. Pipeline the results
     input_sum <= dat0 + dat1;
     updating_sum_reg1 <= updating_sum_reg1 + input_sum - sum_buffer0;
     updating_sum_reg2 <= updating_sum_reg1;
     updating_sum      <= updating_sum_reg2;
     sum_buffer0 <= sum_buffer1;
     sum_buffer1 <= input_sum;
     // store the previous average as an estimate of the pedestal
     ped_buffer1 <= signal_average;
     ped_buffer2 <= ped_buffer1;
     local_trigger_reg <= local_trigger_wire;
     local_trigger     <= local_trigger_reg;
     trigger <= holding_trigger;
  end
end

///////////////////////////////////////////////////////////////////////////////////////////////////
// Create a down-counter that will delay triggers until enough time has passed for the trigger
// calculations to be valid
reg [4:0] delay_cntr;
reg init_delay_cntr;
wire delay_cntr_zero;
// set a flag when the counter is equal to zero
assign delay_cntr_zero = (delay_cntr[4:0] == 0) ? 1'b1 : 1'b0;
always @(posedge clk) begin
    if (rst)
      // reset counter
      delay_cntr[4:0] <= 5'b0;
    else if (init_delay_cntr)
      delay_cntr[4:0] <= 5'd15;    // hold for 30 ADC cycles, so enough samples to cycle through for valid triggering
    else if (init_hold_counter )
      delay_cntr[4:0] <= 5'd21;    // hold for 105 ns after detecting trigger so that it lasts several master 40 MHz clock cycles.  (See master's channel_trigger_receiver.)
    else if (delay_cntr_zero)
      // if zero then hold there
      delay_cntr[4:0] <= 5'b0;
    else
      // decrement the counter
      delay_cntr[4:0] <= delay_cntr[4:0] - 1;
end

// state machine to keep track of when trigger becomes reliable

parameter [2:0]
  IDLE           =  3'd0,
  WAIT_FOR_VALID =  3'd1,
  ACCEPT_TRIGGERS = 3'd2,
  SETUP_HOLD      = 3'd3,
  HOLD_TRIGGER    = 3'd4,
  PIPE_ADJUST     = 3'd5;

// Declare current state and next state variables
(* mark_debug = "true" *) reg [5:0] /* synopsys enum STATE_TYPE */ CS;
reg [5:0] /* synopsys enum STATE_TYPE */ NS;

// sync the enable signal into the adc clk domain
(* ASYNC_REG = "TRUE" *) reg enable_sync1, enable_sync2;
always @(posedge clk) begin
    enable_sync1 <= #1 enable;
    enable_sync2 <= #1 enable_sync1;
end


// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
  if ( rst ) begin
    CS       <= {6{1'b0}}; // set all state bits to 0
    CS[IDLE] <= 1'b1;      // set IDLE state bit to 1
  end
  else
    CS <=  NS;         // set state bits to next state
end

always @ (CS or enable_sync2 or delay_cntr_zero or local_trigger ) begin
  NS = {5{1'b0}}; // default all bits to zero; will overrride one bit
  
  case (1'b1) // synopsys full_case parallel_case
  
  // Stay in the IDLE state whenever we are not enabled.
  CS[IDLE]: begin
    if (enable_sync2) begin
      NS[WAIT_FOR_VALID] = 1'b1;
    end 
    else begin
      NS[IDLE] = 1'b1;
    end
  end
  
  // stay in WAIT_FOR_VALID until count down is done
  CS[WAIT_FOR_VALID]: begin
    if ( delay_cntr_zero ) begin
      NS[ACCEPT_TRIGGERS] = 1'b1;
    end 
    else begin
      NS[WAIT_FOR_VALID] = 1'b1;
    end
  end
  
  CS[ACCEPT_TRIGGERS]: begin
    if ( enable_sync2 ) begin
      if ( local_trigger )
        NS[SETUP_HOLD] = 1'b1;
      else
        NS[ACCEPT_TRIGGERS] = 1'b1;
    end
    else begin
      NS[IDLE] = 1'b1;
    end
  end

  CS[SETUP_HOLD]: begin
    NS[HOLD_TRIGGER] = 1'b1;
  end
  
  // hold the trigger line high so that new triggers can't enter (a deadtime)
  // the length of this should become a parameter
  CS[HOLD_TRIGGER]: begin
    if ( delay_cntr_zero )
      NS[PIPE_ADJUST] = 1'b1;
    else
      NS[HOLD_TRIGGER] = 1'b1;
  end
 
  // go one more clock cycle to adjust for pipeline delay between the trigger and self_trig_ready
  CS[PIPE_ADJUST]: begin
    NS[ACCEPT_TRIGGERS] = 1'b1;
  end
  
  endcase
  
  end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
  init_delay_cntr   <= 1'b0;
  self_trig_ready   <= 1'b0;
  init_hold_counter <= 1'b0;
  holding_trigger   <= 1'b0;
  
  if (NS[IDLE]) begin
    init_delay_cntr <= 1'b1;
  end

  if(NS[ACCEPT_TRIGGERS]) begin
    self_trig_ready <= 1'b1;
  end

  if(NS[SETUP_HOLD]) begin
    init_hold_counter <= 1'b1;
  end

  if(NS[HOLD_TRIGGER]) begin
    holding_trigger <= 1'b1;
    timestamp[41:0] <= timing_counter[41:0];
  end
  
end

endmodule


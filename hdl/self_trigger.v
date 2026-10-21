`timescale 1ns / 10ps

///////////////////////////////////////////////////////////////////////////////////////
// Watch for a signal that exceeds a pedestal measurement and issue a trigger pulse when seen
//  - the comparison is between a running average of the most recent 2*D ADC samples (the "signal")
//    and the same running average from 'ped_delay' clock cycles earlier (the "pedestal")
//  - D (the number of sample pairs in the window) and ped_delay are run-time configurable through
//    channel register 0x28 (see register_block64.v); a bypass bit forces the pedestal to zero so
//    that the trigger becomes an absolute-threshold comparison on the running average
//  - a polarity bit selects the sign of the difference that is tested
//  - the clock is the 400 MHz DDR3 clock with a pair of samples input per clock cycle
//  - the trigger pulse remains high as long as the pedestal-subtracted value exceeds the threshold,
//    and for at least 105 ns so that the master fpga can sense it with its 40 MHz clock
//
// Window / pedestal encoding (quasi-static inputs, changed between runs only):
//   sum_log2_in[2:0]  : D = 2^sum_log2 sample pairs are summed, i.e. 2, 4, 8, ... 128 samples.
//                       Codes above log2(MAX_PAIRS) are clamped to MAX_PAIRS.  Default 1 (4 samples).
//   ped_delay_in[5:0] : the pedestal is the running average from ped_delay (1..63) clock cycles
//                       earlier than the signal average.  0 is treated as 1.  Default 4.
//   ped_bypass_in     : 1 => pedestal forced to zero.  Default 0.
//
// Pipeline (relative to the previous fixed 4-sample / 4-cycle implementation) is four clock cycles (10 ns)
// longer: registered stages on the pair sum, the signal average, the pedestal/signal pair and the trigger
// comparison.  This is a fixed latency and is absorbed by the pre-trigger sample count.

module self_trigger #(
    parameter MAX_PAIRS = 64          // maximum number of clock-cycle pairs in the sliding window; power of two
) (
    // inputs
    input clk,                        // the 400 MHz adc/ddr3 clock
    input rst,                        // reset
    input [25:0] adcdat,              // a pair of ADC samples and a pair of over-range bits
    input [41:0] timing_counter,      // counter of 400 MHz clock ticks
    input signed [11:0] threshold_in, // threshold for average - pedestal to trigger a trigger pulse.
    input polarity_in,                // 1 => positive going signal, 0 => negative going
    input [2:0] sum_log2_in,          // log2 of the number of sample pairs in the running average
    input [5:0] ped_delay_in,         // pedestal delay in clock cycles (1..63)
    input ped_bypass_in,              // 1 => compare the running average against the threshold alone
    input enable,                     // start looking for triggers. Global in time.
    input cbuf_trig_en,               // accept self triggers.  Local in time. Controlled by enable_sm_selftrig
    // outputs
    output reg self_trig_ready,    // enough post-enable cycles have passed for trigger calc's to be valid
    output reg [41:0] timestamp,   // timing_counter latched at trigger time
    output reg trigger
);

localparam MAX_LOG2 = $clog2(MAX_PAIRS);

// add two stages of pipelining
// The format of the adcdat is
// bit 0   :            over-range bit of 1st sample
// bit 1-12:            adc data of 1st sample
// bit 13  :            over-range bit of 2nd sample
// bit 14-25:           adc data of 2nd sample
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
// bring the configuration into the adc clock domain.  All of these are quasi-static.
wire signed [11:0] threshold;
sync_2stage #(
  .WIDTH(12)
) thresh_sync (
   .clk(clk),
   .in(threshold_in),
   .out(threshold)
);

wire polarity;
sync_2stage polar_sync (
   .clk(clk),
   .in(polarity_in),
   .out(polarity)
);

wire [2:0] sum_log2_sync;
wire [5:0] ped_delay_sync;
wire       ped_bypass_sync;
sync_2stage #(
  .WIDTH(10)
) window_sync (
   .clk(clk),
   .in({ped_bypass_in, ped_delay_in[5:0], sum_log2_in[2:0]}),
   .out({ped_bypass_sync, ped_delay_sync[5:0], sum_log2_sync[2:0]})
);

// clamp and register the derived quantities so that the shift-register taps and the
// barrel shifter are driven from clean registers
reg [2:0] sum_log2;        // clamped log2 of the window length in pairs
reg [2:0] avg_shift;       // right shift to turn the window sum into a per-sample average = sum_log2 + 1
reg [5:0] sum_drop_idx;    // tap into the pair-sum history: D - 1
reg [5:0] ped_idx;         // tap into the average history: ped_delay - 1
reg       ped_bypass;
always @(posedge clk) begin
  sum_log2     <= (sum_log2_sync > MAX_LOG2) ? MAX_LOG2 : sum_log2_sync;
  avg_shift    <= sum_log2 + 3'd1;
  sum_drop_idx <= (6'd1 << sum_log2) - 6'd1;
  ped_idx      <= (ped_delay_sync == 6'd0) ? 6'd0 : (ped_delay_sync - 6'd1);
  ped_bypass   <= ped_bypass_sync;
end

///////////////////////////////////////////////////////////////////////////////////////////////////
// accumulate the sums and test for the trigger condition
wire signed [13:0] dat0, dat1;
assign dat0[13:0] = p2_0[13:0];
assign dat1[13:0] = p2_1[13:0];

// sum of the newest pair of samples
reg signed [14:0] input_sum, input_sum_d1;
always @(posedge clk) begin
  input_sum    <= dat0 + dat1;
  input_sum_d1 <= input_sum;
end

// history of pair sums, MAX_PAIRS deep (Vivado maps this to SRL primitives with a dynamic tap).
// sum_sr[k] holds input_sum delayed by k+1 cycles.
reg signed [14:0] sum_sr [0:MAX_PAIRS-1];
integer k;
always @(posedge clk) begin
  sum_sr[0] <= input_sum;
  for (k = 1; k < MAX_PAIRS; k = k + 1)
    sum_sr[k] <= sum_sr[k-1];
end

// the pair that drops out of the window.  Registered, so it is input_sum delayed by D+1 cycles,
// and it is paired with input_sum_d1 (delayed by 1) in the accumulator: the window is D pairs wide.
reg signed [14:0] sum_drop;
always @(posedge clk) begin
  sum_drop <= sum_sr[sum_drop_idx];
end

// The accumulator is cleared on reset and whenever the window length changes, but the pair-sum
// history is a shift register and cannot be cleared.  Until D pairs have been added after a clear,
// the entry that would drop out of the window was never added in, so it must not be subtracted.
// 'window_age' counts cycles since the last clear (saturating) and masks the drop term until then.
reg [5:0] sum_drop_idx_d;
reg [6:0] window_age;
wire      window_filling;
assign window_filling = (window_age <= {1'b0, sum_drop_idx});   // fewer than D pairs accumulated
always @(posedge clk) begin
  sum_drop_idx_d <= sum_drop_idx;
  if (rst || (sum_drop_idx != sum_drop_idx_d))
    window_age <= 7'd0;
  else if (window_age != 7'd127)
    window_age <= window_age + 7'd1;
end

// sliding-window accumulator: 2*MAX_PAIRS samples of 12 bits need 20 bits; use 21 bits signed
reg signed [20:0] updating_sum_reg1, updating_sum_reg2, updating_sum;
always @(posedge clk) begin
  if (rst || (sum_drop_idx != sum_drop_idx_d)) begin
    updating_sum_reg1 <= 21'sd0;
    updating_sum_reg2 <= 21'sd0;
    updating_sum      <= 21'sd0;
  end
  else begin
    updating_sum_reg1 <= updating_sum_reg1 + input_sum_d1 - (window_filling ? 15'sd0 : sum_drop);
    updating_sum_reg2 <= updating_sum_reg1;
    updating_sum      <= updating_sum_reg2;
  end
end

// the per-sample average of the window: arithmetic right shift by log2(2*D).  Registered.
reg signed [11:0] signal_average;
always @(posedge clk) begin
  signal_average <= updating_sum >>> avg_shift;
end

// history of the average for the pedestal estimate, 64 deep (dynamic tap, SRL).
// ped_sr[k] holds signal_average delayed by k+1 cycles.
reg signed [11:0] ped_sr [0:63];
integer j;
always @(posedge clk) begin
  ped_sr[0] <= signal_average;
  for (j = 1; j < 64; j = j + 1)
    ped_sr[j] <= ped_sr[j-1];
end

// the registered pedestal is signal_average delayed by ped_delay+1 cycles; compare it against
// signal_average delayed by 1 so that the separation is exactly ped_delay cycles
reg signed [11:0] pedestal, signal_cmp;
always @(posedge clk) begin
  pedestal   <= ped_bypass ? 12'sd0 : ped_sr[ped_idx];
  signal_cmp <= signal_average;
end

// the trigger comparison, done in 14 bits so that threshold + pedestal cannot wrap.
//   positive polarity: signal > pedestal + threshold
//   negative polarity: pedestal > signal + threshold
wire signed [13:0] thr_plus_ped, thr_plus_sig;
assign thr_plus_ped = threshold + pedestal;
assign thr_plus_sig = threshold + signal_cmp;
reg trig_cond;
always @(posedge clk) begin
  trig_cond <= polarity ? (signal_cmp > thr_plus_ped) : (pedestal > thr_plus_sig);
end

wire local_trigger_wire;
assign local_trigger_wire = self_trig_ready & trig_cond;

reg holding_trigger, init_hold_counter, init_gap_counter;
reg local_trigger_reg;
reg local_trigger;
always @(posedge clk) begin
  local_trigger_reg <= local_trigger_wire & cbuf_trig_en;
  local_trigger     <= local_trigger_reg;
  trigger           <= holding_trigger;
end

///////////////////////////////////////////////////////////////////////////////////////////////////
// Create a down-counter that will delay triggers until enough time has passed for the trigger
// calculations to be valid, and that provides the post-trigger hold (dead time).
// The settling time depends on the configured window and pedestal delay: the pedestal must be a
// fully-populated average, i.e. D + ped_delay cycles plus the pipeline, after the enable.
wire [7:0] settle_cycles;
assign settle_cycles = {2'b00, sum_drop_idx} + {2'b00, ped_idx} + 8'd16;

reg [7:0] delay_cntr;
reg init_delay_cntr;
wire delay_cntr_zero;
// set a flag when the counter is equal to zero
assign delay_cntr_zero = (delay_cntr[7:0] == 0) ? 1'b1 : 1'b0;
always @(posedge clk) begin
    if (rst)
      // reset counter
      delay_cntr[7:0] <= 8'b0;
    else if (init_delay_cntr)
      delay_cntr[7:0] <= settle_cycles;  // at least 16 cycles (the old fixed value was 15), more for long windows
    else if (init_hold_counter )
      delay_cntr[7:0] <= HOLD_CYCLES;  // keep the trigger line high long enough for the master's 40 MHz receiver
    else if (init_gap_counter )
      delay_cntr[7:0] <= GAP_CYCLES;   // and then low long enough that the master sees the end of this trigger before the next
    else if (delay_cntr_zero)
      // if zero then hold there
      delay_cntr[7:0] <= 8'b0;
    else
      // decrement the counter
      delay_cntr[7:0] <= delay_cntr[7:0] - 1;
end

// The trigger line is sampled by the master's channel_triggerc_receiver on its 40 MHz clock through
// a two-stage synchroniser, and that receiver counts one trigger per contiguous high level.  So each
// trigger must be high for at least two 40 MHz periods, and consecutive triggers must be separated
// by at least two 40 MHz periods of low, or the master counts fewer triggers than the channel
// stores waveforms and the readout loses alignment.  Before the gap existed, a pulse that was still
// over threshold when the hold expired re-triggered after a 7.5 ns low, invisible to the master.
localparam [7:0] HOLD_CYCLES = 8'd24;   // 60 ns high
localparam [7:0] GAP_CYCLES  = 8'd24;   // 60 ns low: dead time between consecutive triggers

// state machine to keep track of when trigger becomes reliable

parameter [2:0]
  IDLE           =  3'd0,
  WAIT_FOR_VALID =  3'd1,
  ACCEPT_TRIGGERS = 3'd2,
  SETUP_HOLD      = 3'd3,
  HOLD_TRIGGER    = 3'd4,
  PIPE_ADJUST     = 3'd5,
  TRIG_GAP        = 3'd6;

// Declare current state and next state variables
reg [6:0] /* synopsys enum STATE_TYPE */ CS;  // self_trigger SM state
reg [6:0] /* synopsys enum STATE_TYPE */ NS;

// sync the enable signal into the adc clk domain
(* ASYNC_REG = "TRUE" *) reg enable_sync1;
(* ASYNC_REG = "TRUE" *) reg enable_sync2; // synchronized enable_triggering; must be 1 for SM to leave IDLE
always @(posedge clk) begin
    enable_sync1 <= #1 enable;
    enable_sync2 <= #1 enable_sync1;
end

// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
  if ( rst ) begin
    CS             <= {7{1'b0}}; // set all state bits to 0
    CS[IDLE]       <= 1'b1;      // set IDLE state bit to 1
  end
  else
    CS <=  NS;         // set state bits to next state
end

always @ (CS or enable_sync2 or delay_cntr_zero or local_trigger or init_gap_counter ) begin
  NS = {7{1'b0}}; // default all bits to zero; will overrride one bit

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
  CS[HOLD_TRIGGER]: begin
    if ( delay_cntr_zero )
      NS[TRIG_GAP] = 1'b1;
    else
      NS[HOLD_TRIGGER] = 1'b1;
  end

  // keep the trigger line low for a while so that the master sees the end of this trigger
  CS[TRIG_GAP]: begin
    // the gap counter is loaded during the first cycle in this state, so ignore 'zero' until then
    if ( delay_cntr_zero && !init_gap_counter )
      NS[PIPE_ADJUST] = 1'b1;
    else
      NS[TRIG_GAP] = 1'b1;
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
  init_gap_counter  <= 1'b0;
  holding_trigger   <= 1'b0;

  if (NS[IDLE]) begin
    init_delay_cntr <= 1'b1;
  end

  if(NS[ACCEPT_TRIGGERS]) begin
    self_trig_ready <= 1'b1;
  end

  if(NS[SETUP_HOLD]) begin
    init_hold_counter <= 1'b1;
    timestamp[41:0]   <= timing_counter[41:0];
  end

  if(NS[HOLD_TRIGGER]) begin
    holding_trigger <= 1'b1;
  end

  if(NS[TRIG_GAP] && CS[HOLD_TRIGGER]) begin
    init_gap_counter <= 1'b1;  // load the gap length as we enter TRIG_GAP
  end

end

endmodule

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
    input line_hold_off,              // fill boundary guard from enable_sm_selftrigc: triggers accepted while this
                                      // is high belong to the next fill and their pulse to the master is held back
    input [7:0] min_separation_in,    // minimum separation of accepted triggers, in clocks (quasi-static; < 8 reads as 8)
    input retrig_level_in,            // 1 => re-trigger after the separation while still over threshold (legacy);
                                      // 0 => re-arm only once the comparator has dropped below threshold (one trigger per excursion)
    input trig_backlog_full,          // the trigger-address FIFOs are nearly full (adc_acq_top): accept no more until they drain
    input fill_parity,                // from enable_sm_selftrigc: toggles at every fill boundary (a boundary releases the deferred pulses)
    // outputs
    output reg self_trig_ready,    // enough post-enable cycles have passed for trigger calc's to be valid
    output reg [41:0] timestamp,   // timing_counter latched at trigger time
    output reg trigger_immediate,  // the accepted trigger itself, one HOLD_CYCLES pulse at acceptance: drives the
                                   // trigger-address / time FIFO capture (fixed latency, see enable_sm_selftrigc)
    output reg trigger,            // the trigger line to the master: one pulse per accepted trigger, deferred
                                   // past the fill boundary while 'line_hold_off' is high
    output line_quiet,             // no pulse owed for the closing fill and the line is idle: enable_sm_selftrigc
                                   // waits for this before it closes the fill (raises 'done' to the master)
    output reg [15:0] refused_count, // triggers refused because the FIFOs or the pulse queue were full (saturating; diagnostic)
    output [7:0] pending_pulses    // pulses owed to the master for the open fill, live (diagnostic)
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
wire [7:0] min_separation_sync;
wire       retrig_level;
sync_2stage #(.WIDTH(8)) minsep_sync (.clk(clk), .in(min_separation_in), .out(min_separation_sync));
sync_2stage               retrig_sync (.clk(clk), .in(retrig_level_in),  .out(retrig_level));
// the separation counter is loaded with (separation - 5): SETUP_HOLD, the load cycle of SEPARATION,
// REARM and the two clocks of comparator pipeline before the next trigger can be seen in
// ACCEPT_TRIGGERS make up the other five clocks of the minimum period (verified in simulation:
// accepted triggers are never closer than the programmed value)
reg [7:0] separation_load;
always @(posedge clk) separation_load <= (min_separation_sync < 8'd8) ? 8'd3 : (min_separation_sync - 8'd5);   // floor of 8 clocks (20 ns), the pipeline

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
// 'window_change' and 'window_filling' are registered so that neither comparison sits in front
// of the accumulator's adder (timing at 400 MHz); window_filling is computed one cycle ahead so
// that it still reads "fewer than D pairs accumulated" in the cycle it is used.
reg [5:0] sum_drop_idx_d;
reg [6:0] window_age;
reg       window_change  = 1'b0;
reg       window_filling = 1'b1;
always @(posedge clk) begin
  sum_drop_idx_d <= sum_drop_idx;
  window_change  <= (sum_drop_idx != sum_drop_idx_d);
  if (rst || window_change)
    window_age <= 7'd0;
  else if (window_age != 7'd127)
    window_age <= window_age + 7'd1;
  window_filling <= rst || window_change || (window_age < {1'b0, sum_drop_idx});
end

// sliding-window accumulator: 2*MAX_PAIRS samples of 12 bits need 20 bits; use 21 bits signed
reg signed [20:0] updating_sum_reg1, updating_sum_reg2, updating_sum;
always @(posedge clk) begin
  if (rst || window_change) begin
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
// Pipelined in two stages: the additions are registered, then compared.  An add followed by
// a compare is two carry chains back to back, which does not fit in one 400 MHz cycle on
// this device (the path failed timing in v6.6.5 by 0.1 ns).  Costs one cycle of trigger latency.
reg signed [13:0] thr_plus_ped, thr_plus_sig;
reg signed [11:0] pedestal_d, signal_cmp_d;
always @(posedge clk) begin
  thr_plus_ped <= threshold + pedestal;
  thr_plus_sig <= threshold + signal_cmp;
  pedestal_d   <= pedestal;
  signal_cmp_d <= signal_cmp;
end
reg trig_cond;
always @(posedge clk) begin
  trig_cond <= polarity ? (signal_cmp_d > thr_plus_ped) : (pedestal_d > thr_plus_sig);
end

wire local_trigger_wire;
assign local_trigger_wire = self_trig_ready & trig_cond;

// Back-pressure on acceptance (6.6.9).  A trigger is refused -- it still passes through
// SETUP_HOLD / SEPARATION / REARM, so the dead time and re-arm behave as usual, but it is not
// captured and owes the master no pulse -- when the trigger-address FIFOs are nearly full or the
// queue of pulses owed to the master is nearly saturated.  Without this a channel triggering
// faster than it can be read out (a threshold in the noise) overflows the IP FIFOs silently while
// the parity tag RAM beside them keeps writing, the three lose step, and the master is owed pulses
// for waveforms that were never stored.  Refusing keeps 'the master's count == the channel's
// waveform count' true at any rate.  The decision is registered (one clock stale is harmless).
reg trig_refuse = 1'b0;
reg refused     = 1'b0;          // the current pass through SETUP_HOLD is a refusal
reg accepted_d1;                 // one clock after SETUP_HOLD, for the fixed-latency 'trigger_immediate'
reg init_sep_counter;
reg local_trigger_reg;
reg local_trigger;
// Triggers are accepted whenever the state machine below is out of IDLE, i.e. whenever
// 'enable' (enable_triggering) is set.  They are no longer gated off around a fill boundary:
// a trigger that lands there is accepted, captured, and assigned to the next fill (see the
// trigger-line logic at the end of this file), instead of being dropped.
always @(posedge clk) begin
  local_trigger_reg <= local_trigger_wire;
  local_trigger     <= local_trigger_reg;
  trigger_immediate <= accepted_d1;      // high two clocks after SETUP_HOLD, exactly as the old HOLD_TRIGGER output was
end

///////////////////////////////////////////////////////////////////////////////////////////////////
// Create a down-counter that will delay triggers until enough time has passed for the trigger
// calculations to be valid, and that provides the post-trigger minimum separation (dead time).
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
    else if (init_sep_counter )
      delay_cntr[7:0] <= separation_load;  // the programmed minimum separation between accepted triggers
    else if (delay_cntr_zero)
      // if zero then hold there
      delay_cntr[7:0] <= 8'b0;
    else
      // decrement the counter
      delay_cntr[7:0] <= delay_cntr[7:0] - 1;
end

// The pulse shape on the trigger line to the master (HOLD_CYCLES high, GAP_CYCLES low) is produced
// by the line state machine at the end of this file; the detector below no longer has to wait for
// it.  The detector's own dead time is the programmed minimum separation, and in the default
// (edge) mode it also re-arms only once the comparator has dropped below threshold, so a pulse
// that stays over threshold for longer than the separation gives one trigger, not a train.
localparam [7:0] HOLD_CYCLES = 8'd24;   // 60 ns high
localparam [7:0] GAP_CYCLES  = 8'd24;   // 60 ns low: the master's receiver needs both

// state machine to keep track of when trigger becomes reliable

parameter [2:0]
  IDLE            = 3'd0,
  WAIT_FOR_VALID  = 3'd1,
  ACCEPT_TRIGGERS = 3'd2,
  SETUP_HOLD      = 3'd3,
  SEPARATION      = 3'd4,   // the programmed minimum separation after an accepted trigger
  REARM           = 3'd5;   // wait (edge mode) for the comparator to have dropped below threshold

// Declare current state and next state variables
reg [5:0] /* synopsys enum STATE_TYPE */ CS;  // self_trigger SM state
reg [5:0] /* synopsys enum STATE_TYPE */ NS;

// 'armed': in edge mode a new trigger is accepted only after 'local_trigger' has been low at least
// once since the last accepted trigger.  'local_trigger' is the comparator two clocks later, and the
// acceptance decision uses the same signal, so the two are consistent.
reg armed;
always @(posedge clk) begin
  if (rst || CS[SETUP_HOLD]) armed <= 1'b0;
  else if (!local_trigger)   armed <= 1'b1;
end

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
    CS             <= {6{1'b0}}; // set all state bits to 0
    CS[IDLE]       <= 1'b1;      // set IDLE state bit to 1
  end
  else
    CS <=  NS;         // set state bits to next state
end

always @ (CS or enable_sync2 or delay_cntr_zero or local_trigger or init_sep_counter or armed or retrig_level ) begin
  NS = {6{1'b0}}; // default all bits to zero; will overrride one bit

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
      if ( local_trigger && (armed || retrig_level) )
        NS[SETUP_HOLD] = 1'b1;
      else
        NS[ACCEPT_TRIGGERS] = 1'b1;
    end
    else begin
      NS[IDLE] = 1'b1;
    end
  end

  // one clock: the trigger is accepted here (timestamp latched, pulse owed to the master)
  CS[SETUP_HOLD]: begin
    NS[SEPARATION] = 1'b1;
  end

  // the programmed minimum separation; the counter is loaded on the way in, so ignore 'zero' then
  CS[SEPARATION]: begin
    if ( delay_cntr_zero && !init_sep_counter )
      NS[REARM] = 1'b1;
    else
      NS[SEPARATION] = 1'b1;
  end

  // edge mode: wait for the comparator to have been below threshold since the trigger;
  // level mode: straight back to accepting (a pulse still over threshold re-triggers at once)
  CS[REARM]: begin
    if ( !enable_sync2 )
      NS[IDLE] = 1'b1;
    else if ( armed || retrig_level )
      NS[ACCEPT_TRIGGERS] = 1'b1;
    else
      NS[REARM] = 1'b1;
  end

  endcase

  end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
  init_delay_cntr   <= 1'b0;
  self_trig_ready   <= 1'b0;
  init_sep_counter  <= 1'b0;
  accepted_d1       <= 1'b0;

  if (NS[IDLE]) begin
    init_delay_cntr <= 1'b1;
  end

  // the comparator pipeline is kept live from ACCEPT_TRIGGERS onwards (also through the
  // separation and re-arm), so that 'armed' sees the comparator drop and so that the first
  // ACCEPT_TRIGGERS cycle after a re-arm already has a current 'local_trigger'
  if(NS[ACCEPT_TRIGGERS] || NS[SETUP_HOLD] || NS[SEPARATION] || NS[REARM]) begin
    self_trig_ready <= 1'b1;
  end

  if(NS[SETUP_HOLD]) begin
    timestamp[41:0]   <= timing_counter[41:0];
  end

  if(NS[SEPARATION] && CS[SETUP_HOLD]) begin
    init_sep_counter <= 1'b1;  // load the separation as we enter SEPARATION
  end

  if(CS[SETUP_HOLD] && !refused) begin
    accepted_d1 <= 1'b1;
  end

  if(NS[SETUP_HOLD] && !CS[SETUP_HOLD]) begin
    refused <= trig_refuse;      // decided once, on the way in
  end

end


///////////////////////////////////////////////////////////////////////////////////////////////////
// The trigger line to the master.
//
// Every accepted trigger (one pass through SETUP_HOLD) owes the master exactly one pulse on the
// trigger line: HOLD_CYCLES high then GAP_CYCLES low, as discussed above.  The master counts
// the pulses per fill and latches the count a fixed time after it raises 'new_fill' (io[3]); the
// channel decides at its own fill boundary which fill a trigger belongs to (fill_parity in
// enable_sm_selftrigc), and the two must agree.  So
//   - a trigger accepted while 'line_hold_off' is low belongs to the fill that is open; its pulse
//     goes out at once and reaches the master before the master latches, and
//   - a trigger accepted while 'line_hold_off' is high belongs to the next fill; its pulse is held
//     until the hold-off ends, which enable_sm_selftrigc guarantees is after the master has latched.
// Nothing is dropped: the detection, its timestamp and its circular-buffer address are captured
// at acceptance either way ('trigger_immediate').
//
// A line pulse takes HOLD_CYCLES + GAP_CYCLES = 48 clocks (120 ns), while triggers may now be
// accepted every 'min_separation' clocks, so a burst can be accepted faster than it can be
// reported and the owed pulses queue up here (the DDR3 writer limits the sustained rate to a small
// fraction of the line rate, so the queue is short-lived); deferred pulses also accumulate during a
// fill-boundary hold-off.  The counters saturate rather than wrap.  A pulse that has started always
// completes, so that a trigger accepted just before 'enable' drops is still counted by the master.
// At the fill boundary, enable_sm_selftrigc does not close the fill (and so does not raise 'done'
// to the master) until 'line_quiet': every pulse owed for the closing fill has been sent and its
// gap has elapsed, so the master has counted it before it latches its count on 'done', however
// long the backlog was.  Deferred pulses then go out at least GUARD_CYCLES after 'done'.
localparam [1:0] LINE_IDLE = 2'd0, LINE_HIGH = 2'd1, LINE_LOW = 2'd2;
reg [7:0] pending_now      = 8'd0;   // pulses owed to the master for the fill that is open
reg [7:0] pending_deferred = 8'd0;   // pulses owed for triggers accepted during a hold-off (the next fill)
reg [1:0] line_state       = LINE_IDLE;
reg [7:0] line_cntr        = 8'd0;
reg       line_hold_off_d  = 1'b0;
wire accept_now = CS[SETUP_HOLD] & ~refused & ~line_hold_off;
wire accept_def = CS[SETUP_HOLD] & ~refused &  line_hold_off;
assign pending_pulses = pending_now;
wire send_now   = (line_state == LINE_IDLE) & (pending_now != 8'd0);
// when the hold-off ends the deferred pulses are simply pulses of the fill that is now open, so they
// are merged into 'pending_now' (saturating) rather than kept as a separate, lower-priority queue
// that a steady stream of new triggers could starve past the next fill boundary
wire hold_release    = line_hold_off_d & ~line_hold_off;
// A fill boundary also releases them: the deferred pulses were accepted during the previous
// hold-off and carry the parity of the fill that this boundary is now closing, so they are owed
// for that fill and must go out before its 'done'.  Normally the guard after the previous 'done'
// has long since released them, but if the master opened and closed the next fill before the
// guard ran out (back-to-back readout triggers), they would otherwise stay held through the
// close, be counted by the master in the fill after, and the two sides would disagree by that
// many for two fills.  The master has latched the previous fill's count before it can raise the
// next 'new_fill' (its acquisition controller waits for every channel's done first).
reg  fill_parity_d = 1'b0;
wire boundary        = fill_parity ^ fill_parity_d;
wire merge_deferred  = hold_release | boundary;
wire [8:0] merged = {1'b0, pending_now} + {1'b0, pending_deferred};
assign line_quiet = (line_state == LINE_IDLE) & (pending_now == 8'd0);
always @(posedge clk) begin
  trig_refuse <= trig_backlog_full | (merged[8:0] >= 9'd240);   // the two queues are merged at the hold release, so bound their sum
  if (rst)                                                   refused_count <= 16'd0;
  else if (CS[SETUP_HOLD] && refused && refused_count != 16'hFFFF) refused_count <= refused_count + 16'd1;
end
always @(posedge clk) begin
  if (rst) begin
    pending_now      <= 8'd0;
    pending_deferred <= 8'd0;
    line_state       <= LINE_IDLE;
    line_cntr        <= 8'd0;
    line_hold_off_d  <= 1'b0;
    trigger          <= 1'b0;
  end
  else begin
    line_hold_off_d <= line_hold_off;
    fill_parity_d   <= fill_parity;
    if (merge_deferred)
      pending_now <= (merged[8] ? 8'd255 : merged[7:0]) + {7'd0, accept_now} - {7'd0, send_now};
    else if (!(accept_now && pending_now == 8'd255))
      pending_now <= pending_now + {7'd0, accept_now} - {7'd0, send_now};
    if (merge_deferred)
      pending_deferred <= {7'd0, accept_def};    // a trigger accepted in the boundary clock itself is deferred (new parity)
    else if (!(accept_def && pending_deferred == 8'd255))
      pending_deferred <= pending_deferred + {7'd0, accept_def};
    case (line_state)
      LINE_IDLE: begin
        if (send_now) begin
          trigger    <= 1'b1;
          line_cntr  <= HOLD_CYCLES - 8'd1;
          line_state <= LINE_HIGH;
        end
      end
      LINE_HIGH: begin
        if (line_cntr == 8'd0) begin
          trigger    <= 1'b0;
          line_cntr  <= GAP_CYCLES - 8'd1;
          line_state <= LINE_LOW;
        end
        else line_cntr <= line_cntr - 8'd1;
      end
      LINE_LOW: begin
        if (line_cntr == 8'd0) line_state <= LINE_IDLE;
        else                   line_cntr  <= line_cntr - 8'd1;
      end
      default: line_state <= LINE_IDLE;
    endcase
  end
end

endmodule

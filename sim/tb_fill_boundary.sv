`timescale 1ns/1ps
// Channel + master fill-boundary test for deferred self triggers.
//   channel side (adc_clk 400 MHz): self_trigger, enable_sm_selftrigc, circ_buf_to_ddr3_sm_selftrigc,
//                                   behavioural trigger FIFOs with the parity tag (as in adc_acq_top_selftrigc)
//   master side  (ttc_clk 40 MHz):  channel_triggerc_receiver (real), acq-controller timing model for new_fill
// Pulses arrive at random phases; readout boundaries at random times; every fill's master count must
// equal the number of waveforms the channel stored for that fill, and no pulse may be lost.
module tb;
reg adc_clk = 0; always #1.25 adc_clk = ~adc_clk;      // 400 MHz
reg ttc_clk = 0; always #12.5 ttc_clk = ~ttc_clk;      // 40 MHz (asynchronous phase)
reg rst = 1;

// ---------------- channel: self_trigger ----------------
reg [25:0] adcdat = 26'd0;
reg [41:0] timing_counter = 42'd0; always @(posedge adc_clk) timing_counter <= timing_counter + 1;
reg enable_triggering = 0, enable_acquisition = 0;
reg [7:0] min_sep = 8'd20; reg retrig_level = 0;
integer minsep_arg = 20, level_arg = 0;
initial begin if ($value$plusargs("minsep=%d", minsep_arg)) min_sep = minsep_arg; if ($value$plusargs("level=%d", level_arg)) retrig_level = level_arg; end
wire line_hold_off, fill_parity, line_quiet, close_forced;
wire self_trig_ready, trig_imm, trig_line; wire [41:0] timestamp;
wire trig_backlog_full; wire [15:0] refused_count; wire [7:0] pending_pulses;
self_trigger st (.clk(adc_clk), .rst(rst), .adcdat(adcdat), .timing_counter(timing_counter),
  .threshold_in(12'sd100), .polarity_in(1'b1), .sum_log2_in(3'd1), .ped_delay_in(6'd4), .ped_bypass_in(1'b1),
  .enable(enable_triggering), .line_hold_off(line_hold_off), .min_separation_in(min_sep), .retrig_level_in(retrig_level),
  .trig_backlog_full(trig_backlog_full), .fill_parity(fill_parity), .refused_count(refused_count), .pending_pulses(pending_pulses),
  .self_trig_ready(self_trig_ready), .timestamp(timestamp), .trigger_immediate(trig_imm), .trigger(trig_line), .line_quiet(line_quiet));

// ---------------- channel: enable_sm ----------------
wire cbuf_wr_en, cbuf_trig_en, cbuf_rd_en, ddr3_wr_en, trig_pulse, sm_idle, init_ddr3_addr, ext_done; wire [9:0] en_state;
wire cbuf_rd_trig_wait, ddr3_selftrig_wr_active;
reg  ddr3_wr_done = 0;
reg  new_fill_io3 = 0;      // io[3] from the master (asynchronous)
wire new_fill;              // after channel_main's 2-stage sync
sync_2stage nf_sync (.clk(adc_clk), .in(new_fill_io3), .out(new_fill));
enable_sm_selftrigc en (.adc_clk(adc_clk), .enable_triggering(enable_triggering), .enable_acquisition(enable_acquisition),
  .self_trig(trig_imm), .reset_clk_adc(rst), .cbuf_rd_trig_wait(cbuf_rd_trig_wait), .ddr3_wr_done(ddr3_wr_done), .line_quiet(line_quiet),
  .ddr3_selftrig_wr_active(ddr3_selftrig_wr_active), .initial_fill_num_wr_clkadc(1'b0), .new_fill(new_fill),
  .cbuf_wr_en(cbuf_wr_en), .cbuf_trig_en(cbuf_trig_en), .cbuf_rd_en(cbuf_rd_en), .ddr3_wr_en(ddr3_wr_en),
  .trig_pulse(trig_pulse), .adc_acq_sm_idle(sm_idle), .init_ddr3_addr(init_ddr3_addr), .ext_done(ext_done),
  .line_hold_off(line_hold_off), .fill_parity(fill_parity), .close_forced(close_forced), .enable_sm_state(en_state));
integer close_forced_count = 0; always @(posedge adc_clk) if (close_forced) close_forced_count = close_forced_count + 1;

// ---------------- channel: trigger FIFOs (behavioural, FWFT) + parity FIFO (as in adc_acq_top) ----------------
reg [15:0] addr_mem [0:1023]; reg [9:0] a_wr = 0, a_rd = 0;
wire trig_fifo_empty = (a_wr == a_rd);
wire trig_addr_rd_en;
reg [4:0] fill_parity_d = 5'd0;
always @(posedge adc_clk) fill_parity_d <= {fill_parity_d[3:0], fill_parity};
reg        trig_parity_mem [0:1023];
reg [9:0]  trig_parity_wr = 10'd0, trig_parity_rd = 10'd0;
always @(posedge adc_clk) begin
    if (rst) begin a_wr <= 0; a_rd <= 0; trig_parity_wr <= 0; trig_parity_rd <= 0; end
    else begin
        if (trig_pulse) begin addr_mem[a_wr] <= timing_counter[15:0]; a_wr <= a_wr + 1;
                              trig_parity_mem[trig_parity_wr] <= fill_parity_d[4]; trig_parity_wr <= trig_parity_wr + 1; end
        if (trig_addr_rd_en) begin a_rd <= a_rd + 1; trig_parity_rd <= trig_parity_rd + 1; end
    end
end
wire trig_fifo_parity = trig_parity_mem[trig_parity_rd];
// back-pressure flag as in adc_acq_top (threshold 960 of 1024; +backlog=N lowers it to exercise the path)
integer backlog_thr = 960; initial if ($value$plusargs("backlog=%d", backlog_thr)) ;
reg trig_backlog_full_r = 0; always @(posedge adc_clk) trig_backlog_full_r <= ((trig_parity_wr - trig_parity_rd) >= backlog_thr[9:0]);
assign trig_backlog_full = trig_backlog_full_r;

// ---------------- channel: circ_buf_to_ddr3_sm ----------------
wire [18:0] cb_state;
// bursts per waveform: 1 by default (the reader is then faster than any pulse train); +wfm_bursts=N makes
// each waveform N loops (4 clocks each) long, so that a burst of pulses backs up in the trigger FIFO
integer wfm_bursts = 1; initial if ($value$plusargs("wfm_bursts=%d", wfm_bursts)) ;
integer bursts_left = 0; reg burst_cntr_zero = 1'b1;
always @(posedge adc_clk) begin
  if (cb.NS[cb.WAVEFORM_INIT1] && !cb.CS[cb.WAVEFORM_INIT1]) bursts_left = wfm_bursts;
  if (cb.CS[cb.LOOP4]) bursts_left = bursts_left - 1;
  burst_cntr_zero <= (bursts_left <= 1);
end
wire x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16,x17,x18,x19,x20;
circ_buf_to_ddr3_sm_selftrigc cb (.adc_clk(adc_clk), .reset_clk_adc(rst), .cbuf_rd_en(cbuf_rd_en), .cbuf_trig_en(cbuf_trig_en),
  .trig_fifo_empty(trig_fifo_empty), .trig_fifo_parity(trig_fifo_parity), .fill_parity(fill_parity),
  .enable_acquisition(enable_acquisition), .burst_cntr_zero(burst_cntr_zero),
  .cbuf_rd_trig_wait(cbuf_rd_trig_wait), .burst_adr_cntr_init(x1), .init_circ_buf_rd_addr(x2), .inc_circ_buf_rd_addr(x3),
  .latch_circ_buf_dat(x4), .select_fill_hdr(x5), .select_dat(x6), .select_waveform_hdr(x7), .select_checksum(x8),
  .checksum_update(x9), .checksum_init(x10), .adc_acq_out_valid(x11), .burst_adr_cntr_en(x12), .save_start_adr(x13),
  .save_last_adr(x14), .trig_addr_rd_en(trig_addr_rd_en), .burst_cntr_init(x15), .burst_cntr_en(x16), .waveform_cntr_init(x17),
  .waveform_cntr_en(x18), .ddr3_selftrig_wr_active(ddr3_selftrig_wr_active), .fill_cntr_en(x19), .latch_fill_num(x20),
  .address_cntr_en(), .circ_to_ddr3_state(cb_state));
// DDR3 writer model: 'done' is a level, asserted ~50 clocks after the reader parks in DDR3_WRITE_WAIT (state bit 17)
// and held until the reader leaves it (as ddr3_wr_control's DONE state does)
reg [7:0] wr_done_cnt = 0;
always @(posedge adc_clk) begin
  if (!cb_state[17]) begin wr_done_cnt <= 0; ddr3_wr_done <= 0; end
  else begin if (wr_done_cnt < 60) wr_done_cnt <= wr_done_cnt + 1; ddr3_wr_done <= (wr_done_cnt >= 50); end
end

// ---------------- master side ----------------
// trigger line to the master: board delay then the receiver's own 2-stage sync (it synchronises inside? no: the
// master syncs the io line in selftriggerc_top b4 the receiver), modelled here as 2 stages on ttc_clk
reg trig_s1 = 0, trig_s2 = 0, trig_s3 = 0;
integer bdelay = 3;   // board + IO delay, ns, each direction (+bdelay=)
initial if ($value$plusargs("bdelay=%d", bdelay)) ;
wire trig_line_dly; assign #(bdelay) trig_line_dly = trig_line;
always @(posedge ttc_clk) begin trig_s1 <= trig_line_dly; trig_s2 <= trig_s1; trig_s3 <= trig_s2; end
wire trig_rx = trig_s2 & ~trig_s3;    // as selftriggerc_top: edge-detected on the TTC clock
reg new_fill_pause_triggers = 0;
wire acq_idle = sm_idle | ext_done;   // as channel_main_selftrigc 6.6.9
wire acq_idle_dly; assign #(bdelay) acq_idle_dly = acq_idle;
reg done_s1 = 0, done_s2 = 0;
always @(posedge ttc_clk) begin done_s1 <= acq_idle_dly; done_s2 <= done_s1; end
wire [23:0] trig_num; wire [19:0] selftriggers, selftriggers_latch; wire [22:0] stored_bursts; wire [1:0] rx_state; wire almost_full;
channel_triggerc_receiver rx (.clk(ttc_clk), .reset(rst), .clear_trigger_counts(1'b0), .reset_trig_num(1'b0),
  .trigger(trig_rx), .thres_ddr3_overflow(23'h7fffff), .chan_en(1'b1), .trig_num(trig_num), .selftriggers(selftriggers),
  .selftriggers_latch(selftriggers_latch), .new_fill_pause_triggers(new_fill_pause_triggers), .acq_done(done_s2),
  .burst_count_selftrig(23'd1), .stored_bursts(stored_bursts), .state(rx_state), .ddr3_almost_full(almost_full));
// new_fill_pause_triggers goes to the channel's io[3] with a small board delay
always @(new_fill_pause_triggers) new_fill_io3 <= #(bdelay) new_fill_pause_triggers;

// ---------------- bookkeeping ----------------
integer pulses_sent = 0, accepted = 0, waveforms_this_fill = 0, fills = 0, mismatches = 0;
integer master_latched [0:4095]; integer chan_fill_wf [0:4095]; integer fill_idx_master = 0, fill_idx_chan = 0;
always @(posedge adc_clk) if (st.CS[st.SETUP_HOLD]) accepted = accepted + 1;
// channel: count WAVEFORM_INIT1 entries per fill; a fill is closed when FILL_INIT1 of the next begins
always @(posedge adc_clk) begin
  if (cb.NS[cb.WAVEFORM_INIT1] && !cb.CS[cb.WAVEFORM_INIT1]) waveforms_this_fill = waveforms_this_fill + 1;
  if (cb.NS[cb.FILL_DONE1] && !cb.CS[cb.FILL_DONE1]) begin chan_fill_wf[fill_idx_chan] = waveforms_this_fill; fill_idx_chan = fill_idx_chan + 1; waveforms_this_fill = 0; end
end
// master: latch happens inside the receiver; record it when selftriggers_latch is written (new_fill_latch)
reg latch_d = 0, recording = 0;   // the receiver sees one rising edge of the (idle-high) done line at start-up; ignore latches before the first boundary
always @(posedge ttc_clk) begin latch_d <= rx.new_fill_latch; if (latch_d && recording) begin master_latched[fill_idx_master] = rx.selftriggers_latch; fill_idx_master = fill_idx_master + 1; end end

// a pulse: 6 pairs of samples at +1000 (threshold 100, pedestal bypassed)
task pulse; integer k; begin
  for (k = 0; k < 6; k = k + 1) begin @(posedge adc_clk); adcdat <= {1'b0, 12'd1000, 1'b0, 12'd1000}; end
  @(posedge adc_clk); adcdat <= 26'd0; pulses_sent = pulses_sent + 1;
end endtask
// a readout boundary as the master's acq controller produces it: new_fill_pause_triggers high for 6 ttc clocks
// +nflen=N sets the level's width in ttc clocks (6 = the real NEW_DDR3_BUFFER + TRANSITION; a long level must
// not close a second fill, a 1-clock one must not be missed)
integer nflen = 6; initial if ($value$plusargs("nflen=%d", nflen)) ;
integer boundaries = 0;
// As the master's acquisition controller: a boundary is only raised once the previous one has been answered
// with done (WAIT collects the dones before STORE_ACQ_INFO / IDLE); the next one then follows as soon as the
// readouts thread asks, which with back-to-back triggers is a few ttc clocks after the done.  +freerun drops
// the wait (not what the master does; it shows what the channel makes of boundaries during a close).
reg done_pending = 0;
always @(posedge ttc_clk) if (rx.new_fill_latch) done_pending <= 0;
integer wdone;
task boundary; begin
  recording = 1; boundaries = boundaries + 1;
  wdone = 0; while (done_pending && !$test$plusargs("freerun") && wdone < 1000000) begin @(posedge ttc_clk); wdone = wdone + 1; end
  repeat (3) @(posedge ttc_clk);   // STORE_ACQ_INFO, IDLE, NEW_DDR3_BUFFER
  @(posedge ttc_clk); new_fill_pause_triggers <= 1; done_pending <= 1; repeat (nflen) @(posedge ttc_clk); new_fill_pause_triggers <= 0;
end endtask

integer seed = 1, seed2 = 8, i, gap, fill_gap, nb;
initial begin
  if ($value$plusargs("seed=%d", seed)) seed2 = seed + 7;
  repeat (20) @(posedge adc_clk); rst <= 0;
  repeat (20) @(posedge adc_clk); enable_acquisition <= 1;
  repeat (200) @(posedge adc_clk); enable_triggering <= 1;
  wait (self_trig_ready); repeat (100) @(posedge adc_clk);
  // start the first fill from the master's point of view: a boundary with no triggers b4 it is fine
  if ($test$plusargs("pairs")) begin : pairs
    integer d, b4, got, fails, wide;
    fails = 0;
    for (d = 2; d <= 80; d = d + 1) begin
      repeat (300) @(posedge adc_clk);
      b4 = accepted;
      pulse;                                   // 6 pairs over threshold (7 clocks incl. the clear)
      repeat (d - 7 > 0 ? d - 7 : 0) @(posedge adc_clk);
      pulse;
      repeat (200) @(posedge adc_clk);
      got = accepted - b4;
      // a pair at or beyond the separation must give two; closer pairs give one or two depending on
      // whether the second excursion is still over threshold at re-arm, but never less than one
      if ((d >= min_sep && d >= 14 && got != 2) || got < 1 || got > 2) begin fails = fails + 1; $display("pair spacing %0d clocks: accepted %0d", d, got); end
    end
    // a wide pulse: 100 clocks over threshold
    repeat (300) @(posedge adc_clk); b4 = accepted;
    for (wide = 0; wide < 100; wide = wide + 1) begin @(posedge adc_clk); adcdat <= {1'b0, 12'd1000, 1'b0, 12'd1000}; end
    @(posedge adc_clk); adcdat <= 0; repeat (300) @(posedge adc_clk);
    $display("wide 100-clock pulse: accepted %0d (edge mode expects 1, level mode expects ~%0d)", accepted - b4, 100 / min_sep + 1);
    if (!retrig_level && accepted - b4 != 1) fails = fails + 1;
    if ( retrig_level && accepted - b4 < 2) fails = fails + 1;
    repeat (3000) @(posedge adc_clk);
    boundary; repeat (3000) @(posedge adc_clk);
    $display("pairs: %0d failures; master total %0d accepted %0d", fails, trig_num, accepted);
    if (fails == 0 && trig_num == accepted) $display("PASS"); else $display("FAIL");
    $finish;
  end
  else if ($test$plusargs("sweep")) begin : sweep
    // one boundary per fill; a pulse at a swept offset from the boundary (in adc clocks, negative = b4),
    // and every 3rd fill a second pulse 60 clocks after the first
    integer off;
    for (off = -80; off <= 240; off = off + 1) begin
      repeat (1500) @(posedge adc_clk);
      fork
        begin repeat (400) @(posedge adc_clk); boundary; end
        begin
          if (off < 0) repeat (400 + off) @(posedge adc_clk); else repeat (400 + off) @(posedge adc_clk);
          pulse;
          if ((off % 3) == 0) begin repeat (60) @(posedge adc_clk); pulse; end
        end
      join
    end
  end
  else begin
  fork
    begin : pulser
      for (i = 0; i < 3000; i = i + 1) begin
        if ($test$plusargs("noise")) gap = 10 + ($urandom(seed) % 10); else   // faster than the trigger line: refusals expected
        if ($test$plusargs("burst")) gap = 20 + ($urandom(seed) % 80); else
        gap = 200 + ($urandom(seed) % 400);     // pulses 0.5-1.5 us apart (dense: many land in boundaries)
        repeat (gap) @(posedge adc_clk);
        pulse;
      end
    end
    begin : readouts
      for (nb = 0; nb < 400; nb = nb + 1) begin
        fill_gap = 1500 + ($urandom(seed2) % 1500);   // boundaries every 3.75-7.5 us
        repeat (fill_gap) @(posedge adc_clk);
        boundary;
      end
    end
  join
  end
  repeat (2000) @(posedge adc_clk);
  boundary;                                   // close the last fill
  repeat (3000) @(posedge adc_clk);
  // compare fills.  The first master latch (fill 0) pairs with the first channel fill.
  for (i = 0; i < 24; i = i + 1) $display("fill %0d: master %0d  channel %0d", i, master_latched[i], chan_fill_wf[i]);
  for (i = 0; i < fill_idx_master && i < fill_idx_chan; i = i + 1)
    if (master_latched[i] != chan_fill_wf[i]) begin mismatches = mismatches + 1;
      if (mismatches < 10) $display("MISMATCH fill %0d: master counted %0d, channel stored %0d", i, master_latched[i], chan_fill_wf[i]); end
  $display("pulses sent %0d, passes through SETUP_HOLD %0d, refused %0d, master total trig_num %0d, fills master %0d channel %0d, fill mismatches %0d, pending now/def %0d/%0d, forced closes %0d",
           pulses_sent, accepted, refused_count, trig_num, fill_idx_master, fill_idx_chan, mismatches, st.pending_now, st.pending_deferred, close_forced_count);
  // every pulse is seen (accepted or refused); the master counts exactly the accepted ones; per-fill counts agree;
  // refusals happen only in the noise / low-backlog runs, and never cost a forced close
  // (in the noise run pulses closer than the separation merge, so only 'no more passes than pulses' holds there)
  $display("boundaries issued %0d, fills closed by the channel %0d", boundaries, fill_idx_chan);
  if ((pulses_sent == accepted || ($test$plusargs("noise") && accepted <= pulses_sent)) && accepted - refused_count == trig_num && mismatches == 0 && fill_idx_master == fill_idx_chan && close_forced_count == 0
      && fill_idx_chan == boundaries
      && ((refused_count != 0) == ($test$plusargs("noise") || backlog_thr < 100 || wfm_bursts > 1))) $display("PASS"); else $display("FAIL");
  $finish;
end
endmodule

`timescale 1ns/1ps
// tb_ddr3_arb.v -- DDR3 command-port arbitration between the self-trigger writer and the fill reader
// (channel 6.8.7).
//
// Real modules: ddr3_wr_control_selftrigc, ddr3_addr_control, ddr3_rd_control.
// Models:
//   adc side (400 MHz)  Poisson self-triggers; per trigger the circular-buffer reader is busy 72 clocks
//                       (5 init, 16 x 4 loop, 2 done, 1 back to TRIG_WAIT) and pushes a waveform header
//                       plus 16 data words into the 256-deep write FIFO; ddr3_selftrig_wr_active is low
//                       only in TRIG_WAIT with no trigger waiting (circ_buf_to_ddr3_sm_selftrigc.v:350-378),
//                       registered once more by enable_sm (ddr3_wr_en) and synchronised twice into ui_clk.
//   MIG UI (133 MHz)    in-order command queue of 4, one BL8 per ui clock on the data bus, a direction-change
//                       penalty of +turn clocks (turnaround plus row change), refresh 15 clocks every 1040,
//                       the 7-series PHY's periodic read (once per 1 us unless a user read went out; from the
//                       write direction it costs a turnaround each way), 16-entry write-data buffer, read
//                       latency 20 clocks.  The penalties are a model, not the MIG: +turn sets how hard it is.
//   readout             at every fill boundary the bursts written in the closing fill are read back after
//                       +rd_delay_us, drained from the read FIFO at one word per +drain ui clocks (the link).
//   end of test         triggers stop and wr_active is held high, as the fill-close states do, so the writer
//                       can finish; every pushed waveform must then be in memory.
// Arbitration:
//   +old   acq_enabled = ddr3_wr_en_sync2               (up to 6.8.6: the port follows the adc-side reader)
//   (new)  acq_enabled = wr_app_en | ddr3_wr_en_sync2   (6.8.7, ddr3_intf_selftrigc.v)
// Pass: no write-FIFO overflow, writer never in SYNC_ERR, no read-FIFO overflow, all waveforms written, every
// readout done in time.
//
//   iverilog -g2012 -o sim tb_ddr3_arb.v ../hdl/ddr3_wr_control_selftrigc.v ../hdl/ddr3_addr_control.v \
//       ../hdl/ddr3_rd_control.v
//   Results (120 kHz, 100 Hz readout, 32 ms unless noted; ~1 min each):
//   vvp sim +old                    write FIFO max 62 (102 over 250 ms): the backlog persists, no margin
//   vvp sim +old +turn=9            overflows after ~16k bursts, then SYNC_ERR -- the 6.8.6 failure
//   vvp sim +old +turn=12           overflows after ~6k bursts
//   vvp sim                         max 17 (one waveform); 250 ms: max 17
//   vvp sim +turn=20                max 25
//   vvp sim +turn=12 +rate_khz=1000 +fill_us=1000 +sim_ms=12     max 29, PASS
//   (+rate_khz=2000 +fill_us=500 fails on readout time, not on writing: 2 MHz x 272 B is more than the
//    link drain of one word per 4 clocks, i.e. the link limit, as expected)
module tb_ddr3_arb;

// ------------------------------------------------------------------ parameters (plusargs)
integer rate_khz, fill_us, sim_ms, drain, turn, rd_delay_us, old, seed, verbose, prd;
initial begin
  if (!$value$plusargs("rate_khz=%d", rate_khz))       rate_khz    = 120;
  if (!$value$plusargs("fill_us=%d", fill_us))         fill_us     = 10000;
  if (!$value$plusargs("sim_ms=%d", sim_ms))           sim_ms      = 32;
  if (!$value$plusargs("drain=%d", drain))             drain       = 4;
  if (!$value$plusargs("turn=%d", turn))               turn        = 6;
  if (!$value$plusargs("rd_delay_us=%d", rd_delay_us)) rd_delay_us = 20;
  if (!$value$plusargs("seed=%d", seed))               seed        = 1;
  old     = $test$plusargs("old");
  prd     = !$test$plusargs("noprd");
  verbose = $test$plusargs("verbose");
end

// ------------------------------------------------------------------ clocks and reset
reg adc_clk = 0; always #1.25  adc_clk = ~adc_clk;   // 400 MHz
reg ui_clk  = 0; always #3.75  ui_clk  = ~ui_clk;    // 133.33 MHz (533 MHz DDR3, 4:1)
reg rst = 1;
initial begin #200; @(posedge ui_clk) rst <= 0; end

// ------------------------------------------------------------------ write FIFO (256, FWFT, independent clocks)
localparam WF_DEPTH = 256;
reg [131:0] wf_mem [0:WF_DEPTH-1];
integer wf_wp = 0, wf_rp = 0;            // free-running counts
integer wf_max = 0, wf_overflows = 0;
wire wf_empty = (wf_wp == wf_rp);
wire [131:0] wf_dout = wf_mem[wf_rp % WF_DEPTH];
wire wf_rd_en;
always @(posedge ui_clk) if (wf_rd_en && !wf_empty) wf_rp <= wf_rp + 1;

task wf_push(input [131:0] d);
  begin
    if (wf_wp - wf_rp >= WF_DEPTH) wf_overflows = wf_overflows + 1;   // the IP drops the word
    else begin
      wf_mem[wf_wp % WF_DEPTH] = d;
      wf_wp = wf_wp + 1;
      if (wf_wp - wf_rp > wf_max) wf_max = wf_wp - wf_rp;
    end
  end
endtask

// ------------------------------------------------------------------ adc side: triggers and the circular-buffer reader
integer trig_q = 0, trig_total = 0, wfm_pushed = 0, next_trig = 0, cyc = 0;
integer busy = 0;                         // clocks left in the current waveform
reg [22:0] wfm_addr = 23'd1;
reg wr_active = 0, ddr3_wr_en = 0;
reg closing = 0;    // end of the test: a fill close (FILL_DONE.. states keep wr_active high until the writer is done)
integer mean_clk;
initial mean_clk = 0;
always @(posedge adc_clk) begin
  if (mean_clk == 0) begin mean_clk = 400000 / rate_khz; next_trig = 1000 + $dist_exponential(seed, mean_clk); end
  cyc = cyc + 1;
  if (!rst && cyc >= next_trig) begin
    trig_q = trig_q + 1; trig_total = trig_total + 1;
    next_trig = cyc + 20 + $dist_exponential(seed, (mean_clk > 20 ? mean_clk - 20 : 1)); // 50 ns minimum separation
  end
  if (busy == 0 && trig_q > 0) begin trig_q = trig_q - 1; busy = 72; end
  if (busy > 0) begin
    // header at clock 6 of the waveform, then a data word every 4 clocks
    if (busy == 67) wf_push({4'd2, 79'd0, wfm_addr, 12'd0, 14'd16});
    else if (busy < 67 && busy >= 3 && ((67 - busy) % 4) == 0) wf_push({4'd0, 128'h0});
    if (busy == 67) begin wfm_addr = wfm_addr + 23'd17; wfm_pushed = wfm_pushed + 1; end
    busy = busy - 1;
  end
  wr_active  <= (busy > 0) || (trig_q > 0) || closing;   // low only in TRIG_WAIT with the trigger FIFO empty
  ddr3_wr_en <= wr_active;                     // enable_sm_selftrigc registers it again
end

// ------------------------------------------------------------------ ui_clk side: synchroniser and arbitration
reg wr_en_s1 = 0, wr_en_s2 = 0;
always @(posedge ui_clk) begin wr_en_s1 <= ddr3_wr_en; wr_en_s2 <= wr_en_s1; end

wire wr_app_en, wr_app_rdy, rd_app_en, rd_app_rdy;
wire acq_en = old ? wr_en_s2 : (wr_app_en | wr_en_s2);

wire [26:0] app_addr; wire [2:0] app_cmd; wire app_en; wire app_rdy;
wire [25:0] ddr3_wr_addr, ddr3_rd_addr;
ddr3_addr_control u_addr (
  .acq_enabled(acq_en),
  .wr_addr(ddr3_wr_addr), .wr_app_en(wr_app_en), .wr_app_rdy(wr_app_rdy),
  .rd_addr(ddr3_rd_addr), .rd_app_en(rd_app_en), .rd_app_rdy(rd_app_rdy),
  .app_addr(app_addr), .app_cmd(app_cmd), .app_en(app_en), .app_rdy(app_rdy));

wire app_wdf_wren, app_wdf_end, app_wdf_rdy;
wire wr_sync_err, wr_done, fill_header_wr_en;
wire [151:0] fill_header_wr_dat; wire [16:0] wr_state;
wire fill_address_rd_en;
ddr3_wr_control_selftrigc u_wr (
  .clk(ui_clk), .reset(rst), .acq_enabled(1'b1),
  .ddr3_wr_fifo_dat(wf_dout), .ddr3_wr_fifo_empty(wf_empty), .ddr3_wr_fifo_rd_en(wf_rd_en),
  .app_wdf_wren(app_wdf_wren), .app_wdf_rdy(app_wdf_rdy), .app_wdf_end(app_wdf_end),
  .fill_address(23'd0), .fill_address_rd_en(fill_address_rd_en), .fill_address_fifo_empty(1'b0),
  .ddr3_wr_addr(ddr3_wr_addr), .wr_app_en(wr_app_en), .wr_app_rdy(wr_app_rdy),
  .fill_header_wr_dat(fill_header_wr_dat), .fill_header_wr_en(fill_header_wr_en),
  .ddr3_wr_sync_err(wr_sync_err), .ddr3_wr_done(wr_done),
  .enable_triggering_ddr3(1'b1), .enable_acquisition_ddr3(1'b1),
  .ddr3_wr_ctrl_state(wr_state), .acq_done(1'b0));

// ------------------------------------------------------------------ reader and read FIFO (1024, drained by the link)
reg enable_reading = 0;
reg [22:0] rd_start = 0; reg [23:0] rd_cnt = 0;
wire reading_done, rd_fifo_wr_en, rd_tlast; wire [2:0] rd_state;
wire app_rd_data_valid;
integer rf_cnt = 0, rf_max = 0, rf_div = 0;
wire rf_almost_full = (rf_cnt >= 1024 - 64);
ddr3_rd_control u_rd (
  .clk(ui_clk), .reset(rst), .acq_enabled(acq_en),
  .ddr3_rd_start_addr(rd_start), .ddr3_rd_burst_cnt(rd_cnt), .enable_reading(enable_reading),
  .reading_done(reading_done), .app_rd_data_end(app_rd_data_valid), .app_rd_data_valid(app_rd_data_valid),
  .rd_app_rdy(rd_app_rdy), .ddr3_rd_addr(ddr3_rd_addr), .rd_app_en(rd_app_en),
  .ddr3_rd_fifo_wr_en(rd_fifo_wr_en), .ddr3_rd_fifo_almost_full(rf_almost_full),
  .ddr3_rd_fifo_input_tlast(rd_tlast), .ddr3_rd_ctrl_state(rd_state));
integer rf_overflows = 0;
always @(posedge ui_clk) begin
  rf_div = (rf_div + 1) % drain;
  if (rd_fifo_wr_en) begin if (rf_cnt >= 1024) rf_overflows = rf_overflows + 1; else rf_cnt = rf_cnt + 1; end
  if (rf_div == 0 && rf_cnt > 0) rf_cnt = rf_cnt - 1;
  if (rf_cnt > rf_max) rf_max = rf_cnt;
end

// ------------------------------------------------------------------ MIG user-interface model
localparam QD = 4, LAT = 20;
reg        q_rd [0:QD-1];
integer    qn = 0, qh = 0;
integer    wdf = 0;                      // write-data buffer occupancy
integer    mbusy = 0, last_rd = 0, ref_cnt = 0;
reg [LAT-1:0] rd_pipe = 0;
assign app_rdy     = !rst && (qn < QD);
assign app_wdf_rdy = !rst && (wdf < 16);
assign app_rd_data_valid = rd_pipe[LAT-1];
integer n_wr = 0, n_rd = 0, n_turn = 0, n_prd = 0, prd_cnt = 0, rd_in_int = 0;
always @(posedge ui_clk) begin
  if (!rst) begin : mig
    integer dwdf; reg exec_rd;
    dwdf = (app_wdf_wren && app_wdf_rdy) ? 1 : 0;
    rd_pipe = {rd_pipe[LAT-2:0], 1'b0};
    if (app_en && app_rdy) begin q_rd[(qh + qn) % QD] = (app_cmd == 3'b001); qn = qn + 1; end
    ref_cnt = ref_cnt + 1;
    if (ref_cnt == 1040) begin ref_cnt = 0; mbusy = mbusy + 15; end
    // 7-series PHY periodic read (DQS tracking): one read every 1 us unless a user read went out in that
    // interval; from the write direction it costs a turnaround each way
    prd_cnt = prd_cnt + 1;
    if (prd_cnt >= 133 && prd) begin
      prd_cnt = 0;
      if (rd_in_int) rd_in_int = 0;
      else begin mbusy = mbusy + (last_rd ? 1 : 2 * turn + 1); n_prd = n_prd + 1; end
    end
    if (mbusy > 0) mbusy = mbusy - 1;
    else if (qn > 0 && !(q_rd[qh] == 0 && wdf == 0)) begin
      exec_rd = q_rd[qh];
      if (exec_rd != last_rd) begin last_rd = exec_rd; mbusy = turn; n_turn = n_turn + 1; end
      else begin
        if (exec_rd) begin rd_pipe[0] = 1'b1; n_rd = n_rd + 1; rd_in_int = 1; end
        else begin dwdf = dwdf - 1; n_wr = n_wr + 1; end
        qh = (qh + 1) % QD; qn = qn - 1;
      end
    end
    wdf = wdf + dwdf;
  end
end

// ------------------------------------------------------------------ fills and readouts
integer fill_wr_start = 0;               // n_wr at the start of the open fill
integer pend_bursts [0:63]; integer pend_n = 0, pend_h = 0;
integer readouts = 0, ro_max_us = 0; real ro_t0;
initial begin : fills
  integer t;
  #1000;
  forever begin
    #(fill_us * 1000.0);
    pend_bursts[(pend_h + pend_n) % 64] = n_wr - fill_wr_start;
    pend_n = pend_n + 1;
    fill_wr_start = n_wr;
  end
end
initial begin : readout
  #2000;
  forever begin
    wait (pend_n > 0);
    #(rd_delay_us * 1000.0);
    @(posedge ui_clk);
    rd_start <= 23'h400000; rd_cnt <= pend_bursts[pend_h];
    pend_h = (pend_h + 1) % 64; pend_n = pend_n - 1;
    ro_t0 = $realtime;
    if (rd_cnt == 0) @(posedge ui_clk);
    enable_reading <= 1;
    wait (reading_done);
    if (($realtime - ro_t0) / 1000 > ro_max_us) ro_max_us = ($realtime - ro_t0) / 1000;
    readouts = readouts + 1;
    if (verbose) $display("%0.3f ms  readout %0d: %0d bursts in %0.1f us, write FIFO max so far %0d",
                          $realtime / 1.0e6, readouts, rd_cnt, ($realtime - ro_t0) / 1000, wf_max);
    @(posedge ui_clk) enable_reading <= 0;
    repeat (8) @(posedge ui_clk);
  end
end

// ------------------------------------------------------------------ result
reg sync_err_seen = 0;
always @(posedge ui_clk) if (wr_sync_err) sync_err_seen <= 1;
initial begin : finish
  integer ok, settle;
  #(sim_ms * 1.0e6);
  // stop triggering and let the writer drain before counting
  rate_khz = 0; next_trig = 32'h7fffffff; closing = 1;
  #(50000);
  ok = (wf_overflows == 0) && !sync_err_seen && (rf_overflows == 0) &&
       (n_wr == wfm_pushed * 17) && (readouts >= sim_ms * 1000 / fill_us - 1);
  $display("%s arbitration, %0d kHz, readout every %0d us, turn %0d, drain %0d:",
           old ? "OLD" : "NEW", rate_khz == 0 ? 400000 / mean_clk : rate_khz, fill_us, turn, drain);
  $display("  triggers %0d  waveforms pushed %0d  bursts written %0d (expect %0d)  read %0d  turnarounds %0d  periodic reads %0d",
           trig_total, wfm_pushed, n_wr, wfm_pushed * 17, n_rd, n_turn, n_prd);
  $display("  write FIFO max %0d / %0d, overflows %0d, writer SYNC_ERR %0d",
           wf_max, WF_DEPTH, wf_overflows, sync_err_seen);
  $display("  readouts %0d, longest %0d us, read FIFO max %0d, overflows %0d",
           readouts, ro_max_us, rf_max, rf_overflows);
  $display("  %s", ok ? "PASS" : "FAIL");
  $finish;
end
endmodule

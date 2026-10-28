`timescale 1ns/1ps
module tb;
reg clk=0; always #4 clk=~clk; reg reset=1;
reg run_sm=0, tx_tready=1, hdr_empty=1, reading_done=0, acq_done_latch=1, accept=0;
wire running, done, tvalid, tlast, send_csn, send_cmd, send_inv, rd_en, en_rd, rd_sync, use_ddr3; wire [9:0] st; wire [22:0] addr; wire [23:0] bursts;
cc_rd_fill_sm dut(.clk(clk),.reset(reset),.run_sm(run_sm),.sm_running(running),.sm_done(done),.cc_rd_fill_state(st),
 .tx_tvalid(tvalid),.tx_tlast(tlast),.tx_tready(tx_tready),.send_csn(send_csn),.send_cmd(send_cmd),.send_inv_cmd(send_inv),
 .fill_header_fifo_empty(hdr_empty),.fill_header_fifo_rd_en(rd_en),.fill_header_fifo_out(152'h0),.fixed_ddr3_start_addr(23'd0),.en_fixed_ddr3_start_addr(1'b0),
 .ddr3_rd_start_addr(addr),.ddr3_rd_burst_cnt(bursts),.enable_reading(en_rd),.reading_done(reading_done),.reading_done_synced(rd_sync),.acq_done_latch(acq_done_latch),
 .use_ddr3_data(use_ddr3),.aurora_ddr3_accept(accept),.initial_fill_num_wr(1'b0));
// ERROR1 = state bit 2, GET_FIFO_HDR = bit 3 (per RD_FILL_STATES order)
integer saw_err=0, saw_hdr=0;
always @(posedge clk) begin if (st[2]) saw_err=1; if (st[3]) saw_hdr=1; end
initial begin
  repeat(5) @(posedge clk); reset<=0; repeat(5) @(posedge clk);
  // case 1: the command arrives 1 us before the fill header is written (first event of a run)
  run_sm<=1; repeat(125) @(posedge clk); hdr_empty<=0; repeat(10) @(posedge clk);
  $display("case 1 (header 1 us after command): ERROR1 seen=%0d GET_FIFO_HDR seen=%0d  (want 0 / 1)", saw_err, saw_hdr);
  run_sm<=0; hdr_empty<=1; repeat(20) @(posedge clk); saw_err=0; saw_hdr=0;
  // case 2: header already waiting when the command arrives
  hdr_empty<=0; repeat(5) @(posedge clk); run_sm<=1; repeat(10) @(posedge clk);
  $display("case 2 (header already waiting): ERROR1 seen=%0d GET_FIFO_HDR seen=%0d  (want 0 / 1)", saw_err, saw_hdr);
  run_sm<=0; hdr_empty<=1; repeat(20) @(posedge clk); saw_err=0; saw_hdr=0;
  // case 3: header never comes -> time-out -> ERROR1 (counter preloaded short for the test)
  force dut.acq_wait_cntr = 29'd200; run_sm<=1; @(posedge clk); release dut.acq_wait_cntr; repeat(400) @(posedge clk);
  $display("case 3 (no header, time-out): ERROR1 seen=%0d GET_FIFO_HDR seen=%0d  (want 1 / 0)", saw_err, saw_hdr);
  $finish;
end
endmodule

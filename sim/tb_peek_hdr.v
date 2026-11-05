`timescale 1ns/1ps
// cc_peek_hdr_sm (6.7.0; 6.8.0: no header is popped): the command carries the expected fill number; the reply frame is RSN,
// CC, header[31:0], [63:32], [95:64], [127:96] with tlast on the last word; a header for the
// expected, an older or a newer fill is never popped and CC bit 8 is never set (6.8.0: an older one
// was popped until then; the master now stops on any fill-number mismatch); back-pressure on tx_tready holds each word; when no header arrives
// before the bound the reply is RSN, ~CC with tlast; a command without the fill-number word too.
module tb;
reg clk=0; always #4 clk=~clk; reg reset=1;
reg run_sm=0, tx_tready=1;
reg rx_tvalid=0, rx_tlast=1; reg [31:0] rx_data=0; wire rx_tready;
wire running, done, tvalid, tlast, send_csn, send_cmd, send_inv, send_hdr, discarded, rd_en; wire [1:0] sel;
// a model of the fill-header FIFO: a queue of headers whose fill number is header[23:0]
reg [151:0] q [0:7]; integer qn=0, qh=0;
wire hdr_empty = (qn == 0);
wire [151:0] hdr = q[qh];
integer pops=0;
always @(posedge clk) if (rd_en) begin pops=pops+1; if (qn>0) begin qh<=qh+1; qn<=qn-1; end end
task push(input [23:0] fill, input [31:0] tag); begin q[qh+qn] = {24'd77, tag, 32'hC4C3C2C1, 32'hB4B3B2B1, {8'h0, fill}}; qn=qn+1; end endtask
cc_peek_hdr_sm dut(.clk(clk),.reset(reset),.run_sm(run_sm),.sm_running(running),.sm_done(done),
  .rx_tvalid(rx_tvalid),.rx_tlast(rx_tlast),.rx_data(rx_data),.rx_tready(rx_tready),
  .tx_tvalid(tvalid),.tx_tlast(tlast),.tx_tready(tx_tready),.send_csn(send_csn),.send_cmd(send_cmd),
  .send_inv_cmd(send_inv),.send_hdr_data(send_hdr),.hdr_word_sel(sel),.discarded(discarded),
  .fill_header_fifo_empty(hdr_empty),.fill_header_fill_num(hdr[23:0]),.fill_header_fifo_rd_en(rd_en));
// the TX mux of command_top
reg [31:0] csn = 32'h00001234, cmd = 32'h0000000B;
reg [31:0] tx_data;
always @(posedge clk) begin
  if (send_csn) tx_data <= csn; if (send_cmd) tx_data <= {cmd[31:9], discarded, cmd[7:0]}; if (send_inv) tx_data <= ~cmd;
  if (send_hdr) tx_data <= hdr[sel*32 +: 32];
end
// the RX side: present the fill-number word (with tlast unless told otherwise) until it is taken
always @(posedge clk) if (rx_tvalid && rx_tready) rx_tvalid <= 0;
task send_fill(input [23:0] f, input last); begin rx_data <= {8'h0, f}; rx_tlast <= last; rx_tvalid <= 1; end endtask
// capture the frame
reg [31:0] frame [0:15]; integer n=0, fails=0, lastw=-1;
always @(posedge clk) if (tvalid && tx_tready) begin frame[n] <= tx_data; if (tlast) lastw <= n; n <= n+1; end
task check(input c, input [8*64-1:0] what); begin if (!c) begin fails=fails+1; $display("  FAIL: %0s", what); end end endtask
task run_cmd(input [23:0] f); begin send_fill(f, 1); run_sm<=1; wait(done); @(posedge clk); run_sm<=0; repeat(5) @(posedge clk); end endtask
initial begin
  repeat(5) @(posedge clk); reset<=0; repeat(5) @(posedge clk);
  // 1: header for the expected fill waiting, reader always ready
  push(24'd10, 32'hD4D3D2D1); n=0; lastw=-1; run_cmd(24'd10);
  check(n==6 && lastw==5, "case 1: six words, tlast on the sixth");
  check(frame[0]==csn && frame[1]==cmd && frame[2]==32'h0000000A && frame[3]==32'hB4B3B2B1 && frame[4]==32'hC4C3C2C1 && frame[5]==32'hD4D3D2D1, "case 1: RSN, CC, header words 0..3");
  check(qn==1 && pops==0, "case 1: FIFO not popped");
  // 2: random back-pressure
  n=0; lastw=-1; fork begin run_cmd(24'd10); end begin repeat(60) begin @(posedge clk); tx_tready <= $random; end tx_tready <= 1; end join
  check(n==6 && lastw==5 && frame[2]==32'h0000000A && frame[5]==32'hD4D3D2D1 && frame[1]==cmd, "case 2: same frame under back-pressure");
  // 3: FIFO empty, header arrives 1 us after the command
  qn=0; n=0; lastw=-1; fork begin run_cmd(24'd11); end begin repeat(125) @(posedge clk); push(24'd11, 32'hEEEEEEEE); end join
  check(n==6 && lastw==5 && frame[1]==cmd && frame[5]==32'hEEEEEEEE, "case 3: waits for a late header");
  // 4: no header: time-out (bound shortened) -> RSN, ~CC, tlast
  qn=0; n=0; lastw=-1; send_fill(24'd12, 1); force dut.wait_cntr = 21'd200; run_sm<=1; @(posedge clk); release dut.wait_cntr;
  wait(done); @(posedge clk); run_sm<=0; repeat(5) @(posedge clk);
  check(n==2 && lastw==1 && frame[0]==csn && frame[1]==~cmd, "case 4: time-out reply is RSN, ~CC with tlast");
  // 5: after the time-out, a normal command works again (flags cleared)
  push(24'd12, 32'hD4D3D2D1); n=0; lastw=-1; run_cmd(24'd12);
  check(n==6 && frame[1]==cmd, "case 5: error flag cleared for the next command");
  // 6: an older header in front of the expected one: returned as is (the master stops on it), not popped
  qn=0; push(24'd13, 32'h13131313); push(24'd15, 32'h15151515); pops=0; n=0; lastw=-1; run_cmd(24'd15);
  check(n==6 && frame[1]==cmd && frame[2]==32'h0000000D && frame[5]==32'h13131313, "case 6: older header returned, CC bit 8 clear");
  check(pops==0 && qn==2, "case 6: nothing popped");
  // 7: asked again, the same header
  n=0; run_cmd(24'd15); check(frame[1]==cmd && frame[2]==32'h0000000D && pops==0, "case 7: still the same header, still not popped");
  // 8: a NEWER header is returned as is, not popped
  qn=0; push(24'd20, 32'h20202020); pops=0; n=0; run_cmd(24'd16);
  check(n==6 && frame[1]==cmd && frame[2]==32'h00000014 && pops==0, "case 8: newer header returned, not popped");
  // 9: wrap-around: an older header across the wrap is returned as is too
  qn=0; push(24'hFFFFF0, 32'h01010101); push(24'h000005, 32'h05050505); pops=0; n=0; run_cmd(24'h000005);
  check(frame[1]==cmd && frame[5]==32'h01010101 && pops==0, "case 9: older across the wrap returned, not popped");
  // 10: malformed command (fill word without tlast): ~CC
  qn=0; push(24'd30, 32'h30303030); n=0; lastw=-1; send_fill(24'd30, 0); run_sm<=1; wait(done); @(posedge clk); run_sm<=0; repeat(5) @(posedge clk);
  check(n==2 && frame[1]==~cmd && qn==1, "case 10: malformed command answered with ~CC, nothing popped");
  $display("%0d failure(s)", fails); if (fails==0) $display("PASS"); else $display("FAIL"); $finish;
end
initial begin #2000000; $display("TIMEOUT"); $finish; end
endmodule

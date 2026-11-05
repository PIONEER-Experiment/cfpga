`timescale 1ns/1ps
// chan_error_selftrigc: sets from the three clock domains become sticky bits readable in clk125
// (register 0x37) and a {lost data, fault, cause code} word in adc_clk (fill header); the clear
// from clk125 empties all three domains; the full reset too.
module tb;
reg adc_clk=0; always #1.25 adc_clk=~adc_clk;   // 400 MHz
reg ddr_clk=0; always #2.5  ddr_clk=~ddr_clk;   // 200 MHz
reg clk125=0;  always #4    clk125=~clk125;
reg rst_adc=1, clear=0; reg [4:0] sa=0; reg [2:0] sd=0; reg [1:0] s1=0;
wire [15:0] bits; wire any; wire [6:0] word;
chan_error_selftrigc dut(.adc_clk(adc_clk),.ddr3_clk(ddr_clk),.clk125(clk125),.full_reset_adc(rst_adc),.clear_125(clear),.set_adc(sa),.set_ddr3(sd),.set_125(s1),.err_bits_125(bits),.err_any_125(any),.err_word_adc(word));
integer fails=0;
task check(input c, input [8*64-1:0] what); begin if (!c) begin fails=fails+1; $display("  FAIL: %0s", what); end end endtask
task settle; begin repeat(40) @(posedge clk125); end endtask
initial begin
  repeat(10) @(posedge adc_clk); rst_adc<=0; settle;
  check(bits == 0 && !any && word == 7'b0011111, "clean: no bits, code 31");
  // adc-domain set, bit 1 (fill close forced): loss
  @(posedge adc_clk); sa <= 5'b00010; @(posedge adc_clk); sa <= 0; settle;
  check(bits == 16'h0002 && any && word == 7'b1000001, "adc set bit 1 -> loss, code 1");
  // ddr3-domain set, bit 6 (SYNC_ERR): fault; the code stays the lowest set bit
  @(posedge ddr_clk); sd <= 3'b010; @(posedge ddr_clk); sd <= 0; settle;
  check(bits == 16'h0042 && word == 7'b1100001, "ddr3 set bit 6 -> fault too, code still 1");
  // clk125 set, bit 9 (read stalled)
  @(posedge clk125); s1 <= 2'b10; @(posedge clk125); s1 <= 0; settle;
  check(bits == 16'h0242, "clk125 set bit 9");
  // clear from clk125 empties all three domains
  @(posedge clk125); clear <= 1; @(posedge clk125); clear <= 0; settle; settle;
  check(bits == 0 && !any && word == 7'b0011111, "clear empties every domain");
  // a set while the clear level is still stretched is lost (documented); one afterwards is kept
  @(posedge clk125); s1 <= 2'b01; @(posedge clk125); s1 <= 0; settle;
  check(bits == 16'h0100 && word == 7'b0101000, "clk125 set bit 8 -> fault, code 8");
  // full reset clears
  @(posedge adc_clk); rst_adc <= 1; repeat(20) @(posedge adc_clk); rst_adc <= 0; settle;
  check(bits == 0, "full reset clears");
  $display("%0d failure(s)", fails); if (fails == 0) $display("PASS"); else $display("FAIL"); $finish;
end
endmodule

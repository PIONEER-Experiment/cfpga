// Channel error latch for the self-triggering image (6.6.10).
//
// Principle: the channel never loses data quietly.  Every condition under which a trigger or a
// waveform is dropped ("data loss"), or under which the DDR3 / readout path failed ("fault"), sets
// a sticky bit here.  The bits are reported in every fill header (word 4 bits [13:7] =
// {lost data, fault, cause code}), so the master learns of them at the next readout and raises
// the TTS line, and they are readable in register 0x37, which also takes the snapshot of the
// channel's state machines (0x2A-0x2C, 0x2E, 0x30, 0x33, 0x38, 0x39) at the first error.  A
// write to 0x37, or the full reset, clears them.
//
// Bit map (also in read_status.py):
//    0  trigger refused: the trigger FIFOs were nearly full (self_trigger)                   loss
//    1  fill closed by the time-out, not by the reader (enable_sm_selftrigc)                 loss
//    2  a trigger of the wrong fill parity was discarded (circ_buf_to_ddr3_sm)               loss
//    3  DDR3 write FIFO was full when a word was written to it                               loss
//    4  trigger-address FIFO was full when a trigger was written to it                       loss
//    5  fill-header FIFO was full when a header was written to it                            loss
//    6  DDR3 writer lost sync with the data stream (SYNC_ERR)                                fault
//    7  DDR3 read FIFO overflowed (the Aurora side was not taking words)                     fault
//    8  the read-fill command waited out its bound for the fill header                       fault
//    9  the DDR3 read stalled (8 ms without a word accepted)                                 fault
//   15:10 unused
// The sources live in three clock domains; each domain keeps its own sticky bits and the sets
// are brought together through synchronisers (levels, so no pulse is lost).

module chan_error_selftrigc (
  input  wire        adc_clk,
  input  wire        ddr3_clk,
  input  wire        clk125,
  input  wire        full_reset_adc,     // adc_acq_full_reset (adc_clk)
  input  wire        clear_125,          // one clk125 pulse: software clear (write to 0x37)
  // sets, in their own domains
  input  wire [4:0]  set_adc,            // bits 4..0
  input  wire [2:0]  set_ddr3,           // bits 7..5
  input  wire [1:0]  set_125,            // bits 9..8
  // outputs
  output wire [15:0] err_bits_125,       // all bits, clk125 (register 0x37)
  output wire        err_any_125,
  output wire [6:0]  err_word_adc        // {lost data, fault, cause code[4:0]} for the fill header, adc_clk
);

  localparam [15:0] LOSS_MASK  = 16'h003F;
  localparam [15:0] FAULT_MASK = 16'h03C0;

  // the clear: a clk125 pulse stretched to a level long enough for the slower domains to see it
  // (31 clk125 = 250 ns: a dozen periods of the slowest domain; an error arriving inside that window
  //  after a software clear would be dropped, which is accepted)
  reg [4:0] clear_stretch = 5'd0;
  always @(posedge clk125) begin
    if (clear_125) clear_stretch <= 5'd31;
    else if (clear_stretch != 5'd0) clear_stretch <= clear_stretch - 5'd1;
  end
  wire clear_level = (clear_stretch != 5'd0);
  (* ASYNC_REG = "TRUE" *) reg [1:0] clear_adc_s = 2'd0, clear_ddr_s = 2'd0;
  always @(posedge adc_clk)  clear_adc_s <= {clear_adc_s[0], clear_level};
  always @(posedge ddr3_clk) clear_ddr_s <= {clear_ddr_s[0], clear_level};
  (* ASYNC_REG = "TRUE" *) reg [1:0] rst_ddr_s = 2'd0, rst_125_s = 2'd0;   // the full reset, for the other domains
  always @(posedge ddr3_clk) rst_ddr_s <= {rst_ddr_s[0], full_reset_adc};
  always @(posedge clk125)   rst_125_s <= {rst_125_s[0], full_reset_adc};

  // sticky bits per domain
  reg [4:0] q_adc = 5'd0;  reg [2:0] q_ddr = 3'd0;  reg [1:0] q_125 = 2'd0;
  always @(posedge adc_clk)  if (full_reset_adc || clear_adc_s[1]) q_adc <= 5'd0; else q_adc <= q_adc | set_adc;
  always @(posedge ddr3_clk) if (rst_ddr_s[1]   || clear_ddr_s[1]) q_ddr <= 3'd0; else q_ddr <= q_ddr | set_ddr3;
  always @(posedge clk125)   if (rst_125_s[1]   || clear_level)    q_125 <= 2'd0; else q_125 <= q_125 | set_125;

  // bring them together in clk125 (register) and in adc_clk (fill header)
  (* ASYNC_REG = "TRUE" *) reg [4:0] adc_to_125_s1 = 5'd0, adc_to_125_s2 = 5'd0;
  (* ASYNC_REG = "TRUE" *) reg [2:0] ddr_to_125_s1 = 3'd0, ddr_to_125_s2 = 3'd0;
  always @(posedge clk125) begin
    adc_to_125_s1 <= q_adc; adc_to_125_s2 <= adc_to_125_s1;
    ddr_to_125_s1 <= q_ddr; ddr_to_125_s2 <= ddr_to_125_s1;
  end
  assign err_bits_125 = {6'd0, q_125, ddr_to_125_s2, adc_to_125_s2};
  assign err_any_125  = |err_bits_125;

  (* ASYNC_REG = "TRUE" *) reg [2:0] ddr_to_adc_s1 = 3'd0, ddr_to_adc_s2 = 3'd0;
  (* ASYNC_REG = "TRUE" *) reg [1:0] c125_to_adc_s1 = 2'd0, c125_to_adc_s2 = 2'd0;
  always @(posedge adc_clk) begin
    ddr_to_adc_s1  <= q_ddr; ddr_to_adc_s2  <= ddr_to_adc_s1;
    c125_to_adc_s1 <= q_125; c125_to_adc_s2 <= c125_to_adc_s1;
  end
  wire [15:0] bits_adc = {6'd0, c125_to_adc_s2, ddr_to_adc_s2, q_adc};
  reg  [4:0]  code_adc = 5'd31;
  reg         loss_adc = 1'b0, fault_adc = 1'b0;
  integer i;
  always @(posedge adc_clk) begin
    loss_adc  <= |(bits_adc & LOSS_MASK);
    fault_adc <= |(bits_adc & FAULT_MASK);
    code_adc  <= 5'd31;
    for (i = 15; i >= 0; i = i - 1) if (bits_adc[i]) code_adc <= i[4:0];   // the lowest set bit wins
  end
  assign err_word_adc = {loss_adc, fault_adc, code_adc};

endmodule

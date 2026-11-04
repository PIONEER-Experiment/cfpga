// Process the CC_PEEK_HDR command (6.7.0): return the fill header at the head of the fill-header
// FIFO without popping it and without touching the DDR3.
//
// The master uses this before it reads the fills of an event: the AMC13 event header has to carry
// the total event size, and the exact waveform count of every channel's fill is in its fill header.
// Peeking the five headers first, computing the size, and only then issuing the five read-fill
// commands removes the trigger-line pulse count from the correctness path (it becomes a monitor).
//
// Command frame: CSN, CC, then the fill number the master expects (tlast).  The header at the head of
// the FIFO is returned as it is, whatever its fill number (6.8.0).  A fill-number mismatch means the
// channel and the master disagree about which event this is, and the master stops the readout on it
// (terminal, the run is aborted) rather than risk building an event from uncorrelated fills.  Until
// 6.8.0 a header for an OLDER fill was popped and discarded here (and CC bit 8 set) so that the
// readout could carry on; the expected fill number is still taken from the command frame (the
// frame format is unchanged) but no longer changes what is done, and the DISCARD / SETTLE states
// below are unreachable (synthesis removes them).
//
// Reply frame: RSN, CC (bit 8 always 0 since 6.8.0) or ~CC on error, then the four 32-bit header words
// exactly as the read-fill data stream carries them (word 1 = header[31:0] ... word 4 =
// header[127:96]), tlast on the last.  If no header is waiting,
// wait up to the same bound as the read-fill command (16.8 ms: the fill-closing states are bounded
// at 10.5 ms); after that reply with ~CC and tlast, and the master skips the channel for the event.
// A command frame with no fill-number word (tlast on the CC) is answered with ~CC too.
//
// The style follows cc_rd_reg_sm: two states per transmitted word, 'tvalid' held until 'tready'.

module cc_peek_hdr_sm (
    input clk,                          // local clock
    input reset,                        // active-high
    input run_sm,                       // run this state machine
    output sm_running,                  // we are running
    output sm_done,                     // we are finished
    // RX: the fill-number word of the command
    input  rx_tvalid,
    input  rx_tlast,
    input  [31:0] rx_data,
    output rx_tready,
    // TX: the reply
    output tx_tvalid,                   // the data we are presenting is valid
    output tx_tlast,                    // this is the final word in the frame
    input  tx_tready,                   // the TX FIFO has accepted the data
    output send_csn,                    // mux: the CSN
    output send_cmd,                    // mux: the CC (with bit 8 = a stale header was discarded)
    output send_inv_cmd,                // mux: the inverse CC (error)
    output send_hdr_data,               // mux: a fill-header word
    output [1:0] hdr_word_sel,          // ... which one (0 = header[31:0] ... 3 = header[127:96])
    output discarded,                   // CC bit 8: always 0 since 6.8.0 (was: a stale header was discarded)
    // the fill-header FIFO
    input  fill_header_fifo_empty,      // a header is available when not asserted
    input  [23:0] fill_header_fill_num, // ... its fill number (header[23:0])
    output reg fill_header_fifo_rd_en   // never pops since 6.8.0 (kept for the port list; was: pop a stale header)
);

    parameter [3:0]
        IDLE        = 4'd0,
        WAIT_FILL   = 4'd1,   // the expected fill number
        WAIT_HDR    = 4'd2,
        DISCARD     = 4'd3,   // one clock: pop a stale header
        SETTLE      = 4'd4,   // a few clocks for the FIFO output to show the next header
        ECHO_CSN1   = 4'd5,
        ECHO_CSN2   = 4'd6,
        ECHO_CC1    = 4'd7,
        ECHO_CC2    = 4'd8,
        XMIT_HDR1   = 4'd9,   // one pass per word, 'word' counts 0..3
        XMIT_HDR2   = 4'd10,
        DONE        = 4'd11;

    reg [11:0] CS, NS;
    reg [2:0]  settle_cntr;
    wire       settled = (settle_cntr == 3'd0);
    reg [1:0]  word;
    reg        error_found;
    reg        discarded_r;
    reg [23:0] expected;

    // 6.8.0: an older header is no longer discarded (see the top of the file)
    wire        hdr_older = 1'b0;

    // bound on the wait for the header: 2^21 clocks = 16.8 ms, as cc_rd_fill_sm
    reg  [20:0] wait_cntr;
    wire        wait_timeout = (wait_cntr == 21'd0);
    always @(posedge clk) begin
        if (!run_sm)                            wait_cntr <= 21'h1FFFFF;
        else if (CS[WAIT_HDR] && !wait_timeout) wait_cntr <= wait_cntr - 21'd1;
    end

    always @(posedge clk) begin
        if (!run_sm) begin
            CS <= 12'b0;
            CS[IDLE] <= 1'b1;
        end
        else CS <= NS;
    end

    always @(CS or rx_tvalid or rx_tlast or fill_header_fifo_empty or hdr_older or wait_timeout or tx_tready or error_found or word or settled) begin
        NS = 12'b0;
        case (1'b1) // synopsys full_case parallel_case
            CS[IDLE]:      NS[WAIT_FILL] = 1'b1;
            CS[WAIT_FILL]: begin
                if (rx_tvalid && rx_tlast)  NS[WAIT_HDR]  = 1'b1;
                else if (rx_tvalid)         NS[ECHO_CSN1] = 1'b1;   // malformed: answer with ~CC
                else                        NS[WAIT_FILL] = 1'b1;
            end
            CS[WAIT_HDR]: begin
                if (hdr_older)                                   NS[DISCARD]   = 1'b1;
                else if (!fill_header_fifo_empty || wait_timeout) NS[ECHO_CSN1] = 1'b1;
                else                                             NS[WAIT_HDR]  = 1'b1;
            end
            CS[DISCARD]:   NS[SETTLE] = 1'b1;
            CS[SETTLE]: begin
                if (settled) NS[WAIT_HDR] = 1'b1;
                else         NS[SETTLE]   = 1'b1;
            end
            CS[ECHO_CSN1]: NS[ECHO_CSN2] = 1'b1;
            CS[ECHO_CSN2]: begin
                if (tx_tready) NS[ECHO_CC1]  = 1'b1;
                else           NS[ECHO_CSN2] = 1'b1;
            end
            CS[ECHO_CC1]:  NS[ECHO_CC2] = 1'b1;
            CS[ECHO_CC2]: begin
                if (!tx_tready)      NS[ECHO_CC2]  = 1'b1;
                else if (error_found) NS[DONE]     = 1'b1;
                else                 NS[XMIT_HDR1] = 1'b1;
            end
            CS[XMIT_HDR1]: NS[XMIT_HDR2] = 1'b1;
            CS[XMIT_HDR2]: begin
                if (!tx_tready)       NS[XMIT_HDR2] = 1'b1;
                else if (word == 2'd3) NS[DONE]     = 1'b1;
                else                  NS[XMIT_HDR1] = 1'b1;
            end
            CS[DONE]:      NS[IDLE] = 1'b1;
        endcase
    end

    // the expected fill number, the error and discard flags
    always @(posedge clk) begin
        if (CS[WAIT_FILL] && rx_tvalid) expected <= rx_data[23:0];
        if (CS[IDLE]) begin
            error_found <= 1'b0;
            discarded_r <= 1'b0;
        end
        else begin
            if (CS[WAIT_FILL] && rx_tvalid && !rx_tlast)                  error_found <= 1'b1;
            if (CS[WAIT_HDR] && fill_header_fifo_empty && wait_timeout)   error_found <= 1'b1;
            if (CS[DISCARD])                                              discarded_r <= 1'b1;
        end
        // the pop: registered, one clock, while DISCARD is the next state (so that it lines up with
        // the state, as in cc_rd_fill_sm)
        fill_header_fifo_rd_en <= NS[DISCARD];
        // the FIFO (independent clocks, first-word-fall-through) shows the next word a clock or two
        // after the pop; wait longer than that before looking at it again, so that one stale header
        // can never be popped twice
        if (CS[SETTLE]) settle_cntr <= settle_cntr - 3'd1;
        else            settle_cntr <= 3'd7;
    end
    // which header word is being sent
    always @(posedge clk) begin
        if (CS[IDLE] || CS[ECHO_CC2])            word <= 2'd0;
        else if (CS[XMIT_HDR2] && tx_tready)     word <= word + 2'd1;
    end

    assign rx_tready     = CS[WAIT_FILL];
    assign sm_running    = !CS[IDLE];
    assign sm_done       = CS[DONE];
    assign send_csn      = CS[ECHO_CSN1] || CS[ECHO_CSN2];
    assign send_cmd      = !error_found && (CS[ECHO_CC1] || CS[ECHO_CC2]);
    assign send_inv_cmd  =  error_found && (CS[ECHO_CC1] || CS[ECHO_CC2]);
    assign send_hdr_data = CS[XMIT_HDR1] || CS[XMIT_HDR2];
    assign hdr_word_sel  = word;
    assign discarded     = discarded_r;
    assign tx_tvalid     = CS[ECHO_CSN2] || CS[ECHO_CC2] || CS[XMIT_HDR2];
    assign tx_tlast      = (!error_found && CS[XMIT_HDR2] && word == 2'd3) || (error_found && CS[ECHO_CC2]);

endmodule

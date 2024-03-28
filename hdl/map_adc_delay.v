// map_adc_delay.v
// 
// Map out the ADC data tap delay value for a channel.
// Leave the comments containing "synopsys" in your HDL code.

module map_adc_delay (
    input  clk,                       // adc clock
    input  tap_clk,                   // clock used for tap delays in selectio interface
    input  reset,                     // active-high
    input  run_sm,                    // run this state machine
    output sm_running,                // we are running
    output sm_done,                   // we are finished
    output reg error_found,           // error status
    input  [25:0] packed_adc_dat,     // ADC data
    input  [ 4:0] current_delay,      // current data delay
    input  [ 4:0] ipbus_delay,        // data delay setting from IPbus
    output reg [ 4:0] data_delay,     // data delay to set
    output delay_reset,               // reset to SelectIO Wizard
    output reg [31:0] data_integrity
);

    // synchronize run_sm
    wire run_sm_int;
    sync_2stage run_sm_sync (
        .clk(tap_clk),
        .in(run_sm),
        .out(run_sm_int)
    );

    // synchronize current_delay
    wire [4:0] current_delay_int;
    sync_2stage #(
        .WIDTH(5)
    ) current_delay_sync (
        .clk(tap_clk),
        .in(current_delay),
        .out(current_delay_int)
    );


    // Connect a pipeline of registers to hold all data for 1 burst.
    //   Register #0 will have the oldest data
    //   Register #3 will have the newest data
    reg [23:0] adc_dat_reg0, adc_dat_reg1, adc_dat_reg2, adc_dat_reg3;
    always @ (posedge clk) begin
        adc_dat_reg3[23:0] <= {packed_adc_dat[25:14], packed_adc_dat[12:1]};
        adc_dat_reg2[23:0] <= adc_dat_reg3[23:0];
        adc_dat_reg1[23:0] <= adc_dat_reg2[23:0];
        adc_dat_reg0[23:0] <= adc_dat_reg1[23:0];
    end

    wire latch_xor_dat_tapclk, latch_xor_dat_adcclk;
    sync_2stage latch_xor_inst (
        .clk(clk),
        .in(latch_xor_dat_tapclk),
        .out(latch_xor_dat_adcclk)
     );

    // internal signals
    reg [7:0] count;
    wire [23:0] adc_dat_xor_in;
    wire [23:0] adc_dat_xor;
    assign adc_dat_xor_in[23:0] = adc_dat_reg0[23:0] ^ adc_dat_reg1[23:0] ^ adc_dat_reg2[23:0] ^ adc_dat_reg3[23:0];

    reg [23:0] adc_dat_latched;
    always @ (posedge clk) begin
        // assert 'sm_running' whenever we are not in the IDLE or the DONE state
        if ( latch_xor_dat_adcclk )
            adc_dat_latched[23:0] <= adc_dat_latched[23:0];
        else
            adc_dat_latched[23:0] <= adc_dat_xor_in[23:0];
    end

    reg xor_dat_rcv;  // handshake to acknowledge that
    wire xor_dat_rdy; // data ready for use in the tap clock (dest) domain
    wire dest_rcv;
    xpm_cdc_handshake #(
        .DEST_EXT_HSK(0),
        .WIDTH(24)           // DECIMAL; range: 1-1024
    ) adc_xor_handshake_inst (
        .dest_out(adc_dat_xor),     // WIDTH-bit output: Input bus (src_in) synchronized to destination clock domain.
                                    // This output is registered.
        
        .dest_req(xor_dat_rdy),     // 1-bit output: Assertion of this signal indicates that new dest_out data has been
                                    // received and is ready to be used or captured by the destination logic. When
                                    // DEST_EXT_HSK = 1, this signal will deassert once the source handshake
                                    // acknowledges that the destination clock domain has received the transferred data.
                                    // When DEST_EXT_HSK = 0, this signal asserts for one clock period when dest_out bus
                                    // is valid. This output is registered.
        
        .src_rcv(dest_rcv),          // 1-bit output: Acknowledgement from destination logic that src_in has been
                                     // received. This signal will be deasserted once destination handshake has fully
                                     // completed, thus completing a full data transfer. This output is registered.
        
//        .dest_ack(dest_ack),       // 1-bit input: optional; required when DEST_EXT_HSK = 1
        .dest_clk(tap_clk),          // 1-bit input: Destination clock.
        .src_clk(clk),               // 1-bit input: Source clock.
        .src_in(adc_dat_latched),    // WIDTH-bit input: Input bus that will be synchronized to the destination clock
                                     // domain.
        
        .src_send(latch_xor_dat_adcclk) // 1-bit input: Assertion of this signal allows the src_in bus to be synchronized to
                                        // the destination clock domain. This signal should only be asserted when src_rcv is
                                        // deasserted, indicating that the previous data transfer is complete. This signal
                                        // should only be deasserted once src_rcv is asserted, acknowledging that the src_in
                                        // has been received by the destination logic.
        
    );

// End of xpm_cdc_handshake_inst instantiation
//    // connect a fifo that bridges the adc and tap_delay clock domains
//    wire xor_fifo_empty;    // an xor value is available when not asserted
//    reg xor_rd_enable;
//    adc_mapping_fifo xor_fifo (
//      .rst(reset),                 // input wire rst
//      .wr_clk(clk),                // input wire wr_clkm (adc DDR clock at 400 MHz)
//      .rd_clk(tap_clk),            // input wire rd_clk (aurora tap
//      .din(adc_dat_xor_in),        // input wire [23 : 0] din
//      .wr_en(xor_wr_enable_pulse), // input wire wr_en
//      .rd_en(xor_rd_enable),       // input wire rd_en
//      .dout(adc_dat_xor),          // output wire [23 : 0] dout
//      .full(),                     // output wire full -- not used
//      .empty(xor_fifo_empty)       // output wire empty
//    );

    
    // Declare the symbolic names for states for the state machine.
    // Simplified one-hot encoding (each constant is an index into an array of bits)
    parameter [3:0]
        IDLE           = 4'd0,
        RESET_IO       = 4'd1,
        CHECK_DELAY    = 4'd2,
        PAUSE          = 4'd3,
        LATCH_XOR      = 4'd4,
        SAVE_ADC_DATA  = 4'd5,
        INC_DELAY      = 4'd6,
        RESTORE_DELAY1 = 4'd7,
        RESTORE_DELAY2 = 4'd8,
        ERROR          = 4'd9,
        DONE           = 4'd10;

    // Declare current state and next state variables
    reg [10:0] /* synopsys enum STATE_TYPE */ CS;
    reg [10:0] /* synopsys enum STATE_TYPE */ NS;
    //synopsys state_vector CS

 
    // sequential always block for state transitions (use non-blocking [<=] assignments)
    // Reset the SM whenever we are not enabled.
    always @ (posedge tap_clk) begin
        if (!run_sm_int) begin
            CS <= 12'b0;       // set all state bits to 0
            CS[IDLE] <= 1'b1; // set IDLE state bit to 1
        end
        else CS <= NS;        // set state bits to next state
    end

    // combinational always block to determine next state (use blocking [=] assignments) 
    always @ (CS or count or current_delay_int or data_delay or error_found or xor_dat_rdy ) begin
        NS = 12'b0; // default all bits to zero; will overrride one bit

        case (1'b1) //synopsys full_case parallel_case

            // We will be in the IDLE state whenever cc_map_delay_sm does not enable us.
            // Once enabled, immediately start working.
            CS[IDLE] : begin
                NS[RESET_IO] = 1'b1;
            end

            // Reset the SelectIO Wizard for it to take the new tap delay.
            CS[RESET_IO] : begin
                if (count[7:0] > 8'd40)
                    // Timed out
                    NS[ERROR] = 1'b1;
                else if (current_delay_int[4:0] == data_delay[4:0])
                    // Move on
                    NS[CHECK_DELAY] = 1'b1;
                else
                    // Wait here until the tap delay has been updated
                    NS[RESET_IO] = 1'b1;
            end

            CS[CHECK_DELAY] : begin
                NS[PAUSE] = 1'b1;
            end

            // Pause here before looking at the data.
            // This ensures that 'adc_dat_xor' is based on new ADC samples.
            CS[PAUSE] : begin
                if (count[7:0] > 8'd12)
                    NS[LATCH_XOR] = 1'b1;
                else
                    NS[PAUSE] = 1'b1;
            end

            // push the test pattern data onto the FIFO.
            CS[LATCH_XOR] : begin
                // wait until we are sure the data has appeared for reading in the FIFO
                if ( xor_dat_rdy )
                   // grab the data
                   NS[SAVE_ADC_DATA] = 1'b1;
                else
                   // keep waiting here
                  NS[LATCH_XOR] = 1'b1;
            end

            // Record the test pattern data.
            CS[SAVE_ADC_DATA] : begin
                if (data_delay[4:0] == 5'd31)
                    NS[RESTORE_DELAY1] = 1'b1;
                else
                    NS[INC_DELAY] = 1'b1;
            end

            // Increment the tap delay.
            CS[INC_DELAY] : begin
                NS[RESET_IO] = 1'b1;
            end

            // Restore the original tap delay.
            CS[RESTORE_DELAY1] : begin
                NS[RESTORE_DELAY2] = 1'b1;
            end

            // Restore the original tap delay.
            CS[RESTORE_DELAY2] : begin
                if (current_delay_int[4:0] == data_delay[4:0])
                    NS[DONE] = 1'b1;
                else
                    NS[RESTORE_DELAY2] = 1'b1;
            end

            CS[ERROR] : begin
                NS[DONE] = 1'b1;
            end

            // We enter the DONE state whenever we have finished the procedure.
            // We stay here until diabled.
            CS[DONE] : begin
                NS[DONE] = 1'b1;
            end

        endcase
    end // combinational always block to determine next state


    // set the error status
    always @ (posedge tap_clk) begin
        if (CS[IDLE] == 1'b1)
            error_found <= 1'b0;
        else if (CS[ERROR] == 1'b1)
            error_found <= 1'b1;
        else
            error_found <= error_found;
    end

    // set the counter
    always @ (posedge tap_clk) begin
        if (CS[IDLE] == 1'b1 || CS[CHECK_DELAY] == 1'b1)
            count[7:0] <= 8'h00;
        else if (CS[RESET_IO] == 1'b1 || CS[PAUSE] == 1'b1)
            count[7:0] <= count[7:0] + 1;
        else
            count[7:0] <= count[7:0];
    end

    // set the tap delay
    always @ (posedge tap_clk) begin
        if (CS[IDLE] == 1'b1)
            data_delay[4:0] <= 5'd0;
        else if (CS[INC_DELAY] == 1'b1)
            data_delay[4:0] <= data_delay[4:0] + 1;
        else if (CS[RESTORE_DELAY1] == 1'b1)
            data_delay[4:0] <= ipbus_delay[4:0];
        else
            data_delay[4:0] <= data_delay[4:0];
    end

    // store the test pattern validity
    always @ (posedge tap_clk) begin
        if (CS[IDLE] == 1'b1) begin
            data_integrity[31:0] <= 32'd0;
        end
        else if (CS[SAVE_ADC_DATA] == 1'b1) begin
            if (adc_dat_xor[23:0] == 24'd0)
                // valid test pattern
                data_integrity[31-data_delay] <= 1'b0;
            else
                // invalid test pattern
                data_integrity[31-data_delay] <= 1'b1;
        end
        else begin
            data_integrity[31:0] <= data_integrity[31:0];
        end
    end

    // let the xpm_cdc_handshake know that input data is ready
    assign latch_xor_dat_tapclk = NS[LATCH_XOR] == 1'b1;

    assign sm_running = !(CS[IDLE] == 1'b1 || CS[DONE] == 1'b1);

    // assert 'sm_done' whenever we are in the DONE state
    assign sm_done = (CS[DONE] == 1'b1);

    // assert 'delay_reset' whenever we are in the RESET_IO state
    assign delay_reset = (CS[RESET_IO] == 1'b1 || CS[RESTORE_DELAY2] == 1'b1);

endmodule

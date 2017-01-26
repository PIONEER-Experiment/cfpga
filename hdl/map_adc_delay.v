// map_adc_delay.v
// 
// Map out the ADC data tap delay value for a channel.
// Leave the comments containing "synopsys" in your HDL code.

module map_adc_delay (
    input  clk,                       // adc clock
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
        .clk(clk),
        .in(run_sm),
        .out(run_sm_int)
    );

    // synchronize current_delay
    wire [4:0] current_delay_int;
    sync_2stage #(
        .WIDTH(5)
    ) current_delay_sync (
        .clk(clk),
        .in(current_delay),
        .out(current_delay_int)
    );


    // Connect a pipeline of registers to hold all data for 1 burst.
    //   Register #0 will have the oldest data
    //   Register #7 will have the newest data
    reg [23:0] adc_dat_reg0, adc_dat_reg1, adc_dat_reg2, adc_dat_reg3;
    reg [23:0] adc_dat_reg4, adc_dat_reg5, adc_dat_reg6, adc_dat_reg7;
    always @ (posedge clk) begin
        adc_dat_reg7[23:0] <= {packed_adc_dat[25:14], packed_adc_dat[12:1]};
        adc_dat_reg6[23:0] <= adc_dat_reg7[23:0];
        adc_dat_reg5[23:0] <= adc_dat_reg6[23:0];
        adc_dat_reg4[23:0] <= adc_dat_reg5[23:0];
        adc_dat_reg3[23:0] <= adc_dat_reg4[23:0];
        adc_dat_reg2[23:0] <= adc_dat_reg3[23:0];
        adc_dat_reg1[23:0] <= adc_dat_reg2[23:0];
        adc_dat_reg0[23:0] <= adc_dat_reg1[23:0];
    end

    // internal signals
    reg [7:0] count;
    wire [23:0] adc_dat_xor;
    assign adc_dat_xor[23:0] = adc_dat_reg0[23:0] ^ adc_dat_reg1[23:0] ^ adc_dat_reg2[23:0] ^ adc_dat_reg3[23:0] ^
                               adc_dat_reg4[23:0] ^ adc_dat_reg5[23:0] ^ adc_dat_reg6[23:0] ^ adc_dat_reg7[23:0];


    // Declare the symbolic names for states for the state machine.
    // Simplified one-hot encoding (each constant is an index into an array of bits)
    parameter [3:0]
        IDLE           = 4'd0,
        RESET_IO       = 4'd1,
        CHECK_DELAY    = 4'd2,
        PAUSE          = 4'd3,
        SAVE_ADC_DATA  = 4'd4,
        INC_DELAY      = 4'd5,
        RESTORE_DELAY1 = 4'd6,
        RESTORE_DELAY2 = 4'd7,
        ERROR          = 4'd8,
        DONE           = 4'd9;

    // Declare current state and next state variables
    reg [9:0] /* synopsys enum STATE_TYPE */ CS;
    reg [9:0] /* synopsys enum STATE_TYPE */ NS;
    //synopsys state_vector CS

 
    // sequential always block for state transitions (use non-blocking [<=] assignments)
    // Reset the SM whenever we are not enabled.
    always @ (posedge clk) begin
        if (!run_sm_int) begin
            CS <= 10'b0;       // set all state bits to 0
            CS[IDLE] <= 1'b1; // set IDLE state bit to 1
        end
        else CS <= NS;        // set state bits to next state
    end

    // combinational always block to determine next state (use blocking [=] assignments) 
    always @ (CS or count or current_delay_int or data_delay or error_found) begin
        NS = 10'b0; // default all bits to zero; will overrride one bit

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
                    NS[SAVE_ADC_DATA] = 1'b1;
                else
                    NS[PAUSE] = 1'b1;
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
    always @ (posedge clk) begin
        if (CS[IDLE] == 1'b1)
            error_found <= 1'b0;
        else if (CS[ERROR] == 1'b1)
            error_found <= 1'b1;
        else
            error_found <= error_found;
    end

    // set the counter
    always @ (posedge clk) begin
        if (CS[IDLE] == 1'b1 || CS[CHECK_DELAY] == 1'b1)
            count[7:0] <= 8'h00;
        else if (CS[RESET_IO] == 1'b1 || CS[PAUSE] == 1'b1)
            count[7:0] <= count[7:0] + 1;
        else
            count[7:0] <= count[7:0];
    end

    // set the tap delay
    always @ (posedge clk) begin
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
    always @ (posedge clk) begin
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

    // assert 'sm_running' whenever we are not in the IDLE or the DONE state
    assign sm_running = !(CS[IDLE] == 1'b1 || CS[DONE] == 1'b1);

    // assert 'sm_done' whenever we are in the DONE state
    assign sm_done = (CS[DONE] == 1'b1);

    // assert 'delay_reset' whenever we are in the RESET_IO state
    assign delay_reset = (CS[RESET_IO] == 1'b1 || CS[RESTORE_DELAY2] == 1'b1);

endmodule

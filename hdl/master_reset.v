// master reset interpreter
//
// Asserts 'short_reset' if 'rst_from_master' is less than 100-ns wide;
// otherwise, 'long_reset' is asserted.

module master_reset (
    input  clk,             // sampling clock
    input  rst,             // logic reset
    input  rst_from_master, // reset from master
    output short_reset,     // active-high reset output, for short duration
    output long_reset       // active-high reset output, for long duration
);

    parameter [3:0]
        IDLE  = 4'd0,
        MON0  = 4'd1,
        MON1  = 4'd2,
        MON2  = 4'd3,
        MON3  = 4'd4,
        SRST1 = 4'd5,
        SRST2 = 4'd6,
        WAIT  = 4'd7,
        LRST1 = 4'd8,
        LRST2 = 4'd9;

    reg [9:0] CS;
    reg [9:0] NS;


    // sequential always block for state transitions (use non-blocking [<=] assignments)
    // Reset the sm whenever we get to the end of a frame
    always @ (posedge clk) begin
        if (rst) begin
            CS <= 10'b0;      // set all state bits to 0
            CS[IDLE] <= 1'b1; // set IDLE state bit to 1
        end
        else CS <= NS;        // set state bits to next state
    end

    // combinational always block to determine next state (use blocking [=] assignments)
    always @ (CS or rst_from_master) begin
        NS = 10'b0; // default all bits to zero; will override one bit

        case (1'b1)

            CS[IDLE]: begin
                // reset detected
                if (rst_from_master)
                    NS[MON0] = 1'b1;
                else
                    NS[IDLE] = 1'b1;
            end

            CS[MON0]: begin
                // check if spurious
                if (rst_from_master)
                    NS[MON1] = 1'b1;
                else
                    NS[IDLE] = 1'b1;
            end

            CS[MON1]: begin
                NS[MON2] = 1'b1;
            end

            CS[MON2]: begin
                NS[MON3] = 1'b1;
            end

            CS[MON3]: begin
                if (rst_from_master)
                    // long reset action
                    NS[WAIT] = 1'b1;
                else
                    // short reset action
                    NS[SRST1] = 1'b1;
            end

            CS[SRST1]: begin
                NS[SRST2] = 1'b1;
            end

            CS[SRST2]: begin
                NS[IDLE] = 1'b1;
            end

            CS[WAIT]: begin
                // wait for reset to go low before asserting full reset
                if (~rst_from_master)
                    NS[LRST1] = 1'b1;
                else
                    NS[WAIT] = 1'b1;
            end

            CS[LRST1]: begin
                NS[LRST2] = 1'b1;
            end

            CS[LRST2]: begin
                NS[IDLE] = 1'b1;
            end

        endcase
    end // combinational always block to determine next state


    // static assignments
    assign short_reset = CS[SRST1] | CS[SRST2]; // 40-ns wide
    assign long_reset  = CS[LRST1] | CS[LRST2]; // 40-ns wide

endmodule

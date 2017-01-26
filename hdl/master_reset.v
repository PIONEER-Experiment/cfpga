// master reset interpreter

module master_reset (
    input  clk,             // sampling clock
    input  rst,             // logic reset
    input  rst_from_master, // reset from master
    output short_reset,     // active-high reset output, for short duration
    output long_reset       // active-high reset output, for long duration
);

    parameter [2:0]
        IDLE = 3'd0,
        MON0 = 3'd1,
        MON1 = 3'd2,
        MON2 = 3'd3,
        MON3 = 3'd4,
        SRST = 3'd5,
        WAIT = 3'd6,
        LRST = 3'd7;

    reg [7:0] CS;
    reg [7:0] NS;


    // sequential always block for state transitions (use non-blocking [<=] assignments)
    // Reset the sm whenever we get to the end of a frame
    always @ (posedge clk) begin
        if (rst) begin
            CS <= 8'b0;       // set all state bits to 0
            CS[IDLE] <= 1'b1; // set IDLE state bit to 1
        end
        else CS <= NS;        // set state bits to next state
    end

    // combinational always block to determine next state (use blocking [=] assignments)
    always @ (CS or rst_from_master) begin
        NS = 8'b0; // default all bits to zero; will overrride one bit

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
                    NS[SRST] = 1'b1;
            end

            CS[SRST]: begin
                NS[IDLE] = 1'b1;
            end

            CS[WAIT]: begin
                // wait for reset to go low before asserting full reset
                if (~rst_from_master)
                    NS[LRST] = 1'b1;
                else
                    NS[WAIT] = 1'b1;
            end

            CS[LRST]: begin
                NS[IDLE] = 1'b1;
            end

        endcase
    end // combinational always block to determine next state


    // static assignments
    assign short_reset = CS[SRST];
    assign long_reset  = CS[LRST];

endmodule

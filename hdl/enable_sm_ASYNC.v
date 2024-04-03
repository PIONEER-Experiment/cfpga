`timescale 1ns / 10ps

module enable_sm_ASYNC (
    // inputs
    input adc_clk,
    input ext_enable0,          // external 'enable' for triggers, and fill type
    input ext_enable1,          // external 'enable' for triggers, and fill type
    input ext_trig,             // external trigger to start collecting data
    input reset_clk50,          // synchronously negated reset all of the acquisition logic
    input reset_clk_adc,        // reset everything related to ADC acquisition and storage -- now just reset_clk50 synced to adc_clk
    input cbuf_rd_trig_wait,    // waiting for another trigger or the negation of 'cbuf_rd_en'
    input ddr3_wr_done,         // asserted when the 'ddr3_wr_control' is in the DONE state
    // outputs
    output reg cbuf_wr_en,      // writing into the circ buf by the ADC is enabled, must extend past final trigger
    output reg cbuf_trig_en,    // triggering of new waveforms is enabled
    output reg cbuf_rd_en,      // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
    output reg ddr3_wr_en,      // writing of triggered events to memory is enabled
    output reg [1:0] fill_type, // level of the two 'ext_enable' bits
    output reg trig_pulse,      // a trigger passed while the system is enabled for new triggers
    output reg adc_acq_sm_idle, // ADC acquisition state machine is idle (used for front panel LED status)
    output reg ext_done         // external output indicating acquisition is done

);

///////////////////////////////////////////////////////////////////////////////////////////////////
// Sync the two 'ext_enable' inputs to the ADC clock domain. OR them together.
(* ASYNC_REG = "TRUE" *) reg enable_sync1, enable_sync2;
always @(posedge adc_clk) begin
    enable_sync1 <= #1 ext_enable0 | ext_enable1;
    enable_sync2 <= #1 enable_sync1;
end
 
// synchronize 'ddr3_wr_done'
(* ASYNC_REG = "TRUE" *) reg ddr3_wr_done_sync1, ddr3_wr_done_sync2;
always @ (posedge adc_clk) begin
    ddr3_wr_done_sync1 <= #1 ddr3_wr_done;
    ddr3_wr_done_sync2 <= #1 ddr3_wr_done_sync1;
end

// synchronize 'ext_trig' and create a pulse when it is asserted
(* ASYNC_REG = "TRUE" *) reg trig_sync1, trig_sync2, trig_sync3, trig_sync4, trig_sync5;
always @ (posedge adc_clk) begin
    trig_sync1 <= #1 ext_trig;
    trig_sync2 <= #1 trig_sync1;
    trig_sync3 <= #1 trig_sync2;
    trig_sync4 <= #1 trig_sync3;
    trig_sync5 <= #1 trig_sync4;
    // assert 'trig_pulse' when 'ext_trig' has gotten to the fourth register, but not the fifth
    // pass triggers only during the TRIG_ENABLED state
    trig_pulse <= #1 ((trig_sync4 & ~trig_sync5) && cbuf_trig_en);
end

// // synchronize the 'reset_clk50' signal to the 'adc_clk'
// reg reset_sync1, reset_sync2;
// always @ (posedge adc_clk) begin
//     reset_sync1 <= #1 reset_clk50;
//     reset_sync2 <= #1 reset_sync1;
// end
// assign reset_clk_adc = reset_sync2;

///////////////////////////////////////////////////////////////////////////////////////////////////
// Create a down-counter that will extend the assertion time of 'ext_done'
reg [5:0] pulse_cntr;
reg init_pulse_cntr;
wire pulse_cntr_zero;
// set a flag when the counter is equal to zero
assign pulse_cntr_zero = (pulse_cntr[5:0] == 0) ? 1'b1 : 1'b0;
always @(posedge adc_clk) begin
    if (reset_clk_adc)
        // reset counter
        pulse_cntr[5:0] <= #1 6'b0;
    else if (init_pulse_cntr)
        pulse_cntr[5:0] <= #1 6'd30;    // hold for master FPGA to see, 30 = 81 nsec
    else if (pulse_cntr_zero)
        // if zero then hold there
        pulse_cntr[5:0] <= #1 6'b0;
    else
        // decrement the counter
        pulse_cntr[5:0] <= #1 pulse_cntr[5:0] - 1;
end  

///////////////////////////////////////////////////////////////////////////////////////////////////
//  Leave the comments containing "synopsys" in your HDL code.
// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [3:0]
    IDLE            = 4'd0,
    FILL_WAIT       = 4'd1,
    FILL_START      = 4'd2,
    TRIG_ENABLED    = 4'd3,
    CBUF_RD_ENABLED = 4'd4,
    CBUF_RD_DONE    = 4'd5,
    DDR3_DONE_WAIT  = 4'd6,
    DONE1           = 4'd7,
    DONE2           = 4'd8;
   
// Declare current state and next state variables
reg [8:0] /* synopsys enum STATE_TYPE */ CS;
reg [8:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge adc_clk) begin
    if (reset_clk_adc) begin
        CS <= #1 {9{1'b0}}; // set all state bits to 0
        CS[IDLE] <= #1 1'b1; // set IDLE state bit to 1
    end
    else
        CS <= #1 NS;         // set state bits to next state
end

// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or enable_sync2 or cbuf_rd_trig_wait or ddr3_wr_done_sync2 or pulse_cntr_zero) begin
    NS = {9{1'b0}}; // default all bits to zero; will overrride one bit

    case (1'b1) // synopsys full_case parallel_case

        // Stay in the IDLE state whenever we are not enabled.
        CS[IDLE]: begin
            // all reset signals have been negated, so go wait for the start of a new fill
            NS[FILL_WAIT] = 1'b1;
        end

       // Stay in FILL_WAIT until at least one of the ENABLE signals from the master
       // has been asserted.
        CS[FILL_WAIT]: begin
            if (enable_sync2)
                // a fill is starting, go latch the fill type
                NS[FILL_START] = 1'b1;
             else
                // wait here
                NS[FILL_WAIT] = 1'b1;
        end

        // Stay in the FILL_START state for one clock period.
        CS[FILL_START]: begin
            //  go enable both the ADC and the DDR3
            NS[TRIG_ENABLED] = 1'b1;
        end

       // Triggers are accepted during TRIG_ENABLED. Stay in TRIG_ENABLED until both of the
       // ENABLE signals from the master have been negated. This signals the end of possible
       // new acquisitions for the fill. Go to CBUF_RD_ENABLED to finish writing any triggered
       // acquisitions to the DDR3 and write the final fill_header.
        CS[TRIG_ENABLED]: begin
            if (!enable_sync2)
                // a fill is ending, so disable the ADC but leave the DDR3 asserted.
                NS[CBUF_RD_ENABLED] = 1'b1;
             else
                // fill is still active, so stay here
                NS[TRIG_ENABLED] = 1'b1;
        end


       // Stay in CBUF_RD_ENABLED until the 'cbuf_rd_trig_wait' signal from the circular buf
       // reader has been asserted. This signals that all of the data for the final trigger
       // has been sent to the DDR3
        CS[CBUF_RD_ENABLED]: begin
            if (cbuf_rd_trig_wait)
                // The final event has been processed.
                NS[CBUF_RD_DONE] = 1'b1;
             else
                // still working on events, so stay here
                NS[CBUF_RD_ENABLED] = 1'b1;
        end

        // When we have sent the final event to the DDR3, we need to send the checksum and the
        // fill header. 
        CS[CBUF_RD_DONE]: begin
                NS[DDR3_DONE_WAIT] = 1'b1;
        end

       // Stay in DDR3_DONE_WAIT until the DONE signals from the DDR3
       // has been asserted. This signals that all of the data is in the DDR3
        CS[DDR3_DONE_WAIT]: begin
            if (ddr3_wr_done_sync2)
                // everything is in memory.
                NS[DONE1] = 1'b1;
             else
                // memory writing is still active, so stay here
                NS[DDR3_DONE_WAIT] = 1'b1;
        end

        // when we are done, we need to assert the ext_done for at least 40 nsec.
        // A counter will be used to determine the assertion time.
        // Initialize the counter here. 
        CS[DONE1]: begin
                NS[DONE2] = 1'b1;
        end

        // Stay in DONE2 until the pulse duration counter is zero.
        CS[DONE2]: begin
            if (pulse_cntr_zero)
                NS[IDLE] = 1'b1;
            else
                NS[DONE2] = 1'b1;
        end
    endcase
end // combinational always block to determine next state


// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
reg latch_fill_type;
always @ (posedge adc_clk) begin
    // defaults
    cbuf_wr_en             <= #1 1'b0;        // writing into the circ buf by the ADC is enabled, must extend past final trigger
    cbuf_trig_en           <= #1 1'b0;        // triggering of new waveforms is enabled
    cbuf_rd_en             <= #1 1'b0;        // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
    ddr3_wr_en             <= #1 1'b0;        // writing of triggered events to memory is enabled
    ext_done               <= #1 1'b0;        // total acquisition is done, data is stored in DDR3
    init_pulse_cntr        <= #1 1'b0;        // initialize the pulse duration counter
    latch_fill_type        <= #1 1'b0;        // copy level of the two 'ext_enable' bits into the 'fill_type'
    adc_acq_sm_idle        <= #1 1'b0;        // ADC acquisition state machine is idle (used for front panel LED status)
    
    // next states
    if (NS[IDLE]) begin
        adc_acq_sm_idle        <= #1 1'b1;
    end
    
    if (NS[FILL_WAIT]) begin
        adc_acq_sm_idle     <= #1 1'b1;
    end

    if (NS[FILL_START]) begin
        latch_fill_type        <= #1 1'b1;        // copy level of the two 'ext_enable' bits into the 'fill_type'
    end

    if (NS[TRIG_ENABLED]) begin
        cbuf_wr_en           <= #1 1'b1;        // writing into the circ buf by the ADC is enabled, must extend past final trigger
        cbuf_trig_en         <= #1 1'b1;        // triggering of new waveforms is enabled
        cbuf_rd_en           <= #1 1'b1;        // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
        ddr3_wr_en           <= #1 1'b1;        // writing of triggered events to memory is enabled
     end

    if (NS[CBUF_RD_ENABLED]) begin
        cbuf_wr_en           <= #1 1'b1;        // writing into the circ buf by the ADC is enabled, must extend past final trigger
        cbuf_rd_en           <= #1 1'b1;        // moving data from the circ buf to the DDR3 FIFO is enabled, checksum and fill header go when first negated
        ddr3_wr_en           <= #1 1'b1;        // writing of triggered events to memory is enabled
    end

    if (NS[CBUF_RD_DONE]) begin
        ddr3_wr_en           <= #1 1'b1;        // writing of triggered events to memory is enabled
    end

    if (NS[DDR3_DONE_WAIT]) begin
        ddr3_wr_en           <= #1 1'b1;        // writing of triggered events to memory is enabled
    end

    if (NS[DONE1]) begin
        init_pulse_cntr      <= #1 1'b1;        // initialize the pulse duration counter
    end

    if (NS[DONE2]) begin
        ext_done    <= #1 1'b1;     // total acquisition is done, data is stored in DDR3
    end

 
end

// After we have been enabled, latch the value of the two 'acq_enable' signals in the 'fill_type'
// register. The fill type does not currently do anything in ASYNC mode, other than getting inserted
// the fill header. 
always @(posedge adc_clk) begin
    if (latch_fill_type) begin
        fill_type[1] <= #1 ext_enable1;
        fill_type[0] <= #1 ext_enable0;
    end
end

endmodule

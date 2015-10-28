`timescale 1ns / 1ps

/////////////////////////////////////////////////////////////
// Connect the module that manages writing data to the memory

module ddr3_wr_control (
    // User interface clock and reset   
    input clk,                            // DDR3 domain user clock
    input reset,
    input acq_enabled,                    // input, writing is enabled
    // Connections to the FIFO from the ADC
    input [127:0] ddr3_wr_fifo_dat,       // input, next 'write' data from the ADC FIFO
    input ddr3_wr_fifo_empty,             // input, data is available when this is not asserted
    output ddr3_wr_fifo_rd_en,            // output, use and remove the data on the FIFO head
    // 'write' ports to memory
    output  app_wdf_wren,                 // output, request to perform a 'write' 
    input app_wdf_rdy,                    // input, memory can accept data
    output  app_wdf_end,                  // output, last data cycle
    // 'write' ports to address controller
    output [25:0] ddr3_wr_addr,           // output, next 'write' address
    output  wr_app_en,                    // output, request to perform a 'write' 
    input wr_app_rdy,                     // input, increment the 'write' address
    input [22:0] fixed_ddr3_start_addr,
    input en_fixed_ddr3_start_addr,
    // 'write' ports to the fill_header_fifo
    output [127:0] fill_header_wr_dat,    // header data
    output reg fill_header_wr_en,         // store header in FIFO
    // synchronization error flag
    output reg ddr3_wr_sync_err,
    // status flag back to the ADC acquisition machine
    output reg ddr3_wr_done,              // asserted when the 'ddr3_wr_control' is in the DONE state
    input acq_done                        // asserted when the 'adc_acq_sm' is in the DONE state

);

// synchronize 'acq_done'
reg acq_done_sync1, acq_done_sync2;
always @ (posedge clk) begin
    acq_done_sync1 <= acq_done;
    acq_done_sync2 <= acq_done_sync1;
end

// define equivalent statement for data and address acceptance
assign address_accept   = (wr_app_en & wr_app_rdy);         // we presented an address and it was accepted
assign data_accept      = (app_wdf_wren & app_wdf_rdy);     // we presented data and it was accepted
wire address_allow; // allow attempts to write an address
 
// Create a register to hold the header for future writing to the fill-header FIFO
reg [127:0] fill_header_wr_dat_reg;
reg latch_header;   // will be asserted by the state machine
always @ (posedge clk) begin
    if (reset) fill_header_wr_dat_reg <= 128'b0;
    else if (latch_header) fill_header_wr_dat_reg[127:0] <= ddr3_wr_fifo_dat[127:0];
end
assign fill_header_wr_dat[127:0] = fill_header_wr_dat_reg[127:0];

// Create an address generator
// Initialize it from the 'start_address' in the header
// Increment it whenever we the address is accepted ( we get a 'wr_app_rdy' while asserting 'wr_app_en') 
reg [22:0] address_gen;
reg init_address_gen;   // will be asserted by the state machine
always @ (posedge clk) begin
    if (reset) address_gen[22:0] <= 23'b0;
    else if (init_address_gen && en_fixed_ddr3_start_addr) address_gen[22:0] <= fixed_ddr3_start_addr[22:0];
    else if (init_address_gen && ~en_fixed_ddr3_start_addr) address_gen[22:0] <= ddr3_wr_fifo_dat[57:35];
    else if (address_accept) address_gen[22:0] <= address_gen[22:0] + 1;
end
assign ddr3_wr_addr[25:0] = {address_gen[22:0], 3'b0};

// Create an address counter
// Initialize it from the 'burst_cnt' in the header
// Decrement it whenever an address is accepted. This happens when
// we are asserting 'wr_app_en' and receiving 'wr_app_rdy'.
reg [23:0] address_cntr;
reg init_address_cntr;   // will be asserted by the state machine
reg adjust_address_cntr; // add 2 to account for header and checksum
wire address_cntr_zero;  // the counter is at zero
always @ (posedge clk) begin
    if (reset) address_cntr[23:0] <= 24'b0;
    else if (init_address_cntr) address_cntr[23:0] <= ddr3_wr_fifo_dat[87:64];
    else if (adjust_address_cntr) address_cntr[23:0] <= address_cntr[23:0] + 2;
    else if (address_cntr_zero) address_cntr[23:0] <= 24'b0; 
    else if (address_accept) address_cntr[23:0] <= address_cntr[23:0] - 1;
end
// create a flag that gets set when the address counter is down to zero
assign address_cntr_zero = (address_cntr[23:0] == 24'd0) ? 1'b1 : 1'b0;

// Create a burst counter
// Initialize it from the header
// Decrement it whenever we get a successful write. This happens when
// we are asserting 'wdf_wren' and receiving 'wdf_rdy'.
reg [23:0] burst_cntr;
reg init_burst_cntr;   // will be asserted by the state machine
reg adjust_burst_cntr; // add 2 to account for header and checksum
wire burst_cntr_zero;  // the counter is at zero
always @ (posedge clk) begin
    if (reset) burst_cntr[23:0] <= 24'b0;
    else if (init_burst_cntr) burst_cntr[23:0] <= ddr3_wr_fifo_dat[87:64];
    else if (adjust_burst_cntr) burst_cntr[23:0] <= burst_cntr[23:0] + 2;
    else if (burst_cntr_zero) burst_cntr[23:0] <= 24'b0; 
    else if (data_accept) burst_cntr[23:0] <= burst_cntr[23:0] - 1;
end
// create a flag that gets set when the burst counter is down to zero
assign burst_cntr_zero = (burst_cntr[23:0] == 24'b0) ? 1'b1 : 1'b0;

// Create a counter that will control when addresses are sent to the DDR3 interface.
// Since addresses come from a counter, we always have addresses available. However, when we
// send an address, we must send the data within 2 clock periods.
// With this throttle, we will never send an address until after we have sent the data
// destined for that address.
reg [4:0] address_control;
always @ (posedge clk) begin
    // set to zero when reset
    if (reset) address_control <= 0;
    // increment when data is accepted and an address is not accepted
    else if (data_accept && !address_accept) address_control <= address_control + 1;
    // decrement when address is accepted and data is not accepted
    else if (!data_accept && address_accept) address_control <= address_control - 1;
    // don't change if both are accepted or if neither is accepted
    else address_control <= address_control;
end
// attempts to write addresses are only allowed when the counter is not zero
assign address_allow = ~(address_control == 0);

// 
//  Leave the comments containing "synopsys" in your HDL code.
 
// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [3:0]
    IDLE        = 4'd0,
    TST_HDR_TAG = 4'd1,
    SYNC_ERR    = 4'd2,
    INIT        = 4'd3,
    ADJ_CNT     = 4'd4,
    WRITE       = 4'd5,
    WRITE_HDR   = 4'd6,
    DONE        = 4'd7;
    
// Declare current state and next state variables
reg [7:0] /* synopsys enum STATE_TYPE */ CS;
reg [7:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
    if (reset || !acq_enabled) begin
        CS <= 7'b0;             // set all state bits to 0
        CS[IDLE] <= 1'b1;       // set IDLE state bit to 1
    end
    else
        CS <= NS;           // set state bits to next state
end

// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or ddr3_wr_fifo_empty or ddr3_wr_fifo_dat or burst_cntr_zero or address_cntr_zero or acq_done_sync2)     begin
    NS = 7'b0;                  // default all bits to zero; will overrride one bit

    case (1'b1) //synopsys full_case parallel_case

        // Stay in the IDLE state until we see that the fifo is not empty.
        // Since the FIFO runs in first-word fall-through mode, if the fifo
        // in not empty, then the data will be vaild
        CS[IDLE]: begin
            if (ddr3_wr_fifo_empty)
                    // stay here if there is no data
                    NS[IDLE] = 1'b1;
            else
                    NS[TST_HDR_TAG] = 1'b1;
        end

        // Stay in TST_HDR_TAG state for one period.
        // If the 2 MSBs of the data are a valid header tag (2'b01), then proceed.
        // If not, then we are out of sync and need to flag an error 
        CS[TST_HDR_TAG]: begin
            if (ddr3_wr_fifo_dat[127:126] == 2'b01)
                // we have a valid header
                NS[INIT] = 1'b1;
            else
                // we are not synchronized. Go raise an error condition
                NS[SYNC_ERR] = 1'b1;
        end

        // Stay in SYNC_ERR state until the state machine is reset.
        // Raise the 'error' flag
        CS[SYNC_ERR]: begin
               NS[SYNC_ERR] = 1'b1;
        end

        // Stay in INIT state for one period.
        // Initialize the address and data counters. Store a copy of the header
        // for writing to the fill header fifo
        CS[INIT]: begin
                NS[ADJ_CNT] = 1'b1;
        end

        // Stay in ADJ_CNT state for one period.
        // Make necessary adjustments to the address and burst counters to account for
        // how we determine when we are done 
        CS[ADJ_CNT]: begin
                NS[WRITE] = 1'b1;
        end

        // Stay in WRITE state until all of the data has been written to memory.
        CS[WRITE]: begin
            if (burst_cntr_zero && address_cntr_zero)
                // we have written the requested number of addresses and bursts
                NS[WRITE_HDR] = 1'b1;
            else
                // More addresses or data to write, stay here
                NS[WRITE] = 1'b1;
        end

        // Stay in WRITE_HDR state for one period.
        // Write the original header to the fill_header_fifo
        CS[WRITE_HDR]: begin
               NS[DONE] = 1'b1;
        end        
        
        // Stay in DONE state until acquisition is finished
        // Write the original header to the fill_header_fifo
        CS[DONE]: begin
            if (acq_done_sync2)
               NS[IDLE] = 1'b1;
            else
                NS[DONE] = 1'b1;
        end


    endcase
end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
    // defaults
        ddr3_wr_done        <= 1'b0;
        latch_header        <= 1'b0;
        init_address_gen    <= 1'b0;
        init_address_cntr   <= 1'b0;
        init_burst_cntr     <= 1'b0;
        adjust_burst_cntr   <= 1'b0;
        adjust_address_cntr <= 1'b0;
        ddr3_wr_sync_err    <= 1'b0;
        fill_header_wr_en   <= 1'b0;

    // next states
    if (NS[IDLE]) begin
    end
    
    if (NS[TST_HDR_TAG]) begin
        // latch the header data for use later
        latch_header        <= 1'b1;
    end

    if (NS[INIT]) begin
        // initialize the address counter from the header
        init_address_gen    <= 1'b1;
        // initialize the address counter from the header
        init_address_cntr   <= 1'b1;
        // initialize the burst counter from the header
        init_burst_cntr     <= 1'b1;
    end
 
    if (NS[ADJ_CNT]) begin
        // increment the address counter to adjust for the checksum
        adjust_address_cntr <= 1'b1;
        // increment the burst counter to adjust for the checksum
        adjust_burst_cntr   <= 1'b1;
    end

    if (NS[WRITE]) begin
    end

    if (NS[SYNC_ERR]) begin
        // assert an error flag
        ddr3_wr_sync_err    <= 1'b1;
    end

    if (NS[WRITE_HDR]) begin
        // write the header to the FIFO
        fill_header_wr_en   <= 1'b1;
    end

    if (NS[DONE]) begin
        ddr3_wr_done        <= 1'b1;
    end    


end

// indicate that we want to supply an address if data has already been accepted
assign wr_app_en = CS[WRITE] && address_allow && !address_cntr_zero;

// indicate that we want to supply data if it is available 
assign app_wdf_wren = CS[WRITE] && !ddr3_wr_fifo_empty && !burst_cntr_zero; // was: ~burst_cntr_zero;
assign app_wdf_end = CS[WRITE] && !ddr3_wr_fifo_empty && !burst_cntr_zero;  // was: ~burst_cntr_zero;

// if the current data was accepted then bring the next FIFO data to the front 
assign ddr3_wr_fifo_rd_en   = CS[WRITE] && data_accept && !burst_cntr_zero;

endmodule

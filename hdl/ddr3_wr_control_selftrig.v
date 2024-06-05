`timescale 1ns / 1ps

/////////////////////////////////////////////////////////////
// Connect the module that manages writing data to the memory

module ddr3_wr_control_selftrig (
    // User interface clock and reset
    input clk,                            // DDR3 domain user clock
    input reset,
    input acq_enabled,                    // input, writing is enabled
    // Connections to the FIFO from the ADC
    input [131:0] ddr3_wr_fifo_dat,       // input, next 'write' data from the ADC FIFO
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
    // 'write' ports to the fill_header_fifo
    output [151:0] fill_header_wr_dat,    // header data
    output reg fill_header_wr_en,         // store header in FIFO
    // synchronization error flag
    output reg ddr3_wr_sync_err,
    // status flag back to the ADC acquisition machine
    output reg ddr3_wr_done,              // asserted when the 'ddr3_wr_control' is in the DONE state
    input acq_done                        // asserted when the 'adc_acq_sm' is in the DONE state
);

// Leave the comments containing "synopsys" in your HDL code.

// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [3:0]
    IDLE        = 4'd0,
    INIT_ALL	= 4'd1,
    WAIT		= 4'd2,
    TST_TAG     = 4'd3,
    SYNC_ERR    = 4'd4,
    INIT_FILL	= 4'd5,
    WRITE_FILL	= 4'd6,
    INIT_WFM    = 4'd7,
    INIT_CKSM   = 4'd8,
    WRITE       = 4'd9,
    WRITE_CKSM  = 4'd10,
    WRITE_HDR   = 4'd11,
    DONE        = 4'd12;

// synchronize 'acq_done'
(* ASYNC_REG = "TRUE" *) reg acq_done_sync1, acq_done_sync2;
always @ (posedge clk) begin
    acq_done_sync1 <= acq_done;
    acq_done_sync2 <= acq_done_sync1;
end

// define equivalent statement for data and address acceptance
assign address_accept   = (wr_app_en & wr_app_rdy);         // we presented an address and it was accepted
assign data_accept      = (app_wdf_wren & app_wdf_rdy);     // we presented data and it was accepted
wire address_allow; // allow attempts to write an address

// Create a counter to hold the total burst count for a fill. It will include the
// fill header, all waveform headers and data, and the checksum. Clear it at the 
// start of a fill. Increment it every time an address is accepted by the DDR3 memory.
reg [23:0] total_burst_count;
reg init_total_burst_count;
always @ (posedge clk) begin
	if (reset)
		total_burst_count[23:0] <= 24'd0;
	else if (init_total_burst_count)
	    total_burst_count[23:0] <= 24'd1;
	else if (address_accept)
		total_burst_count[23:0] <= total_burst_count[23:0] + 1;
end
	 
// Create a register to hold the header for future writing to the fill-header FIFO
reg [151:0] fill_header_wr_dat_reg;
reg latch_header;   // will be asserted by the state machine
always @ (posedge clk) begin
    if (reset) fill_header_wr_dat_reg <= {152{1'b0}};
    else if (latch_header) begin
    	fill_header_wr_dat_reg[127:0] <= ddr3_wr_fifo_dat[127:0];	// leave off the 4 tag bits
        fill_header_wr_dat_reg[151:128] <= total_burst_count[23:0]; // append the total burst count before issue write command to the FIFO
	end
end
assign fill_header_wr_dat[151:0] = fill_header_wr_dat_reg[151:0];

// Create an address generator
// Initialize it from the 'start_address' in the fill_header
// Increment it whenever the address is accepted (we get a 'wr_app_rdy' while asserting 'wr_app_en') 
reg [22:0] address_gen;
reg init_address_gen;   // will be asserted by the state machine
always @ (posedge clk) begin
    if (reset || !acq_enabled)
        // start up with it a '1'. This way, if we have a fill with no waveforms we will put
        // the checksum in the correct place.
        address_gen[22:0] <= 23'd1;
    else if (init_address_gen && (ddr3_wr_fifo_dat[131:128] == 4'd1))
        // fill header, so set the address to zero (relative to the upper vs lower half range for the buffering)
        address_gen[22:0] <= {ddr3_wr_fifo_dat[24],22'd0};
    else if (init_address_gen && (ddr3_wr_fifo_dat[131:128] == 4'd2))
        // waveform header, extract the address
        address_gen[22:0] <= ddr3_wr_fifo_dat[48:26];
    else if (address_accept)
        address_gen[22:0] <= address_gen[22:0] + 1;
end
assign ddr3_wr_addr[25:0] = {address_gen[22:0], 3'b0};

// Create an address counter that will count how many addresses are accepted
// For storing the fill_header or the checksum, initialize it to 1.
// For storing waveform data, initialize it to the 'burst_cnt' in the header plus 1
// Decrement it whenever an address is accepted. This happens when
// we are asserting 'wr_app_en' and receiving 'wr_app_rdy'.
reg [23:0] address_cntr;
reg init_address_cntr;   // will be asserted by the state machine
reg init_address_cntr_to_1;   // will be asserted by the state machine
wire address_cntr_zero;  // the counter is at zero
always @ (posedge clk) begin
    if (reset) address_cntr[23:0] <= 24'd0;
    else if (init_address_cntr_to_1) address_cntr[23:0] <= 24'd1;
    else if (init_address_cntr) address_cntr[23:0] <= {10'd0, ddr3_wr_fifo_dat[13:0]} + 1; // num_fill_bursts + 1 to account for waveform header (from the waveform header not fill header...)
    else if (address_cntr_zero) address_cntr[23:0] <= 24'b0;
    else if (address_accept) address_cntr[23:0] <= address_cntr[23:0] - 1;
end
// create a flag that gets set when the address counter is down to zero
assign address_cntr_zero = (address_cntr[23:0] == 24'd0) ? 1'b1 : 1'b0;

// Create a burst counter
// For storing the fill_header or the checksum, initialize it to 1.
// For storing waveform data, initialize it to the 'burst_cnt' in the header plus 1
// Decrement it whenever we get a successful write. This happens when
// we are asserting 'wdf_wren' and receiving 'wdf_rdy'.
reg [23:0] burst_cntr;
reg init_burst_cntr;   // will be asserted by the state machine
reg init_burst_cntr_to_1;   // will be asserted by the state machine
wire burst_cntr_zero;  // the counter is at zero
always @ (posedge clk) begin
    if (reset) burst_cntr[23:0] <= 24'd0;
    else if (init_burst_cntr_to_1) burst_cntr[23:0] <= 24'd1;
    else if (init_burst_cntr) burst_cntr[23:0] <= {10'd0, ddr3_wr_fifo_dat[13:0]} + 1; // num_fill_bursts + 1 to account for waveform header (from the waveform header not fill header...)
    else if (burst_cntr_zero) burst_cntr[23:0] <= 24'b0;
    else if (data_accept) burst_cntr[23:0] <= burst_cntr[23:0] - 1;
end
// create a flag that gets set when the burst counter is down to zero
assign burst_cntr_zero = (burst_cntr[23:0] == 24'd0) ? 1'b1 : 1'b0;

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
    
// Declare current state and next state variables
reg [12:0] /* synopsys enum STATE_TYPE */ CS;
reg [12:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
    if (reset || !acq_enabled) begin
        CS <= 13'b0;             // set all state bits to 0
        CS[IDLE] <= 1'b1;       // set IDLE state bit to 1
    end
    else
        CS <= NS;           // set state bits to next state
end

// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or ddr3_wr_fifo_empty or ddr3_wr_fifo_dat or burst_cntr_zero or address_cntr_zero or acq_done_sync2)     begin
    NS = 13'b0;                  // default all bits to zero; will overrride one bit

    case (1'b1) //synopsys full_case parallel_case

        // Stay in the IDLE state until we are released from the 'reset' condition by the assertion of 'acq_enabled".
       CS[IDLE]: begin
                NS[INIT_ALL] = 1'b1;
		end
		
        // Stay in the INIT_ALL state for 1 clock period.
        // Initialize stuff for a new fill.
        CS[INIT_ALL]: begin
                NS[WAIT] = 1'b1;
        end

        // Stay in the WAIT state until we see that the fifo is not empty.
        // Since the FIFO runs in first-word fall-through mode, if the fifo
        // in not empty, then the data will be vaild
        CS[WAIT]: begin
            if (ddr3_wr_fifo_empty)
            	// stay here if there is no data
                NS[WAIT] = 1'b1;
            else
                // figure out how to handle the data
                NS[TST_TAG] = 1'b1;
        end
        
        // Stay in TST_TAG state for one period.
        // Check the 4 MSBs of the data for valid tag types. Possibilities are
        // 'fill_header' tag (4'd1), 'waveform_header' tag (4'd2), and 'checksum' tag (4'd4).
        // Anything else says that we are out of sync and need to flag an error 
        CS[TST_TAG]: begin
            if (ddr3_wr_fifo_dat[131:128] == 4'd1)
                // we have a valid 'fill_header'
                NS[INIT_FILL] = 1'b1;
            else if (ddr3_wr_fifo_dat[131:128] == 4'd2)
                // we have a valid 'waveform_header'
                NS[INIT_WFM] = 1'b1;
            else if (ddr3_wr_fifo_dat[131:128] == 4'd4)
                // we have a valid 'checksum'
                NS[INIT_CKSM] = 1'b1;
            else
                // we are not synchronized. Go raise an error condition
                NS[SYNC_ERR] = 1'b1;
        end

        // Stay in SYNC_ERR state until the state machine is reset.
        // Raise the 'error' flag
        CS[SYNC_ERR]: begin
               NS[SYNC_ERR] = 1'b1;
        end

        // Stay in INIT_FILL state for one period.
        // Initialize the address and data counters. Store a copy of the header
        // for writing to the fill header fifo
        CS[INIT_FILL]: begin
                NS[WRITE_FILL] = 1'b1;
        end

        // Stay in WRITE_FILL state until all of the data for the fill header
        // has been written to memory.
        CS[WRITE_FILL]: begin
            if (burst_cntr_zero && address_cntr_zero)
                // we have written the requested number of addresses and bursts
                // Go put the fill header into the FIFO
                NS[WRITE_HDR] = 1'b1;
            else
                // More addresses or data to write, stay here
                NS[WRITE_FILL] = 1'b1;
        end

        // Stay in INIT_WFM state for one period.
        // Initialize the address and data counters.
        CS[INIT_WFM]: begin
                NS[WRITE] = 1'b1;
        end

        // Stay in WRITE state until all of the data for the fill_header or waveform_header
        // has been written to memory.
        CS[WRITE]: begin
            if (burst_cntr_zero && address_cntr_zero)
                // we have written the requested number of addresses and bursts
                // go back and wait for another waveform or the checksum
                NS[WAIT] = 1'b1;
            else
                // More addresses or data to write, stay here
                NS[WRITE] = 1'b1;
        end

        // Stay in INIT_CKSM state for one period.
        // Initialize the address and data counters to stuff in the checksum.
        CS[INIT_CKSM]: begin
                NS[WRITE_CKSM] = 1'b1;
        end

       // Stay in WRITE_CKSM state until all of the data for the checksum
        // has been written to memory.
        CS[WRITE_CKSM]: begin
            if (burst_cntr_zero && address_cntr_zero)
                // we have written the requested number of addresses and bursts
                // Go back and wait for the fill header
                NS[WAIT] = 1'b1;
            else
                // More addresses or data to write, stay here
                NS[WRITE_CKSM] = 1'b1;
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
               NS[WAIT] = 1'b1;
            else
                NS[DONE] = 1'b1;
        end


    endcase
end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
    // defaults
        ddr3_wr_done        	<= 1'b0;
        latch_header        	<= 1'b0;
        init_address_gen    	<= 1'b0;
        init_address_cntr_to_1	<= 1'b0;
        init_address_cntr   	<= 1'b0;
        init_burst_cntr     	<= 1'b0;
        init_burst_cntr_to_1	<= 1'b0;
        init_total_burst_count	<= 1'b0;
        ddr3_wr_sync_err    	<= 1'b0;
        fill_header_wr_en   	<= 1'b0;

    // next states
    if (NS[IDLE]) begin
    end
    
    if (NS[INIT_ALL]) begin
       // initialize the total_burst counter to 1 (to include fill header)
       init_total_burst_count	<= 1'b1;
    end

    if (NS[WAIT]) begin
    end

    if (NS[INIT_FILL]) begin
        // latch the header data for use later
        latch_header        <= 1'b1;
        // initialize the address from the header
        init_address_gen    <= 1'b1;
        // initialize the address counter to 1
        init_address_cntr_to_1	<= 1'b1;
        // initialize the burst counter to 1
        init_burst_cntr_to_1	<= 1'b1;
    end
 
    if (NS[WRITE_FILL]) begin
    end

    if (NS[INIT_WFM]) begin
        // initialize the address from the header
        init_address_gen    <= 1'b1;
        // initialize the address counter from the header
        init_address_cntr   <= 1'b1;
        // initialize the burst counter from the header
        init_burst_cntr     <= 1'b1;
    end

    if (NS[INIT_CKSM]) begin
        // we do not initialize the address
        // initialize the address counter to 1
        init_address_cntr_to_1	<= 1'b1;
        // initialize the burst counter to 1
        init_burst_cntr_to_1	<= 1'b1;
    end
    
    if (NS[WRITE]) begin
    end

    if (NS[SYNC_ERR]) begin
        // assert an error flag
        ddr3_wr_sync_err    <= 1'b1;
    end

    if (NS[WRITE_CKSM]) begin
    end

    if (NS[WRITE_HDR]) begin
        // write the header to the FIFO
        fill_header_wr_en   <= 1'b1;
        // to allow the checksum to be written to memory
        //address_control <= 1'b1;
    end

    if (NS[DONE]) begin
        ddr3_wr_done        <= 1'b1;
    end    


end

// indicate that we want to supply an address if data has already been accepted
assign wr_app_en = (CS[WRITE] || CS[WRITE_CKSM] || CS[WRITE_FILL]) && address_allow && !address_cntr_zero;

// indicate that we want to supply data if it is available 
assign app_wdf_wren = (CS[WRITE] || CS[WRITE_CKSM] || CS[WRITE_FILL]) && !ddr3_wr_fifo_empty && !burst_cntr_zero; // was: ~burst_cntr_zero;
assign app_wdf_end = (CS[WRITE] || CS[WRITE_CKSM] || CS[WRITE_FILL]) && !ddr3_wr_fifo_empty && !burst_cntr_zero;  // was: ~burst_cntr_zero;

// if the current data was accepted then bring the next FIFO data to the front 
assign ddr3_wr_fifo_rd_en   = (CS[WRITE] || CS[WRITE_CKSM] || CS[WRITE_FILL]) && data_accept && !burst_cntr_zero;

endmodule

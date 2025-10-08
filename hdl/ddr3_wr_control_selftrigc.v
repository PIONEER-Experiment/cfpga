`timescale 1ns / 1ps

/////////////////////////////////////////////////////////////
// Connect the module that manages writing data to the memory

module ddr3_wr_control_selftrigc (
    // User interface clock and reset
    input clk,                            // DDR3 domain user clock
    input reset,
(* mark_debug = "true" *) input acq_enabled,                    // input, writing is enabled
    // Connections to the FIFO from the ADC
(* mark_debug = "true" *) input [131:0] ddr3_wr_fifo_dat,       // input, next 'write' data from the ADC FIFO
(* mark_debug = "true" *) input ddr3_wr_fifo_empty,             // input, data is available when this is not asserted
(* mark_debug = "true" *) output ddr3_wr_fifo_rd_en,            // output, use and remove the data on the FIFO head
    // 'write' ports to memory
(* mark_debug = "true" *) output  app_wdf_wren,                 // output, request to perform a 'write'
(* mark_debug = "true" *) input app_wdf_rdy,                    // input, memory can accept data
(* mark_debug = "true" *) output  app_wdf_end,                  // output, last data cycle
(* mark_debug = "true" *) input [22:0] fill_address,            // starting address of this fill
(* mark_debug = "true" *) output reg fill_address_rd_en,
(* mark_debug = "true" *) input fill_address_fifo_empty,              // the fill address for this fill is available when low    
    // 'write' ports to address controller
    output [25:0] ddr3_wr_addr,           // output, next 'write' address
(* mark_debug = "true" *) output  wr_app_en,                    // output, request to perform a 'write'
(* mark_debug = "true" *) input wr_app_rdy,                     // input, increment the 'write' address
    // 'write' ports to the fill_header_fifo
(* mark_debug = "true" *) output [151:0] fill_header_wr_dat,    // header data
(* mark_debug = "true" *) output reg fill_header_wr_en,         // store header in FIFO
    // synchronization error flag
(* mark_debug = "true" *) output reg ddr3_wr_sync_err,
    // status flag back to the ADC acquisition machine
    output reg ddr3_wr_done,              // asserted when the 'ddr3_wr_control' is in the DONE state (once per waveform, header or checksum)
(* mark_debug = "true" *) input enable_triggering_ddr3,
(* mark_debug = "true" *) input enable_acquisition_ddr3,
    //
    output [16:0] ddr3_wr_ctrl_state,     // current state
    input acq_done,                      // asserted when the 'adc_acq_sm' is in the DONE state
(* mark_debug = "true" *) output writing_last_fill             // asserted when enable_acquisition_ddr3 deasserts but we haven't finished writing the info from this fill
);

// 
(* mark_debug = "true" *) reg [4:0] fill_number_dwc;
always @ (posedge clk) begin
  if (reset)
    fill_number_dwc[4:0] <= 5'd0;
  else if (fill_header_wr_en)
    fill_number_dwc[4:0] = fill_number_dwc[4:0] + 1;
end

// Leave the comments containing "synopsys" in your HDL code.

// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [3:0]
    IDLE             = 4'd0,  // 00001
    INIT_ALL         = 4'd1,  // 00002
    WAIT             = 4'd2,  // 00004
    TST_TAG          = 4'd3,  // 00008
    SYNC_ERR         = 4'd4,  // 00010
    INIT_FILL        = 4'd5,  // 00020
    WRITE_FILL       = 4'd6,  // 00040
    INIT_WFM         = 4'd7,  // 00080
    INIT_CKSM        = 4'd8,  // 00100
    WRITE            = 4'd9,  // 00200
    WRITE_CKSM       = 4'd10, // 00400
    WRITE_HDR        = 4'd11, // 00800
    FINISH           = 4'd12, // 01000
    CLR_FILL_ADR     = 4'd13, // 02000 
    FILL_DONE        = 4'd14, // 04000
    WAIT_FILL_ADR    = 4'd15, // 08000
    SET_FILL_ADR     = 4'd16; // 20000

// synchronize 'acq_done'
(* ASYNC_REG = "TRUE" *) reg acq_done_sync1, acq_done_sync2;
always @ (posedge clk) begin
    acq_done_sync1 <= acq_done;
    acq_done_sync2 <= acq_done_sync1;
end

// define equivalent statement for data and address acceptance
(* mark_debug = "true" *) wire address_accept;
assign address_accept   = (wr_app_en & wr_app_rdy);         // we presented an address and it was accepted
wire data_accept;
assign data_accept      = (app_wdf_wren & app_wdf_rdy);     // we presented data and it was accepted
(* mark_debug = "true" *) wire address_allow; // allow attempts to write an address

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
      fill_header_wr_dat_reg[127:0]   <= ddr3_wr_fifo_dat[127:0];	// leave off the 4 tag bits
      fill_header_wr_dat_reg[151:128] <= total_burst_count[23:0]; // append the total burst count before issue write command to the FIFO
	end
end
assign fill_header_wr_dat[151:0] = fill_header_wr_dat_reg[151:0];

// Create an address generator
// Initialize it from the 'start_address' in the fill_header
// Increment it whenever the address is accepted (we get a 'wr_app_rdy' while asserting 'wr_app_en') 
(* mark_debug = "true" *) wire [3:0] data_type_tag;
assign data_type_tag[3:0] = (ddr3_wr_fifo_empty == 1'b1) ? 4'd0 : ddr3_wr_fifo_dat[131:128];
reg [22:0] address_gen;
(* mark_debug = "true" *) reg init_address_gen;   // will be asserted by the state machine
//always @ (posedge clk) begin
//    if (reset )
//      // start up with it a '1'. This way, if we have a fill with no waveforms we will put
//      // the checksum in the correct place.
////      address_gen[22:0] <= 23'd1;
//        address_gen[22:0] <= fill_address[22:0] + 1;
//    else if (init_address_gen && (ddr3_wr_fifo_dat[131:128] == 4'd1))
//      // fill header, so set the address to the starting address for this fill
//      address_gen[22:0] <= fill_address;
//    else if (init_address_gen && (ddr3_wr_fifo_dat[131:128] == 4'd2))
//      // waveform header, extract the address
//      address_gen[22:0] <= ddr3_wr_fifo_dat[48:26];
//    else if (init_address_gen && !(acq_enabled && enable_triggering_ddr3) )
//      // The starting fill address
//        address_gen[22:0] <= fill_address[22:0] + 1;
//    else if (address_accept)
//      address_gen[22:0] <= address_gen[22:0] + 1;
//end
always @ (posedge clk) begin
    if (reset )
      // start up with it a '1'. This way, if we have a fill with no waveforms we will put
      // the checksum in the correct place.
        address_gen[22:0] <= fill_address[22:0] + 1;
    else if (init_address_gen ) begin
//      if ( ddr3_wr_fifo_dat[131:128] == 4'd1 )
      if ( data_type_tag[3:0] == 4'd1 )
        // fill header, so set the address to the starting address for this fill
        address_gen[22:0] <= fill_address;
//      else if ( ddr3_wr_fifo_dat[131:128] == 4'd2 )
      else if ( data_type_tag[3:0] == 4'd2 )
        // waveform header, extract the address
        address_gen[22:0] <= ddr3_wr_fifo_dat[48:26];
      else 
        // The starting fill address.  Set it 1 past where the header will eventually go
        address_gen[22:0] <= fill_address[22:0] + 1;
    end
    else if (address_accept)
      address_gen[22:0] <= address_gen[22:0] + 1;
end
assign ddr3_wr_addr[25:0] = {address_gen[22:0], 3'b0};
(* mark_debug = "true" *) wire [22:0] ddr3_wr_addr_burst;
assign ddr3_wr_addr_burst[22:0] =  address_gen[22:0];

// Create an address counter that will count how many addresses are accepted
// For storing the fill_header or the checksum, initialize it to 1.
// For storing waveform data, initialize it to the 'burst_cnt' in the header plus 1
// Decrement it whenever an address is accepted. This happens when
// we are asserting 'wr_app_en' and receiving 'wr_app_rdy'.
(* mark_debug = "true" *) reg [23:0] address_cntr;
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
(* mark_debug = "true" *) reg [23:0] burst_cntr;
reg init_burst_cntr;   // will be asserted by the state machine
reg init_burst_cntr_to_1;   // will be asserted by the state machine
(* mark_debug = "true" *) wire burst_cntr_zero;  // the counter is at zero
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
(* mark_debug = "true" *) reg [4:0] address_control;
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
    
(* mark_debug = "true" *) wire addresses_equal;
assign addresses_equal = (ddr3_wr_addr_burst == fill_address ) ? 1 : 0;

// Declare current state and next state variables
(* mark_debug = "true" *) reg [16:0] /* synopsys enum STATE_TYPE */ CS;
reg [16:0] /* synopsys enum STATE_TYPE */ NS;
assign ddr3_wr_ctrl_state[14:0] = CS[16:0];

// // debug counter to catch stall state at end of run in WRITE
// reg [15:0] debug_ctr;
// reg debug_ctr_reset, debug_ctr_inc;
// (* mark_debug = "true" *) wire debug_ctr_at_limit;
// always @ (posedge clk) begin
//   if ( reset ) debug_ctr[15:0] <= 200;
//   else if ( debug_ctr_reset ) debug_ctr[15:0] <= 200;
//   else if ( debug_ctr_inc ) debug_ctr[15:0] <= debug_ctr[15:0] - 1;
//   else if (debug_ctr_at_limit ) debug_ctr[15:0] <= 0;
// end
// assign debug_ctr_at_limit = (debug_ctr[15:0] == 0 )? 1'b1 : 1'b0;

//ddr3_wr_cntrl_ila ddr3_wr_cntrl_ila_inst (
//  .clk(clk), // input wire clk
//
//
//  .probe0(CS),                    // input wire [12:0]  probe0
//  .probe1(acq_enabled),           // input wire [0:0]  probe1
//  .probe2(ddr3_wr_fifo_dat),      // input wire [131:0]  probe2
//  .probe3(ddr3_wr_fifo_empty),    // input wire [0:0]  probe3
//  .probe4(ddr3_wr_fifo_rd_en),    // input wire [0:0]  probe4
//  .probe5(app_wdf_wren),          // input wire [0:0]  probe5
//  .probe6(app_wdf_rdy),           // input wire [0:0]  probe6
//  .probe7(app_wdf_end),           // input wire [0:0]  probe7
//  .probe8(writing_last_fill),     // input wire [0:0]  probe8
//  .probe9(wr_app_en),             // input wire [0:0]  probe9
//  .probe10(wr_app_rdy),           // input wire [0:0]  probe10
//  .probe11(fill_header_wr_dat),   // input wire [151:0]  probe11
//  .probe12(fill_header_wr_en),    // input wire [0:0]  probe12
//  .probe13(init_address_gen),     // input wire [0:0]  probe13
//  .probe14(ddr3_wr_done),         // input wire [0:0]  probe14
//  .probe15(checksum_memory_range), // input wire [0:0]  probe15
//  .probe16(fill_header_fifo_empty), // input wire [0:0]  probe12
//  .probe17(fill_header_fifo_rd_en), // input wire [0:0]  probe12
//  .probe18(correct_chksum_addr),     // input wire [0:0]  probe12
//  .probe19(enable_acquisition_ddr3), // input wire [0:0]  probe12
//  .probe20(fill_num),
//  .probe21(ddr3_wr_en_sync2),
//  .probe22(evt_cnt_reset),
//  .probe23(rst_from_master),
//  .probe24(latch_header),
//  .probe25(ddr3_wr_fill_in_progress),
//  .probe26(next_ddr3_wr_fill_in_progress),
//  .probe27(header_written),
//  .probe28(acq_done_sync2),
//  .probe29(address_cntr[3:0]),
//  .probe30(app_rdy),
//  .probe31(address_gen)
//);



//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
reg ddr3_wr_fill_in_progress;       // asserted when a new fill has started, but the last write (header) has not finished
reg header_written;                 // assert as soon as the header has finished writing
reg next_ddr3_wr_fill_in_progress;       // asserted when a new fill has started, but the last write (header) has not finished
reg next_header_written;                 // assert as soon as the header has finished writing

always @ (posedge clk) begin
    if (reset ) begin
        CS <= 17'b0;             // set all state bits to 0
        CS[IDLE] <= 1'b1;       // set IDLE state bit to 1
    end
    else
        CS <= NS;           // set state bits to next state
end

// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or ddr3_wr_fifo_empty or ddr3_wr_fifo_dat or burst_cntr_zero or address_cntr_zero or acq_done_sync2 or header_written or ddr3_wr_fill_in_progress or acq_enabled or enable_acquisition_ddr3 or fill_address_fifo_empty )     begin
    NS = 17'b0;                  // default all bits to zero; will overrride one bit
    next_header_written           <= header_written;
    next_ddr3_wr_fill_in_progress <= ddr3_wr_fill_in_progress;
    
    case (1'b1) //synopsys full_case parallel_case

        // Stay in the IDLE state until we are released from the 'reset' condition by the assertion of 'acq_enabled".
       CS[IDLE]: begin
         if ( acq_enabled )
           NS[INIT_ALL] = 1'b1;
         else
           NS[IDLE]     = 1'b1;
         end

        // Stay in the INIT_ALL state for 1 clock period.
        // Initialize stuff for a new fill.
        CS[INIT_ALL]: begin
          next_ddr3_wr_fill_in_progress <= enable_acquisition_ddr3;
          NS[WAIT] = 1'b1;
        end

        // Stay in the WAIT state until we see that the fifo is not empty.
        // Since the FIFO runs in first-word fall-through mode, if the fifo
        // in not empty, then the data will be vaild
        // We must also make sure that the fill address has become available
        CS[WAIT]: begin
          next_ddr3_wr_fill_in_progress <= ~(header_written & acq_done_sync2);
          if ( !enable_acquisition_ddr3 )
            // go to idle between runs
            NS[IDLE]     = 1'b1;
          else if (ddr3_wr_fifo_empty || fill_address_fifo_empty )
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
          next_header_written <= 1'b1;
          NS[FINISH] = 1'b1;
        end        
        
        // Stay in FINISH state until acquisition is finished
        // Write the original header to the fill_header_fifo
        CS[FINISH]: begin
            if (acq_done_sync2)
              NS[CLR_FILL_ADR] = 1'b1;
            else
              NS[FINISH] = 1'b1;
        end

        // Stay in CLR_FILL_ADR state for 1 clock cycle
        // pull the stale address out of the fill_address fifo
        CS[CLR_FILL_ADR]: begin
          NS[FILL_DONE] = 1'b1;
        end

        // Stay in FILL_DONE state 1 cycle to flag that the DDR3 writing is done
        CS[FILL_DONE]: begin
          NS[WAIT_FILL_ADR] = 1'b1;
        end
        
        // wait in WAIT_FILL_ADR until the next fill address is valid.  Necessary for empty fills
        CS[WAIT_FILL_ADR]: begin
          if ( fill_address_fifo_empty )
            NS[WAIT_FILL_ADR] = 1'b1;
          else
            NS[SET_FILL_ADR] = 1'b1;
        end
        
        // stay in SET_FILL_ADR 1 cycle to prep the next fill address.  Necessary for empty fills
        CS[SET_FILL_ADR]: begin
          if ( acq_enabled )
            NS[WAIT] = 1'b1;
          else
            NS[IDLE] = 1'b1;
        end


    endcase
end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
    // defaults
        ddr3_wr_done            <= 1'b0;
        latch_header            <= 1'b0;
        init_address_gen        <= 1'b0;
        init_address_cntr_to_1  <= 1'b0;
        init_address_cntr       <= 1'b0;
        init_burst_cntr         <= 1'b0;
        init_burst_cntr_to_1    <= 1'b0;
        init_total_burst_count	<= 1'b0;
        ddr3_wr_sync_err        <= 1'b0;
        fill_header_wr_en       <= 1'b0;
        fill_address_rd_en      <= 1'b0;
        ddr3_wr_fill_in_progress <= 1'b0;
        header_written           <= 1'b0;
//        debug_ctr_reset          <= 1'b0;
//        debug_ctr_inc            <= 1'b0;

    // next states
    if (NS[IDLE]) begin
    end
    
    if (NS[INIT_ALL]) begin
       // initialize the total_burst counter to 1 (to include fill header)
       init_total_burst_count	<= 1'b1;
       ddr3_wr_fill_in_progress      <= enable_acquisition_ddr3;
       header_written                <= 1'b0;
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
        // clear the header written register
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
//        debug_ctr_reset          <= 1'b1;
    end

    if (NS[INIT_CKSM]) begin
        // note: no special initializion of the the address for the checksum, but
        // initialize the address counter to 1
        init_address_cntr_to_1	<= 1'b1;
        // initialize the burst counter to 1
        init_burst_cntr_to_1	<= 1'b1;
    end
    
    if (NS[WRITE]) begin
//        debug_ctr_inc          <= 1'b1;
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
        // flag that the header got written
    end

    if (NS[FINISH]) begin
        ddr3_wr_done        <= 1'b1;
        // this fill has been processed when the header has been written and writing confirmation acknowledged
    end
    
    if (NS[CLR_FILL_ADR]) begin
        fill_address_rd_en      <= 1'b1;
        // pull the now stale fill_address off the fifo
    end
    
    if (NS[FILL_DONE]) begin
      ddr3_wr_done        <= 1'b1;
      // this fill has been processed when the header has been written and writing confirmation acknowledged
    end

    if (NS[WAIT_FILL_ADR]) begin
      // just waiting in this state
    end
    
    if (NS[SET_FILL_ADR]) begin
      init_address_gen    <= 1'b1;
      // the address of the new fill is available, set the next address to be there
    end

end

// indicate that we want to supply an address if data has already been accepted
assign wr_app_en = (CS[WRITE] || CS[WRITE_CKSM] || CS[WRITE_FILL]) && address_allow && !address_cntr_zero;

// indicate that we want to supply data if it is available 
assign app_wdf_wren = (CS[WRITE] || CS[WRITE_CKSM] || CS[WRITE_FILL]) && !ddr3_wr_fifo_empty && !burst_cntr_zero; // was: ~burst_cntr_zero;
assign app_wdf_end = (CS[WRITE] || CS[WRITE_CKSM] || CS[WRITE_FILL]) && !ddr3_wr_fifo_empty && !burst_cntr_zero;  // was: ~burst_cntr_zero;

// if the current data was accepted then bring the next FIFO data to the front 
assign ddr3_wr_fifo_rd_en   = (CS[WRITE] || CS[WRITE_CKSM] || CS[WRITE_FILL]) && data_accept && !burst_cntr_zero;

// we want to keep writing the last fill's information out, where last is flagged by enable_triggering deasserting
assign writing_last_fill = ~enable_acquisition_ddr3 & ddr3_wr_fill_in_progress;


endmodule

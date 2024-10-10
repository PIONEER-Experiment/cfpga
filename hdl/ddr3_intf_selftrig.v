`timescale 1ns / 10ps

module ddr3_intf_selftrig(
    // clocks and resets
    input refclk,                               // input, 200 MHz for I/O timing adjustments
    input sysclk,                               // input, drives the Xilinx DDR3 IP
    input reset_clk50,                          // input, reset at startup or when requested by master FPGA 
    output ddr3_domain_clk,                     // output, the DDR3 user-interface synchronous clock
    output reset_ddr3_clk,                      // output, synched to ddr3_clk
    // writing connections
    input ddr3_wr_en,                           // writing of triggered events to memory is enabled
    input cbuf_rd_en,                           // we have enabled storing of events -- asserted when not switching fill buffers
    input ddr3_wr_fifo_empty,                   // input, data is available when this is not asserted
    output ddr3_wr_fifo_rd_en,                  // output, use and remove the data on the FIFO head
    input [131:0] ddr3_wr_fifo_dat,             // input, 132-bit 4-bit header plus 128-bit data from the ddr3_write_fifo, to be written to the DDR3
    output ddr3_wr_sync_err,                    // synchronization error flag
    output ddr3_wr_done,                        // asserted when the 'ddr3_wr_control' is in the DONE state
    input checksum_memory_range,                // latch the memory buffer for writing the checksum
    input acq_done,                             // input from the adc_acq_sm, aquisition is done
    // reading connections
    input local_domain_clk,                     // input, the local interface synchronous clock
    input fill_header_fifo_reset,               // input, clear out the fifo for a new run
    (* mark_debug = "true" *) output fill_header_fifo_empty,              // output, a header is available when not asserted
    (* mark_debug = "true" *) input fill_header_fifo_rd_en,               // input, remove the current data from the FIFO
    output [151:0] fill_header_fifo_out,        // output, data at the head of the FIFO
    input [22:0] ddr3_rd_start_addr,            // input, the address of the first requested 128-bit burst
    input [23:0] ddr3_rd_burst_cnt,             // input, the number of bursts to read
    input enable_reading,                       // input, initialize the address generator and both counters, go
    output reading_done,                        // output, reading is complete
    // ports to the 'read' fifo
    output ddr3_rd_fifo_wr_en,                  // data is valid, so put it in the READ FIFO
    output [127:0] ddr3_rd_fifo_input_dat,      // output, memory data
    input ddr3_rd_fifo_almost_full,             // there is not much room left
    output ddr3_rd_fifo_input_tlast,            // the last burst for this fill
    // connections to the DDR3 chips
    output [12:0] ddr3_addr,
    output [2:0] ddr3_ba,
    inout [15:0] ddr3_dq,
    output [0:0] ddr3_ck_p,
    output [0:0] ddr3_ck_n,
    output [1:0] ddr3_dqs_p,
    output [1:0] ddr3_dqs_n,
    output ddr3_we_n,
    output [0:0] ddr3_cke,
    output ddr3_ras_n,
    output ddr3_cas_n,
    output ddr3_reset_n,
    output [1:0] ddr3_dm,
    output [0:0] ddr3_odt,
    output app_rdy,                              // output, PHY calibration is done
    input [11:0] xadc_temp,
    // for debugging
    input [3:0] event_cnt_short,
    input enable_triggering,
    input readout_pause,
    input [23:0] fill_num,
    input initial_fill_num_wr,
    input evt_cnt_reset,
    input rst_from_master
    // end of debugging

);
// for fast simulation uncomment the next 3 lines, and comment out lines marked farther into this file.
//wire app_wdf_rdy;				// for fast simulation ONLY
//assign app_rdy = 1'b1;		// for fast simulation ONLY
//assign app_wdf_rdy = 1'b1;	// for fast simulation ONLY
// end fast simulation mods    

// sync some signals for debugging into the various domains
(* mark_debug = "true" *) wire enable_triggering_ddr3;
(* mark_debug = "true" *) wire enable_triggering_125;
sync_2stage et_ddr3 (
   .clk(ddr3_domain_clk),
   .in(enable_triggering),
   .out(enable_triggering_ddr3)
);
sync_2stage et_125 (
   .clk(local_domain_clk),
   .in(enable_triggering),
   .out(enable_triggering_125)
);
(* mark_debug = "true" *) wire readout_pause_ddr3;
(* mark_debug = "true" *) wire readout_pause_125;
sync_2stage rp_ddr3 (
   .clk(ddr3_domain_clk),
   .in(readout_pause),
   .out(readout_pause_ddr3)
);
sync_2stage rp_125 (
   .clk(local_domain_clk),
   .in(readout_pause),
   .out(readout_pause_125)
);

// sync event_cnt_short into this domain
wire [3:0] event_cnt_short_ddr3;
sync_2stage  #(
.WIDTH(4)
) event_cnt_ddr3_sync (
   .clk(ddr3_domain_clk),
   .in(event_cnt_short),
   .out(event_cnt_short_ddr3)
);

//synchronize the 'reset' signal
(* ASYNC_REG = "TRUE" *) reg reset_sync1, reset_sync2;
always @(posedge sysclk) begin
    reset_sync1 <= reset_clk50;
    reset_sync2 <= reset_sync1;
end
assign reset_ddr3_clk = reset_sync2;

//synchronize the 'ddr3_wr_en' signal
(* ASYNC_REG = "TRUE" *) reg ddr3_wr_en_sync1, ddr3_wr_en_sync2;
always @(posedge ddr3_domain_clk) begin
    ddr3_wr_en_sync1 <= ddr3_wr_en;
    ddr3_wr_en_sync2 <= ddr3_wr_en_sync1;
end

//synchronize the 'cbuf_rd_en' signal
(* ASYNC_REG = "TRUE" *) reg cbuf_rd_en_sync1, cbuf_rd_en_sync2;
always @(posedge ddr3_domain_clk) begin
    cbuf_rd_en_sync1 <= cbuf_rd_en;
    cbuf_rd_en_sync2 <= cbuf_rd_en_sync1;
end

(* mark_debug = "true" *) wire [23:0] fill_num_ddr3;
sync_2stage #(
  .WIDTH(24)
) fn_sync_ddr3 (
  .clk(ddr3_domain_clk),
  .in(fill_num),
  .out(fill_num_ddr3)
);

wire [25:0] ddr3_wr_addr;
wire [25:0] ddr3_rd_addr;
(* mark_debug = "true" *) wire [151:0] fill_header_wr_dat;
wire [26:0] app_addr;
wire [2:0] app_cmd;
wire [127:0] ddr3_rd_dat;
wire [127:0] ddr3_wr_dat;

// just pass the DDR3 data thru to the FIFO
assign ddr3_rd_fifo_input_dat[127:0] = ddr3_rd_dat[127:0];

////////////////////////////////////////////////////////////////
// Connect the module that manages the address and command ports
ddr3_addr_control ddr3_addr_control (
    // 'write' ports
    .wr_addr(ddr3_wr_addr[25:0]),           // input, next 'write' address
    .wr_app_rdy(wr_app_rdy),                // output, increment the 'write' address
    .wr_app_en(wr_app_en),                  // input, request to perform a 'write'  
    .acq_enabled(ddr3_wr_en_sync2),        // input, writing is enabled
    // 'read' ports
    .rd_addr(ddr3_rd_addr[25:0]),           // input, next 'read' address
    .rd_app_rdy(rd_app_rdy),                // output, increment the 'read' address
    .rd_app_en(rd_app_en),                  // input, request to perform a 'read'   
    // 'memory' ports
    .app_addr(app_addr[26:0]),  
    .app_cmd(app_cmd[2:0]),
    .app_en(app_en),
    .app_rdy(app_rdy)
);

/////////////////////////////////////////////////////////////
// Connect the module that manages writing data to the memory
(* mark_debug = "true" *) wire fill_header_wr_en;
ddr3_wr_control_selftrig ddr3_wr_control_selftrig (
    // User interface clock and reset   
    .clk(ddr3_domain_clk),
    .reset(ddr3_domain_reset),
    .acq_enabled(cbuf_rd_en_sync2),                 // input, writing from cbuf to ddr3 has been enabled for a fill.
    .checksum_memory_range(checksum_memory_range),  // latch the memory buffer for writing the checksum
    // Connections to the FIFO from the ADC
    .ddr3_wr_fifo_dat(ddr3_wr_fifo_dat[131:0]),     // input, next 'write' data from the ADC FIFO
    .ddr3_wr_fifo_empty(ddr3_wr_fifo_empty),        // input, data is available when this is not asserted
    .ddr3_wr_fifo_rd_en(ddr3_wr_fifo_rd_en),        // output, use and remove the data on the FIFO head
    // 'write' ports to memory
    .app_wdf_end(app_wdf_end),                      // output, last data cycle
    .app_wdf_rdy(app_wdf_rdy),                      // input, memory can accept data
    .app_wdf_wren(app_wdf_wren),                    // output, request to perform a 'write' 
    // 'write' ports to address controller
    .ddr3_wr_addr(ddr3_wr_addr[25:0]),              // output, next 'write' address
    .wr_app_rdy(wr_app_rdy),                        // input, increment the 'write' address
    .wr_app_en(wr_app_en),                          // output, request to perform a 'write'
    // 'write' ports to the fill_header_fifo
    .fill_header_wr_dat(fill_header_wr_dat[151:0]), // header data
    .fill_header_wr_en(fill_header_wr_en),          // store header in FIFO
    .ddr3_wr_sync_err(ddr3_wr_sync_err),            // synchronization error flag
    // status signals connected to the ADC acquisition machine
    .ddr3_wr_done(ddr3_wr_done),                    // asserted when the 'ddr3_wr_control' is in the DONE state
    // next batch for debugging, eliminate when done
    .fill_header_fifo_empty(fill_header_fifo_empty),
    .fill_header_fifo_rd_en(fill_header_fifo_rd_en),
    .readout_pause_ddr3(readout_pause_ddr3),
    .enable_triggering_ddr3(enable_triggering_ddr3),
    .fill_num(fill_num_ddr3),
    .initial_fill_num_wr(initial_fill_num_wr),
    .evt_cnt_reset(evt_cnt_reset),
    .rst_from_master(rst_from_master),
    // done debugging
    .acq_done(acq_done)                             // input, asserted when the 'adc_acq_sm' is in the DONE state
 );

///////////////////////////////////////////////////////////////
// Connect the module that manages reading data from the memory
ddr3_rd_control ddr3_rd_control (
    // User interface clock and reset   
    .clk(ddr3_domain_clk),
    .reset(ddr3_domain_reset),                              // reset at startup or when requested
    .acq_enabled(ddr3_wr_en_sync2),                        // input, writing is enabled
    // connections to the 'rd_fill' command logic
    .ddr3_rd_start_addr(ddr3_rd_start_addr[22:0]),          // input, the address of the first requested 128-bit burst
    .ddr3_rd_burst_cnt(ddr3_rd_burst_cnt[23:0]),            // input, the number of bursts to read
    .enable_reading(enable_reading),                        // input, initialize the address generator and both counters, go
    .reading_done(reading_done),                            // output, reading is complete
    // 'read' ports to memory
    .app_rd_data_end(app_rd_data_end),                      // input, last data cycle
    .app_rd_data_valid(app_rd_data_valid),                  // input, memory data is valid  
    //.app_rd_data(ddr3_rd_dat[127:0]),                       // input, memory data   
    // 'read' ports to address controller
    .ddr3_rd_addr(ddr3_rd_addr[25:0]),                      // output, next 'read' address
    .rd_app_rdy(rd_app_rdy),                                // input, increment the 'read' address
    .rd_app_en(rd_app_en),                                  // output, request to perform a 'read'
    // ports to the 'read' fifo
    .ddr3_rd_fifo_wr_en(ddr3_rd_fifo_wr_en),                // data is valid, so put it in the READ FIFO    
    //.ddr3_rd_fifo_input_dat(ddr3_rd_fifo_input_dat[127:0]), // output, memory data
    .ddr3_rd_fifo_almost_full(ddr3_rd_fifo_almost_full),    // there is not much room left    
    .ddr3_rd_fifo_input_tlast(ddr3_rd_fifo_input_tlast)    // the last burst for this fill 
);

////////////////////////////////////////////////////////////////////////////
// Create a FIFO for the fill header info.
// The write port will be connected to the 'write' controller.
// The read port will be connected to the 'read' controller.
wire full_fifo_reset;
assign full_fifo_reset = fill_header_fifo_reset | ddr3_domain_reset;
fill_header_fifo fill_header_fifo (
    .rst(full_fifo_reset),                   // was .rst(ddr3_domain_reset),                // reset at startup or when requested
    .wr_clk(ddr3_domain_clk),               // clock used by 'write' controller
    .rd_clk(local_domain_clk),              // clock used by 'rd_fill' controller
    .din(fill_header_wr_dat[151:0]),        // header data to write
    .wr_en(fill_header_wr_en),              // store the fill header 
    .rd_en(fill_header_fifo_rd_en),             // read the next word of the fill header
    .dout(fill_header_fifo_out[151:0]),     // fill header 
    .full(),                                // the header fifo is full, WHAT DO WE DO?
    .empty(fill_header_fifo_empty)          // a fill header is available when this is not asserted
);
    
///////////////////////////////////////////////////////////////////////////
// instantiate the MIG DDR3 interface

wfd5_ddr3_r1 u_wfd5_ddr3_r1 (
    // clocks and resets
    .clk_ref_i(refclk),                             // input, 200 MHz for I/O timing adjustments
    .sys_clk_i(sysclk),                             // input, drives the Xilinx DDR3 IP
    .sys_rst(reset_ddr3_clk),                       // input, reset at startup or when requested by master FPGA 
    // Memory interface ports
    .ddr3_addr(ddr3_addr[12:0]),
    .ddr3_ba(ddr3_ba[2:0]),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_ck_n(ddr3_ck_n[0:0]),
    .ddr3_ck_p(ddr3_ck_p[0:0]),
    .ddr3_cke(ddr3_cke[0:0]),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_dq(ddr3_dq[15:0]),
    .ddr3_dqs_n(ddr3_dqs_n[1:0]),
    .ddr3_dqs_p(ddr3_dqs_p[1:0]),
    .ddr3_dm(ddr3_dm[1:0]),
    .ddr3_odt(ddr3_odt[0:0]),
    // Address and Command ports
    .app_addr(app_addr[26:0]),  
    .app_cmd(app_cmd[2:0]),
    .app_en(app_en),
// for fast simulation swap the comment markers on the next 2 lines
    .app_rdy(app_rdy),	// for normal operation
    //.app_rdy(),		// for fast simulation ONLY
// end fast simulation mods    
    // Write ports
    .app_wdf_data(ddr3_wr_fifo_dat[127:0]),
    .app_wdf_end(app_wdf_end),
    .app_wdf_wren(app_wdf_wren),
// for fast simulation swap the comment markers on the next 2 lines
    .app_wdf_rdy(app_wdf_rdy),	// for normal operation
    //.app_wdf_rdy(),			// for fast simulation ONLY
// end fast simulation mods    
    .app_wdf_mask(16'h0000),                        // we never mask off any bytes
    // Read ports
    .app_rd_data(ddr3_rd_dat[127:0]),
    .app_rd_data_end(app_rd_data_end),
    .app_rd_data_valid(app_rd_data_valid),
    // User interface clock and reset   
    .ui_clk(ddr3_domain_clk),
    .ui_clk_sync_rst(ddr3_domain_reset),
    // Odds-n-Ends
    .app_sr_req(1'b0),                              // input, reserved, should be 0
    .app_sr_active(),                               // output, reserved
    .app_ref_req(1'b0),                             // input, request for refresh cycle
    .app_ref_ack(),                                 // output, a refresh has been requested
    .app_zq_req(1'b0),                              // input, request a ZQ calibration
    .app_zq_ack(),                                  // output, a ZQ calibration has been requested
    .init_calib_complete(init_calib_complete),      // output, PHY calibration is done
    .device_temp_i(xadc_temp[11:0]),                // input, temperature measured by XADC
    .device_temp()                                  // output,
    // Debug Ports
    // .ddr3_ila_basic(ddr3_ila_basic),
    // .ddr3_ila_wrpath(ddr3_ila_wrpath),
    // .ddr3_ila_rdpath(ddr3_ila_rdpath),
    // .ddr3_vio_sync_out(ddr3_vio_sync_out),
    // .dbg_pi_counter_read_val(dbg_pi_counter_read_val),
    // .dbg_sel_pi_incdecdbg_sel_pi_incdec),
    // .dbg_po_counter_read_val(dbg_po_counter_read_val),
    // .dbg_sel_po_incdec(dbg_sel_po_incdec),
    // .dbg_byte_sel(dbg_byte_sel),
    // .dbg_pi_f_inc(dbg_pi_f_inc),
    // .dbg_pi_f_dec(dbg_pi_f_dec),
    // .dbg_po_f_inc(dbg_po_f_inc),
    // .dbg_po_f_stg23_sel(dbg_po_f_stg23_sel),
    // .dbg_po_f_dec(dbg_po_f_dec),
);


//*************************************************************************
// read data shift latch
//   data should come in bursts of qty 8 16 bit words
//   shift them in and then tell the reader when they are valid (TBD)
//*************************************************************************
//always @ (posedge ui_clk)
//begin
//  if (app_rd_data_valid)
//      data_out[127:0] <= app_rd_data[127:0];
//  else
//      data_out[127:0] <= data_out[127:0];

//end


//*************************************************************************
// state machine to drive the ddr app interface
//*************************************************************************

// write cycle
//  app_cmd:  driven 000 = Write, 001 = Read
//  app_en:   driven 1= enable
//  app_rdy:  read 1 = ready for command
//  app_wdf_data
//  app_wdf_wren
//  app_wdf_wend
//
//  check for app_rdy = 1 then drive app_en simultaneous with app_cmd,
//  app_addr, app_wdf_data, app_wdf_wren, app_wdf_end  


// read cycle
//  app_cmd:  driven 000 = Write, 001 = Read
//  app_en:   driven 1= enable
//  app_rdy:  read 1 = ready for command
//  app_rd_data
//  app_rd_data_valid


//  check for app_rdy = 1 then drive app_en simultaneous with app_cmd,
//  app_addr
//  check for app_data_valid and simultaneously latch app_rd_data


// states:      IDLE, 
//      READ_CHK_RDY 
//      READ_CMD 
//      READ_CHK_VALID 
//
//      WRITE_CHK_RDY
//      WRITE_CMD
//      WRITE_DRIVE
//  
//      REMOVE_STROBE

//parameter S1 = 8'b00000001;
//parameter S2 = 8'b00000010;
//parameter S3 = 8'b00000100;
//parameter S4 = 8'b00001000;
//parameter S5 = 8'b00010000;
//parameter S6 = 8'b00100000;
//parameter S7 = 8'b01000000;
//parameter S8 = 8'b10000000;

//reg[7:0] ddr3_state = S1;

//always @ (posedge ui_clk)
//begin
//  if (ui_clk_sync_rst)
//      begin
//          app_cmd <= 3'b000;
//          app_en <= 1'b0;
//          app_wdf_wren <= 1'b0;
//          app_wdf_end <= 1'b0;
//      end
//  else
//      begin
//          case (ddr3_state)
//              //IDLE
//              S1 : begin
//                  app_cmd <= 3'b000;
//                  app_en <= 1'b0;
//                  app_wdf_wren <= 1'b0;
//                  app_wdf_end <= 1'b0;
//                  if (rd_enS)         // get a read command
//                      ddr3_state <= S2;
//                  else if (wr_enS)
//                      ddr3_state <= S5;
//                  else
//                      ddr3_state <= S1;
//              end
                
//              //READ_CHK_RDY
//              S2 : begin
//                  app_cmd <= 3'b000;
//                  app_en <= 1'b0;
//                  app_wdf_wren <= 1'b0;
//                  app_wdf_end <= 1'b0;
//                  if (app_rdy)            //the app must be ready
//                      ddr3_state <= S3;
//                  else
//                      ddr3_state <= S2;
//              end
                
//              //READ_CMD
//              S3 : begin
//                  app_cmd <= 3'b001;
//                  app_en <= 1'b1;
//                  app_wdf_wren <= 1'b0;
//                  app_wdf_end <= 1'b0;
//                  if (!app_rdy)           //make sure it is still ready
//                      ddr3_state <= S3;
//                  else
//                      ddr3_state <= S4;
//              end
                
//              //READ_CHK_VALID
//              S4 : begin
//                  app_cmd <= 3'b001;
//                  app_en <= 1'b0;
//                  app_wdf_wren <= 1'b0;
//                  app_wdf_end <= 1'b0;
//                  if (app_rd_data_valid)      //valid will go away when the data is done
//                      ddr3_state <= S4;
//                  else
//                      ddr3_state <= S8;
//              end
                
//              //WRITE_CHK_RDY
//              S5 : begin
//                  app_cmd <= 3'b000;
//                  app_en <= 1'b0;
//                  app_wdf_wren <= 1'b0;
//                  app_wdf_end <= 1'b0;
//                  if (app_rdy)            //the app must be ready
//                      ddr3_state <= S6;
//                  else
//                      ddr3_state <= S5;

//              end

//              //WRITE_CMD
//              S6 : begin
//                  app_cmd <= 3'b000;
//                  app_en <= 1'b1;
//                  app_wdf_wren <= 1'b0;
//                  app_wdf_end <= 1'b0;
//                  if (!app_rdy)           //make sure it is still ready
//                      ddr3_state <= S6;
//                  else
//                      ddr3_state <= S7;

//              end

//              //WRITE_DRIVE
//              S7 : begin
//                  app_cmd <= 3'b000;
//                  app_en <= 1'b0;
//                  app_wdf_wren <= 1'b1;       //data is assumed to be stable
//                  app_wdf_end <= 1'b1;        //single word writes for now
//                  if (!app_wdf_rdy)       //seperate write ready to check
//                      ddr3_state <= S7;
//                  else
//                      ddr3_state <= S8;
//              end

//              //REMOVE_STROBE
//              S8 : begin
//                  app_cmd <= 3'b000;
//                  app_en <= 1'b0;
//                  app_wdf_wren <= 1'b0;
//                  app_wdf_end <= 1'b0;
//                  if (rd_enS || wr_enS)       //wait till the strobe is removed
//                      ddr3_state <= S8;
//                  else
//                      ddr3_state <= S1;                   

//              end


//          endcase
//      end



//end


//*************************************************************************
// debug assignments
//*************************************************************************
//assign debug[7] = ui_clk;
//assign debug[6] = wr_enS;
//assign debug[5] = rd_enS;
//assign debug[4] = app_rdy; 
//assign debug[3] = app_wdf_rdy; 
//assign debug[2] = app_en;
//assign debug[1] = app_rd_data_valid;
//assign debug[0] = app_rd_data_end;


endmodule

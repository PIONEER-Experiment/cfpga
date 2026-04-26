`timescale 1ns / 10ps

module ddr3_intf_selftrigc(
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
    output high_water_warning,                  // passed ddr3 high water mark -- must pause data taking
    input acq_done,                             // input from the adc_acq_sm, aquisition is done
    input [22:0] fill_address,                  // starting address of fill
    output fill_address_rd_en,                  // we've used this address, read it off the fifo
    input fill_address_fifo_empty,              // the fill address for this fill is available when low
    // reading connections
    input local_domain_clk,                     // input, the local interface synchronous clock
    input fill_header_fifo_reset,               // input, clear out the fifo for a new run
    output fill_header_fifo_empty,              // output, a header is available when not asserted
    input fill_header_fifo_rd_en,               // input, remove the current data from the FIFO
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
    // states
    output [ 2:0] ddr3_rd_ctrl_state,            // read control current state
    output [16:0] ddr3_wr_ctrl_state,            // write control current state

    input [11:0] xadc_temp,
    input enable_triggering,
    input enable_acquisition
);

//wire app_rdy;
// for fast simulation uncomment the next 3 lines, and comment out lines marked farther into this file.
//wire app_wdf_rdy;				// for fast simulation ONLY
//assign app_rdy = 1'b1;		// for fast simulation ONLY
//assign app_wdf_rdy = 1'b1;	// for fast simulation ONLY
// end fast simulation mods    

// sync some signals into the various domains
wire enable_triggering_ddr3;
wire enable_triggering_125;
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
wire ddr3_wr_en_dbg;
assign ddr3_wr_en_dbg = ddr3_wr_en_sync2;

//synchronize the 'cbuf_rd_en' signal
(* ASYNC_REG = "TRUE" *) reg cbuf_rd_en_sync1, cbuf_rd_en_sync2;
always @(posedge ddr3_domain_clk) begin
    cbuf_rd_en_sync1 <= cbuf_rd_en;
    cbuf_rd_en_sync2 <= cbuf_rd_en_sync1;
end

wire [25:0] ddr3_wr_addr;
wire [25:0] ddr3_rd_addr;
wire [151:0] fill_header_wr_dat;
wire [26:0] app_addr;
wire [2:0] app_cmd;
wire [127:0] ddr3_rd_dat;
wire [127:0] ddr3_wr_dat;

// just pass the DDR3 data thru to the FIFO
assign ddr3_rd_fifo_input_dat[127:0] = ddr3_rd_dat[127:0];

////////////////////////////////////////////////////////////////
assign addressing_acq_enabled = writing_last_fill | ddr3_wr_en_sync2;
// Connect the module that manages the address and command ports
ddr3_addr_control ddr3_addr_control (
    // 'write' ports
    .wr_addr(ddr3_wr_addr[25:0]),           // input, next 'write' address
    .wr_app_rdy(wr_app_rdy),                // output, increment the 'write' address
    .wr_app_en(wr_app_en),                  // input, request to perform a 'write'  
    .acq_enabled(addressing_acq_enabled),        // input, writing is enabled
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
wire fill_header_wr_en;
ddr3_wr_control_selftrigc ddr3_wr_control_selftrigc (
    // User interface clock and reset
    .clk(ddr3_domain_clk),
    .reset(ddr3_domain_reset),
    .acq_enabled(cbuf_rd_en_sync2),                 // input, writing from cbuf to ddr3 has been enabled for a fill.
    // Connections to the FIFO from the ADC
    .ddr3_wr_fifo_dat(ddr3_wr_fifo_dat[131:0]),     // input, next 'write' data from the ADC FIFO
    .ddr3_wr_fifo_empty(ddr3_wr_fifo_empty),        // input, data is available when this is not asserted
    .ddr3_wr_fifo_rd_en(ddr3_wr_fifo_rd_en),        // output, use and remove the data on the FIFO head
    // 'write' ports to memory
    .app_wdf_end(app_wdf_end),                      // output, last data cycle
    .app_wdf_rdy(app_wdf_rdy),                      // input, memory can accept data
    .app_wdf_wren(app_wdf_wren),                    // output, request to perform a 'write' 
    .fill_address(fill_address),                    // the starting address of this fill
    .fill_address_rd_en(fill_address_rd_en),      // we've used this address, mark it read
    .fill_address_fifo_empty(fill_address_fifo_empty), // the fill address for this fill is available  when low
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
    .enable_triggering_ddr3(enable_triggering_ddr3),
    .enable_acquisition_ddr3(enable_acquisition),
    // next batch for debugging, eliminate when done
    //.fill_header_fifo_empty(fill_header_fifo_empty),
    //.fill_header_fifo_rd_en(fill_header_fifo_rd_en),
    //.ddr3_wr_en_sync2(ddr3_wr_en_sync2),
    //.app_rdy(app_rdy),
    // done debugging
    .ddr3_wr_ctrl_state(ddr3_wr_ctrl_state),        // write control current state
    .acq_done(acq_done),                            // input, asserted when the 'adc_acq_sm' is in the DONE state
    .writing_last_fill(writing_last_fill)
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
    .ddr3_rd_fifo_input_tlast(ddr3_rd_fifo_input_tlast),   // the last burst for this fill 
    .ddr3_rd_ctrl_state(ddr3_rd_ctrl_state)                 // read control current state
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

endmodule

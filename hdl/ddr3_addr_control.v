`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////
// This is the module that manages the address and command ports of the DDR3 memory.
// It switches the address and command between writing and reading.
//
// The 'wr_mode' input will be asserted whenever there is more fill data expected 
// from the ADC fifo. It will be asserted whenever the remaining 'burst count'
// is not zero.
//
// The 'wr_request' or 'rd_request' will be issued when data is actually available
// for writing or desired from reading.
//
// The 'wr_addr_ack' or 'rd_addr_ack' outputs will be asserted when the address
// and command have been accepted by the memory controller.

module ddr3_addr_control(
	input wr_mode,					// use the 'write' port when asserted
	// 'write' ports
	input [25:0] wr_addr,			// input, next 'write' address
	input wr_request,				// input, request to perform a 'write'	
	output wr_addr_ack,				// output, increment the 'write' address
	// 'read' ports
	input [25:0] rd_addr,			// input, next 'read' address
	input rd_request,				// input, request to perform a 'read'	
	output rd_addr_ack,				// output, increment the 'read' address
	// 'memory' ports
	output [26:0] app_addr,	
	output [2:0] app_cmd,
	output app_en,					// strobe for 'app_addr' and 'app_cmd'
	input app_rdy					// the memory is accepting an address and command
);

// use the mode input to switch between using the 'write' ports or the 'read'
// ports to drive the 'memory' ports.
assign app_addr[26:0] = wr_mode ? {1'b0, wr_addr[25:0]} : {1'b0, rd_addr[25:0]};

//CMD 001 = Read, 000 = Write
assign app_cmd[2:0] = wr_mode ? 3'b000 : 3'b001;

// Drive 'app_en' with the 'request' that goes with the 'mode'
assign app_en =  (wr_mode && wr_request) | (!wr_mode && rd_request);

// If 'app_en' and 'app_rdy' are both asserted when the clock rises, then the
// address and command have been accepted. Acknowledge that back to the controler.
// It will increment the associated address and decrement the word count. 
assign 	wr_addr_ack =  ( wr_mode && wr_request && app_rdy);
assign 	rd_addr_ack =  (~wr_mode && rd_request && app_rdy);

endmodule

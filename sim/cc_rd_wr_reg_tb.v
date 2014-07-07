`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: Xilinx Inc 
// Engineer: 
//
// Create Date:   14:31:39 12/22/2010
// Design Name:   bft
// Module Name:   bft_tb.v
// Project Name:  
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Bench for module: bft
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module cc_rd_wr_reg_tb;

	// Inputs
	reg clk;
	reg resetN;
	reg [31:0] rx_data;
	reg [0:3] rx_tkeep;
	reg rx_tvalid;
	reg rx_tlast;
	reg tx_tready;

	// Outputs
	wire rx_tready;
	wire [31:0] tx_data;
	wire [0:3] tx_tkeep;
	wire tx_tvalid;
	wire tx_tlast;

 ///////////////////////////////////////////////////////////////////////////////////
  // Connect the command processor. This will receive commands from the Aurora serial
  // link and process them
  command_top uut(
    // clocks and reset
    .clk(clk),                        // clock for the interconnect side of the FIFOs
    .resetN(resetN),          // active-lo reset for the interconnect side of the FIFOs
    // channel 0 connections
    // connections to 4-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
    // RX Interface to master side of receive FIFO for receiving from the Master FPGA
    .rx_data(rx_data[31:0]),       // note index order
    .rx_tkeep(rx_tkeep[0:3]),        // note index order
    .rx_tvalid(rx_tvalid),
    .rx_tlast(rx_tlast),
    .rx_tready(rx_tready),            // input wire m_axis_tready
    // TX interface to slave side of transmit FIFO for sending to the Master FPGA 
    .tx_data(tx_data[31:0]),        // note index order
    .tx_tkeep(tx_tkeep[0:3]),         // note index order
    .tx_tvalid(tx_tvalid),
    .tx_tlast(tx_tlast),
    .tx_tready(tx_tready)
	);
	
	initial begin
		// Initialize Inputs
		clk = 0;
		resetN = 1;
		rx_tvalid = 0;
		rx_tlast = 0;
        tx_tready = 0;
		// Wait 100 ns for global reset to finish
		#100;
      resetN = 1;
        
		// Add stimulus here
   end

   initial
      $timeformat (-9, 3, " ns", 13);

   parameter CLK_PERIOD = 10;

	always begin
		#(CLK_PERIOD/2) clk = ~clk;
	end
	
    initial begin
        #110 resetN = 1'b0;
		#20  resetN = 1'b1;
	end
	
    initial begin 
    // the TX fifo will always be ready
	#150 tx_tready = 1'b1;

    // write to a register
    // send the CSN
	#10	rx_data = 32'h10000001; rx_tvalid = 1'b1;
	    while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
		
    // send the CC for WR_REG
	#20	rx_data = 32'h00000003; rx_tvalid = 1'b1;	
	    while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
    
	#20
		//send the register number
		rx_data = 31'h00000005; rx_tvalid = 1'b1;	
    	while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;

	#20
		// send the register data
		rx_data = 32'h55555555; rx_tvalid = 1'b1; rx_tlast = 1'b1;	
        while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
		rx_tlast = 1'b0;

    // delay before another operation
    #150
    // write to a register
    // send the CSN
	#10	rx_data = 32'h10000002; rx_tvalid = 1'b1;
	    while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
		
    // send the CC for WR_REG
	#20	rx_data = 32'h00000003; rx_tvalid = 1'b1;	
	    while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
    
	#20
		//send the register number
		rx_data = 31'h00000006; rx_tvalid = 1'b1;	
    	while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;

	#20
		// send the register data
		rx_data = 32'h22222222; rx_tvalid = 1'b1; rx_tlast = 1'b1;	
        while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
		rx_tlast = 1'b0;

    // delay before another operation
    #150
    // read from a register
    // send the CSN
	#10	rx_data = 32'h10000003; rx_tvalid = 1'b1;
	    while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
		
    // send the CC for RD_REG
	#20	rx_data = 32'h00000002; rx_tvalid = 1'b1;	
	    while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
    
	#20
		//send the register number
		rx_data = 31'h00000005; rx_tvalid = 1'b1; rx_tlast = 1'b1;	
    	while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
		rx_tlast = 1'b0;
	    

   // delay before another operation
    #150
    // read from a register
    // send the CSN
	#10	rx_data = 32'h10000004; rx_tvalid = 1'b1;
	    while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
		
    // send the CC for RD_REG
	#20	rx_data = 32'h00000002; rx_tvalid = 1'b1;	
	    while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
    
	#20
		//send the register number
		rx_data = 31'h00000006; rx_tvalid = 1'b1; rx_tlast = 1'b1;	
    	while (rx_tready == 1'b0) begin #10; end
		rx_tvalid = 1'b0;
		rx_tlast = 1'b0;
    end  
endmodule


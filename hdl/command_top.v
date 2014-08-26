`timescale 1ns / 1ps
`include "constants.txt"
// command_top.v
//
// This module executed commands received on the Aurora interface.
//

module command_top(
	// clocks and reset
    input clk,                   // 125 MHz, clock for the interconnect side of the FIFOs
    input resetN,                // active-lo reset for the interconnect side of the FIFOs
    // channel connections
    // connections to 4-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
    // RX Interface to master side of receive FIFO for receiving from the Master FPGA
    input  [31:0] rx_data,       // note index order
    input  [0:3] rx_tkeep,        // note index order
    input  rx_tvalid,
    input  rx_tlast,
    output rx_tready,            // input wire m_axis_tready
    // TX interface to slave side of transmit FIFO for sending to the Master FPGA 
    output [31:0] tx_data,        // note index order
    output [0:3] tx_tkeep,         // note index order
    output tx_tvalid,
    output tx_tlast,
    input  tx_tready,
	// interface to the ADC data memory and header FIFO
	output [11:0] ADC_data_mem_addrb,		// output wire [11 : 0] addrb
    input [31:0] ADC_data_mem_doutb,		// input wire [31 : 0] doutb
	output ADC_header_fifo_rd_en,			// output wire rd_en
	input [31:0] ADC_header_fifo_dout,		// input wire [31 : 0] dout
	input ADC_header_fifo_empty,			// input wire empty
	// temporary use of registers to write to the ADC memory and ADC header FIFO
	output ADC_data_mem_wea,      // input wire [0 : 0] wea
	output [11:0] ADC_data_mem_addra,  // input wire [11 : 0] addra
	output [31:0] ADC_data_mem_dina,    // input wire [31 : 0] dina
	output [31:0] ADC_header_fifo_din,        // input wire [31 : 0] din
	output ADC_header_fifo_wr_en,    // input wire wr_en
	// Register to/from the ADC acquisition state machine
	output [31:0] ADC_buffer_size,		// number of words in the data stream (2 samples per word)
	output [31:0] ADC_channel_num,		// the number for this channel
	output [31:0] ADC_post_trig_size,	// number of words to continue acquiring after a trigger
	output [31:0] ADC_initial_trig_num,	// initial value for the event number
	output ADC_trig_num_we,				// enable saving of the initial value for the event number
	input [31:0] ADC_current_trig_num	// the current value for the event number
);

	// temporary use of registers to write to the ADC memory and ADC header FIFO
	// the data inputs for the memory and fifo are just the received data
	assign ADC_data_mem_dina[31:0] = rx_data[31:0];    // input wire [31 : 0] dina
	assign ADC_header_fifo_din[31:0] = rx_data[31:0];        // input wire [31 : 0] din

	wire ser_num_le, command_le;
	// make active-hi reset
	wire reset;
	assign reset = ~resetN;
	// always drive all 4 'tx_tkeep' bits
	assign tx_tkeep[0:3] = 4'b1111;
	
	wire [31:0] reg_data;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// connect registers to hold the incoming serial number and command
	reg [31:0] command_reg;
	reg [31:0] serial_num_reg;
	always @ (posedge clk) begin
		if (reset) 
			serial_num_reg <= 32'b0;
		else if (ser_num_le) 
			serial_num_reg[31:0] <= rx_data[31:0];
		else
			serial_num_reg[31:0] <= serial_num_reg[31:0];
	end
	always @ (posedge clk) begin
		if (reset)
			command_reg <= 32'b0;
		else if (command_le)
			command_reg[31:0] <= rx_data[31:0];
		else
			command_reg[31:0] <= command_reg[31:0];
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// generate 'run' signals for the state machines that handle individual commands
	// start with 'run_cmd_sm' which is a 'run someone' from the command sm.
	// Use the actual command from the command register to activate 1 particular sm.
	wire run_cmd_sm;    
	wire run_cc_no_cmd, run_cc_loopback, run_cc_rd_reg, run_cc_wr_reg, run_cc_rd_patmem,
		 run_cc_wr_patmem, run_cc_rd_mem, run_cc_wr_mem, run_cc_rd_fill, run_cc_rd_adc;
	assign run_cc_no_cmd     = (run_cmd_sm && (command_reg[4:0] == `CC_LOOPBACK));
	assign run_cc_loopback   = (run_cmd_sm && (command_reg[4:0] == `CC_LOOPBACK));
	assign run_cc_rd_reg     = (run_cmd_sm && (command_reg[4:0] == `CC_RD_REG));
	assign run_cc_wr_reg     = (run_cmd_sm && (command_reg[4:0] == `CC_WR_REG));
	assign run_cc_rd_patmem  = (run_cmd_sm && (command_reg[4:0] == `CC_RD_PATMEM));
	assign run_cc_wr_patmem  = (run_cmd_sm && (command_reg[4:0] == `CC_WR_PATMEM));
	assign run_cc_rd_mem     = (run_cmd_sm && (command_reg[4:0] == `CC_RD_MEM));
	assign run_cc_wr_mem     = (run_cmd_sm && (command_reg[4:0] == `CC_WR_MEM));
	assign run_cc_rd_fill    = (run_cmd_sm && (command_reg[4:0] == `CC_RD_FILL));
	assign run_cc_rd_adc     = (run_cmd_sm && (command_reg[4:0] == `CC_RD_ADC));

	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// merge 'running' and 'done' signals from the state machines that handle individual commands.
	// only 1 of each, from the activated sm, should ever be active at the same time
	wire cmd_sm_running;
	wire cc_loopback_running, cc_rd_reg_running, cc_wr_reg_running, cc_rd_fill_running ;
	   // cc_no_cmd_running, , cc_rd_patmem_running,
	   // cc_wr_patmem_running, cc_rd_mem_running, cc_wr_mem_running, cc_rd_adc_running;
	assign cmd_sm_running = cc_loopback_running || cc_rd_reg_running || cc_wr_reg_running || cc_rd_fill_running ;
	   // cc_no_cmd_running || cc_rd_reg_running || cc_wr_reg_running || cc_rd_patmem_running
	   // || cc_wr_patmem_running || cc_rd_mem_running || cc_wr_mem_running|| cc_rd_adc_running;

	wire cmd_sm_done;
	wire cc_loopback_done, cc_rd_reg_done, cc_wr_reg_done, cc_rd_fill_done;
	   // cc_no_cmd_done, , cc_rd_patmem_done,
	   // cc_wr_patmem_done, cc_rd_mem_done, cc_wr_mem_done, , cc_rd_adc_done;
	assign cmd_sm_done = cc_loopback_done || cc_rd_reg_done || cc_wr_reg_done || cc_rd_fill_done ;
	   //cc_no_cmd_done  || cc_rd_patmem_done
	   // || cc_wr_patmem_done || cc_rd_mem_done || cc_wr_mem_done || cc_rd_adc_done;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// every state machine will need to drive certain FIFO control lines
	wire command_top_sm_rx_tready, loopback_sm_rx_tready, rd_reg_sm_rx_tready, wr_reg_sm_rx_tready;
	   //no_cmd_sm_rx_tready,
	   //, rd_patmem_sm_rx_tready, wr_patmem_sm_rx_tready, rd_mem_sm_rx_tready,
	   //wr_mem_sm_rx_tready, , rd_adc_sm_rx_tready;
	assign rx_tready = command_top_sm_rx_tready || loopback_sm_rx_tready || rd_reg_sm_rx_tready
					|| wr_reg_sm_rx_tready;
	    //|| no_cmd_sm_rx_tready
		// || rd_patmem_sm_rx_tready || wr_patmem_sm_rx_tready || rd_mem_sm_rx_tready
		//|| wr_mem_sm_rx_tready || rd_adc_sm_rx_tready;
		 
	wire loopback_sm_tx_tvalid, rd_reg_sm_tx_tvalid, wr_reg_sm_tx_tvalid, rd_fill_sm_tx_tvalid;
	   // no_cmd_sm_tx_tvalid
	   // , rd_patmem_sm_tx_tvalid, wr_patmem_sm_tx_tvalid, rd_mem_sm_tx_tvalid,
	   // wr_mem_sm_tx_tvalid, , rd_adc_sm_tx_tvalid;
	assign tx_tvalid = loopback_sm_tx_tvalid || rd_reg_sm_tx_tvalid || wr_reg_sm_tx_tvalid
					|| rd_fill_sm_tx_tvalid ;
	   // no_cmd_sm_tx_tvalid 
	   //	 || rd_patmem_sm_tx_tvalid || wr_patmem_sm_tx_tvalid || rd_mem_sm_tx_tvalid
	   //	|| wr_mem_sm_tx_tvalid || rd_adc_sm_tx_tvalid;

	wire loopback_sm_tx_tlast, rd_reg_sm_tx_tlast, wr_reg_sm_tx_tlast, rd_fill_sm_tx_tlast;
	   // no_cmd_sm_tx_tlast
	   //	, rd_patmem_sm_tx_tlast, wr_patmem_sm_tx_tlast, rd_mem_sm_tx_tlast,
	   //	wr_mem_sm_tx_tlast, , rd_adc_sm_tx_tlast;
	assign tx_tlast = loopback_sm_tx_tlast || rd_reg_sm_tx_tlast || wr_reg_sm_tx_tlast
					|| rd_fill_sm_tx_tlast;
	   // no_cmd_sm_tx_tlast
	   //	|| rd_patmem_sm_tx_tlast || wr_patmem_sm_tx_tlast || rd_mem_sm_tx_tlast
	   //	|| wr_mem_sm_tx_tlast  || rd_adc_sm_tx_tlast;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// connect a big mux to steer data to the TX FIFO
	wire send_csn, send_cmd, send_inv_cmd, send_rx_data, send_reg_data, send_adc_header_data, send_adc_mem_data;
	reg [31:0] tx_data_reg;
	wire [31:0] adc_header_data;
	always @ (posedge clk) begin
		if (send_csn) tx_data_reg[31:0] <= serial_num_reg[31:0];	// serial number
		if (send_cmd) tx_data_reg[31:0] <= command_reg[31:0];		// command
		if (send_inv_cmd) tx_data_reg[31:0] <= ~command_reg[31:0];	// inverse of command
		if (send_rx_data) tx_data_reg[31:0] <= rx_data[31:0];		// loopback
		if (send_reg_data) tx_data_reg[31:0] <= reg_data[31:0];		// reading from a register
		if (send_adc_header_data) tx_data_reg[31:0] <= adc_header_data[31:0];		// ADC header, indirectly from FIFO
		if (send_adc_mem_data) tx_data_reg[31:0] <= ADC_data_mem_doutb[31:0];		// ADC data directly from memory
	end
	assign tx_data[31:0] = tx_data_reg[31:0];
	
	// create the mux control signals
	// All state machines need to send the CSN
	wire loopback_sm_send_csn, rd_reg_sm_send_csn, wr_reg_sm_send_csn, rd_fill_sm_send_csn;
	assign send_csn = loopback_sm_send_csn || rd_reg_sm_send_csn || wr_reg_sm_send_csn || rd_fill_sm_send_csn;
	
	// All state machines need to send the CC
	wire loopback_sm_send_cmd, rd_reg_sm_send_cmd, wr_reg_sm_send_cmd, rd_fill_sm_send_cmd;
	assign send_cmd = loopback_sm_send_cmd || rd_reg_sm_send_cmd || wr_reg_sm_send_cmd || rd_fill_sm_send_cmd;

	// Only a few state machines need to send the inverse CC
	wire rd_reg_sm_send_inv_cmd, wr_reg_sm_send_inv_cmd, rd_fill_sm_send_inv_cmd;
	assign send_inv_cmd = rd_reg_sm_send_inv_cmd || wr_reg_sm_send_inv_cmd || rd_fill_sm_send_inv_cmd;
	
	// Only the loopback state machine send RX DATA directly
	wire loopback_sm_send_rx_data;
	assign send_rx_data = loopback_sm_send_rx_data;
	
	// Only the read_register state machine sends register data
	assign send_reg_data = rd_reg_sm_send_reg_data;
	
	// Only the read_fill state machine sends ADC header data and ADC memory data
	assign send_adc_header_data = rd_fill_sm_send_adc_header_data;
	assign send_adc_mem_data = rd_fill_sm_send_adc_mem_data;
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// connect the state machine that receives and dispatches commands
	// This state machine never drives the transmit fifo 
	command_sm command_sm (
		.clk(clk),					// local clock
		.reset(reset),
		// RX fifo interface
		.rx_tvalid(rx_tvalid),            // valid data is available
		.rx_tkeep(rx_tkeep[0:3]),    // which bytes are valid, should always be all of them
		.rx_tlast(rx_tlast),              // final word in the frame
		.rx_tready(command_top_sm_rx_tready), // signal that we are accepting the data from the fifo
		// control outputs
		.ser_num_le(ser_num_le),          // latch the serial number
		.command_le(command_le),          // latch the command
		.run_cmd_sm(run_cmd_sm),   		  // run a state machine
		// control inputs
		.cmd_sm_running(cmd_sm_running),  // someone is running
		.cmd_sm_done(cmd_sm_done)		  // someone is finished
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// connect the state machine that processes the CC_LOOPBACK command
	cc_loopback_sm cc_loopback_sm (
		.clk(clk),					// local clock
		.reset(reset),				// active-hi
		// state machine control
		.run_sm(run_cc_loopback),   	    // run this state machine
		.sm_running(cc_loopback_running),	// we are running
		.sm_done(cc_loopback_done),			// we are finished
		// RX FIFO
		.rx_tvalid(rx_tvalid),				// valid data is available
		.rx_data(rx_data[31:0]), 				// received data
		.rx_tkeep(rx_tkeep),				// which bytes are valid, should always be all of them
		.rx_tlast(rx_tlast),				// final word in the frame
		.rx_tready(loopback_sm_rx_tready),	// signal that we are accepting the data from the fifo
		// TX FIFO
		.tx_tvalid(loopback_sm_tx_tvalid),	// the data we are presenting is valid
		.tx_tlast(loopback_sm_tx_tlast),	// this is the final word in the frame
		.tx_tready(tx_tready),				// the TX fifo is ready to accepted data
		// TX mux control
		.send_csn(loopback_sm_send_csn),    // send the CSN
		.send_cmd(loopback_sm_send_cmd),	// send the CC
		.send_rx_data(loopback_sm_send_rx_data)	// mux source is RX FIFO
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// connect the state machine that processes the CC_RD_REG command
	cc_rd_reg_sm cc_rd_reg_sm (
		.clk(clk),					// local clock
		.reset(reset),				// active-hi
		// state machine control
		.run_sm(run_cc_rd_reg),   	    // run this state machine
		.sm_running(cc_rd_reg_running),	// we are running
		.sm_done(cc_rd_reg_done),			// we are finished
		// RX FIFO
		.rx_tvalid(rx_tvalid),				// valid data is available
		.rx_data(rx_data[31:0]), 				// received data
		.rx_tkeep(rx_tkeep),				// which bytes are valid, should always be all of them
		.rx_tlast(rx_tlast),				// final word in the frame
		.rx_tready(rd_reg_sm_rx_tready),	// signal that we are accepting the data from the fifo
		// TX FIFO
		.tx_tvalid(rd_reg_sm_tx_tvalid),	// the data we are presenting is valid
		.tx_tlast(rd_reg_sm_tx_tlast),	    // this is the final word in the frame
		.tx_tready(tx_tready),				// the TX fifo is ready to accepted data
		// TX mux control
		.send_csn(rd_reg_sm_send_csn),      // send the CSN
		.send_cmd(rd_reg_sm_send_cmd),  	// send the CC
		.send_inv_cmd(rd_reg_sm_send_inv_cmd),  	// send the inverse CC
		.send_reg_data(rd_reg_sm_send_reg_data),	// mux source is the register bank
		//local controls
		.reg_num_le(rd_reg_sm_reg_num_le),		// enable saving the register number
		.rd_en(rd_reg_sm_reg_rd_en),		// enable reading the specific register
		.illegal_reg_num(illegal_reg_num)		// The desired register does not exist
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// connect the state machine that processes the CC_WR_REG command
	cc_wr_reg_sm cc_wr_reg_sm (
		.clk(clk),					// local clock
		.reset(reset),				// active-hi
		// state machine control
		.run_sm(run_cc_wr_reg),   	    // run this state machine
		.sm_running(cc_wr_reg_running),	// we are running
		.sm_done(cc_wr_reg_done),			// we are finished
		// RX FIFO
		.rx_tvalid(rx_tvalid),				// valid data is available
		.rx_data(rx_data[31:0]), 				// received data
		.rx_tkeep(rx_tkeep),				// which bytes are valid, should always be all of them
		.rx_tlast(rx_tlast),				// final word in the frame
		.rx_tready(wr_reg_sm_rx_tready),	// signal that we are accepting the data from the fifo
		// TX FIFO
		.tx_tvalid(wr_reg_sm_tx_tvalid),	// the data we are presenting is valid
		.tx_tlast(wr_reg_sm_tx_tlast),	    // this is the final word in the frame
		.tx_tready(tx_tready),				// the TX fifo is ready to accepted data
		// TX mux control
		.send_csn(wr_reg_sm_send_csn),      // send the CSN
		.send_cmd(wr_reg_sm_send_cmd),  	// send the CC
		.send_inv_cmd(wr_reg_sm_send_inv_cmd),  	// send the inverse CC
		//local controls
		.reg_num_le(wr_reg_sm_reg_num_le),		// enable saving the register number
		.wr_en(wr_reg_sm_reg_wr_en),		// enable writing to the specific register
		.illegal_reg_num(illegal_reg_num)		// The desired register does not exist
	);
	
	wire reg_num_le;
	assign reg_num_le = rd_reg_sm_reg_num_le || wr_reg_sm_reg_num_le;
	register_block register_block (
		// clocks and reset
		.clk(clk),                   // 125 MHz, clock for the interconnect side of the FIFOs
		.reset(reset),                 // reset 
		// incoming and outgoing data
        .rx_data(rx_data[31:0]),       // note index order
		.tx_data(reg_data[31:0]),
		// controls
		.rd_en(rd_reg_sm_reg_rd_en),			// enable reading of the specific register
		.wr_en(wr_reg_sm_reg_wr_en),			// enable writing to the specific register
		.reg_num_le(reg_num_le),				// enable saving of the selected register number
		.illegal_reg_num(illegal_reg_num),		// The desired register does not exist
		// temporary connections for writing to the ADC memory and header FIFO
		.ADC_data_mem_wea(ADC_data_mem_wea),      // input wire [0 : 0] wea
		.ADC_data_mem_addra(ADC_data_mem_addra),  // input wire [11 : 0] addra
		.ADC_header_fifo_wr_en(ADC_header_fifo_wr_en),    // input wire wr_en
		// Register to/from the ADC acquisition state machine
		.buffer_size(ADC_buffer_size),		// number of words in the data stream (2 samples per word)
		.channel_num(ADC_channel_num),		// the number for this channel
		.post_trig_size(ADC_post_trig_size),	// number of words to continue acquiring after a trigger
		.initial_trig_num(ADC_initial_trig_num),	// initial value for the event number
		.trig_num_we(ADC_trig_num_we),				// enable saving of the initial value for the event number
		.current_trig_num(ADC_current_trig_num)	// the current value for the event number
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// connect the state machine that processes the CC_RD_FILL command
	cc_rd_fill_sm cc_rd_fill_sm (
		.clk(clk),					// local clock
		.reset(reset),				// active-hi
		// state machine control
		.run_sm(run_cc_rd_fill),   	    // run this state machine
		.sm_running(cc_rd_fill_running),	// we are running
		.sm_done(cc_rd_fill_done),			// we are finished
		// RX FIFO - this sm does not get anything from the RX FIFO
		// TX FIFO
		.tx_tvalid(rd_fill_sm_tx_tvalid),	// the data we are presenting is valid
		.tx_tlast(rd_fill_sm_tx_tlast),	    // this is the final word in the frame
		.tx_tready(tx_tready),				// the TX fifo is ready to accepted data
		// TX mux control
		.send_csn(rd_fill_sm_send_csn),      // send the CSN
		.send_cmd(rd_fill_sm_send_cmd),  	// send the CC
		.send_inv_cmd(rd_fill_sm_send_inv_cmd),  	// send the inverse CC
		.send_adc_header_data(rd_fill_sm_send_adc_header_data),	// mux source is the ADC header
		.send_adc_mem_data(rd_fill_sm_send_adc_mem_data),	// mux source is the ADC memory
		//local controls
		// interface to the ADC data memory and header FIFO
		.ADC_data_mem_addrb(ADC_data_mem_addrb),		// output wire [11 : 0] addrb
		.ADC_data_mem_doutb(ADC_data_mem_doutb),		// input wire [31 : 0] doutb
		.ADC_header_fifo_rd_en(ADC_header_fifo_rd_en),	// output wire rd_en
		.ADC_header_fifo_dout(ADC_header_fifo_dout),	// input wire [31 : 0] dout
		.ADC_header_fifo_empty(ADC_header_fifo_empty),	// input wire empty
		.adc_header_data(adc_header_data)
	);
	
	endmodule

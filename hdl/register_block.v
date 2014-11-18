// register_block.v
//
// This module provides access to 16 32-bit registers. R/W = read/write, RO = read-only
//
// ADC data comes in pairs of 800 MHz samples. All references to ADC data counts is in terms
// of pairs of words packed into a 32-bit word.
//
// R0: R/W Initial Trigger Number - ADC events will be numbered starting with this value. This
//             is a 32-bit register that will wrap around. Large numbers may appear negative
//             to some programs.
//
// R1: RO  Next Trigger Number - The next ADC event will be assigned this value. Needs at least
//             one 'arm' event after reset to become valid. This is a 32-bit register that will
//             wrap around. Large numbers may appear negative to some programs.
//
// R2: R/W ADC Buffer Size - This register controls the number of 32-bit ADC data words that are
//            transmitted in response to a 'CC_RD_FILL' command. It is limited to 4095. 
//
// R3: R/W ADC Channel Number - This register controls the value of the channel number that is in
//             the ADC data header. It is a 32-bit number. Initialization code may want to insert
//             board numbers and crate numbers along with the actual channel number.
//
// R4: R/W ADC Post Trigger Count - This register control the number of ADC data words that
//             continue to be stored after a trigger is received. It is a 32-bit number that will
//             allow one to collect data long after the trigger has been seen. The amount of data
//             will still be limited by the ADC buffer size and the actual memory size.
// R5:  generic register address and control
// R6:  generic register wr
// R7:  generic register rd
// R8:
// R9:
// R10:
// R11:
// R12:
//
// R13: R/W Test Memory Address - This register holds the address in the Test Memory that will be
//              used for the next memory access using register R14. Only the low 12 bits are used.
//
// R14: R/W Test Memory Data - This register is used to write data to the Test Memory, at the
//              address specified by register R13. It is a 32-bit number.
//
// R15: R/W Test FIFO Data - This register is used to write data to the Test FIFO. It is a 32-bit
//              number.



module register_block(
	// clocks and reset
    input clk,                   // 125 MHz, clock for the interconnect side of the FIFOs
    input reset,                 // reset 
    // data from/to Master FPGA
    input  [31:0] rx_data,       // note index order
	output [31:0] tx_data,
	input rd_en,			// enable reading of the specific register
	input wr_en,			// enable writing to the specific register
	input reg_num_le,		// enable saving of the selected register number
	output illegal_reg_num,	// The desired register does not exist
	// temporary use of registers to write to the ADC memory and ADC header FIFO
	output ADC_data_mem_wea,      // input wire [0 : 0] wea
	output [11:0] ADC_data_mem_addra,  // input wire [11 : 0] addra
	output ADC_header_fifo_wr_en,    // input wire wr_en
	// Register to/from the ADC acquisition state machine
	output [31:0] buffer_size,		// number of words in the data stream (2 samples per word)
	output [31:0] channel_num,		// the number for this channel
	output [31:0] post_trig_size,	// number of words to continue acquiring after a trigger
	output [31:0] initial_trig_num,	// initial value for the event number
	output trig_num_we,				// enable saving of the initial value for the event number
	input [31:0] current_trig_num,	// the current value for the event number
	output [31:0] genreg_addr_ctrl,	//generic register address and control output
	output [31:0] genreg_wr_data,	//generic register data written from Master FPGA 
	input [31:0] genreg_rd_data	//generic register data read by Master FPGA

);
			
	// make a register to hold the number of the selected register.
	// This will be a 32-bit, but only the lower bits are used.
	// If any upper bits are non-zero, an error flag will be raised
	reg [31:0] reg_num;
	
	always @ (posedge clk) begin
		if (reset)
			reg_num[31:0] <= 32'b0;
		else if (reg_num_le)
			reg_num[31:0] <= rx_data[31:0];
		else
			reg_num[31:0] <= reg_num[31:0];
	end
	// set the illegal flag if any upper bit is non-zero
	assign illegal_reg_num = (reg_num[31:4] == 28'h0000000) ? 1'b0 : 1'b1;
	
	//  make a block of 16 32-bit registers
	reg [31:0] reg0_, reg1_, reg2_, reg3_, 
				reg4_, reg5_, reg6_, reg7_,
				reg8_, reg9_, reg10_, reg11_,
				reg12_, reg13_, reg14_, reg15_;

	// write to the writable registers
	always @ (posedge clk) begin
		if (wr_en && (reg_num[3:0] == 4'h0)) reg0_[31:0] <= rx_data[31:0];
		// R1 is read-only
		// if (wr_en && (reg_num[3:0] == 4'h1)) reg1_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h2)) reg2_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h3)) reg3_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h4)) reg4_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h5)) reg5_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h6)) reg6_[31:0] <= rx_data[31:0];
		//R7 is read only
		//if (wr_en && (reg_num[3:0] == 4'h7)) reg7_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h8)) reg8_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h9)) reg9_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'ha)) reg10_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'hb)) reg11_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'hc)) reg12_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'hd)) reg13_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'he)) reg14_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'hf)) reg15_[31:0] <= rx_data[31:0];
	end

	// Register to/from the ADC acquisition state machine
	// R0
	assign initial_trig_num[31:0] = reg0_[31:0];	// initial value for the event number
	// Send R0 'wr_en' to the ADC acquisition controller
	assign trig_num_we  = (wr_en && (reg_num[3:0] == 4'h0)) ? 1'b1 : 1'b0;

	// R1 is read-only
	
	// R2
	assign buffer_size[31:0]      = reg2_[31:0];		// number of words in the data stream (2 samples per word)

	// R3
	assign channel_num[31:0]      = reg3_[31:0];		// the number for this channel

	// R4
	assign post_trig_size[31:0]   = reg4_[31:0];	// number of words to continue acquiring after a trigger

	// R5
	assign genreg_addr_ctrl[31:0] = reg5_[31:0];	//address and control for the generic register interface

	// R6
	assign genreg_wr_data[31:0]  = reg6_[31:0];	//data written TO generic register interface

	// R7 is read only
	
	// temporary use of registers to write to the ADC memory and ADC header FIFO
	// Use R13 for the memory address
	assign ADC_data_mem_addra[11:0] = reg13_[11:0]; 

	// Use R14 'wr_en' for the memory write_enable
	assign ADC_data_mem_wea = (wr_en && (reg_num[3:0] == 4'he)) ? 1'b1 : 1'b0;

	// Use R15 'wr_en' for the header FIFO write_enable
	assign ADC_header_fifo_wr_en  = (wr_en && (reg_num[3:0] == 4'hf)) ? 1'b1 : 1'b0;
	
	reg [31:0] rdbk_reg;
	assign tx_data[31:0] = rdbk_reg[31:0];
	always @ (posedge clk) begin
		if (rd_en && (reg_num[3:0] == 4'h0)) rdbk_reg[31:0] <= reg0_[31:0];
		// R1 is read-only from outside of this module
		if (rd_en && (reg_num[3:0] == 4'h1)) rdbk_reg[31:0] <= current_trig_num[31:0];
		if (rd_en && (reg_num[3:0] == 4'h2)) rdbk_reg[31:0] <= reg2_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h3)) rdbk_reg[31:0] <= reg3_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h4)) rdbk_reg[31:0] <= reg4_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h5)) rdbk_reg[31:0] <= reg5_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h6)) rdbk_reg[31:0] <= reg6_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h7)) rdbk_reg[31:0] <= genreg_rd_data[31:0];  //data read from generic register interface
		if (rd_en && (reg_num[3:0] == 4'h8)) rdbk_reg[31:0] <= reg8_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h9)) rdbk_reg[31:0] <= reg9_[31:0];
		if (rd_en && (reg_num[3:0] == 4'ha)) rdbk_reg[31:0] <= reg10_[31:0];
		if (rd_en && (reg_num[3:0] == 4'hb)) rdbk_reg[31:0] <= reg11_[31:0];
		if (rd_en && (reg_num[3:0] == 4'hc)) rdbk_reg[31:0] <= reg12_[31:0];
		if (rd_en && (reg_num[3:0] == 4'hd)) rdbk_reg[31:0] <= reg13_[31:0];
		if (rd_en && (reg_num[3:0] == 4'he)) rdbk_reg[31:0] <= reg14_[31:0];
		if (rd_en && (reg_num[3:0] == 4'hf)) rdbk_reg[31:0] <= reg15_[31:0];
	end
endmodule	

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
	output ADC_header_fifo_wr_en    // input wire wr_en
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
		if (wr_en && (reg_num[3:0] == 4'h1)) reg1_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h2)) reg2_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h3)) reg3_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h4)) reg4_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h5)) reg5_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h6)) reg6_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h7)) reg7_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h8)) reg8_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'h9)) reg9_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'ha)) reg10_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'hb)) reg11_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'hc)) reg12_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'hd)) reg13_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'he)) reg14_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[3:0] == 4'hf)) reg15_[31:0] <= rx_data[31:0];
	end

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
		if (rd_en && (reg_num[3:0] == 4'h1)) rdbk_reg[31:0] <= reg1_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h2)) rdbk_reg[31:0] <= reg2_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h3)) rdbk_reg[31:0] <= reg3_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h4)) rdbk_reg[31:0] <= reg4_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h5)) rdbk_reg[31:0] <= reg5_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h6)) rdbk_reg[31:0] <= reg6_[31:0];
		if (rd_en && (reg_num[3:0] == 4'h7)) rdbk_reg[31:0] <= reg7_[31:0];
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
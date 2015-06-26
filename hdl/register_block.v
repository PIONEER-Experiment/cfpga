// register_block.v
//
// This module provides access to 32 32-bit registers. R/W = read/write, RO = read-only
//

module register_block(
	// clocks and reset
	input clk50,                             // 50 MHz buffered clock 
	input reset_clk50,                       // active-high reset output, goes low after startup
    input clk,                               // 125 MHz, clock for the interconnect side of the FIFOs
    input reset,                             // reset

    // data from/to Master FPGA
    input  [31:0] rx_data,                   // note index order
	output [31:0] tx_data,
	input rd_en,			                 // enable reading of the specific register
	input wr_en,			                 // enable writing to the specific register
	input reg_num_le,		                 // enable saving of the selected register number
	output illegal_reg_num,	                 // The desired register does not exist

	// Register to/from the ADC acquisition state machine
	input [23:0] fill_num,	                 // fill number for this fill
    output [15:0] channel_tag,		         // stuff about the channel to put in the header
	output [20:0] num_muon_bursts,	         // number of sample bursts in a MUON fill
	output [20:0] num_laser_bursts,          // number of sample bursts in a LASER fill
	output [20:0] num_ped_bursts,	         // number of sample bursts in a PEDESTAL fill
	output [23:0] initial_fill_num,          // event number to assign to the first fill
    output initial_fill_num_wr,              // write-strobe to store the initial_fill_num
	input [2:0] ch_addr,			         // the channel address jumpers
	output adc_buf_delay_data_reset,	     // use the new delay settings
	output [4:0] adc_buf_data_delay,	     // 5 delay-tap-bits per line, all lines always all the same
	input [64:0] adc_buf_current_data_delay, // 13 lines *5 bits/line, current tap settings
 
 	// generic register space connections
	output [31:0] genreg_addr_ctrl,	         // generic register address and control output
	output [31:0] genreg_wr_data,	         // generic register data written from Master FPGA 
	input [31:0] genreg_rd_data		         // generic register data read by Master FPGA
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
	assign illegal_reg_num = (reg_num[31:5] == 28'h0000000) ? 1'b0 : 1'b1;
	
	// make a block of 32 32-bit registers
	reg [31:0]         reg1_,
			   reg4_,  reg5_,  reg6_,  reg7_,
			           reg9_,  reg10_, reg11_,
			   reg12_, reg13_, reg14_, reg15_,
			   reg16_, reg17_, reg18_, reg19_,
			   reg20_, reg21_, reg22_, reg23_,
			   reg24_, reg25_, reg26_, reg27_,
			   reg28_, reg29_, reg30_, reg31_;

	// set non-zero default register values
	reg [31:0] reg0_ = 32'd1;     // initial fill number set to 1
	reg [31:0] reg2_ = 32'd70000; // muon fill burst count of 70,000
	reg [31:0] reg3_ = 32'd0;     // laser fill burst count of 0
	reg [31:0] reg4_ = 32'd0;     // pedestal fill burst count of 0
	reg [31:0] reg8_ = 32'd14;    // data bus delay tap value of 14

	// write to the writable registers
	always @ (posedge clk) begin
		if (wr_en && (reg_num[4:0] == 5'h00)) reg0_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h01)) reg1_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h02)) reg2_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h03)) reg3_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h04)) reg4_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h05)) reg5_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h06)) reg6_[31:0] <= rx_data[31:0];
		//if (wr_en && (reg_num[3:0] == 4'h7)) reg7_[31:0] <= rx_data[31:0]; //R7 is read only
		if (wr_en && (reg_num[4:0] == 5'h08)) reg8_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h09)) reg9_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h0a)) reg10_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h0b)) reg11_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h0c)) reg12_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h0d)) reg13_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h0e)) reg14_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h0f)) reg15_[31:0] <= rx_data[31:0];

		if (wr_en && (reg_num[4:0] == 5'h10)) reg16_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h11)) reg17_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h12)) reg18_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h13)) reg19_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h14)) reg20_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h15)) reg21_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h16)) reg22_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h17)) reg23_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h18)) reg24_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h19)) reg25_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h1a)) reg26_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h1b)) reg27_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h1c)) reg28_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h1d)) reg29_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h1e)) reg30_[31:0] <= rx_data[31:0];
		if (wr_en && (reg_num[4:0] == 5'h1f)) reg31_[31:0] <= rx_data[31:0];

	end

	// Register to/from the ADC acquisition state machine
	// R0 - initial value for the fill number
	assign initial_fill_num[23:0] = reg0_[23:0];
	// Send R0 'wr_en' to the ADC acquisition controller
	// fill number will be set back to initial value after a reset
	assign initial_fill_num_wr  = ((wr_en && (reg_num[4:0] == 5'h00)) | reset) ? 1'b1 : 1'b0;

	// R1 - channel tag
	// bits [2:0] from configuration jumpers
	assign channel_tag[2:0] = ch_addr[2:0];	     // the channel address jumpers
	assign channel_tag[15:3] = reg1_[15:3];
	
	// R2 - Muon fill burst count
	assign num_muon_bursts[20:0] = reg2_[20:0];

	// R3 - Laser fill burst count
	assign num_laser_bursts[20:0] = reg3_[20:0];

	// R4 - Pedestal fill burst count
	assign num_ped_bursts[20:0] = reg4_[20:0];

	// R5
	assign genreg_addr_ctrl[31:0] = reg5_[31:0]; // address and control for the generic register interface

	// R6
	assign genreg_wr_data[31:0]  = reg6_[31:0];	 // data written to generic register interface

	// R7 is read only

	// R8
	assign adc_buf_data_delay[4:0] = reg8_[4:0]; // tap value for the data bus delay
	// When we write a new delay, we need to assert 'adc_buf_delay_data_reset'. Use this SM.
	data_delay_reset data_delay_reset(
	    .clk(clk50),                                      // input, 50 MHz buffered clock
	    .reset(reset_clk50),                              // input, start-up reset to initialize SM
	    .delay_tap(adc_buf_data_delay[4:0]),              // input [4:0], tap delay to set from register block
	    .wiz_delay_tap(adc_buf_current_data_delay[64:0]), // input [64:0], tap values according to the wizard
	    .delay_data_reset(adc_buf_delay_data_reset),      // output, active-high reset
	    .error(adc_buf_delay_data_error)                  // output, tap values not set properly
	);
	

	reg [31:0] rdbk_reg;
	assign tx_data[31:0] = rdbk_reg[31:0];
	always @ (posedge clk) begin
		// R0 is read back from the fill counter outside of this module
		if (rd_en && (reg_num[4:0] == 5'h00)) rdbk_reg[31:0] <= {8'b0, fill_num[23:0]};
		// R1 bits [2:0] from the channel address jumpers
		// R1 bits [31:16] always read back as zero
		if (rd_en && (reg_num[4:0] == 5'h01)) rdbk_reg[31:0] <= {16'h0000, reg1_[15:3], ch_addr[2:0]};
		// R2, R3, R4 bits [31:21] always read back as zero
		if (rd_en && (reg_num[4:0] == 5'h02)) rdbk_reg[31:0] <= {11'h0000, reg2_[21:0]};
		if (rd_en && (reg_num[4:0] == 5'h03)) rdbk_reg[31:0] <= {11'h0000, reg3_[21:0]};
		if (rd_en && (reg_num[4:0] == 5'h04)) rdbk_reg[31:0] <= {11'h0000, reg4_[21:0]};
		if (rd_en && (reg_num[4:0] == 5'h05)) rdbk_reg[31:0] <= reg5_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h06)) rdbk_reg[31:0] <= reg6_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h07)) rdbk_reg[31:0] <= genreg_rd_data[31:0];  //data read from generic register interface
		if (rd_en && (reg_num[4:0] == 5'h08)) rdbk_reg[31:0] <= reg8_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h09)) rdbk_reg[31:0] <= {7'b0,adc_buf_current_data_delay[24:0]};   // R9 is read only
		if (rd_en && (reg_num[4:0] == 5'h0a)) rdbk_reg[31:0] <= {7'b0,adc_buf_current_data_delay[49:25]};  // R10 is read only
		if (rd_en && (reg_num[4:0] == 5'h0b)) rdbk_reg[31:0] <= {17'b0,adc_buf_current_data_delay[64:50]}; // R11 is read only
		if (rd_en && (reg_num[4:0] == 5'h0c)) rdbk_reg[31:0] <= {31'b0,adc_buf_delay_data_error};          // R12 is read only
		if (rd_en && (reg_num[4:0] == 5'h0d)) rdbk_reg[31:0] <= reg13_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h0e)) rdbk_reg[31:0] <= reg14_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h0f)) rdbk_reg[31:0] <= reg15_[31:0];
		
		if (rd_en && (reg_num[4:0] == 5'h10)) rdbk_reg[31:0] <= reg16_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h11)) rdbk_reg[31:0] <= reg17_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h12)) rdbk_reg[31:0] <= reg18_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h13)) rdbk_reg[31:0] <= reg19_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h14)) rdbk_reg[31:0] <= reg20_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h15)) rdbk_reg[31:0] <= reg21_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h16)) rdbk_reg[31:0] <= reg22_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h17)) rdbk_reg[31:0] <= reg23_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h18)) rdbk_reg[31:0] <= reg24_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h19)) rdbk_reg[31:0] <= reg25_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h1a)) rdbk_reg[31:0] <= reg26_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h1b)) rdbk_reg[31:0] <= reg27_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h1c)) rdbk_reg[31:0] <= reg28_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h1d)) rdbk_reg[31:0] <= reg29_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h1e)) rdbk_reg[31:0] <= reg30_[31:0];
		if (rd_en && (reg_num[4:0] == 5'h1f)) rdbk_reg[31:0] <= reg31_[31:0];

		//else rdbk_reg[31:0] <= rdbk_reg[31:0];
	end
endmodule	

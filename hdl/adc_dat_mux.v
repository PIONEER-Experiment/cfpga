`timescale 1ns / 1ps
/////////////////////////////////////////////////////////////////////////////////////////////////
// connect a mux that will supply either header info or ADC data to the DDR3 write FIFO
// All bit ordering is done in this mux
module adc_dat_mux (
    // inputs
    input [25:0] dat4_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat3_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat2_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat1_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat0_,                // a pair of ADC samples and a pair of over-range bits
    input [15:0] channel_tag, 		   // stuff about the channel to put in the header
    input [1:0] fill_type,             // to determine how much data to collect
    input [20:0] num_fill_bursts,      // number of 8(or 10) sample bursts
    input [22:0] burst_start_adr,      // first DDR3 memory location for this fill
    input [23:0] fill_num,             // fill number for this fill
    input clk,
    input select_dat,                  // '0' selects header, '1' selects data
    input select_checksum,             // '0' selects data, '1' selects checksum
    // outputs
    output reg [127:0] adc_acq_out_dat     // 128-bit header or ADC data   
);

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// assemble the header
wire [127:0] header;
// first 32-bit word
assign header[23:0]		= fill_num[23:0];                       // 24-bit fill number, always positive, 
assign header [31:24]	= 8'b0;                                 // filler, always zero
// second 32-bit word
assign header[57:32]	= {burst_start_adr[22:0], 3'b0};        // 23-bit DDR3 burst address, 3 LSBs always zero, 
assign header[63:58]	= 6'b0;                                 // filler, always zero
// third 32-bit word
assign header[84:64]	= num_fill_bursts[20:0];                // 21-bit burst count, 
assign header[95:85]	= 11'b0;                                // filler, always zero
// fourth 32-bit word
assign header[111:96]	= channel_tag[15:0];            		  // 16-bit channel info, 
assign header[113:112]	= fill_type[1:0];                       // 2-bit fill type
assign header[125:114]	= 12'b0;                                // filler, always zero
// make the last 2 bits be a header tag.  This pattern cannot appear in sign-extended data (always 2'b00 or 2'b11)
assign header[127:126]	= 2'b01;

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// assemble the data
wire [127:0] data;
// put 8 ADC samples into 8 16-bit words.
// Omit the overrange bit and sign extend into the upper 4 bits of each word
assign data[11:0]		= dat0_[12:1];                         // 0 oldest sample data
assign data[15:12]		= {dat0_[12], dat0_[12], dat0_[12], dat0_[12]};   // 0 oldest sample sign extension

assign data[27:16]		= dat0_[25:14];                         // 1 sample data
assign data[31:28]		= {dat0_[25], dat0_[25], dat0_[25], dat0_[25]};   // 1 sample sign extension

assign data[43:32]		= dat1_[12:1];                         // 2 oldest sample data
assign data[47:44]		= {dat1_[12], dat1_[12], dat1_[12], dat1_[12]};   // 2 sample sign extension

assign data[59:48]		= dat1_[25:14];                         // 3 sample data
assign data[63:60]		= {dat1_[25], dat1_[25], dat1_[25], dat1_[25]};   // 3 sample sign extension

assign data[75:64]		= dat2_[12:1];                         // 4 sample data
assign data[79:76]		= {dat2_[12], dat2_[12], dat2_[12], dat2_[12]};   // 4 sample sign extension

assign data[91:80]		= dat2_[25:14];                         // 5 sample data
assign data[95:92]		= {dat2_[25], dat2_[25], dat2_[25], dat2_[25]};   // 5 sample sign extension

assign data[107:96]		= dat3_[12:1];                         // 6 sample data
assign data[111:108]	= {dat3_[12], dat3_[12], dat3_[12], dat3_[12]};   // 6 sample sign extension

assign data[123:112]	= dat3_[25:14];                       // 7 sample data
assign data[127:124]	= {dat3_[25], dat3_[25], dat3_[25], dat3_[25]};   // 7 sample sign extension

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// create a checksum register
reg [127:0] checksum;
always @(posedge clk) begin
	if (!select_dat && !select_checksum) begin
		// initialize the checksum 
		checksum[127:0] <= header[127:0];
	end
	else if (select_dat && !select_checksum) begin
		// XOR the data with the checksum
		checksum[127:0] <= checksum[127:0] ^ data[127:0];
	end
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// make a mux to select header, data, or checksum		
always @(posedge clk) begin
	if (!select_dat && !select_checksum) begin
		// connect header bits
		adc_acq_out_dat[127:0] <= header[127:0];
	end
	else if (select_dat && !select_checksum) begin
		// connect the data to the output
		adc_acq_out_dat[127:0]   <= data[127:0];
	end
	else if (select_checksum) begin
		// connect the checksum to the output
		adc_acq_out_dat[127:0]   <= checksum[127:0];
	end
end                                
endmodule

// connect data bits to the output
// put 8 ADC samples into 8 16-bit words.
// These lines put the overrange bit in the LSB of each word and sign extend into the upper 3 bits of each word
//        assign data[0]       = dat0_[0];                            // 0 oldest sample overrange bit
//        assign data[12:1]    = dat0_[12:1];                         // 0 oldest sample data
//        assign data[15:13]   = {dat0_[12], dat0_[12], dat0_[12]};   // 0 oldest sample sign extension

//        assign data[16]      = dat0_[13];                           // 1 sample overrange bit
//        assign data[28:17]   = dat0_[25:14];                        // 1 sample data
//        assign data[31:29]   = {dat0_[25], dat0_[25], dat0_[25]};   // 1 sample sign extension
 
//        assign data[32]      = dat1_[0];                            // 2 sample overrange bit
//        assign data[44:33]   = dat1_[12:1];                         // 2 sample data
//        assign data[47:45]   = {dat1_[12], dat1_[12], dat1_[12]};   // 2 sample sign extension

//        assign data[48]      = dat1_[13];                           // 3 sample overrange bit
//        assign data[60:49]   = dat1_[25:14];                        // 3 sample data
//        assign data[63:61]   = {dat1_[25], dat1_[25], dat1_[25]};   // 3 sample sign extension
 
//        assign data[64]      = dat2_[0];                            // 4 sample overrange bit
//        assign data[76:65]   = dat2_[12:1];                         // 4 sample data
//        assign data[79:77]   = {dat2_[12], dat2_[12], dat2_[12]};   // 4 sample sign extension
 
//        assign data[80]      = dat2_[13];                           // 5 sample overrange bit
//        assign data[92:81]   = dat2_[25:14];                        // 5 sample data
// /      assign data[95:93]   = {dat2_[25], dat2_[25], dat2_[25]};   // 5 sample sign extension
 
//        assign data[96]      = dat3_[0];                            // 6 sample overrange bit
//        assign data[108:97]  = dat3_[12:1];                         // 6 sample data
//        assign data[111:109] = {dat3_[12], dat3_[12], dat3_[12]};   // 6 sample sign extension

//        assign data[112]     = dat3_[13];                           // 7 newest sample overrange bit
//        assign data[124:113] = dat3_[25:14];                        // 7 newest sample data
//        assign data[127:125] = {dat3_[25], dat3_[25], dat3_[25]};   // 7 newest sample sign extension

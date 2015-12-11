`timescale 1ns / 1ps

///////////////////////////////////////////////////////////////////////////////////////
// Create a mux that will supply one of the following to the DDR3 write FIFO:
//  1) fill header
//  2) waveform header
//  3) ADC data
//  4) checksum 
// All bit ordering for the headers and the ADC data is done in this mux

module adc_dat_mux (
    // inputs
    input [25:0] dat4_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat3_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat2_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat1_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat0_,                // a pair of ADC samples and a pair of over-range bits
    (* mark_debug = "true" *) input [15:0] channel_tag, 		   // stuff about the channel to put in the header
    (* mark_debug = "true" *) input [1:0] fill_type,             // to determine how much data to collect
    (* mark_debug = "true" *) input [22:0] num_fill_bursts,      // number of 8 (or 10) sample bursts
    input [22:0] burst_start_adr,      // first DDR3 memory location for this fill
    (* mark_debug = "true" *) input [23:0] fill_num,             // fill number for this fill
    (* mark_debug = "true" *) input [11:0] num_waveforms,	       // number of waveforms to store per trigger
	input [11:0] current_waveform_num, // the current waveform number, to be used in header
    (* mark_debug = "true" *) input [21:0] waveform_gap,	       // idle time between waveforms
    input clk,
    input select_fill_hdr,     			// selects fill header
    input select_waveform_hdr,  		// selects waveform header
    input select_dat,                  //  selects data
    input select_checksum,             //  selects checksum
    input checksum_update,				// update the checksum 
    // outputs
    output reg [131:0] adc_acq_out_dat // 132-bit: 4-bit tag plus 128-bit header or ADC data   
);

//////////////////////
// assemble the fill header
wire [131:0] fill_header;
assign fill_header[22:0]	= num_fill_bursts[22:0];          // 23-bit burst count, 
assign fill_header[46:23]	= fill_num[23:0];                 // 24-bit fill number, always positive, 
assign fill_header[48:47]	= fill_type[1:0];                 // 2-bit fill type
assign fill_header[49]		= 1'b0;						      // 1-bit reserved for future 3-bit fill type
assign fill_header[75:50]	= {burst_start_adr[22:0], 3'b0};  // 23-bit DDR3 burst address, 3 LSBs always zero, 
assign fill_header[87:76]	= num_waveforms[11:0];            // 12-bit number of waveforms to store per trigger
assign fill_header[109:88]	= waveform_gap[21:0];	          // 22-bit idle time between waveforms
assign fill_header[125:110]	= channel_tag[15:0];              // 16-bit channel info, 
// make the next 2 bits be a header tag.  This pattern cannot appear in sign-extended data (always 2'b00 or 2'b11).
assign fill_header[127:126]	= 2'b01;
// tag = '1' for fill header
assign fill_header[131:128]	= 4'd1;

//////////////////////
// assemble the waveform header
wire [131:0] waveform_header;
assign waveform_header[22:0]	= num_fill_bursts[22:0];          // 23-bit burst count, 
assign waveform_header[24:23]	= fill_type[1:0];    	          // 2-bit fill type
assign waveform_header[25]		= 1'b0;						      // 1-bit reserved for future 3-bit fill type
assign waveform_header[51:26]	= {burst_start_adr[22:0], 3'b0};  // 23-bit DDR3 burst address, 3 LSBs always zero, 
assign waveform_header[63:52]	= num_waveforms[11:0];            // 12-bit number of waveforms to store per trigger
assign waveform_header[75:64]	= current_waveform_num[11:0];     // 12-bit current waveform number
assign waveform_header[97:76]	= waveform_gap[21:0];	          // 22-bit idle time between waveforms
assign waveform_header[113:98]	= channel_tag[15:0];              // 16-bit channel info, 
assign waveform_header[125:114]	= 12'b0;		                  // 12-bit spare 
// make the next 2 bits be a header tag.  This pattern cannot appear in sign-extended data (always 2'b00 or 2'b11).
assign waveform_header[127:126]	= 2'b01;
// tag = '2' for waveform header
assign waveform_header[131:128]	= 4'd2;

////////////////////
// assemble the data
wire [131:0] data;
// put 8 ADC samples into 8 16-bit words.
// omit the overrange bit and sign extend into the upper 4 bits of each word
assign data[11:0]	 = dat0_[12:1];                                  // 0 oldest sample data
assign data[15:12]	 = {dat0_[12], dat0_[12], dat0_[12], dat0_[12]}; // 0 oldest sample sign extension

assign data[27:16]	 = dat0_[25:14];                                 // 1 sample data
assign data[31:28]	 = {dat0_[25], dat0_[25], dat0_[25], dat0_[25]}; // 1 sample sign extension

assign data[43:32]	 = dat1_[12:1];                                  // 2 oldest sample data
assign data[47:44]	 = {dat1_[12], dat1_[12], dat1_[12], dat1_[12]}; // 2 sample sign extension

assign data[59:48]	 = dat1_[25:14];                                 // 3 sample data
assign data[63:60]	 = {dat1_[25], dat1_[25], dat1_[25], dat1_[25]}; // 3 sample sign extension

assign data[75:64]	 = dat2_[12:1];                                  // 4 sample data
assign data[79:76]	 = {dat2_[12], dat2_[12], dat2_[12], dat2_[12]}; // 4 sample sign extension

assign data[91:80]	 = dat2_[25:14];                                 // 5 sample data
assign data[95:92]	 = {dat2_[25], dat2_[25], dat2_[25], dat2_[25]}; // 5 sample sign extension

assign data[107:96]	 = dat3_[12:1];                                  // 6 sample data
assign data[111:108] = {dat3_[12], dat3_[12], dat3_[12], dat3_[12]}; // 6 sample sign extension

assign data[123:112] = dat3_[25:14];                                 // 7 sample data
assign data[127:124] = {dat3_[25], dat3_[25], dat3_[25], dat3_[25]}; // 7 sample sign extension

// tag = '3' for data
assign data[131:128]	= 4'd3;

/////////////////////////////
// create a checksum register
reg [127:0] checksum;
wire [3:0] checksum_tag;
// tag = '4' for checksum
assign checksum_tag[3:0] = 4'd4;

always @(posedge clk) begin
	if (select_fill_hdr && !select_waveform_hdr && !select_dat) begin
		// initialize the checksum, exclude the 4-bit tag 
		checksum[127:0] <= fill_header[127:0];
	end
	
	else if (!select_fill_hdr && select_waveform_hdr &&  !select_dat) begin
		// XOR the current fill header with the checksum, exclude the 4-bit tag
		checksum[127:0] <= checksum[127:0] ^ waveform_header[127:0];
	end

	else if (checksum_update) begin
		// XOR the data with the checksum, exclude the 4-bit tag
		checksum[127:0] <= checksum[127:0] ^ data[127:0];
	end
end

//////////////////////////////////////////////////
// make a mux to select fill header, waveform header, data, or checksum		
always @(posedge clk) begin
	if (select_fill_hdr) begin
		// connect fill header bits
		adc_acq_out_dat[131:0] <= fill_header[131:0];
	end
	if (select_waveform_hdr) begin
		// connect waveform header bits
		adc_acq_out_dat[131:0] <= waveform_header[131:0];
	end
	if (select_dat) begin
		// connect the data to the output
		adc_acq_out_dat[131:0] <= data[131:0];
	end
	if (select_checksum) begin
		// connect the checksum to the output
		adc_acq_out_dat[131:0] <= {checksum_tag[3:0], checksum[127:0]};
	end
end

endmodule

`timescale 1ns / 10ps

///////////////////////////////////////////////////////////////////////////////////////
// Create a mux that will supply one of the following to the DDR3 write FIFO:
//  1) fill header
//  2) waveform header
//  3) ADC data
//  4) checksum 
// All bit ordering for the headers and the ADC data is done in this mux

module adc_dat_mux_selftrig (
    // inputs
    input [25:0] dat3_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat2_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat1_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat0_,                // a pair of ADC samples and a pair of over-range bits
    input [11:0] channel_tag,          // stuff about the channel to put in the header
    input [1:0]  ddr3_range,           // level of the ddr3 range bit.  Two copies because of history of other modes
    input [22:0] num_fill_bursts,      // number of 8 (or 10) sample bursts
    input [22:0] waveform_start_adr,   // first DDR3 memory location for this waveform
    input [23:0] fill_num,             // fill number for this fill
    input [22:0] current_waveform_num, // the current waveform number, to be used in header
    input [3:0] xadc_alarms,
    input clk,
    input [13:0] async_num_bursts,     // number of 8-sample bursts in an ASYNC waveform
    input [15:0] async_pre_trig,       // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    input select_fill_hdr,             // selects fill header
    input select_waveform_hdr,         // selects waveform header
    input select_dat,                  // selects data
    input select_checksum,             // selects checksum
    input checksum_init,               // initialize the checksum
    input checksum_update,             // update the checksum
    input [41:0] trigger_time,         // the time of the most recent data trigger
    // outputs
    output reg [131:0] adc_acq_out_dat // 132-bit: 4-bit tag plus 128-bit header or ADC data
);

//////////////////////////////////////
// assemble the selftrig mode fill header
wire [131:0] fill_header;
assign fill_header[ 23:  0] = fill_num[23:0];             // 24-bit fill number from register R0, incremented each fill
assign fill_header[ 25: 24] = ddr3_range[1:0];            //  2-bit fill type from pins "ACQ_ENABLE[1:0]"
assign fill_header[     26] = 1'b0;                       //  1-bit fill header format: sync/cbuf/selftrig=0, async=1
assign fill_header[ 49: 27] = num_fill_bursts[22:0];      // 23-bit final burst count covering all headers, waveforms, checksum
assign fill_header[ 63: 50] = async_num_bursts[13:0];     // 14-bit value for number of bursts per trigger from register R20
assign fill_header[ 75: 64] = async_pre_trig[11:0];       // 12-bit LSB value for number of pre-trigger ADC pairs from register R21
assign fill_header[ 98: 76] = current_waveform_num[22:0]; // 23-bit final waveform (trigger) count
assign fill_header[102: 99] = async_pre_trig[15:12];      //  4-bit MSB value for number of pre-trigger ADC pairs from register R21
assign fill_header[109:103] = 7'd0;                       //  7-bit unused
assign fill_header[121:110] = channel_tag[11:0];          // 12-bit channel tag
assign fill_header[122:122] = 1'b0;                       //  1-bit cbuf=1, all other modes = 0
assign fill_header[123:123] = 1'b1;                       //  1-bit self triggered = 1, all other modes = 0
assign fill_header[125:124] = 2'd0;                       //  2-bit unused
assign fill_header[127:126] = 2'b01;                      //  2-bit header tag; this pattern cannot appear in sign-extended data (always 2'b00 or 2'b11)
assign fill_header[131:128] = 4'd1;                       //  4-bit burst contents tag, tag = '1' for fill header

//////////////////////////////////////////
// assemble the selftrig mode waveform header
wire [131:0] waveform_header;
assign waveform_header[ 13:  0] = async_num_bursts[13:0];           // 14-bit value for number of bursts per trigger from register R20
assign waveform_header[ 25: 14] = async_pre_trig[13:2];             // 12-bit LSB value for number of pre-trigger bursts register R21 (which has pairs)
assign waveform_header[ 48: 26] = waveform_start_adr[22:0];         // 23-bit waveform starting address: add 3 "0" bits for physical byte address
assign waveform_header[ 71: 49] = current_waveform_num[22:0];       // 23-bit waveform (trigger) index
assign waveform_header[ 97: 72] = trigger_time[25:0];               // 26-bit lower bit portion of 42-bit trigger time tag
assign waveform_header[109: 98] = channel_tag[11:0];                // 12-bit channel tag
assign waveform_header[125:110] = trigger_time[41:26];              // 16-bit upper bit portion of 42-bit trigger time tag
assign waveform_header[127:126] = 2'b01;                            //  2-bit header tag; this pattern cannot appear in sign-extended data (always 2'b00 or 2'b11)
assign waveform_header[131:128] = 4'd2;                             //  4-bit burst contents tag, tag = '2' for waveform header

////////////////////
// assemble the data
wire [131:0] data;
// put 8 ADC samples into 8 16-bit words.
// omit the overrange bit and sign extend into the upper 4 bits of each word
assign data[ 11:  0] = dat0_[12:1];                                  // 0 oldest sample data
assign data[ 15: 12] = {dat0_[12], dat0_[12], dat0_[12], dat0_[12]}; // 0 oldest sample sign extension

assign data[ 27: 16] = dat0_[25:14];                                 // 1 sample data
assign data[ 31: 28] = {dat0_[25], dat0_[25], dat0_[25], dat0_[25]}; // 1 sample sign extension

assign data[ 43: 32] = dat1_[12:1];                                  // 2 oldest sample data
assign data[ 47: 44] = {dat1_[12], dat1_[12], dat1_[12], dat1_[12]}; // 2 sample sign extension

assign data[ 59: 48] = dat1_[25:14];                                 // 3 sample data
assign data[ 63: 60] = {dat1_[25], dat1_[25], dat1_[25], dat1_[25]}; // 3 sample sign extension

assign data[ 75: 64] = dat2_[12:1];                                  // 4 sample data
assign data[ 79: 76] = {dat2_[12], dat2_[12], dat2_[12], dat2_[12]}; // 4 sample sign extension

assign data[ 91: 80] = dat2_[25:14];                                 // 5 sample data
assign data[ 95: 92] = {dat2_[25], dat2_[25], dat2_[25], dat2_[25]}; // 5 sample sign extension

assign data[107: 96] = dat3_[12:1];                                  // 6 sample data
assign data[111:108] = {dat3_[12], dat3_[12], dat3_[12], dat3_[12]}; // 6 sample sign extension

assign data[123:112] = dat3_[25:14];                                 // 7 sample data
assign data[127:124] = {dat3_[25], dat3_[25], dat3_[25], dat3_[25]}; // 7 sample sign extension

// tag = '3' for data
assign data[131:128] = 4'd3;

/////////////////////////////
// create a checksum register
reg [127:0] checksum;
wire [3:0] checksum_tag;
// tag = '4' for checksum
assign checksum_tag[3:0] = 4'd4;

always @(posedge clk) begin
	if (checksum_init)
		// set checksum to zero
		checksum[127:0] <= #1 {128{1'b0}};
	else if (select_fill_hdr && !select_waveform_hdr && !select_dat)
		// XOR the current fill header with the checksum, exclude the 4-bit tag
		checksum[127:0] <= #1 checksum[127:0] ^ fill_header[127:0];
	else if (!select_fill_hdr && select_waveform_hdr &&  !select_dat)
		// XOR the current waveform header with the checksum, exclude the 4-bit tag
		checksum[127:0] <= #1 checksum[127:0] ^ waveform_header[127:0];
	else if (checksum_update) begin
		// XOR the data with the checksum, exclude the 4-bit tag
		checksum[127:0] <= #1 checksum[127:0] ^ data[127:0];
	end
end

///////////////////////////////////////////////////////////////////////
// make a mux to select fill header, waveform header, data, or checksum		
always @(posedge clk) begin
	if (select_fill_hdr) begin
		// connect fill header bits
		adc_acq_out_dat[131:0] <= #1 fill_header[131:0];
	end
	if (select_waveform_hdr) begin
		// connect waveform header bits
		adc_acq_out_dat[131:0] <= #1 waveform_header[131:0];
	end
	if (select_dat) begin
		// connect the data to the output
		adc_acq_out_dat[131:0] <= #1 data[131:0];
	end
	if (select_checksum) begin
		// connect the checksum to the output
		adc_acq_out_dat[131:0] <= #1 {checksum_tag[3:0], checksum[127:0]};
	end
end

endmodule

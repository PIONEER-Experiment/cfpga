`timescale 1ns / 10ps

///////////////////////////////////////////////////////////////////////////////////////
// Create a mux that will supply one of the following to the DDR3 write FIFO:
//  1) fill header
//  2) waveform header
//  3) ADC data
//  4) checksum 
// All bit ordering for the headers and the ADC data is done in this mux

module adc_dat_mux_CBUF (
    // inputs
    input [25:0] dat3_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat2_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat1_,                // a pair of ADC samples and a pair of over-range bits
    input [25:0] dat0_,                // a pair of ADC samples and a pair of over-range bits
    input [11:0] channel_tag,          // stuff about the channel to put in the header
    input [1:0] fill_type,             // to determine how much data to collect
    input [22:0] burst_start_adr,      // first DDR3 memory location for this fill
    input [23:0] fill_num,             // fill number for this fill
    input [3:0] xadc_alarms,
    input clk,
    input [13:0] async_num_bursts,     // number of 8-sample bursts in an ASYNC waveform
    input [15:0] async_pre_trig,       // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    (* mark_debug = "true" *) input select_fill_hdr,                 // selects fill header
    (* mark_debug = "true" *) input select_waveform_hdr,         // selects waveform header
    (* mark_debug = "true" *) input select_dat,                  // selects data
    (* mark_debug = "true" *) input select_checksum,             // selects checksum
    input checksum_update,               // update the checksum
    // outputs
    (* mark_debug = "true" *) output reg [131:0] adc_acq_out_dat // 132-bit: 4-bit tag plus 128-bit header or ADC data
);

//////////////////////////////////////
// assemble the async mode fill header
wire [131:0] fill_header;
assign fill_header[ 23:  0] = fill_num[23:0];             // 24-bit fill number from register R0, incremented each fill
assign fill_header[ 25: 24] = fill_type[1:0];             //  2-bit fill type from pins "ACQ_ENABLE[1:0]"
assign fill_header[     26] = 0'b1;                       //  1-bit fill header format: sync=0, cbuf = 0, async=1
assign fill_header[ 40: 27] = async_num_bursts[13:0];     // 14-bit value for number of bursts per trigger from register R20
assign fill_header[ 52: 41] = async_pre_trig[11:0];       // 12-bit LSB value for number of pre-trigger ADC pairs from register R21
assign fill_header[ 75: 53] = burst_start_adr[22:0];      // 23-bit DDR3 burst address, physical (16 bit word) address would require 3 LSBs of zero
assign fill_header[ 98: 76] = 23'd1;                      // 23-bit final waveform (trigger) count.  By def just 1 for cbuf mode
assign fill_header[102: 99] = async_pre_trig[15:12];      //  4-bit MSB value for number of pre-trigger ADC pairs from register R21
assign fill_header[    103] = 1'b1;                       //  1-bit sync = async=0, cbuf=1 flag, if needed
assign fill_header[109:104] = 6'd0;                       //  7-bit unused
assign fill_header[121:110] = channel_tag[11:0];          // 12-bit channel tag
assign fill_header[125:122] = 4'd0;                       //  4-bit unused
assign fill_header[127:126] = 2'b01;                      //  2-bit header tag; this pattern cannot appear in sign-extended data (always 2'b00 or 2'b11)
assign fill_header[131:128] = 4'd1;                       //  4-bit burst contents tag, tag = '1' for fill header

//////////////////////////////////////////
// assemble the async mode waveform header
wire [131:0] waveform_header;
reg  [4  :0] latched_xadc_alarms;
assign waveform_header[ 13:  0] = async_num_bursts[13:0];           // 14-bit value for number of bursts per trigger from register R20
assign waveform_header[ 25: 14] = async_pre_trig[11:0];             // 12-bit LSB value for number of pre-trigger ADC pairs from register R21
assign waveform_header[ 51: 26] = {burst_start_adr[22:0], 3'd0};    // 26-bit waveform starting address
assign waveform_header[ 74: 52] = 23'd1;                            // 23-bit waveform (trigger) index
assign waveform_header[ 97: 75] = 23'd0;                            // 23-bit unused
assign waveform_header[109: 98] = channel_tag[11:0];                // 12-bit channel tag

assign waveform_header[113:110] = latched_xadc_alarms[3:0];         //  4-bit alarms from XADC
assign waveform_header[    114] = 1'b1;                             //  1-bit sync = async=0, cbuf=1 flag
assign waveform_header[125:115] = 11'd0;                            // 11-bit unused
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
    if (select_fill_hdr && !select_waveform_hdr && !select_dat) begin
        // initialize the checksum, exclude the 4-bit tag
        checksum[127:0] <= #1 fill_header[127:0];
    end

    else if (!select_fill_hdr && select_waveform_hdr &&  !select_dat) begin
        // XOR the current waveform header with the checksum, exclude the 4-bit tag
        checksum[127:0] <= #1 checksum[127:0] ^ waveform_header[127:0];
    end
    
    else if (checksum_update) begin
        // XOR the data with the checksum, exclude the 4-bit tag
        checksum[127:0] <= #1 checksum[127:0] ^ data[127:0];
    end
end

///////////////////////////////////////////////////////////////////////
// make a mux to select fill header, waveform header, data, or checksum
always @(posedge clk) begin
    if (select_fill_hdr) begin
        // latch the xadc alarms so that they cannot change between checksum calc and sending data
        latched_xadc_alarms[3:0] <= xadc_alarms[3:0];
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

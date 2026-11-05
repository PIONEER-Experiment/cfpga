`include "constants.txt"

// register_block.v
//
// This module provides access to 64 32-bit registers. R/W = read/write, RO = read-only.

module register_block64(
    // clocks and reset
    input clk50,                             // 50 MHz buffered clock 
    input reset_clk50,                       // active-high reset output, goes low after startup
    input clk,                               // 125 MHz, clock for the interconnect side of the FIFOs
    input reset,                             // reset
    input cnt_reset,                         // reset, for fill number count

    // data from/to Master FPGA
    input  [31:0] rx_data,                   // note index order
    output [31:0] tx_data,
    input rd_en,                             // enable reading of the specific register
    input wr_en,                             // enable writing to the specific register
    input reg_num_le,                         // enable saving of the selected register number
    output illegal_reg_num,                     // The desired register does not exist

    // Register to/from the ADC acquisition state machine
    input [23:0] fill_num,                     // fill number for this fill
    output [11:0] channel_tag,                 // stuff about the channel to put in the header
    output [22:0] muon_num_bursts,             // number of sample bursts in a MUON fill
    output [22:0] laser_num_bursts,          // number of sample bursts in a LASER fill
    output [22:0] ped_num_bursts,             // number of sample bursts in a PEDESTAL fill
    output [23:0] initial_fill_num,          // event number to assign to the first fill
    output reg initial_fill_num_wr,          // write-strobe to store the initial_fill_num
    input [2:0] ch_addr,                     // the channel address jumpers
    output adc_buf_delay_data_reset,         // use the new delay settings
    output [4:0] adc_buf_data_delay,         // 5 delay-tap-bits per line, all lines always all the same
    input [64:0] adc_buf_current_data_delay, // 13 lines *5 bits/line, current tap settings
    output [22:0] fixed_ddr3_start_addr,
    output en_fixed_ddr3_start_addr,
    output [11:0] muon_num_waveforms,         // number of waveforms to store per trigger
    output [21:0] muon_waveform_gap,         // idle time between waveforms 
    output [11:0] laser_num_waveforms,         // number of waveforms to store per trigger
    output [21:0] laser_waveform_gap,         // idle time between waveforms 
    output [11:0] ped_num_waveforms,         // number of waveforms to store per trigger
    output [21:0] ped_waveform_gap,             // idle time between waveforms 
    output [13:0] async_num_bursts,          // number of 8-sample bursts in an ASYNC waveform
    output [15:0] async_pre_trig,            // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    output [11:0] selftrig_threshold,        // above-pedestal threshold for self triggering
    output        selftrig_polarity,         // for self-triggering: 0 => negative polarity, 1 => positive
    output [2:0]  selftrig_sum_log2,         // self-triggering: log2 of the number of sample pairs averaged
    output [5:0]  selftrig_ped_delay,        // self-triggering: pedestal delay in 400 MHz clock cycles (1..63)
    output        selftrig_ped_bypass,       // self-triggering: 1 => no pedestal subtraction
    output [7:0]  selftrig_min_separation,   // self-triggering: minimum separation of accepted triggers, 400 MHz clocks
    output        selftrig_retrig_level,     // self-triggering: 1 => re-trigger while still over threshold (legacy level mode)
    output        line_out_off,              // R39 (0x27) [0], 6.8.3 test: 1 => hold the trigger-line pin to the master low
    input  [22:0] current_waveform_num,
 
    // slow control
    input [15:0] xadc_temp,
    input [15:0] xadc_vccint,
    input [15:0] xadc_vccaux,
    input [15:0] xadc_vccbram,

     // generic register space connections
    output [31:0] genreg_addr_ctrl,             // generic register address and control output
    output [31:0] genreg_wr_data,             // generic register data written from Master FPGA 
    input  [31:0] genreg_rd_data,             // generic register data read by Master FPGA
    input  [31:0] map_data_integrity,
    input  [3:0] image_type,

    // state machine states
    input [18:0] adc_acq_state,
    input [18:0] circ_to_ddr3_state,
    input [ 9:0] cc_rd_fill_state,
    input [ 9:0] enable_sm_state,
    input [31:0] cmd_path_live,                // R41 (0x29): command-path diagnostics, live
    input [31:0] cmd_path_snapshot,            // R42 (0x2A): the same, frozen just before the last master reset
    input [31:0] ddr3_path_snap_a,             // R43 (0x2B): acquisition / DDR3 state machines, frozen before the last reset
    input [31:0] ddr3_path_snap_b,             // R44 (0x2C): circ-buf drain SM and read-fill handshakes, frozen before the last reset
    input [31:0] ddr3_path_live_b,             // R45 (0x2D): the same as R44, live
    input [31:0] link_word_counts_snap,        // R46 (0x2E): {Aurora RX words, Aurora TX words} frozen before the last reset
    input [31:0] link_word_counts,             // R47 (0x2F): the same, live
    input [31:0] enable_diag_snap,             // R48 (0x30): enable-line decoder diagnostics, frozen before the last reset
    input [31:0] enable_diag,                  // R49 (0x31): the same, live
    input [31:0] core_word_counts,             // R50 (0x32): {RX words, TX words} at the Aurora core itself (after the TX FIFO), live
    input [31:0] core_word_counts_snap,        // R51 (0x33): the same, frozen before the last reset
    input [31:0] link_event_counts,            // R52 (0x34): {channel_up drops, lane_up drops, hard_err, link_reset}, 8 bits each, free running
    input [31:0] selftrig_diag,                // R53 (0x35): {pulses owed to the master [31:24], forced fill closes [23:16], refused triggers [15:0]}
    input [31:0] rd_fill_diag,                 // R54 (0x36): {stalls in GET_DDR3_DATA [31:26], DDR3 words still to send [25:0]}
    input [31:0] error_status,                 // R55 (0x37): {snapshot valid, lost data, fault, 13'd0, error bits [15:0]}; a write clears
    input [31:0] selftrig_diag_snap,           // R56 (0x38): 0x35 frozen at the first error
    input [31:0] rd_fill_diag_snap,            // R57 (0x39): 0x36 frozen at the first error
    output       clear_errors,                 // one clock: register 0x37 was written
    input [ 2:0] ddr3_rd_ctrl_state,            // read control current state
    input [16:0] ddr3_wr_ctrl_state            // write control current state
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
    assign illegal_reg_num = (reg_num[31:6] == 26'b00000000000000000000000000) ? 1'b0 : 1'b1;
    reg clear_errors_r = 1'b0;
    assign clear_errors = clear_errors_r;
    
    // make a block of 64 32-bit registers
    // those with explicit defaults follow below
    reg [31:0] reg1_, reg5_, reg6_, reg26_, reg27_, reg28_, reg29_, reg30_;

    // set non-zero default register values
    reg [31:0] reg0_  = 32'd1;        // initial fill number set to 1
    reg [31:0] reg2_  = 32'd70000;    // muon fill burst count of 70,000
    reg [31:0] reg3_  = 32'd100;      // laser fill burst count of 100
    reg [31:0] reg4_  = 32'd100;      // pedestal fill burst count of 100
    reg [31:0] reg8_  = 32'd11;       // data bus delay tap value of 11
    reg [31:0] reg13_ = 32'hf0000000; // use normal DDR3 start addresses
    reg [31:0] reg14_ = 32'd1;        // 1 muon waveform per trigger; 1 threshold and negative polarity for self triggering
    reg [31:0] reg16_ = 32'd4;        // 4 laser waveform per trigger
    reg [31:0] reg18_ = 32'd1;        // 1 pedestal waveform per trigger
    reg [31:0] reg19_ = 32'd1;        // muon waveform gap of 1
    reg [31:0] reg15_ = 32'd200;      // laser waveform gap of 200
    reg [31:0] reg17_ = 32'd1;        // pedestal waveform gap of 1
    reg [31:0] reg20_ = 32'd10;       // async burst count of 10
    reg [31:0] reg21_ = 32'd2;        // async pre-trigger of 2
    reg [31:0] reg38_ = 32'd200;      // self trigger threshold and polarity
    // R40 (0x28): self-trigger running-average window and pedestal
    //   bits [2:0]  log2 of the number of sample pairs summed (001 = 4 samples)
    //   bits [8:3]  pedestal delay in 400 MHz clock cycles, 1..63 (000100 = 4)
    //   bit  [9]    1 = bypass the pedestal subtraction
    // default 0x21 reproduces the original fixed 4-sample / 4-cycle trigger
    reg [31:0] reg39_ = 32'd0;        // 6.8.3 test: [0] = 1 holds the trigger-line pin low (the frontend never writes it)
    reg [31:0] reg40_ = 32'h00005021;  // window 4 samples, pedestal delay 4 clocks, minimum separation 20 clocks (50 ns), edge mode
    
    // write to the writable registers
    always @ (posedge clk) begin
        if (wr_en && (reg_num[5:0] == 6'h00)) reg0_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h01)) reg1_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h02)) reg2_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h03)) reg3_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h04)) reg4_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h05)) reg5_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h06)) reg6_[31:0] <= rx_data[31:0];
        // R7  is read only
        if (wr_en && (reg_num[5:0] == 6'h08)) reg8_[31:0] <= rx_data[31:0];
        // R9  is read only
        // R10 is read only
        // R11 is read only
        // R12 is read only
        if (wr_en && (reg_num[5:0] == 6'h0d)) reg13_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h0e)) reg14_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h0f)) reg15_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h10)) reg16_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h11)) reg17_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h12)) reg18_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h13)) reg19_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h14)) reg20_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h15)) reg21_[31:0] <= rx_data[31:0];
        // R22 is read only
        // R23 is read only
        // R24 is read only
        // R25 is read only
        if (wr_en && (reg_num[5:0] == 6'h1a)) reg26_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h1b)) reg27_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h1c)) reg28_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h1d)) reg29_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h1e)) reg30_[31:0] <= rx_data[31:0];
        // R31 through 37 are read only
        if (wr_en && (reg_num[5:0] == 6'h26)) reg38_[31:0] <= rx_data[31:0];
        if (wr_en && (reg_num[5:0] == 6'h28)) reg40_[31:0] <= rx_data[31:0];
        // R39 (0x27) was a 'run in progress' flag that nothing in the firmware consumed; since 6.8.3 bit 0
        // switches the trigger-line pin to the master off (a test of whether the master depends on it)
        if (wr_en && (reg_num[5:0] == 6'h27)) reg39_[31:0] <= rx_data[31:0];
        // R55 (0x37): any write clears the error latch and its snapshot (6.6.10)
        clear_errors_r <= wr_en && (reg_num[5:0] == 6'h37);
        // R40 through R63 are read only
    end

    // Register to/from the ADC acquisition state machine
    // R0 - initial value for the fill number
    assign initial_fill_num[23:0] = reg0_[23:0];
    // Send R0 'wr_en' to the ADC acquisition controller
    // fill number will be set back to initial value after a reset
    //wire initial_fill_num_wr_wire;
    //assign initial_fill_num_wr_wire = ((wr_en && (reg_num[6:0] == 6'h00)) | reset | cnt_reset) ? 1'b1 : 1'b0;

    // R1 - channel tag
    // bits [2:0] from configuration jumpers
    assign channel_tag[ 2:0] = ch_addr[2:0]; // the channel address jumpers
    assign channel_tag[11:3] = reg1_[11:3];
    
    // R2 - Muon burst count
    assign muon_num_bursts[22:0]  = reg2_[22:0];

    // R3 - Laser burst count
    assign laser_num_bursts[22:0] = reg3_[22:0];

    // R4 - Pedestal burst count
    assign ped_num_bursts[22:0]   = reg4_[22:0];

    // R5
    assign genreg_addr_ctrl[31:0] = reg5_[31:0]; // address and control for the generic register interface

    // R6
    assign genreg_wr_data[31:0]   = reg6_[31:0]; // data written to generic register interface

    // R7 is read only

    // R8
    // When we write a new delay, we need to assert 'adc_buf_delay_data_reset'. Use this SM.
    assign adc_buf_data_delay[4:0] = reg8_[4:0]; // tap value for the data bus delay
    data_delay_reset data_delay_reset(
        .clk(clk50),                                      // input, 50 MHz buffered clock
        .reset(reset_clk50),                              // input, start-up reset to initialize SM
        .delay_tap(adc_buf_data_delay[4:0]),              // input [4:0], tap delay to set from register block
        .wiz_delay_tap(adc_buf_current_data_delay[64:0]), // input [64:0], tap values according to the wizard
        .delay_data_reset(adc_buf_delay_data_reset),      // output, active-high reset
        .error(adc_buf_delay_data_error)                  // output, tap values not set properly
    );

    // R9  is read only
    // R10 is read only
    // R11 is read only
    // R12 is read only

    // R13
    assign fixed_ddr3_start_addr[22:0] = reg13_[22:0];
    assign en_fixed_ddr3_start_addr = (reg13_[31:28] == 4'b1111) ? 1'b0 : 1'b1;
    
    // R14
    // number of muon waveforms to store per trigger (regular mode)
    // triggering threshold, self-triggering mode
    assign muon_num_waveforms[11:0]  = reg14_[11:0];

    // R15
    // idle time between laser waveforms
    assign laser_waveform_gap[21:0]  = reg15_[21:0];

    // R16
    // number of laser waveforms to store per trigger
    assign laser_num_waveforms[11:0] = reg16_[11:0];

    // R17
    // idle time between pedestal waveforms
    assign ped_waveform_gap[21:0]  = reg17_[21:0];

    // R18
    // number of pedestal waveforms to store per trigger
    assign ped_num_waveforms[11:0] = reg18_[11:0];

    // R19
    // idle time between muon waveforms
    assign muon_waveform_gap[21:0] = reg19_[21:0];

    // R20
    // number of 8-sample bursts in an ASYNC waveform
    assign async_num_bursts[13:0] = reg20_[13:0];

    // R21
    // number of pre-trigger 400 MHz ADC clocks in an ASYNC waveform
    assign async_pre_trig[15:0]   = reg21_[15:0];

    // R22 is read only
    // R23 is read only
    // R24 is read only
    // R25 is read only
    
    // R31 is read only


    // R38
    // value away from pedestal to self trigger (above or below depends on polarity)
    // 0 for odd polarity and 1 for even polarity
    assign selftrig_threshold[11:0]    = reg38_[11:0];
    assign selftrig_polarity           = reg38_[12];

    // R40
    // self-trigger averaging window, pedestal delay and pedestal bypass
    assign selftrig_sum_log2[2:0]      = reg40_[2:0];
    assign selftrig_ped_delay[5:0]     = reg40_[8:3];
    assign selftrig_ped_bypass         = reg40_[9];
    // R40 [17:10]: minimum separation between accepted self triggers in 400 MHz clocks; 0 (an older
    // configuration writing only the low bits) reads as the default of 20 = 50 ns.  R40 [18]: 1 keeps
    // the legacy behaviour of re-triggering after the separation while the signal is still over
    // threshold; 0 (default) re-arms only once it has dropped below, one trigger per excursion.
    assign selftrig_min_separation[7:0] = (reg40_[17:10] == 8'd0) ? 8'd20 : reg40_[17:10];
    assign selftrig_retrig_level        = reg40_[18];
    assign line_out_off                 = reg39_[0];
    
    reg [31:0] rdbk_reg;
    assign tx_data[31:0] = rdbk_reg[31:0];
    always @ (posedge clk) begin
        // R0 is read back from the fill counter outside of this module
        if (rd_en && (reg_num[5:0] == 6'h00)) rdbk_reg[31:0] <= {8'b0, fill_num[23:0]};
        // R1 bits [2:0] from the channel address jumpers
        // R1 bits [31:16] always read back as zero
        if (rd_en && (reg_num[5:0] == 6'h01)) rdbk_reg[31:0] <= {20'h0000, reg1_[11:3], ch_addr[2:0]};
        // R2, R3, R4 bits [31:24] always read back as zero
        if (rd_en && (reg_num[5:0] == 6'h02)) rdbk_reg[31:0] <= { 9'd0, reg2_[22:0]};
        if (rd_en && (reg_num[5:0] == 6'h03)) rdbk_reg[31:0] <= { 9'd0, reg3_[22:0]};
        if (rd_en && (reg_num[5:0] == 6'h04)) rdbk_reg[31:0] <= { 9'd0, reg4_[22:0]};
        if (rd_en && (reg_num[5:0] == 6'h05)) rdbk_reg[31:0] <= reg5_[31:0];
        if (rd_en && (reg_num[5:0] == 6'h06)) rdbk_reg[31:0] <= reg6_[31:0];
        if (rd_en && (reg_num[5:0] == 6'h07)) rdbk_reg[31:0] <= genreg_rd_data[31:0]; // data read from generic register interface
        if (rd_en && (reg_num[5:0] == 6'h08)) rdbk_reg[31:0] <= {27'd0, reg8_[4:0]};
        if (rd_en && (reg_num[5:0] == 6'h09)) rdbk_reg[31:0] <= { 7'd0, adc_buf_current_data_delay[24: 0]}; // R9  is read only
        if (rd_en && (reg_num[5:0] == 6'h0a)) rdbk_reg[31:0] <= { 7'd0, adc_buf_current_data_delay[49:25]}; // R10 is read only
        if (rd_en && (reg_num[5:0] == 6'h0b)) rdbk_reg[31:0] <= {17'd0, adc_buf_current_data_delay[64:50]}; // R11 is read only
        if (rd_en && (reg_num[5:0] == 6'h0c)) rdbk_reg[31:0] <= {31'd0, adc_buf_delay_data_error};          // R12 is read only
        if (rd_en && (reg_num[5:0] == 6'h0d)) rdbk_reg[31:0] <= reg13_[31:0];
        if (rd_en && (reg_num[5:0] == 6'h0e)) rdbk_reg[31:0] <= {20'd0, reg14_[11:0]};
        if (rd_en && (reg_num[5:0] == 6'h0f)) rdbk_reg[31:0] <= {10'd0, reg15_[21:0]};
        if (rd_en && (reg_num[5:0] == 6'h10)) rdbk_reg[31:0] <= {20'd0, reg16_[11:0]};
        if (rd_en && (reg_num[5:0] == 6'h11)) rdbk_reg[31:0] <= {10'd0, reg17_[21:0]};
        if (rd_en && (reg_num[5:0] == 6'h12)) rdbk_reg[31:0] <= {20'd0, reg18_[11:0]};
        if (rd_en && (reg_num[5:0] == 6'h13)) rdbk_reg[31:0] <= {10'd0, reg19_[21:0]};
        if (rd_en && (reg_num[5:0] == 6'h14)) rdbk_reg[31:0] <= {18'd0, reg20_[13:0]};
        if (rd_en && (reg_num[5:0] == 6'h15)) rdbk_reg[31:0] <= {16'd0, reg21_[15:0]};
        if (rd_en && (reg_num[5:0] == 6'h16)) rdbk_reg[31:0] <= map_data_integrity[31:0];                // R22 is read only
        if (rd_en && (reg_num[5:0] == 6'h17)) rdbk_reg[31:0] <= {xadc_vccint[15:0], xadc_temp[15:0]};    // R23 is read only
        if (rd_en && (reg_num[5:0] == 6'h18)) rdbk_reg[31:0] <= {xadc_vccbram[15:0], xadc_vccaux[15:0]}; // R24 is read only
        if (rd_en && (reg_num[5:0] == 6'h19)) rdbk_reg[31:0] <= { 9'd0, current_waveform_num[22:0]};     // R25 is read only
        if (rd_en && (reg_num[5:0] == 6'h1a)) rdbk_reg[31:0] <= reg26_[31:0];
        if (rd_en && (reg_num[5:0] == 6'h1b)) rdbk_reg[31:0] <= reg27_[31:0];
        if (rd_en && (reg_num[5:0] == 6'h1c)) rdbk_reg[31:0] <= reg28_[31:0];
        if (rd_en && (reg_num[5:0] == 6'h1d)) rdbk_reg[31:0] <= reg29_[31:0];
        if (rd_en && (reg_num[5:0] == 6'h1e)) rdbk_reg[31:0] <= reg30_[31:0];
        if (rd_en && (reg_num[5:0] == 6'h1f)) rdbk_reg[31:0] <= {4'b0, image_type, `MAJOR_REV, `MINOR_REV, `PATCH_REV}; // R31 is read only
        if (rd_en && (reg_num[5:0] == 6'h20)) rdbk_reg[31:0] <= {13'd0,adc_acq_state[18:0]};
        if (rd_en && (reg_num[5:0] == 6'h21)) rdbk_reg[31:0] <= {13'd0,circ_to_ddr3_state[18:0]};
        if (rd_en && (reg_num[5:0] == 6'h22)) rdbk_reg[31:0] <= {22'd0,cc_rd_fill_state[9:0]};
        if (rd_en && (reg_num[5:0] == 6'h23)) rdbk_reg[31:0] <= {29'd0,ddr3_rd_ctrl_state[2:0]};
        if (rd_en && (reg_num[5:0] == 6'h24)) rdbk_reg[31:0] <= {15'd0,ddr3_wr_ctrl_state[16:0]};
        if (rd_en && (reg_num[5:0] == 6'h25)) rdbk_reg[31:0] <= {22'd0,enable_sm_state[9:0]};
        if (rd_en && (reg_num[5:0] == 6'h26)) rdbk_reg[31:0] <= reg38_[31:0];
        if (rd_en && (reg_num[5:0] == 6'h27)) rdbk_reg[31:0] <= {31'd0, reg39_[0]}; // [0]: trigger-line pin held low (6.8.3 test)
        if (rd_en && (reg_num[5:0] == 6'h28)) rdbk_reg[31:0] <= reg40_[31:0];
        if (rd_en && (reg_num[5:0] == 6'h29)) rdbk_reg[31:0] <= cmd_path_live[31:0];
        if (rd_en && (reg_num[5:0] == 6'h2a)) rdbk_reg[31:0] <= cmd_path_snapshot[31:0];
        if (rd_en && (reg_num[5:0] == 6'h2b)) rdbk_reg[31:0] <= ddr3_path_snap_a[31:0];
        if (rd_en && (reg_num[5:0] == 6'h2c)) rdbk_reg[31:0] <= ddr3_path_snap_b[31:0];
        if (rd_en && (reg_num[5:0] == 6'h2d)) rdbk_reg[31:0] <= ddr3_path_live_b[31:0];
        if (rd_en && (reg_num[5:0] == 6'h2e)) rdbk_reg[31:0] <= link_word_counts_snap[31:0];
        if (rd_en && (reg_num[5:0] == 6'h2f)) rdbk_reg[31:0] <= link_word_counts[31:0];
        if (rd_en && (reg_num[5:0] == 6'h30)) rdbk_reg[31:0] <= enable_diag_snap[31:0];
        if (rd_en && (reg_num[5:0] == 6'h31)) rdbk_reg[31:0] <= enable_diag[31:0];
        if (rd_en && (reg_num[5:0] == 6'h32)) rdbk_reg[31:0] <= core_word_counts[31:0];
        if (rd_en && (reg_num[5:0] == 6'h33)) rdbk_reg[31:0] <= core_word_counts_snap[31:0];
        if (rd_en && (reg_num[5:0] == 6'h34)) rdbk_reg[31:0] <= link_event_counts[31:0];
        if (rd_en && (reg_num[5:0] == 6'h35)) rdbk_reg[31:0] <= selftrig_diag[31:0];
        if (rd_en && (reg_num[5:0] == 6'h36)) rdbk_reg[31:0] <= rd_fill_diag[31:0];
        if (rd_en && (reg_num[5:0] == 6'h37)) rdbk_reg[31:0] <= error_status[31:0];
        if (rd_en && (reg_num[5:0] == 6'h38)) rdbk_reg[31:0] <= selftrig_diag_snap[31:0];
        if (rd_en && (reg_num[5:0] == 6'h39)) rdbk_reg[31:0] <= rd_fill_diag_snap[31:0];
        if (rd_en && (reg_num[5:0] == 6'h3a)) rdbk_reg[31:0] <= 32'd0;
        if (rd_en && (reg_num[5:0] == 6'h3b)) rdbk_reg[31:0] <= 32'd0;
        if (rd_en && (reg_num[5:0] == 6'h3c)) rdbk_reg[31:0] <= 32'd0;
        if (rd_en && (reg_num[5:0] == 6'h3d)) rdbk_reg[31:0] <= 32'd0;
        if (rd_en && (reg_num[5:0] == 6'h3e)) rdbk_reg[31:0] <= 32'd0;
        if (rd_en && (reg_num[5:0] == 6'h3f)) rdbk_reg[31:0] <= 32'd0;


        // fill number will be set back to initial value after a reset
        if ( (wr_en && (reg_num[5:0] == 6'h00)) | reset | cnt_reset) begin
           initial_fill_num_wr <= 1'b1;
        end
        else begin
           initial_fill_num_wr <= 1'b0; 
        end
        //initial_fill_num_wr <= initial_fill_num_wr_wire;

        // else rdbk_reg[31:0] <= rdbk_reg[31:0];
    end
endmodule    

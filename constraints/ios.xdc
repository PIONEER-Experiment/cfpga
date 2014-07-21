#use internal VREF for DDR data bus
#set_property INTERNAL_VREF 0.75 [get_iobanks 34]

#set_property BUFFER_TYPE NONE [get_ports *]

#make_diff_pair_ports c0_rx c0_rx_N
#make_diff_pair_ports c0_tx c0_tx_N
#make_diff_pair_ports xcvr_clk xcvr_clk_N
#make_diff_pair_ports ddr3_ck_p[0] ddr3_ck_n[0]
#make_diff_pair_ports ddr3_dqs_p[0] ddr3_dqs_n[0]
#make_diff_pair_ports ddr3_dqs_p[1] ddr3_dqs_n[1]
#make_diff_pair_ports adc_d0p adc_d0n
#make_diff_pair_ports adc_d1p adc_d1n
#make_diff_pair_ports adc_d2p adc_d2n
#make_diff_pair_ports adc_d3p adc_d3n
#make_diff_pair_ports adc_d4p adc_d4n
#make_diff_pair_ports adc_d5p adc_d5n
#make_diff_pair_ports adc_d6p adc_d6n
#make_diff_pair_ports adc_d7p adc_d7n
#make_diff_pair_ports adc_d8p adc_d8n
#make_diff_pair_ports adc_d9p adc_d9n
#make_diff_pair_ports adc_d10p adc_d10n
#make_diff_pair_ports adc_d11p adc_d11n
#make_diff_pair_ports adc_clk_p adc_clk_n
#make_diff_pair_ports adc_dovrp adc_dovrn
#make_diff_pair_ports adc_syncp adc_syncn

create_interface adc_data
set_property INTERFACE adc_data [get_ports { adc_d0n adc_d0p adc_d1n adc_d1p adc_d2n adc_d2p adc_d3n adc_d3p adc_d4n adc_d4p adc_d5n adc_d5p adc_d6n adc_d6p adc_d7n adc_d7p adc_d8n adc_d8p adc_d9n adc_d9p adc_d10n adc_d10p adc_d11n adc_d11p adc_dovrn adc_dovrp adc_syncn adc_syncp}]
#create_interface ddr3_controls
#set_property INTERFACE ddr3_controls [get_ports { ddr3_cas_n ddr3_cke ddr3_ck_n ddr3_ck_p ddr3_cs_n ddr3_dm[0] ddr3_dqs_n[0] ddr3_dqs_p[0] ddr3_odt ddr3_ras_n ddr3_reset_n ddr3_dm[1] ddr3_dqs_nn[1] ddr3_dqs_p[1] ddr3_we_n }]
#create_interface serial_xcvrs
#set_property INTERFACE serial_xcvrs [get_ports { c0_rx c0_rx_N xcvr_clk xcvr_clk_N }]
#set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports c0_tx]
#set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports c0_tx_N]
#
set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports xcvr_clk]
set_property IOSTANDARD LVDS [get_ports adc_d0n]
set_property IOSTANDARD LVDS [get_ports adc_d0p]
set_property IOSTANDARD LVDS [get_ports adc_d1n]
set_property IOSTANDARD LVDS [get_ports adc_d1p]
set_property IOSTANDARD LVDS [get_ports adc_d2n]
set_property IOSTANDARD LVDS [get_ports adc_d2p]
set_property IOSTANDARD LVDS [get_ports adc_d3n]
set_property IOSTANDARD LVDS [get_ports adc_d3p]
set_property IOSTANDARD LVDS [get_ports adc_d4n]
set_property IOSTANDARD LVDS [get_ports adc_d4p]
set_property IOSTANDARD LVDS [get_ports adc_d5n]
set_property IOSTANDARD LVDS [get_ports adc_d5p]
set_property IOSTANDARD LVDS [get_ports adc_d6n]
set_property IOSTANDARD LVDS [get_ports adc_d6p]
set_property IOSTANDARD LVDS [get_ports adc_d7n]
set_property IOSTANDARD LVDS [get_ports adc_d7p]
set_property IOSTANDARD LVDS [get_ports adc_d8n]
set_property IOSTANDARD LVDS [get_ports adc_d8p]
set_property IOSTANDARD LVDS [get_ports adc_d9n]
set_property IOSTANDARD LVDS [get_ports adc_d9p]
set_property IOSTANDARD LVDS [get_ports adc_d10n]
set_property IOSTANDARD LVDS [get_ports adc_d10p]
set_property IOSTANDARD LVDS [get_ports adc_d11n]
set_property IOSTANDARD LVDS [get_ports adc_d11p]
set_property IOSTANDARD LVDS [get_ports adc_clk_n]
set_property IOSTANDARD LVDS [get_ports adc_clk_p]
set_property IOSTANDARD LVDS [get_ports adc_dovrn]
set_property IOSTANDARD LVDS [get_ports adc_dovrp]
set_property IOSTANDARD LVDS [get_ports adc_syncp]
set_property IOSTANDARD LVDS [get_ports adc_syncn]

set_property IOSTANDARD SSTL15 [get_ports ddr3_cas_n]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_cke[0]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports ddr3_ck_p[0]]
set_property IOSTANDARD DIFF_SSTL15 [get_ports ddr3_ck_n[0]]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[0]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_n[0]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_p[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_odt[0]}]
set_property IOSTANDARD SSTL15 [get_ports ddr3_ras_n]
set_property IOSTANDARD LVCMOS15 [get_ports ddr3_reset_n]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[1]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_n[1]}]
set_property IOSTANDARD DIFF_SSTL15_T_DCI [get_ports {ddr3_dqs_p[1]}]
set_property IOSTANDARD SSTL15 [get_ports ddr3_we_n]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[2]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[12]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[11]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[10]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[9]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[8]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[7]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[6]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[5]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[4]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[3]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[2]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[0]}]

set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[15]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[14]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[13]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[12]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[11]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[10]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[9]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[8]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[7]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[6]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[5]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[4]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[3]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[2]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[1]}]
set_property IOSTANDARD SSTL15_T_DCI [get_ports {ddr3_dq[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {debug[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ch_addr[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ch_addr[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ch_addr[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {power_good[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {power_good[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {power_good[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports clkin]
set_property IOSTANDARD LVCMOS33 [get_ports acq_done]
set_property IOSTANDARD LVCMOS33 [get_ports led1]
set_property IOSTANDARD LVCMOS33 [get_ports led2]
set_property IOSTANDARD LVCMOS33 [get_ports acq_trig]
set_property IOSTANDARD LVCMOS33 [get_ports bbus_scl]
set_property IOSTANDARD LVCMOS33 [get_ports bbus_sda]
set_property IOSTANDARD LVCMOS33 [get_ports {io[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports adc_sdo]
set_property IOSTANDARD LVCMOS18 [get_ports adc_sdio]
set_property IOSTANDARD LVCMOS18 [get_ports adc_sdclk]
set_property IOSTANDARD LVCMOS18 [get_ports adc_sdenb]
set_property IOSTANDARD LVCMOS18 [get_ports adc_sresetb]
set_property IOSTANDARD LVCMOS18 [get_ports adc_enable]


set_property DRIVE 12 [get_ports {debug[9]}]
set_property DRIVE 12 [get_ports {debug[8]}]
set_property DRIVE 12 [get_ports {debug[7]}]
set_property DRIVE 12 [get_ports {debug[6]}]
set_property DRIVE 12 [get_ports {debug[5]}]
set_property DRIVE 12 [get_ports {debug[4]}]
set_property DRIVE 12 [get_ports {debug[3]}]
set_property DRIVE 12 [get_ports {debug[2]}]
set_property DRIVE 12 [get_ports {debug[1]}]
set_property DRIVE 12 [get_ports {debug[0]}]
set_property DRIVE 12 [get_ports {ch_addr[2]}]
set_property DRIVE 12 [get_ports {ch_addr[1]}]
set_property DRIVE 12 [get_ports {ch_addr[0]}]
set_property DRIVE 12 [get_ports {power_good[2]}]
set_property DRIVE 12 [get_ports {power_good[1]}]
set_property DRIVE 12 [get_ports {power_good[0]}]
set_property DRIVE 12 [get_ports clkin]
set_property DRIVE 12 [get_ports acq_done]
set_property DRIVE 12 [get_ports led1]
set_property DRIVE 12 [get_ports led2]
set_property DRIVE 12 [get_ports acq_trig]
set_property DRIVE 12 [get_ports bbus_scl]
set_property DRIVE 12 [get_ports bbus_sda]
set_property DRIVE 12 [get_ports {io[3]}]
set_property DRIVE 12 [get_ports {io[2]}]
set_property DRIVE 12 [get_ports {io[1]}]
set_property DRIVE 12 [get_ports {io[0]}]
set_property DRIVE 12 [get_ports adc_sdo]
set_property DRIVE 12 [get_ports adc_sdio]
set_property DRIVE 12 [get_ports adc_sdclk]
set_property DRIVE 12 [get_ports adc_sdenb]
set_property DRIVE 12 [get_ports adc_sresetb]
set_property DRIVE 12 [get_ports adc_enable]


set_property SLEW SLOW [get_ports ddr3_cas_n]
set_property SLEW FAST [get_ports {ddr3_cke[0]}]
set_property SLEW FAST [get_ports ddr3_ck_p[0]]
set_property SLEW FAST [get_ports ddr3_ck_n[0]]
set_property SLEW SLOW [get_ports {ddr3_dm[0]}]
#set_property SLEW SLOW [get_ports ddr3_dqs_n[0]]
#set_property SLEW SLOW [get_ports ddr3_dqs_p[0]]
set_property SLEW SLOW [get_ports {ddr3_odt[0]}]
set_property SLEW SLOW [get_ports ddr3_ras_n]
set_property SLEW SLOW [get_ports ddr3_reset_n]
set_property SLEW SLOW [get_ports {ddr3_dm[1]}]
set_property SLEW SLOW [get_ports {ddr3_dqs_n[1]}]
set_property SLEW SLOW [get_ports {ddr3_dqs_p[1]}]
set_property SLEW FAST [get_ports ddr3_we_n]
set_property SLEW SLOW [get_ports {ddr3_ba[2]}]
set_property SLEW SLOW [get_ports {ddr3_ba[1]}]
set_property SLEW SLOW [get_ports {ddr3_ba[0]}]
set_property SLEW SLOW [get_ports {ddr3_addr[12]}]
set_property SLEW SLOW [get_ports {ddr3_addr[11]}]
set_property SLEW SLOW [get_ports {ddr3_addr[10]}]
set_property SLEW SLOW [get_ports {ddr3_addr[9]}]
set_property SLEW SLOW [get_ports {ddr3_addr[8]}]
set_property SLEW SLOW [get_ports {ddr3_addr[7]}]
set_property SLEW SLOW [get_ports {ddr3_addr[6]}]
set_property SLEW SLOW [get_ports {ddr3_addr[5]}]
set_property SLEW SLOW [get_ports {ddr3_addr[4]}]
set_property SLEW SLOW [get_ports {ddr3_addr[3]}]
set_property SLEW SLOW [get_ports {ddr3_addr[2]}]
set_property SLEW SLOW [get_ports {ddr3_addr[1]}]
set_property SLEW SLOW [get_ports {ddr3_addr[0]}]
set_property SLEW SLOW [get_ports {ddr3_dq[15]}]
set_property SLEW SLOW [get_ports {ddr3_dq[14]}]
set_property SLEW SLOW [get_ports {ddr3_dq[13]}]
set_property SLEW SLOW [get_ports {ddr3_dq[12]}]
set_property SLEW SLOW [get_ports {ddr3_dq[11]}]
set_property SLEW SLOW [get_ports {ddr3_dq[10]}]
set_property SLEW SLOW [get_ports {ddr3_dq[9]}]
set_property SLEW SLOW [get_ports {ddr3_dq[8]}]
set_property SLEW SLOW [get_ports {ddr3_dq[7]}]
set_property SLEW SLOW [get_ports {ddr3_dq[6]}]
set_property SLEW SLOW [get_ports {ddr3_dq[5]}]
set_property SLEW SLOW [get_ports {ddr3_dq[4]}]
set_property SLEW SLOW [get_ports {ddr3_dq[3]}]
set_property SLEW SLOW [get_ports {ddr3_dq[2]}]
set_property SLEW SLOW [get_ports {ddr3_dq[1]}]
set_property SLEW SLOW [get_ports {ddr3_dq[0]}]
set_property SLEW SLOW [get_ports {debug[9]}]
set_property SLEW SLOW [get_ports {debug[8]}]
set_property SLEW SLOW [get_ports {debug[7]}]
set_property SLEW SLOW [get_ports {debug[6]}]
set_property SLEW SLOW [get_ports {debug[5]}]
set_property SLEW SLOW [get_ports {debug[4]}]
set_property SLEW SLOW [get_ports {debug[3]}]
set_property SLEW SLOW [get_ports {debug[2]}]
set_property SLEW SLOW [get_ports {debug[1]}]
set_property SLEW SLOW [get_ports {debug[0]}]
set_property SLEW SLOW [get_ports {ch_addr[2]}]
set_property SLEW SLOW [get_ports {ch_addr[1]}]
set_property SLEW SLOW [get_ports {ch_addr[0]}]
set_property SLEW SLOW [get_ports {power_good[2]}]
set_property SLEW SLOW [get_ports {power_good[1]}]
set_property SLEW SLOW [get_ports {power_good[0]}]
set_property SLEW SLOW [get_ports clkin]
set_property SLEW SLOW [get_ports acq_done]
set_property SLEW SLOW [get_ports led1]
set_property SLEW SLOW [get_ports led2]
set_property SLEW SLOW [get_ports acq_trig]
set_property SLEW SLOW [get_ports bbus_scl]
set_property SLEW SLOW [get_ports bbus_sda]
set_property SLEW SLOW [get_ports {io[3]}]
set_property SLEW SLOW [get_ports {io[2]}]
set_property SLEW SLOW [get_ports {io[1]}]
set_property SLEW SLOW [get_ports {io[0]}]
set_property SLEW SLOW [get_ports adc_sdo]
set_property SLEW SLOW [get_ports adc_sdio]
set_property SLEW SLOW [get_ports adc_sdclk]
set_property SLEW SLOW [get_ports adc_sdenb]
set_property SLEW SLOW [get_ports adc_sresetb]
set_property SLEW SLOW [get_ports adc_enable]

set_property PACKAGE_PIN A11 [get_ports acq_done]
set_property PACKAGE_PIN A10 [get_ports acq_trig]
set_property PACKAGE_PIN W12 [get_ports adc_d0p]
set_property PACKAGE_PIN AA6 [get_ports adc_d10p]
set_property PACKAGE_PIN AA5 [get_ports adc_d11p]
set_property PACKAGE_PIN AB13 [get_ports adc_d1p]
set_property PACKAGE_PIN W11 [get_ports adc_d2p]
set_property PACKAGE_PIN AA11 [get_ports adc_d3p]
set_property PACKAGE_PIN AA10 [get_ports adc_d4p]
set_property PACKAGE_PIN W9 [get_ports adc_d5p]
set_property PACKAGE_PIN AA9 [get_ports adc_d6p]
set_property PACKAGE_PIN Y8 [get_ports adc_d7p]
set_property PACKAGE_PIN AB8 [get_ports adc_d8p]
set_property PACKAGE_PIN W6 [get_ports adc_d9p]
set_property PACKAGE_PIN V7 [get_ports adc_clk_p]
set_property PACKAGE_PIN Y13 [get_ports adc_dovrp]
set_property PACKAGE_PIN A15 [get_ports bbus_scl]
set_property PACKAGE_PIN A16 [get_ports bbus_sda]
set_property PACKAGE_PIN B6 [get_ports c0_rx]
set_property PACKAGE_PIN B5 [get_ports c0_rx_N]
set_property PACKAGE_PIN Y17 [get_ports {ch_addr[0]}]
set_property PACKAGE_PIN AA18 [get_ports {ch_addr[1]}]
set_property PACKAGE_PIN AB18 [get_ports {ch_addr[2]}]
set_property PACKAGE_PIN N18 [get_ports clkin]
set_property PACKAGE_PIN V2 [get_ports {ddr3_addr[0]}]
set_property PACKAGE_PIN U2 [get_ports {ddr3_addr[1]}]
set_property PACKAGE_PIN W4 [get_ports {ddr3_addr[2]}]
set_property PACKAGE_PIN V4 [get_ports {ddr3_addr[3]}]
set_property PACKAGE_PIN AB3 [get_ports {ddr3_addr[4]}]
set_property PACKAGE_PIN AA4 [get_ports {ddr3_addr[5]}]
set_property PACKAGE_PIN AB2 [get_ports {ddr3_addr[6]}]
set_property PACKAGE_PIN AA3 [get_ports {ddr3_addr[7]}]
set_property PACKAGE_PIN AB1 [get_ports {ddr3_addr[8]}]
set_property PACKAGE_PIN AA1 [get_ports {ddr3_addr[9]}]
set_property PACKAGE_PIN Y1 [get_ports {ddr3_addr[10]}]
set_property PACKAGE_PIN W1 [get_ports {ddr3_addr[11]}]
set_property PACKAGE_PIN W5 [get_ports {ddr3_addr[12]}]
set_property PACKAGE_PIN V3 [get_ports {ddr3_ba[0]}]
set_property PACKAGE_PIN U5 [get_ports {ddr3_ba[1]}]
set_property PACKAGE_PIN T5 [get_ports {ddr3_ba[2]}]
set_property PACKAGE_PIN N5 [get_ports {ddr3_cas_n}]
set_property PACKAGE_PIN T4 [get_ports {ddr3_cke[0]}]
set_property PACKAGE_PIN Y3 [get_ports {ddr3_ck_p[0]}]
set_property PACKAGE_PIN Y2 [get_ports {ddr3_ck_n[0]}]
set_property PACKAGE_PIN M3 [get_ports {ddr3_dq[0]}]
set_property PACKAGE_PIN K1 [get_ports {ddr3_dq[1]}]
set_property PACKAGE_PIN L1 [get_ports {ddr3_dq[2]}]
set_property PACKAGE_PIN K3 [get_ports {ddr3_dq[3]}]
set_property PACKAGE_PIN K2 [get_ports {ddr3_dq[4]}]
set_property PACKAGE_PIN N3 [get_ports {ddr3_dq[5]}]
set_property PACKAGE_PIN N2 [get_ports {ddr3_dq[6]}]
set_property PACKAGE_PIN L5 [get_ports {ddr3_dq[7]}]
set_property PACKAGE_PIN R2 [get_ports {ddr3_dq[8]}]
set_property PACKAGE_PIN P1 [get_ports {ddr3_dq[9]}]
set_property PACKAGE_PIN R1 [get_ports {ddr3_dq[10]}]
set_property PACKAGE_PIN T1 [get_ports {ddr3_dq[11]}]
set_property PACKAGE_PIN U1 [get_ports {ddr3_dq[12]}]
set_property PACKAGE_PIN P4 [get_ports {ddr3_dq[13]}]
set_property PACKAGE_PIN R4 [get_ports {ddr3_dq[14]}]
set_property PACKAGE_PIN R3 [get_ports {ddr3_dq[15]}]
set_property PACKAGE_PIN L3 [get_ports {ddr3_dm[0]}]
set_property PACKAGE_PIN M2 [get_ports {ddr3_dqs_p[0]}]
set_property PACKAGE_PIN M1 [get_ports {ddr3_dqs_n[0]}]
set_property PACKAGE_PIN M5 [get_ports {ddr3_dqs_p[1]}]
set_property PACKAGE_PIN N4 [get_ports {ddr3_dqs_n[1]}]
set_property PACKAGE_PIN U3 [get_ports {ddr3_odt[0]}]
set_property PACKAGE_PIN W2 [get_ports {ddr3_ras_n}]
set_property PACKAGE_PIN T3 [get_ports {ddr3_reset_n}]
set_property PACKAGE_PIN P2 [get_ports {ddr3_dm[1]}]
set_property PACKAGE_PIN P5 [get_ports {ddr3_we_n}]

set_property PACKAGE_PIN V22 [get_ports {debug[0]}]
set_property PACKAGE_PIN U22 [get_ports {debug[1]}]
set_property PACKAGE_PIN W21 [get_ports {debug[2]}]
set_property PACKAGE_PIN U21 [get_ports {debug[3]}]
set_property PACKAGE_PIN W22 [get_ports {debug[4]}]
set_property PACKAGE_PIN AB20 [get_ports {debug[5]}]
set_property PACKAGE_PIN Y21 [get_ports {debug[6]}]
set_property PACKAGE_PIN AB21 [get_ports {debug[7]}]
set_property PACKAGE_PIN Y22 [get_ports {debug[8]}]
set_property PACKAGE_PIN AB22 [get_ports {debug[9]}]
set_property PACKAGE_PIN P19 [get_ports led1]
set_property PACKAGE_PIN P20 [get_ports led2]
set_property PACKAGE_PIN R19 [get_ports {power_good[0]}]
set_property PACKAGE_PIN L21 [get_ports {power_good[1]}]
set_property PACKAGE_PIN R18 [get_ports {power_good[2]}]
set_property PACKAGE_PIN D5 [get_ports xcvr_clk_N]
set_property PACKAGE_PIN D6 [get_ports xcvr_clk]
set_property PACKAGE_PIN B18 [get_ports {io[3]}]
set_property PACKAGE_PIN A19 [get_ports {io[2]}]
set_property PACKAGE_PIN C22 [get_ports {io[1]}]
set_property PACKAGE_PIN B22 [get_ports {io[0]}]
set_property PACKAGE_PIN V13 [get_ports adc_sdo]
set_property PACKAGE_PIN V12 [get_ports adc_sdio]
set_property PACKAGE_PIN U10 [get_ports adc_sdclk]
set_property PACKAGE_PIN V9 [get_ports adc_sdenb]
set_property PACKAGE_PIN T11 [get_ports adc_sresetb]
set_property PACKAGE_PIN T10 [get_ports adc_enable]
set_property PACKAGE_PIN U12 [get_ports adc_syncp]
set_property PACKAGE_PIN U11 [get_ports adc_syncn]











create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list adc_clk_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 12 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {adc_acq_top_selftrigc/self_trigger/threshold[0]} {adc_acq_top_selftrigc/self_trigger/threshold[1]} {adc_acq_top_selftrigc/self_trigger/threshold[2]} {adc_acq_top_selftrigc/self_trigger/threshold[3]} {adc_acq_top_selftrigc/self_trigger/threshold[4]} {adc_acq_top_selftrigc/self_trigger/threshold[5]} {adc_acq_top_selftrigc/self_trigger/threshold[6]} {adc_acq_top_selftrigc/self_trigger/threshold[7]} {adc_acq_top_selftrigc/self_trigger/threshold[8]} {adc_acq_top_selftrigc/self_trigger/threshold[9]} {adc_acq_top_selftrigc/self_trigger/threshold[10]} {adc_acq_top_selftrigc/self_trigger/threshold[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 12 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {adc_acq_top_selftrigc/self_trigger/ped_buffer2[0]} {adc_acq_top_selftrigc/self_trigger/ped_buffer2[1]} {adc_acq_top_selftrigc/self_trigger/ped_buffer2[2]} {adc_acq_top_selftrigc/self_trigger/ped_buffer2[3]} {adc_acq_top_selftrigc/self_trigger/ped_buffer2[4]} {adc_acq_top_selftrigc/self_trigger/ped_buffer2[5]} {adc_acq_top_selftrigc/self_trigger/ped_buffer2[6]} {adc_acq_top_selftrigc/self_trigger/ped_buffer2[7]} {adc_acq_top_selftrigc/self_trigger/ped_buffer2[8]} {adc_acq_top_selftrigc/self_trigger/ped_buffer2[9]} {adc_acq_top_selftrigc/self_trigger/ped_buffer2[10]} {adc_acq_top_selftrigc/self_trigger/ped_buffer2[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 12 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {adc_acq_top_selftrigc/self_trigger/signal_average[0]} {adc_acq_top_selftrigc/self_trigger/signal_average[1]} {adc_acq_top_selftrigc/self_trigger/signal_average[2]} {adc_acq_top_selftrigc/self_trigger/signal_average[3]} {adc_acq_top_selftrigc/self_trigger/signal_average[4]} {adc_acq_top_selftrigc/self_trigger/signal_average[5]} {adc_acq_top_selftrigc/self_trigger/signal_average[6]} {adc_acq_top_selftrigc/self_trigger/signal_average[7]} {adc_acq_top_selftrigc/self_trigger/signal_average[8]} {adc_acq_top_selftrigc/self_trigger/signal_average[9]} {adc_acq_top_selftrigc/self_trigger/signal_average[10]} {adc_acq_top_selftrigc/self_trigger/signal_average[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 6 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {adc_acq_top_selftrigc/self_trigger/CS[0]} {adc_acq_top_selftrigc/self_trigger/CS[1]} {adc_acq_top_selftrigc/self_trigger/CS[2]} {adc_acq_top_selftrigc/self_trigger/CS[3]} {adc_acq_top_selftrigc/self_trigger/CS[4]} {adc_acq_top_selftrigc/self_trigger/CS[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {adc_acq_top_selftrigc/self_trigger/selftrig_count[0]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[1]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[2]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[3]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[4]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[5]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[6]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[7]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[8]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[9]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[10]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[11]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[12]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[13]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[14]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[15]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[16]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[17]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[18]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[19]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[20]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[21]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[22]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[23]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[24]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[25]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[26]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[27]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[28]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[29]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[30]} {adc_acq_top_selftrigc/self_trigger/selftrig_count[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list adc_acq_top_selftrigc/self_trigger/enable_debug]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list adc_acq_top_selftrigc/self_trigger/local_trigger_wire_d1]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list adc_acq_top_selftrigc/self_trigger/neg_trig_cond]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list adc_acq_top_selftrigc/self_trigger/polarity]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list adc_acq_top_selftrigc/self_trigger/pos_trig_cond]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list adc_acq_top_selftrigc/self_trigger/self_trig_ready]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list ddr3_intf_selftrigc/u_wfd5_ddr3_r1/u_wfd5_ddr3_r1_mig/u_ddr3_infrastructure/CLK]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 17 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[0]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[1]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[2]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[3]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[4]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[5]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[6]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[7]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[8]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[9]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[10]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[11]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[12]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[13]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[14]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[15]} {ddr3_intf_selftrigc/ddr3_wr_control_selftrigc/CS[16]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ddr3_domain_clk]

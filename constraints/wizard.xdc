






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
set_property port_width 9 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {command_top/register_block64/enable_sm_state[0]} {command_top/register_block64/enable_sm_state[1]} {command_top/register_block64/enable_sm_state[2]} {command_top/register_block64/enable_sm_state[3]} {command_top/register_block64/enable_sm_state[4]} {command_top/register_block64/enable_sm_state[5]} {command_top/register_block64/enable_sm_state[6]} {command_top/register_block64/enable_sm_state[7]} {command_top/register_block64/enable_sm_state[8]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 19 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {command_top/register_block64/circ_to_ddr3_state[0]} {command_top/register_block64/circ_to_ddr3_state[1]} {command_top/register_block64/circ_to_ddr3_state[2]} {command_top/register_block64/circ_to_ddr3_state[3]} {command_top/register_block64/circ_to_ddr3_state[4]} {command_top/register_block64/circ_to_ddr3_state[5]} {command_top/register_block64/circ_to_ddr3_state[6]} {command_top/register_block64/circ_to_ddr3_state[7]} {command_top/register_block64/circ_to_ddr3_state[8]} {command_top/register_block64/circ_to_ddr3_state[9]} {command_top/register_block64/circ_to_ddr3_state[10]} {command_top/register_block64/circ_to_ddr3_state[11]} {command_top/register_block64/circ_to_ddr3_state[12]} {command_top/register_block64/circ_to_ddr3_state[13]} {command_top/register_block64/circ_to_ddr3_state[14]} {command_top/register_block64/circ_to_ddr3_state[15]} {command_top/register_block64/circ_to_ddr3_state[16]} {command_top/register_block64/circ_to_ddr3_state[17]} {command_top/register_block64/circ_to_ddr3_state[18]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list adc_acq_top_selftrig/self_trigger/local_trigger]]
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
connect_debug_port u_ila_1/clk [get_nets [list ddr3_intf_selftrig/u_wfd5_ddr3_r1/u_wfd5_ddr3_r1_mig/u_ddr3_infrastructure/CLK]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 4 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {ddr3_intf_selftrig/ddr3_wr_control_selftrig/tag[0]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/tag[1]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/tag[2]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/tag[3]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 13 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[0]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[1]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[2]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[3]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[4]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[5]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[6]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[7]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[8]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[9]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[10]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[11]} {ddr3_intf_selftrig/ddr3_wr_control_selftrig/CS[12]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 3 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {command_top/register_block64/ddr3_rd_ctrl_state[0]} {command_top/register_block64/ddr3_rd_ctrl_state[1]} {command_top/register_block64/ddr3_rd_ctrl_state[2]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list ddr3_intf_selftrig/ddr3_wr_control_selftrig/acq_enabled]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
set_property port_width 1 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list ddr3_intf_selftrig/ddr3_wr_control_selftrig/clear_data_collection]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
set_property port_width 1 [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list ddr3_intf_selftrig/ddr3_wr_control_selftrig/data_collection_in_progress]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
set_property port_width 1 [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list ddr3_intf_selftrig/ddr3_wr_control_selftrig/ddr3_wr_fifo_empty]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
set_property port_width 1 [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list ddr3_intf_selftrig/ddr3_wr_control_selftrig/ddr3_wr_fill_in_progress]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe8]
set_property port_width 1 [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list ddr3_intf_selftrig/ddr3_wr_control_selftrig/run_in_progress_sync]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe9]
set_property port_width 1 [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list ddr3_intf_selftrig/ddr3_wr_control_selftrig/set_data_collection]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ddr3_domain_clk]

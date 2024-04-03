

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
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[0]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[1]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[2]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[3]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[4]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[5]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[6]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[7]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[8]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[9]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[10]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[11]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[12]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[13]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[14]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_addr[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 26 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[0]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[1]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[2]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[3]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[4]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[5]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[6]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[7]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[8]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[9]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[10]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[11]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[12]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[13]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[14]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[15]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[16]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[17]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[18]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[19]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[20]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[21]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[22]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[23]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[24]} {adc_acq_top_cbuf/adc_to_circ_buf_ASYNC/circ_buf_wr_dat[25]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 26 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {adc_acq_top_cbuf/circ_buf_rd_dat[0]} {adc_acq_top_cbuf/circ_buf_rd_dat[1]} {adc_acq_top_cbuf/circ_buf_rd_dat[2]} {adc_acq_top_cbuf/circ_buf_rd_dat[3]} {adc_acq_top_cbuf/circ_buf_rd_dat[4]} {adc_acq_top_cbuf/circ_buf_rd_dat[5]} {adc_acq_top_cbuf/circ_buf_rd_dat[6]} {adc_acq_top_cbuf/circ_buf_rd_dat[7]} {adc_acq_top_cbuf/circ_buf_rd_dat[8]} {adc_acq_top_cbuf/circ_buf_rd_dat[9]} {adc_acq_top_cbuf/circ_buf_rd_dat[10]} {adc_acq_top_cbuf/circ_buf_rd_dat[11]} {adc_acq_top_cbuf/circ_buf_rd_dat[12]} {adc_acq_top_cbuf/circ_buf_rd_dat[13]} {adc_acq_top_cbuf/circ_buf_rd_dat[14]} {adc_acq_top_cbuf/circ_buf_rd_dat[15]} {adc_acq_top_cbuf/circ_buf_rd_dat[16]} {adc_acq_top_cbuf/circ_buf_rd_dat[17]} {adc_acq_top_cbuf/circ_buf_rd_dat[18]} {adc_acq_top_cbuf/circ_buf_rd_dat[19]} {adc_acq_top_cbuf/circ_buf_rd_dat[20]} {adc_acq_top_cbuf/circ_buf_rd_dat[21]} {adc_acq_top_cbuf/circ_buf_rd_dat[22]} {adc_acq_top_cbuf/circ_buf_rd_dat[23]} {adc_acq_top_cbuf/circ_buf_rd_dat[24]} {adc_acq_top_cbuf/circ_buf_rd_dat[25]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 16 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {adc_acq_top_cbuf/circ_buf_rd_addr[0]} {adc_acq_top_cbuf/circ_buf_rd_addr[1]} {adc_acq_top_cbuf/circ_buf_rd_addr[2]} {adc_acq_top_cbuf/circ_buf_rd_addr[3]} {adc_acq_top_cbuf/circ_buf_rd_addr[4]} {adc_acq_top_cbuf/circ_buf_rd_addr[5]} {adc_acq_top_cbuf/circ_buf_rd_addr[6]} {adc_acq_top_cbuf/circ_buf_rd_addr[7]} {adc_acq_top_cbuf/circ_buf_rd_addr[8]} {adc_acq_top_cbuf/circ_buf_rd_addr[9]} {adc_acq_top_cbuf/circ_buf_rd_addr[10]} {adc_acq_top_cbuf/circ_buf_rd_addr[11]} {adc_acq_top_cbuf/circ_buf_rd_addr[12]} {adc_acq_top_cbuf/circ_buf_rd_addr[13]} {adc_acq_top_cbuf/circ_buf_rd_addr[14]} {adc_acq_top_cbuf/circ_buf_rd_addr[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list adc_acq_top_cbuf/adc_acq_sm_cbuf/adc_mux_dat_sel]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list adc_acq_top_cbuf/adc_acq_sm_cbuf/latch_circ_buf_dat]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list adc_acq_top_cbuf/adc_acq_sm_cbuf/trig_addr_rd_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list adc_acq_top_cbuf/adc_acq_sm_cbuf/trig_pulse]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets adc_clk_BUFG]

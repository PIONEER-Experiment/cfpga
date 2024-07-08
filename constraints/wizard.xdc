

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list adc_clk_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 23 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[0]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[1]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[2]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[3]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[4]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[5]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[6]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[7]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[8]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[9]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[10]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[11]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[12]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[13]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[14]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[15]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[16]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[17]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[18]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[19]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[20]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[21]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/adc_dat_mux_selftrig/waveform_start_adr[22]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 23 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[0]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[1]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[2]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[3]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[4]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[5]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[6]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[7]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[8]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[9]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[10]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[11]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[12]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[13]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[14]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[15]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[16]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[17]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[18]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[19]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[20]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[21]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/waveform_start_adr[22]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 23 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[0]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[1]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[2]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[3]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[4]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[5]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[6]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[7]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[8]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[9]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[10]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[11]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[12]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[13]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[14]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[15]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[16]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[17]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[18]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[19]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[20]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[21]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr[22]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 9 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {adc_acq_top_selftrig/enable_sm_selftrig/CS[0]} {adc_acq_top_selftrig/enable_sm_selftrig/CS[1]} {adc_acq_top_selftrig/enable_sm_selftrig/CS[2]} {adc_acq_top_selftrig/enable_sm_selftrig/CS[3]} {adc_acq_top_selftrig/enable_sm_selftrig/CS[4]} {adc_acq_top_selftrig/enable_sm_selftrig/CS[5]} {adc_acq_top_selftrig/enable_sm_selftrig/CS[6]} {adc_acq_top_selftrig/enable_sm_selftrig/CS[7]} {adc_acq_top_selftrig/enable_sm_selftrig/CS[8]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 18 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[0]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[1]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[2]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[3]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[4]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[5]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[6]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[7]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[8]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[9]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[10]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[11]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[12]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[13]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[14]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[15]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[16]} {adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/CS[17]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list acq_trig_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list adc_acq_top_selftrig/adc_acq_out_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/burst_adr_cntr_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list adc_acq_top_selftrig/enable_sm_selftrig/cbuf_rd_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list adc_acq_top_selftrig/enable_sm_selftrig/cbuf_trig_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/cbuf_trig_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list adc_acq_top_selftrig/enable_sm_selftrig/cbuf_wr_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list adc_acq_top_selftrig/ddr3_buffer]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list adc_acq_top_selftrig/enable_sm_selftrig/ddr3_mem_range]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list adc_acq_top_selftrig/ddr3_wr_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list adc_acq_top_selftrig/enable_sm_selftrig/ddr3_wr_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list ddr3_intf_selftrig/ddr3_wr_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list adc_acq_top_selftrig/enable_triggering]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list adc_acq_top_selftrig/ext_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list adc_acq_top_selftrig/self_trigger/holding_trigger]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list adc_acq_top_selftrig/self_trigger/init_hold_counter]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list adc_acq_top_selftrig/enable_sm_selftrig/prev_ddr3_buffer]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list adc_acq_top_selftrig/enable_sm_selftrig/range_flip]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/save_start_adr]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list adc_acq_top_selftrig/self_trig]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list adc_acq_top_selftrig/trig_addr_rd_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/circ_buf_to_ddr3_sm_selftrig/trig_fifo_empty]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list adc_acq_top_selftrig/enable_sm_selftrig/trig_pulse]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list adc_acq_top_selftrig/self_trigger/trigger]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets adc_clk_BUFG]

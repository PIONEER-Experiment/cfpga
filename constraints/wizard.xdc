




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
connect_debug_port u_ila_0/clk [get_nets [list clk125]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 11 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {command_top/command_sm/CS[0]} {command_top/command_sm/CS[1]} {command_top/command_sm/CS[2]} {command_top/command_sm/CS[3]} {command_top/command_sm/CS[4]} {command_top/command_sm/CS[5]} {command_top/command_sm/CS[6]} {command_top/command_sm/CS[7]} {command_top/command_sm/CS[8]} {command_top/command_sm/CS[9]} {command_top/command_sm/CS[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 152 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {command_top/cc_rd_fill_sm/fill_header_fifo_out[0]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[1]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[2]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[3]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[4]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[5]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[6]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[7]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[8]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[9]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[10]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[11]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[12]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[13]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[14]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[15]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[16]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[17]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[18]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[19]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[20]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[21]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[22]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[23]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[24]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[25]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[26]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[27]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[28]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[29]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[30]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[31]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[32]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[33]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[34]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[35]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[36]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[37]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[38]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[39]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[40]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[41]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[42]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[43]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[44]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[45]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[46]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[47]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[48]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[49]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[50]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[51]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[52]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[53]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[54]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[55]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[56]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[57]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[58]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[59]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[60]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[61]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[62]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[63]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[64]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[65]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[66]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[67]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[68]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[69]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[70]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[71]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[72]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[73]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[74]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[75]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[76]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[77]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[78]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[79]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[80]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[81]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[82]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[83]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[84]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[85]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[86]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[87]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[88]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[89]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[90]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[91]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[92]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[93]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[94]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[95]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[96]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[97]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[98]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[99]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[100]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[101]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[102]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[103]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[104]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[105]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[106]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[107]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[108]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[109]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[110]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[111]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[112]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[113]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[114]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[115]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[116]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[117]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[118]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[119]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[120]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[121]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[122]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[123]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[124]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[125]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[126]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[127]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[128]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[129]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[130]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[131]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[132]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[133]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[134]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[135]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[136]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[137]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[138]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[139]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[140]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[141]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[142]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[143]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[144]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[145]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[146]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[147]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[148]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[149]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[150]} {command_top/cc_rd_fill_sm/fill_header_fifo_out[151]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 12 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {command_top/cc_rd_fill_sm/event_ctr[0]} {command_top/cc_rd_fill_sm/event_ctr[1]} {command_top/cc_rd_fill_sm/event_ctr[2]} {command_top/cc_rd_fill_sm/event_ctr[3]} {command_top/cc_rd_fill_sm/event_ctr[4]} {command_top/cc_rd_fill_sm/event_ctr[5]} {command_top/cc_rd_fill_sm/event_ctr[6]} {command_top/cc_rd_fill_sm/event_ctr[7]} {command_top/cc_rd_fill_sm/event_ctr[8]} {command_top/cc_rd_fill_sm/event_ctr[9]} {command_top/cc_rd_fill_sm/event_ctr[10]} {command_top/cc_rd_fill_sm/event_ctr[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 10 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {command_top/cc_rd_fill_sm/NS[0]} {command_top/cc_rd_fill_sm/NS[1]} {command_top/cc_rd_fill_sm/NS[2]} {command_top/cc_rd_fill_sm/NS[3]} {command_top/cc_rd_fill_sm/NS[4]} {command_top/cc_rd_fill_sm/NS[5]} {command_top/cc_rd_fill_sm/NS[6]} {command_top/cc_rd_fill_sm/NS[7]} {command_top/cc_rd_fill_sm/NS[8]} {command_top/cc_rd_fill_sm/NS[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 10 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {command_top/cc_rd_fill_sm/CS[0]} {command_top/cc_rd_fill_sm/CS[1]} {command_top/cc_rd_fill_sm/CS[2]} {command_top/cc_rd_fill_sm/CS[3]} {command_top/cc_rd_fill_sm/CS[4]} {command_top/cc_rd_fill_sm/CS[5]} {command_top/cc_rd_fill_sm/CS[6]} {command_top/cc_rd_fill_sm/CS[7]} {command_top/cc_rd_fill_sm/CS[8]} {command_top/cc_rd_fill_sm/CS[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 128 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {ddr3_rd_fifo_output_dat[0]} {ddr3_rd_fifo_output_dat[1]} {ddr3_rd_fifo_output_dat[2]} {ddr3_rd_fifo_output_dat[3]} {ddr3_rd_fifo_output_dat[4]} {ddr3_rd_fifo_output_dat[5]} {ddr3_rd_fifo_output_dat[6]} {ddr3_rd_fifo_output_dat[7]} {ddr3_rd_fifo_output_dat[8]} {ddr3_rd_fifo_output_dat[9]} {ddr3_rd_fifo_output_dat[10]} {ddr3_rd_fifo_output_dat[11]} {ddr3_rd_fifo_output_dat[12]} {ddr3_rd_fifo_output_dat[13]} {ddr3_rd_fifo_output_dat[14]} {ddr3_rd_fifo_output_dat[15]} {ddr3_rd_fifo_output_dat[16]} {ddr3_rd_fifo_output_dat[17]} {ddr3_rd_fifo_output_dat[18]} {ddr3_rd_fifo_output_dat[19]} {ddr3_rd_fifo_output_dat[20]} {ddr3_rd_fifo_output_dat[21]} {ddr3_rd_fifo_output_dat[22]} {ddr3_rd_fifo_output_dat[23]} {ddr3_rd_fifo_output_dat[24]} {ddr3_rd_fifo_output_dat[25]} {ddr3_rd_fifo_output_dat[26]} {ddr3_rd_fifo_output_dat[27]} {ddr3_rd_fifo_output_dat[28]} {ddr3_rd_fifo_output_dat[29]} {ddr3_rd_fifo_output_dat[30]} {ddr3_rd_fifo_output_dat[31]} {ddr3_rd_fifo_output_dat[32]} {ddr3_rd_fifo_output_dat[33]} {ddr3_rd_fifo_output_dat[34]} {ddr3_rd_fifo_output_dat[35]} {ddr3_rd_fifo_output_dat[36]} {ddr3_rd_fifo_output_dat[37]} {ddr3_rd_fifo_output_dat[38]} {ddr3_rd_fifo_output_dat[39]} {ddr3_rd_fifo_output_dat[40]} {ddr3_rd_fifo_output_dat[41]} {ddr3_rd_fifo_output_dat[42]} {ddr3_rd_fifo_output_dat[43]} {ddr3_rd_fifo_output_dat[44]} {ddr3_rd_fifo_output_dat[45]} {ddr3_rd_fifo_output_dat[46]} {ddr3_rd_fifo_output_dat[47]} {ddr3_rd_fifo_output_dat[48]} {ddr3_rd_fifo_output_dat[49]} {ddr3_rd_fifo_output_dat[50]} {ddr3_rd_fifo_output_dat[51]} {ddr3_rd_fifo_output_dat[52]} {ddr3_rd_fifo_output_dat[53]} {ddr3_rd_fifo_output_dat[54]} {ddr3_rd_fifo_output_dat[55]} {ddr3_rd_fifo_output_dat[56]} {ddr3_rd_fifo_output_dat[57]} {ddr3_rd_fifo_output_dat[58]} {ddr3_rd_fifo_output_dat[59]} {ddr3_rd_fifo_output_dat[60]} {ddr3_rd_fifo_output_dat[61]} {ddr3_rd_fifo_output_dat[62]} {ddr3_rd_fifo_output_dat[63]} {ddr3_rd_fifo_output_dat[64]} {ddr3_rd_fifo_output_dat[65]} {ddr3_rd_fifo_output_dat[66]} {ddr3_rd_fifo_output_dat[67]} {ddr3_rd_fifo_output_dat[68]} {ddr3_rd_fifo_output_dat[69]} {ddr3_rd_fifo_output_dat[70]} {ddr3_rd_fifo_output_dat[71]} {ddr3_rd_fifo_output_dat[72]} {ddr3_rd_fifo_output_dat[73]} {ddr3_rd_fifo_output_dat[74]} {ddr3_rd_fifo_output_dat[75]} {ddr3_rd_fifo_output_dat[76]} {ddr3_rd_fifo_output_dat[77]} {ddr3_rd_fifo_output_dat[78]} {ddr3_rd_fifo_output_dat[79]} {ddr3_rd_fifo_output_dat[80]} {ddr3_rd_fifo_output_dat[81]} {ddr3_rd_fifo_output_dat[82]} {ddr3_rd_fifo_output_dat[83]} {ddr3_rd_fifo_output_dat[84]} {ddr3_rd_fifo_output_dat[85]} {ddr3_rd_fifo_output_dat[86]} {ddr3_rd_fifo_output_dat[87]} {ddr3_rd_fifo_output_dat[88]} {ddr3_rd_fifo_output_dat[89]} {ddr3_rd_fifo_output_dat[90]} {ddr3_rd_fifo_output_dat[91]} {ddr3_rd_fifo_output_dat[92]} {ddr3_rd_fifo_output_dat[93]} {ddr3_rd_fifo_output_dat[94]} {ddr3_rd_fifo_output_dat[95]} {ddr3_rd_fifo_output_dat[96]} {ddr3_rd_fifo_output_dat[97]} {ddr3_rd_fifo_output_dat[98]} {ddr3_rd_fifo_output_dat[99]} {ddr3_rd_fifo_output_dat[100]} {ddr3_rd_fifo_output_dat[101]} {ddr3_rd_fifo_output_dat[102]} {ddr3_rd_fifo_output_dat[103]} {ddr3_rd_fifo_output_dat[104]} {ddr3_rd_fifo_output_dat[105]} {ddr3_rd_fifo_output_dat[106]} {ddr3_rd_fifo_output_dat[107]} {ddr3_rd_fifo_output_dat[108]} {ddr3_rd_fifo_output_dat[109]} {ddr3_rd_fifo_output_dat[110]} {ddr3_rd_fifo_output_dat[111]} {ddr3_rd_fifo_output_dat[112]} {ddr3_rd_fifo_output_dat[113]} {ddr3_rd_fifo_output_dat[114]} {ddr3_rd_fifo_output_dat[115]} {ddr3_rd_fifo_output_dat[116]} {ddr3_rd_fifo_output_dat[117]} {ddr3_rd_fifo_output_dat[118]} {ddr3_rd_fifo_output_dat[119]} {ddr3_rd_fifo_output_dat[120]} {ddr3_rd_fifo_output_dat[121]} {ddr3_rd_fifo_output_dat[122]} {ddr3_rd_fifo_output_dat[123]} {ddr3_rd_fifo_output_dat[124]} {ddr3_rd_fifo_output_dat[125]} {ddr3_rd_fifo_output_dat[126]} {ddr3_rd_fifo_output_dat[127]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list command_top/cc_rd_fill_sm/acq_done_latch]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list command_top/cc_rd_fill_sm/aurora_ddr3_accept]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list ddr3_rd_fifo_output_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list ddr3_rd_fifo_output_tvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list command_top/cc_rd_fill_sm/en_fixed_ddr3_start_addr]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list command_top/cc_rd_fill_sm/enable_reading]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list ddr3_intf_selftrig/enable_triggering_125]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list command_top/cc_rd_fill_sm/error_found]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list ddr3_intf_selftrig/fill_header_fifo_empty]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list command_top/cc_rd_fill_sm/fill_header_fifo_empty]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list command_top/cc_rd_fill_sm/fill_header_fifo_rd_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list ddr3_intf_selftrig/fill_header_fifo_rd_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list adc_acq_top_selftrig/circ_buf_to_ddr3_selftrig/initial_fill_num_wr]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list command_top/cc_rd_fill_sm/initial_fill_num_wr]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list ddr3_intf_selftrig/readout_pause_125]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list command_top/run_cmd_sm]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list command_top/cc_rd_fill_sm/run_sm]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list command_top/cc_rd_fill_sm/send_cmd]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list command_top/cc_rd_fill_sm/send_csn]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list command_top/cc_rd_fill_sm/send_inv_cmd]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list command_top/cc_rd_fill_sm/sm_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list command_top/cc_rd_fill_sm/sm_running]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list command_top/cc_rd_fill_sm/tx_tlast]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list command_top/cc_rd_fill_sm/tx_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list command_top/cc_rd_fill_sm/tx_tvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list command_top/cc_rd_fill_sm/use_ddr3_data]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ddr3_domain_clk]

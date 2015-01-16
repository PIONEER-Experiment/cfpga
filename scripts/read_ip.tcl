# Load necessary IP into the project
# For each IP, check to see if the file already exists.
# If it doesn't exist, create it

# If you want to add a module here, you can get the appropriate create_ip and set_property lines
# by creating and customizing the IP in the Vivado GUI, then checking the TCL console to see
# the commands that Vivado has run to create it.


# setup
set_property target_simulator XSim [current_project]
set_property part xc7k70tfbg484-2 [current_project]

# channnel serial link FIFO
if {[file exists $ROOT/ip/chan_link_axis_data_fifo/chan_link_axis_data_fifo.xci
]} {
	read_ip $ROOT/ip/chan_link_axis_data_fifo/chan_link_axis_data_fifo.xci
} else {
	create_ip -name axis_data_fifo -vendor xilinx.com -library ip -module_name chan_link_axis_data_fifo -dir $ROOT/ip
	set_property -dict [list CONFIG.TDATA_NUM_BYTES {4} CONFIG.FIFO_DEPTH {4096} CONFIG.IS_ACLK_ASYNC {1} CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1}] [get_ips chan_link_axis_data_fifo]
	generate_target all [get_files $ROOT/ip/chan_link_axis_data_fifo/chan_link_axis_data_fifo.xci]
	synth_ip [get_ips chan_link_axis_data_fifo]
}

# aurora serial link to channel fpga
if {[file exists $ROOT/ip/aurora_8b10b_0/aurora_8b10b_0.xci]} {
	read_ip $ROOT/ip/aurora_8b10b_0/aurora_8b10b_0.xci
} else {
	create_ip -name aurora_8b10b -vendor xilinx.com -library ip -module_name aurora_8b10b_0 -dir $ROOT/ip
	set_property -dict [list CONFIG.C_LANE_WIDTH {4} CONFIG.C_LINE_RATE {5.0}] [get_ips aurora_8b10b_0]
	generate_target all [get_files $ROOT/ip/aurora_8b10b_0/aurora_8b10b_0.xci]
	synth_ip [get_ips aurora_8b10b_0]
}

# SelectIO Interface Wizard
if {[file exists $ROOT/ip/selectio_wiz_0/selectio_wiz_0.xci]} {
	read_ip $ROOT/ip/selectio_wiz_0/selectio_wiz_0.xci
} else {
	create_ip -name selectio_wiz -vendor xilinx.com -library ip -module_name selectio_wiz_0 -dir $ROOT/ip
	set_property -dict [list CONFIG.BUS_SIG_TYPE {DIFF} CONFIG.BUS_IO_STD {LVDS_25} CONFIG.SELIO_ACTIVE_EDGE {DDR} CONFIG.SYSTEM_DATA_WIDTH {13} CONFIG.SELIO_BUS_IN_DELAY {VAR_LOADABLE} CONFIG.CLK_DELAY {FIXED} CONFIG.CLK_TAP {0} CONFIG.SELIO_DDR_ALIGNMENT {OPPOSITE_EDGE}] [get_ips selectio_wiz_0]
	generate_target all [get_files $ROOT/ip/selectio_wiz_0/selectio_wiz_0.xci]
	synth_ip [get_ips selectio_wiz_0]
}

# ADC Data Memory - 4k by 32-bit simple dual-port
if {[file exists $ROOT/ip/ADC_data_mem/ADC_data_mem.xci]} {
	read_ip $ROOT/ip/ADC_data_mem/ADC_data_mem.xci
} else {
	create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name ADC_data_mem -dir $ROOT/ip
	set_property -dict [list CONFIG.Memory_Type {Simple_Dual_Port_RAM} CONFIG.Write_Width_A {32} CONFIG.Write_Depth_A {4096} CONFIG.Enable_A {Always_Enabled} CONFIG.Enable_B {Always_Enabled}] [get_ips ADC_data_mem]
	generate_target all [get_files $ROOT/ip/ADC_data_mem/ADC_data_mem.xci]
	synth_ip [get_ips ADC_data_mem]
}

# ADC Header FIFO - 128 by 32-bit with first-word fall-through
if {[file exists $ROOT/ip/ADC_header_fifo/ADC_header_fifo.xci]} {
	read_ip $ROOT/ip/ADC_header_fifo/ADC_header_fifo.xci
} else {
	create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name ADC_header_fifo -dir $ROOT/ip
	set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} CONFIG.Performance_Options {First_Word_Fall_Through} CONFIG.Input_Data_Width {32} CONFIG.Input_Depth {128}] [get_ips ADC_header_fifo]
	generate_target all [get_files $ROOT/ip/ADC_header_fifo/ADC_header_fifo.xci]
	synth_ip [get_ips ADC_header_fifo]
}

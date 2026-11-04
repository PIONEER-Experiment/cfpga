# Add the 6.8.1 trigger-line VIO to the open self-trigger channel project (run once, in the Vivado
# Tcl console, with project_selftrigc open):    source <repo>/scripts/add_line_vio.tcl
#
# It creates the vio_line IP in ip/vio_line/ and generates its output products.  Because the IP
# lives under ip/, build_project_selftrigc.tcl picks it up by itself when a project is rebuilt from
# scratch afterwards.
#   probe_in0  [15:0]  {line hold, line gap} as applied (read back)
#   probe_out0 [7:0]   trigger-line pulse, clocks high (400 MHz), initial value 24 (60 ns, as 6.7.0)
#   probe_out1 [7:0]   trigger-line pulse, clocks low after it,  initial value 24 (60 ns, as 6.7.0)
# 0 reads as 1.  The values are resynchronised into the ADC clock domain; change them between runs.
#
# Release build: set DEBUG_LINE_VIO = 0 in channel_main_selftrigc (the shape is then fixed at 24 / 24)
# and remove ip/vio_line/vio_line.xci from the project (remove_files ...).
set origin_dir [file normalize [file dirname [info script]]/..]
if {[llength [get_ips -quiet vio_line]] == 0} {
  create_ip -name vio -vendor xilinx.com -library ip -module_name vio_line -dir $origin_dir/ip
  set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {1} CONFIG.C_NUM_PROBE_OUT {2} CONFIG.C_EN_PROBE_IN_ACTIVITY {0} \
    CONFIG.C_PROBE_IN0_WIDTH {16} \
    CONFIG.C_PROBE_OUT0_WIDTH {8} CONFIG.C_PROBE_OUT0_INIT_VAL {0x18} \
    CONFIG.C_PROBE_OUT1_WIDTH {8} CONFIG.C_PROBE_OUT1_INIT_VAL {0x18} ] [get_ips vio_line]
  generate_target all [get_files vio_line.xci]
  puts "INFO: vio_line created in $origin_dir/ip/vio_line"
} else {
  puts "INFO: vio_line already in the project"
}

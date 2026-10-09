# Post opt_design hook: apply ILA constraints AFTER implement_debug_core
# has instantiated the ILA netlist.
#
# Three separate constraints:
#   1. Multicycle path (2 cycles) for probeDelay capture registers.
#      These are synchronous to adc_clk but routing from user logic can be long.
#      2-cycle budget = 5 ns at 400 MHz; ILA capture pipeline absorbs the latency.
#   2. Multicycle path (2 cycles) for shifted_data_in_reg capture SRLs.
#      These are the ILA circular-buffer SRLs that immediately follow probeDelay.
#      Wide buses (e.g. ped_buffer2) can have long routes to these cells.
#      Both ends of the probeDelay->SRL path carry MCP=2, so Vivado has
#      a 5 ns budget for the hop; ILA waveform latency is irrelevant for debug.
#   3. False path for XSDB clock-domain cells only.
#      The JTAG readback clock (~10 MHz) is genuinely asynchronous to adc_clk.

set probe_cells [get_cells -hierarchical -quiet \
    -filter {NAME =~ *ila_core_inst*probeDelay*}]
if {[llength $probe_cells] > 0} {
    set_multicycle_path 2 -setup -to $probe_cells
    set_multicycle_path 1 -hold  -to $probe_cells
    puts "INFO: post_opt_ila_fp: 2-cycle MCP applied to [llength $probe_cells] probeDelay cells"
} else {
    puts "INFO: post_opt_ila_fp: no probeDelay cells found"
}

set srl_cells [get_cells -hierarchical -quiet \
    -filter {NAME =~ *ila_core_inst*shifted_data_in_reg*}]
if {[llength $srl_cells] > 0} {
    set_multicycle_path 2 -setup -to $srl_cells
    set_multicycle_path 1 -hold  -to $srl_cells
    puts "INFO: post_opt_ila_fp: 2-cycle MCP applied to [llength $srl_cells] shifted_data_in_reg cells"
} else {
    puts "INFO: post_opt_ila_fp: no shifted_data_in_reg cells found"
}

set xsdb_cells [get_cells -hierarchical -quiet \
    -filter {NAME =~ *ila_core_inst*xsdb*}]
if {[llength $xsdb_cells] > 0} {
    set_false_path -quiet -to $xsdb_cells
    puts "INFO: post_opt_ila_fp: false path applied to [llength $xsdb_cells] XSDB cells"
} else {
    puts "INFO: post_opt_ila_fp: no XSDB cells found"
}

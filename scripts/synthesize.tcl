# Synthesizes the firmware and opens the Vivado GUI
# If you want to do synthesis and implementation all in one go,
# use implement.tcl

source setup.tcl

source read_hdl.tcl
source read_ip.tcl
source read_constraints.tcl

# Run the synthesis
synth_design -top channel_main -name wfd -part xc7k70tfbg484-2
refresh_design

start_gui
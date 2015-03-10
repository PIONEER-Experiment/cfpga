#
# Vivado (TM) v2014.4 (64-bit)
#
# temp2.tcl: Tcl script for re-creating project 'WFD5_proj_channel'
#
# Generated by Vivado on Tue Mar 10 15:00:13 -0400 2015
# IP Build 1070531 on Tue Nov 18 01:10:18 MST 2014
#
# This file contains the Vivado Tcl commands for re-creating the project to the state*
# when this script was generated. In order to re-create the project, please source this
# file in the Vivado Tcl Shell.
#
# * Note that the runs in the created project will be configured the same way as the
#   original project, however they will not be launched automatically. To regenerate the
#   run results please launch the synthesis/implementation runs as needed.
#
#*****************************************************************************************
# NOTE: In order to use this script for source control purposes, please make sure that the
#       following files are added to the source control system:-
#
# 1. This project restoration tcl script (temp2.tcl) that was generated.
#
# 2. The following source(s) files that were local or imported into the original project.
#    (Please see the '$orig_proj_dir' and '$origin_dir' variable setting below at the start of the script)
#
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/aurora_8b10b_0_cdc_sync_exdes.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/data_delay_reset.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/aurora_8b10b_0_clock_module.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/aurora_8b10b_0_support_reset_logic.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/aurora_8b10b_0_standard_cc_module.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/aurora_8b10b_0/aurora_8b10b_0.xci"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/chan_link_axis_data_fifo/chan_link_axis_data_fifo.xci"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/register_block.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/command_sm.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/cc_wr_reg_sm.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/cc_rd_reg_sm.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/cc_rd_fill_sm.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/cc_loopback_sm.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_fill_size_mux.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_fill_cntr.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_dat_mux.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_burst_cntr.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_acq_sm.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/one_channel.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/reg32_ce2.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/ddr3_addr_control.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/ddr3_wr_control.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/ddr3_rd_control.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_address_cntr.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/fill_header_fifo/fill_header_fifo.xci"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/selectio_wiz_0/selectio_wiz_0.xci"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/wfd5_ddr3_r1/wfd5_ddr3_r1.xci"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_acq_top.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/ddr3_intf.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_intf.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/startup_reset.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/led_flasher.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/genreg.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/all_channels.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/ddr3_write_fifo/ddr3_write_fifo.xci"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/g2_chan_clks/g2_chan_clks.xci"
#    "C:/Users/das556/git_projects/git_tests/git_proj_chan_test_1/hdl/constants.txt"
#    "C:/Users/das556/git_projects/git_tests/git_proj_chan_test_1/hdl/command_top.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/channel_main.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/wfd5_ddr3_r1/mig_a.prj"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/wfd5_ddr3_r1/mig_b.prj"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/constrs_1/new/ios.xdc"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/constrs_1/new/synthesis.xdc"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/constrs_1/new/timing.xdc"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sim_1/new/adc_acq_top_tb1.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sim_1/new/ddr3_intf_tb1.v"
#    "C:/Users/das556/git_projects/git_tests/WFD5_proj_channel/WFD5_proj_channel.srcs/sim_1/new/channel_main_tb1.v"
#
# 3. The following remote source files that were added to the original project:-
#
#    <none>
#
#*****************************************************************************************

# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "."

# Set the directory path for the original project from where this script was exported
set orig_proj_dir "[file normalize "$origin_dir/../../WFD5_proj_channel"]"

# Create project
create_project WFD5_proj_channel ./WFD5_proj_channel

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [get_projects WFD5_proj_channel]
set_property "default_lib" "xil_defaultlib" $obj
set_property "part" "xc7k70tfbg484-2" $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]
set files [list \
 "[file normalize "$origin_dir/../hdl/constants.txt"]"\
 "[file normalize "$origin_dir/../hdl/command_top.v"]"\
]
add_files -norecurse -fileset $obj $files

# Import local files from the original project
set files [list \
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/aurora_8b10b_0_cdc_sync_exdes.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/data_delay_reset.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/aurora_8b10b_0_clock_module.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/aurora_8b10b_0_support_reset_logic.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/aurora_8b10b_0_standard_cc_module.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/aurora_8b10b_0/aurora_8b10b_0.xci"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/chan_link_axis_data_fifo/chan_link_axis_data_fifo.xci"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/register_block.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/command_sm.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/cc_wr_reg_sm.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/cc_rd_reg_sm.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/cc_rd_fill_sm.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/cc_loopback_sm.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_fill_size_mux.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_fill_cntr.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_dat_mux.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_burst_cntr.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_acq_sm.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/one_channel.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/reg32_ce2.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/ddr3_addr_control.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/ddr3_wr_control.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/ddr3_rd_control.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_address_cntr.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/fill_header_fifo/fill_header_fifo.xci"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/selectio_wiz_0/selectio_wiz_0.xci"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/wfd5_ddr3_r1/wfd5_ddr3_r1.xci"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_acq_top.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/ddr3_intf.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/adc_intf.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/startup_reset.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/led_flasher.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/genreg.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/all_channels.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/ddr3_write_fifo/ddr3_write_fifo.xci"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/g2_chan_clks/g2_chan_clks.xci"]"\
 "[file normalize "$origin_dir/../hdl/constants.txt"]"\
 "[file normalize "$origin_dir/../hdl/command_top.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/new/channel_main.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/wfd5_ddr3_r1/mig_a.prj"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sources_1/ip/wfd5_ddr3_r1/mig_b.prj"]"\
]
set imported_files [import_files -fileset sources_1 $files]

# Set 'sources_1' fileset file properties for remote files
# None

# Set 'sources_1' fileset file properties for local files
set file "aurora_8b10b_0/aurora_8b10b_0.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "chan_link_axis_data_fifo/chan_link_axis_data_fifo.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "fill_header_fifo/fill_header_fifo.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "selectio_wiz_0/selectio_wiz_0.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "wfd5_ddr3_r1/wfd5_ddr3_r1.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "ddr3_write_fifo/ddr3_write_fifo.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "g2_chan_clks/g2_chan_clks.xci"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "synth_checkpoint_mode" "Singular" $file_obj
}

set file "hdl/constants.txt"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property "file_type" "Verilog Header" $file_obj


# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property "top" "channel_main" $obj

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
set file "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/constrs_1/new/ios.xdc"]"
set file_imported [import_files -fileset constrs_1 $file]
set file "new/ios.xdc"
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property "file_type" "XDC" $file_obj

# Add/Import constrs file and set constrs file properties
set file "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/constrs_1/new/synthesis.xdc"]"
set file_imported [import_files -fileset constrs_1 $file]
set file "new/synthesis.xdc"
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property "file_type" "XDC" $file_obj

# Add/Import constrs file and set constrs file properties
set file "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/constrs_1/new/timing.xdc"]"
set file_imported [import_files -fileset constrs_1 $file]
set file "new/timing.xdc"
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property "file_type" "XDC" $file_obj

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]
set_property "target_constrs_file" "$proj_dir/WFD5_proj_channel.srcs/constrs_1/new/ios.xdc" $obj

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]
# Import local files from the original project
set files [list \
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sim_1/new/adc_acq_top_tb1.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sim_1/new/ddr3_intf_tb1.v"]"\
 "[file normalize "$origin_dir/../../WFD5_proj_channel/WFD5_proj_channel.srcs/sim_1/new/channel_main_tb1.v"]"\
]
set imported_files [import_files -fileset sim_1 $files]

# Set 'sim_1' fileset file properties for remote files
# None

# Set 'sim_1' fileset file properties for local files
set file "new/channel_main_tb1.v"
set file_obj [get_files -of_objects [get_filesets sim_1] [list "*$file"]]
set_property "used_in_implementation" "0" $file_obj
set_property "used_in_synthesis" "0" $file_obj


# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]
set_property "runtime" "1us" $obj
set_property "top" "adc_acq_top_tb1" $obj
set_property "xsim.simulate.runtime" "1us" $obj

# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
  create_run -name synth_1 -part xc7k70tfbg484-2 -flow {Vivado Synthesis 2014} -strategy "Vivado Synthesis Defaults" -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2014" [get_runs synth_1]
}
set obj [get_runs synth_1]
set_property "part" "xc7k70tfbg484-2" $obj
set_property "steps.synth_design.args.flatten_hierarchy" "none" $obj
set_property "steps.synth_design.args.fsm_extraction" "one_hot" $obj

# set the current synth run
current_run -synthesis [get_runs synth_1]

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part xc7k70tfbg484-2 -flow {Vivado Implementation 2014} -strategy "Vivado Implementation Defaults" -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2014" [get_runs impl_1]
}
set obj [get_runs impl_1]
set_property "part" "xc7k70tfbg484-2" $obj

# set the current impl run
current_run -implementation [get_runs impl_1]

puts "INFO: Project created:WFD5_proj_channel"

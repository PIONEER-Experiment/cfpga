# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir [file dirname [info script]]/..

# Create project
create_project WFD_Channel $origin_dir/project

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [get_projects WFD_Channel]
set_property "default_lib" "xil_defaultlib" $obj
set_property "part" "xc7k70tfbg484-2" $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]

add_files -norecurse -fileset $obj [glob $origin_dir/ip/*/*.xci]
add_files -norecurse -fileset $obj [glob $origin_dir/hdl/*.txt]
add_files -norecurse -fileset $obj [glob $origin_dir/hdl/*.v]
# uncomment the following line if using VDHL source files
# add_files -norecurse -fileset $obj [glob $origin_dir/hdl/*.vhd]

# Set 'sources_1' fileset file properties for remote files
foreach file [glob $origin_dir/ip/*/*.xci] {
  set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	if { ![get_property "is_locked" $file_obj] } {
  		set_property "synth_checkpoint_mode" "Singular" $file_obj
	}
}

foreach file [glob $origin_dir/hdl/*.txt] {
  set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "Verilog Header" $file_obj
}

# uncomment the following lines if using VDHL source files
# foreach file [glob $origin_dir/hdl/*.vhd] {
#     set file [file normalize $file]
# 	  set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
# 	  set_property "file_type" "VHDL" $file_obj
# }

# Set 'sources_1' fileset file properties for local files
# None

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
foreach file_temp [glob $origin_dir/constraints/*.xdc] {
	set file "[file normalize "$file_temp"]"
	set file_added [add_files -norecurse -fileset $obj $file]
	set file "$file_temp"
	set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
	set_property "file_type" "XDC" $file_obj
}

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]
add_files -norecurse -fileset $obj [glob $origin_dir/sim/*.v]

# Set 'sim_1' fileset file properties
set file "$origin_dir/sim/channel_main_tb1.v"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets sim_1] [list "*$file"]]
set_property "used_in_implementation" "0" $file_obj
set_property "used_in_synthesis" "0" $file_obj

# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]
set_property "xsim.simulate.runtime" "1us" $obj
set_property "top" "channel_main_tb1" $obj

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
set_property "steps.write_bitstream.tcl.pre" "[file normalize "$origin_dir/scripts/get_version.tcl"]" $obj
set_property "steps.write_bitstream.tcl.post" "[file normalize "$origin_dir/scripts/export_bitstream.tcl"]" $obj

# set the current impl run
current_run -implementation [get_runs impl_1]

puts "INFO: Project created: WFD_Channel"

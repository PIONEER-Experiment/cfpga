===============================================================================
Muon g-2 Experiment (E989) Calorimeter Waveform Digitizer Channel FPGA Firmware
===============================================================================

This repository contains the firmware for the Channel FPGA on the Muon g-2
Experiment (E989) Calorimeter Waveform Digitizer (WFD). This firmware performs
several tasks:

1. 

Versions
--------

This firmware was developed and tested with Vivado 2014.4.


Synthesizing and Implementing the Firmware
------------------------------------------

This repository is intended to be run in Vivado's project mode. To build the
Vivado project from a fresh checkout, first open the Vivado 2014.4 GUI and run
the script 'scripts/build_project.tcl'. This will create a new folder named
'project' which contains all of the project-related files. To open the project
afterward, use the Vivado project file 'WFD_Channel.xpr'. Note: the local
repository's absolute path is not allowed to have any spaces.

To build the firmware, click 'Generate Bitstream' from the Flow Navigator which
will automatically run synthesis and/or implementation if required.  If successful,
the bitstream 'bitstreams/wfd_channel.bit' will be generated along with the debug
file 'debugs/debug_channel.ltx' if set up.

Intellectual Property (IP)
--------------------------

This repository stores the XCI file for each IP in the 'ip' folder, along with the
PRJ file for the DDR3 MIG IP. It is unclear whether merging will be successful
between IP versions. Therefore, any changes to the IPs should be coordinated between
the firmware developers.

Repository File Structure
-------------------------

This repository is structured as follows:

WFD_Channel/
	|-- .gitignore
	|-- bitstreams/
	|		|-- .gitignore
	|		`-- <generated bitstreams>
	|-- constraints/
	|		`-- <constraint XDC files>
	|-- debugs/
	|		|-- .gitignore
	|		`-- <generated debugs>
	|-- hdl/
	|		`-- <main source files>
	|-- ip/
	|		`-- <generated IP files>
	|-- scripts/
	|		|-- build_project.tcl
	|		`-- export_bitstream.tcl 
	`-- README.txt

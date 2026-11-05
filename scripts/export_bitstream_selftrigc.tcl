# Delete stale ILA dashboard (.ila) waveform config files so Vivado regenerates
# them from the new probe list rather than reopening a cached, out-of-date view.
set hw_dir [file normalize [file dirname [info script]]/../project_selftrigc/WFD_Channel_selftrigc.hw/backup]
foreach stale [glob -nocomplain $hw_dir/*.ila] {
    file delete -force $stale
    puts "INFO: Deleted stale ILA dashboard: $stale"
}

# Export the bitstream file and create the .mcs file
if {[file exists ./channel_main_selftrigc.bit]} {
  file copy -force ./channel_main_selftrigc.bit [file dirname [info script]]/../bitstreams/wfd_channel_selftrigc_$version.bit
  puts "INFO: Bitstream copied: wfd_channel_selftrigc.bit"
  write_cfgmem -force -format MCS -size 32 -interface SPIx1 \
      -loadbit "up 0x012E0000 ./channel_main_selftrigc.bit" [file dirname [info script]]/../bitstreams/wfd_channel_selftrigc_$version
} else {
  puts "ERROR: Bitstream not found: channel_main_selftrigc.bit"
}

# Export the debug file
if {[file exists ./debug_nets.ltx]} {
  file copy -force ./debug_nets.ltx [file dirname [info script]]/../bitstreams/wfd_channel_selftrigc_$version.ltx
  puts "INFO: Debug copied: debug_channel_selftrigc.ltx"
} else {
  puts "ERROR: Debug not found: debug_nets.ltx"
}

# Export the bitstream file and create the .mcs file
if {[file exists ./channel_main_selftrig.bit]} {
  file copy -force ./channel_main_selftrig.bit [file dirname [info script]]/../bitstreams/wfd_channel_selftrig_$version.bit
  puts "INFO: Bitstream copied: wfd_channel_selftrig.bit"
  write_cfgmem -force -format MCS -size 32 -interface SPIx1 \
      -loadbit "up 0x012E0000 ./channel_main_selftrig.bit" [file dirname [info script]]/../bitstreams/wfd_channel_selftrig_$version
} else {
  puts "ERROR: Bitstream not found: channel_main_selftrig.bit"
}

# Export the debug file
if {[file exists ./debug_nets.ltx]} {
  file copy -force ./debug_nets.ltx [file dirname [info script]]/../bitstreams/wfd_channel_selftrig_$version.ltx
  puts "INFO: Debug copied: debug_channel_selftrig.ltx"
} else {
  puts "ERROR: Debug not found: debug_nets.ltx"
}

# Export the bitstream file and create the .mcs file
if {[file exists ./channel_main.bit]} {
  file copy -force ./channel_main.bit [file dirname [info script]]/../bitstreams/wfd_channel_$version.bit
  puts "INFO: Bitstream copied: wfd_channel.bit"
  write_cfgmem -force -format MCS -size 32 -interface SPIx1 \
      -loadbit "up 0x01000000 ./channel_main.bit" [file dirname [info script]]/../bitstreams/wfd_channel_$version
} else {
  puts "ERROR: Bitstream not found: channel_main.bit"
}

# Export the debug file
if {[file exists ./debug_nets.ltx]} {
  file copy -force ./debug_nets.ltx [file dirname [info script]]/../bitstreams/wfd_channel_$version.ltx
  puts "INFO: Debug copied: debug_channel.ltx"
} else {
  puts "ERROR: Debug not found: debug_nets.ltx"
}

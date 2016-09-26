# Export the bitstream file and create the .mcs file
if {[file exists ./channel_main_async.bit]} {
  file copy -force ./channel_main_async.bit [file dirname [info script]]/../bitstreams/wfd_channel_async.bit
  puts "INFO: Bitstream copied: wfd_channel_async.bit"
  write_cfgmem -force -format MCS -size 32 -interface SPIx1 \
      -loadbit "up 0x12E0000 ./channel_main_async.bit" [file dirname [info script]]/../bitstreams/wfd_channel_async
} else {
  puts "ERROR: Bitstream not found: channel_main_async.bit"
}

# Export the debug file
if {[file exists ./debug_nets.ltx]} {
  file copy -force ./debug_nets.ltx [file dirname [info script]]/../bitstreams/wfd_channel_async.ltx
  puts "INFO: Debug copied: debug_channel_async.ltx"
} else {
  puts "ERROR: Debug not found: debug_nets.ltx"
}

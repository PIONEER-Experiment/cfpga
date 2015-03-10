# Export the bitstream file
if {[file exists ./channel_main.bit]} {
  file copy -force ./channel_main.bit [file dirname [info script]]/../bitstreams/wfd_channel.bit
  puts "INFO: Bitstream copied: wfd_channel.bit"
} else {
  puts "ERROR: Bitstream not found: channel_main.bit"
}

# Export the debug file
if {[file exists ./debug_nets.ltx]} {
  file copy -force ./debug_nets.ltx [file dirname [info script]]/../debugs/debug_channel.ltx
  puts "INFO: Debug copied: debug_channel.ltx"
} else {
  puts "ERROR: Debug not found: debug_nets.ltx"
}

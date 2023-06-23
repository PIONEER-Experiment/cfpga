# Export the bitstream file and create the .mcs file
if {[file exists ./channel_main_cbuf.bit]} {
  file copy -force ./channel_main_cbuf.bit [file dirname [info script]]/../bitstreams/wfd_channel_cbuf_$version.bit
  puts "INFO: Bitstream copied: wfd_channel_cbuf.bit"
  write_cfgmem -force -format MCS -size 32 -interface SPIx1 \
      -loadbit "up 0x012E0000 ./channel_main_cbuf.bit" [file dirname [info script]]/../bitstreams/wfd_channel_cbuf_$version
} else {
  puts "ERROR: Bitstream not found: channel_main_cbuf.bit"
}

# Export the debug file
if {[file exists ./debug_nets.ltx]} {
  file copy -force ./debug_nets.ltx [file dirname [info script]]/../bitstreams/wfd_channel_cbuf_$version.ltx
  puts "INFO: Debug copied: debug_channel_cbuf.ltx"
} else {
  puts "ERROR: Debug not found: debug_nets.ltx"
}

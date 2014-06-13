# define our input clocks
create_clock -period 20.000 -name clk50 [get_ports clkin]
create_clock -period 8.000 -name xcvr_clk [get_ports xcvr_clk]

# Aurora USER_CLK Constraint : Value is selected based on the line rate (5.0 Gbps) and lane width (4-Byte)
create_clock -period 8.000 -name user_clk_chan0 [get_pins channels/chan0/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan1 [get_pins channels/chan1/clock_module/user_clk_buf_i/O]

###### CDC in RESET_LOGIC from INIT_CLK to USER_CLK ##############
set_max_delay -datapath_only -from [get_clocks clk50] -to [get_clocks user_clk_chan0] 8.000

# input delays have to be specified
#set_input_delay -clock [get_clocks adc_clk] 1.000 [get_ports adc_d*]
#set_input_delay -clock [get_clocks adc_clk] 1.000 [get_ports adc_o*]
#
#http://forums.xilinx.com/t5/Timing-Analysis/XDC-constraints-Source-Synchronous-ADC-DDR/td-p/292807
# ADS5463 DATA to DRY skew -350 to +650 ps
#For the input_delay, 'max' is the setup time and 'min' is the hold time
create_clock -period 40.000 -name adc_clk -waveform {0.000 20.000} [get_ports adc_clk_p]
#create_clock -name virt -period 4
#OK create_clock -name adc_clk -waveform {0.7 2.7} -period 4.000 [get_ports adc_clk_p]
#FAIL create_clock -name adc_clk -waveform {0.0 2.0} -period 4.000 [get_ports adc_clk_p]
#create_clock -name adc_clk -waveform {0.0 2.0} -period 4.000 [get_ports adc_clk_p]
set_input_delay -clock [get_clocks adc_clk] -max 1.850 [get_ports adc_d*]
set_input_delay -clock [get_clocks adc_clk] -min 2.050 [get_ports adc_d*]
#set_input_delay -clock $vclk -max  1.850 -clock_fall $ins -add_delay
#set_input_delay -clock $vclk -min  2.050 -clock_fall $ins -add_delay

# everything from the 50 MHz 'clkin' (clk50) signal is asynchronous to everything from the 100 MHz 'xcvr_clk' signal
set_clock_groups -asynchronous -group [get_clocks clk50]
set_clock_groups -asynchronous -group [get_clocks xcvr_clk]
set_clock_groups -asynchronous -group [get_clocks user_clk_chan0]
set_clock_groups -asynchronous -group [get_clocks user_clk_chan1]



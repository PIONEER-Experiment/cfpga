# define our input clocks
# The 50 MHz 'clkin' is created in in 'g2_chan_clks.xdc'?
#create_clock -period 20.000 -name clkin [get_ports clkin]

# The 125 MHz oscillator
# crs - I think this is only for XMIT
create_clock -period 8.000 -name xcvr_clk [get_ports xcvr_clk]

# Aurora USER_CLK Constraint : Value is selected based on the line rate (5.0 Gbps) and lane width (4-Byte)
# crs - I think this is for RECV, and is extracted from the incoming signal 
create_clock -period 8.000 -name user_clk_chan0 [get_pins channels/chan0/clock_module/user_clk_buf_i/O]

# 400 MHz ADC clock
# This cones from the ADC
create_clock -period 2.500 -name adc_clk [get_ports adc_clk_p]
#create_clock -period 10.000 -name adc_clk [get_ports adc_clk_p] // a 100 MHz version for debugging (200 MHz adc)

# Asynchronous clock groups
# Each group should be generally be isolated from the others with FIFOs or 2-stage synchronizers.
# There are quasi-DC signals, like configuration registers, that span clock domains without synchronizers.
# The use of the registers is synchronized by way of how the logic operates.
set_clock_groups -asynchronous -group [get_clocks xcvr_clk]
set_clock_groups -asynchronous -group [get_clocks user_clk_chan0]
set_clock_groups -asynchronous -group [get_clocks adc_clk]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks clkin]

# This path is in the 'clkin' group, but is crossing from 250 MHz to 200 MHz
set_false_path -from [get_pins ddr3_intf*/reset_sync2_reg/C] -to [all_registers]

# These are DDR registers with a 400 MHz clock, so the time between edges is 1.25 nsec. Vivado complains
# about these. It can't assure that the 'reset' signals all happen within 1.25 nsec. 
# A wildcard is used in the hierarchy path to support both the normal and the ASYNC project
#set_false_path -from [get_pins */adc_acq_full_reset_reg/C] -to [all_registers]
set_false_path -from [get_cells -hierarchical -filter {NAME =~ *adc_acq_full_reset*}]

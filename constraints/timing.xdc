# define our input clocks
# The 50 MHz 'clkin' is created in in 'g2_chan_clks.xdc'?
#create_clock -period 20.000 -name clkin [get_ports clkin]

# The 125 MHz oscillator
# crs - I think this is only for XMIT
create_clock -period 8.000 -name xcvr_clk [get_ports xcvr_clk]

# Aurora USER_CLK Constraint : Value is selected based on the line rate (5.0 Gbps) and lane width (4-Byte)
# -- lkg 03/04/24 In Viv2023.2, this now gets defined in aurora_8b10b_0.xdc
# crs - I think this is for RECV, and is extracted from the incoming signal
#create_clock -period 8.000 -name TXOUTCLK [get_pins -filter REF_PIN_NAME=~*TXOUTCLK -of_objects [get_cells -hierarchical -filter {NAME =~ *gt_wrapper_i*aurora_8b10b_0_multi_gt_i*gt0_aurora_8b10b_0_i*gtxe2_i*}]]


# 400 MHz ADC clock
# This cones from the ADC
create_clock -period 2.500 -name adc_clk [get_ports adc_clk_p]
#create_clock -period 10.000 -name adc_clk [get_ports adc_clk_p] // a 100 MHz version for debugging (200 MHz adc)

# Asynchronous clock groups
# Each group should be generally be isolated from the others with FIFOs or 2-stage synchronizers.
# There are quasi-DC signals, like configuration registers, that span clock domains without synchronizers.
# The use of the registers is synchronized by way of how the logic operates.
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {xcvr_clk}]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {adc_clk}]

# This path is in the 'clkin' group, but is crossing from 250 MHz to 200 MHz
##set_false_path -from [get_pins ddr3_intf*/reset_sync2_reg/C] -to [all_registers]

# These are DDR registers with a 400 MHz clock, so the time between edges is 1.25 nsec. Vivado complains
# about these. It can't assure that the 'reset' signals all happen within 1.25 nsec.
# A wildcard is used in the hierarchy path to support both the normal and the ASYNC project
#set_false_path -from [get_pins */adc_acq_full_reset_reg/C] -to [all_registers]
set_false_path -from [get_cells -hierarchical -filter {NAME =~ *adc_acq_full_reset*}]

# Vivado flags an unsafe CDC violation from the clk_125 reset to the fill_num_wr  register beginning the sync to the adc_clk
#test set_false_path -from [get_cells -hierarchical -filter {NAME =~ *clk125_sync2*}] -to [get_cells -hierarchical -filter {NAME =~ */initial_fill_num_wr_sync_inst/*}]

# There are register values that are stable, so don't worry about clock crossing to the data mux or the circ_buf_start_address.  Vivado flags that
# crossing status as unknown, otherwise
#test set_false_path -from [get_cells -hierarchical -filter {NAME =~ *command_top/register_block/reg21__reg*}] -to [get_cells -hierarchical -filter {NAME =~ *adc_acq_top_cbuf/adc_dat_mux_CBUF/checksum_reg*}]
#test set_false_path -from [get_cells -hierarchical -filter {NAME =~ *command_top/register_block/reg21__reg*}] -to [get_cells -hierarchical -filter {NAME =~ *adc_acq_top_cbuf/adc_dat_mux_CBUF/checksum_reg*}]
#test set_false_path -from [get_cells -hierarchical -filter {NAME =~ *command_top/register_block/reg1__reg*}] -to [get_pins -hierarchical -filter {NAME =~ */dummy_dat_reset_mode_reg/C}]
#test set_false_path -from [get_cells -hierarchical -filter {NAME =~ *command_top/register_block/reg1__reg*}] -to [get_pins -hierarchical -filter {NAME =~ */use_dummy_data_reg/C}]
#test set_false_path -from [get_pins -hierarchical -filter {NAME =~ *command_top/register_block/reg21__reg[*]/C}] -to [get_pins -hierarchical -filter {NAME =~ *adc_acq_top_cbuf/adc_dat_mux_CBUF/checksum_reg[*]/D}]
#test set_false_path -from [get_pins -hierarchical -filter {NAME =~ *command_top/register_block/reg21__reg[*]/C}] -to [get_pins -hierarchical -filter {NAME =~ *adc_acq_top_cbuf/circ_buf_start_addr_reg[*]/D}]
#test set_false_path -from [get_pins -hierarchical -filter {NAME =~ *command_top/register_block/reg1__reg[4]/C}]  -to [get_pins -hierarchical -filter {NAME =~ *adc_acq_top_cbuf/dummy_dat_reset_mode_reg/D}]
#test set_false_path -from [get_pins -hierarchical -filter {NAME =~ *command_top/register_block/reg1__reg[3]/C}]  -to [get_pins -hierarchical -filter {NAME =~ *adc_acq_top_cbuf/use_dummy_data_reg/D}]


# test set_false_path -from [get_cells -hierarchical -filter {NAME =~ *master_reset/CS_reg*}] -to [get_cells -hierarchical -filter {NAME =~ *adc_acq_top_cbuf/initial_fill_num_wr_sync_inst/sync1_reg*}]

#set_false_path -from [get_pins -hierarchical -filter {NAME =~ command_top/map_adc_delay/CS_reg[*]/C}] -to [get_pins -hierarchical -filter {NAME =~ */adc_dat_buf/inst/pins[*].idelaye2_bus/CNTVALUEIN[*]}]
#set_false_path -from [get_pins -hierarchical -filter {NAME =~ command_top/map_adc_delay/CS_reg[*]/C}] -to [get_pins -hierarchical -filter {NAME =~ */adc_dat_buf/inst/pins[*].idelaye2_bus/LD}]

# test set_false_path -from [get_pins -hierarchical -filter {NAME =~ master_reset/CS_reg[*]/C}] -to [get_pins -hierarchical -filter {NAME =~ */initial_fill_num_wr_sync_inst/sync1_reg[0]/D}]


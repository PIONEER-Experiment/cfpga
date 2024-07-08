# add constraints that require synthesis to have completed before they will work
# from the constraints wizard
set_clock_groups -asynchronous -group [get_clocks clk_50M_g2_chan_clks] -group [get_clocks channels/chan0/aurora/inst/gt_wrapper_i/aurora_8b10b_0_multi_gt_i/gt0_aurora_8b10b_0_i/gtxe2_i/TXOUTCLK]
set_false_path -from [get_clocks clk_200M_g2_chan_clks] -to [get_clocks adc_clk]
set_false_path -from [get_clocks clk_50M_g2_chan_clks] -to [get_clocks xcvr_clk]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {clk_50M_g2_chan_clks clk_200M_g2_chan_clks}]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {clk_8M_g2_chan_clks adc_sdclk_g2_chan_clks}]






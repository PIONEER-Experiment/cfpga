
################################################################################
##
## (c) Copyright 2010-2023 Advanced Micro Devices, Inc. All rights reserved.
##
## This file contains confidential and proprietary information
## of Advanced Micro Devices, Inc. and is protected under U.S. and
## international copyright and other intellectual property
## laws.
##
## DISCLAIMER
## This disclaimer is not a license and does not grant any
## rights to the materials distributed herewith. Except as
## otherwise provided in a valid license issued to you by
## AMD, and to the maximum extent permitted by applicable
## law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
## WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
## AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
## BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
## INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
## (2) AMD shall not be liable (whether in contract or tort,
## including negligence, or under any other theory of
## liability) for any loss or damage of any kind or nature
## related to, arising under or in connection with these
## materials, including for any direct, or any indirect,
## special, incidental, or consequential loss or damage
## (including loss of data, profits, goodwill, or any type of
## loss or damage suffered as a result of any action brought
## by a third party) even if such damage or loss was
## reasonably foreseeable or AMD had been advised of the
## possibility of the same.
##
## CRITICAL APPLICATIONS
## AMD products are not designed or intended to be fail-
## safe, or for use in any application requiring fail-safe
## performance, such as life-support or safety devices or
## systems, Class III medical devices, nuclear facilities,
## applications related to the deployment of airbags, or any
## other applications that could lead to death, personal
## injury, or severe property or environmental damage
## (individually and collectively, "Critical
## Applications"). Customer assumes the sole risk and
## liability of any use of AMD products in Critical
## Applications, subject only to applicable laws and
## regulations governing limitations on product liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
## PART OF THIS FILE AT ALL TIMES.
##
##
################################################################################
## aurora_8b10b_0.xdc generated for xc7k70t-fbg484-2 device
# TXOUTCLK Constraint: Value is selected based on the line rate (5.0 Gbps) and lane width (4-Byte)
#create_clock -period 8.000	-name TXOUTCLK [get_pins -filter {REF_PIN_NAME=~*TXOUTCLK} -of_objects [get_cells -hierarchical -filter {NAME =~ *gt_wrapper_i*aurora_8b10b_0_multi_gt_i*gt0_aurora_8b10b_0_i*gtxe2_i*}]]

#### CDC Path #####
set_false_path -to [get_pins -filter REF_PIN_NAME=~*D -of_objects [get_cells -hierarchical -filter {NAME =~ *aurora_8b10b_0_cdc_to*}]]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *data_sync_reg1}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *ack_sync_reg1}]


# we've already set package_pin, so the LOC constraints are not needed
####################### GT reference clock LOC (For use in top level design) #######################
#set_property LOC D5 [get_ports GTXQ0_N]
#set_property LOC D6 [get_ports GTXQ0_P]

############################### GT LOC (For use in top level design) ###################################
#set_property LOC GTXE2_CHANNEL_X0Y3 [get_cells aurora_module_i/aurora_8b10b_0_i/inst/gt_wrapper_i/aurora_8b10b_0_multi_gt_i/gt0_aurora_8b10b_0_i/gtxe2_i]



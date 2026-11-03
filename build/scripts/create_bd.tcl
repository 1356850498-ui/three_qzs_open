# Run after create_project and source registration. No hardware operations.
source [file join $root src board_files pynqz2_ps_preset.tcl]
create_bd_design ps_clock_reset
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
apply_pynqz2_ps_preset $ps
# Keep board DDR/MIO/PS oscillator settings. Use only the required fabric clock.
set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_EN_CLK0_PORT {1} CONFIG.PCW_EN_RST0_PORT {1} \
    CONFIG.PCW_EN_CLK1_PORT {0} CONFIG.PCW_EN_CLK2_PORT {0} CONFIG.PCW_EN_CLK3_PORT {0} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {0}] $ps
set ddr [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR]
set fixed [create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO]
connect_bd_intf_net $ddr [get_bd_intf_pins ps7/DDR]
connect_bd_intf_net $fixed [get_bd_intf_pins ps7/FIXED_IO]
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_100m]
set_property -dict [list CONFIG.C_AUX_RESET_HIGH {1} \
    CONFIG.C_EXT_RST_WIDTH {4} CONFIG.C_AUX_RST_WIDTH {4}] $rst
# In Vivado 2025.2 C_EXT_RESET_HIGH and the sink polarity are propagate-only.
# The connection from PS FCLK_RESET0_N supplies ACTIVE_LOW metadata. Validate
# below must prove the resulting model parameter is 0; do not override it.
set zero [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_zero]
set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {0}] $zero
set one [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_one]
set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {1}] $one
connect_bd_net [get_bd_pins const_zero/dout] [get_bd_pins rst_100m/aux_reset_in] [get_bd_pins rst_100m/mb_debug_sys_rst]
# No PL MMCM/DCM is used. PG164 specifies tying dcm_locked high in this case.
connect_bd_net [get_bd_pins const_one/dout] [get_bd_pins rst_100m/dcm_locked]
set clk [create_bd_port -dir O -type clk clk_100m]
set_property CONFIG.FREQ_HZ {100000000} $clk
set_property CONFIG.ASSOCIATED_RESET {reset_async_n} $clk
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins rst_100m/slowest_sync_clk] $clk
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins rst_100m/ext_reset_in]
# Raw PS assertion guard plus the sequenced peripheral release. The board RTL
# adds asynchronous assertion / two-clock synchronous release after this AND.
set guard [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 reset_guard]
set_property -dict [list CONFIG.C_OPERATION {and} CONFIG.C_SIZE {1}] $guard
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins reset_guard/Op1]
connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] [get_bd_pins reset_guard/Op2]
set resetport [create_bd_port -dir O -type rst reset_async_n]
set_property CONFIG.POLARITY {ACTIVE_LOW} $resetport
connect_bd_net [get_bd_pins reset_guard/Res] $resetport
validate_bd_design
if {[get_property CONFIG.C_EXT_RESET_HIGH $rst] != 0} {error "Reset polarity propagation failed"}
save_bd_design
set fh [open [file join $project_audit bd_validate.txt] w]
puts $fh "RESULT=PASS\nvalidate_bd_design completed without errors."
puts $fh "FCLK0_REQUEST_MHZ=[get_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $ps]"
puts $fh "FCLK0_ACTUAL_MHZ=[get_property CONFIG.PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ $ps]"
puts $fh "PS_OSC_MHZ=[get_property CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ $ps]"
puts $fh "EXT_RESET_HIGH=[get_property CONFIG.C_EXT_RESET_HIGH $rst] AUX_RESET_HIGH=[get_property CONFIG.C_AUX_RESET_HIGH $rst]"
foreach pin [get_bd_pins -of_objects $rst -filter {DIR == I}] {
    puts $fh "$pin NET=[get_bd_nets -of_objects $pin]"
}
close $fh
write_bd_tcl -force [file join $project_audit ps_clock_reset_export.tcl]
set fh [open [file join $project_audit ps_properties.txt] w]
foreach prop [lsort [list_property $ps]] {
    if {[string match CONFIG.* $prop]} {puts $fh "$prop=[get_property $prop $ps]"}
}
close $fh

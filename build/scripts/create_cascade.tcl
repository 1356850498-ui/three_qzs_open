set root [file normalize [file join [file dirname [info script]] .. ..]]
set cfg main
if {[llength $argv]} {set cfg [lindex $argv 0]}
if {$cfg ni {main d0}} {error "Expected main or d0"}
set dest [file join $root board project_$cfg]
if {[file exists [file join $dest cascade_qzs.xpr]]} {error "Refuse to overwrite existing project"}
set project_audit [file join $dest build_audit]
file mkdir $project_audit
create_project cascade_qzs $dest -part xc7z020clg400-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set active [list src/rtl/core/sine_ref_pair.v src/rtl/core/run_fault_ctrl.v src/rtl/qzs/qzs_window.v src/rtl/qzs/qzs_normal_interlock.v src/rtl/qzs/qzs_gate_arbiter.v src/rtl/board/button_sync.v src/rtl/board/button_event.v src/rtl/board/board_controls.v src/rtl/board/board_reset_sync.v]
foreach f $active {add_files [file join $root $f]}
add_files [glob [file join $root src rtl cascade *.v]]
add_files [file join $root src rtl cascade cascade_config.vh]
set_property is_global_include true [get_files cascade_config.vh]
set_property include_dirs [list [file join $root src rtl cascade]] [get_filesets sources_1]
add_files [file join $root src rtl core spwm_duty.mem]
set_property file_type {Memory Initialization Files} [get_files spwm_duty.mem]
source [file join $root build scripts create_bd.tcl]
set bd [get_files */ps_clock_reset.bd]
set_property synth_checkpoint_mode None $bd
generate_target all $bd
add_files -norecurse [make_wrapper -files $bd -top]
add_files -fileset constrs_1 [file join $root src constraints cascade_qzs_board.xdc]
set top cascade_qzs_board_top
if {$cfg eq "d0"} {set top cascade_qzs_d0_board_top}
set_property top $top [get_filesets sources_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
add_files -fileset utils_1 [file join $root build scripts synth_mem_pre.tcl]
set_property STEPS.SYNTH_DESIGN.TCL.PRE [file join $root build scripts synth_mem_pre.tcl] [get_runs synth_1]
foreach spec {{sim_main cascade_main_tb} {sim_d0 cascade_d0_tb} {sim_buttons cascade_buttons_tb} {sim_parameters cascade_parameters_tb}} {
    lassign $spec fs tb
    create_fileset -simset $fs
    add_files -fileset $fs [file join $root sim cascade_tb.sv]
    add_files -fileset $fs [file join $root src rtl core spwm_duty.mem]
    set_property top $tb [get_filesets $fs]
    set_property include_dirs [list [file join $root src rtl cascade]] [get_filesets $fs]
    set_property xsim.simulate.runtime 0ns [get_filesets $fs]
    set_property xsim.simulate.log_all_signals false [get_filesets $fs]
    set_property xsim.view [list [file join $root sim cascade_[string range $fs 4 end].wcfg]] [get_filesets $fs]
}
current_fileset -simset [get_filesets sim_main]
update_compile_order -fileset sources_1
report_compile_order -used_in synthesis -file [file join $project_audit compile_order.txt]
set fh [open [file join $project_audit entry.txt] w]
puts $fh "TOP=$top\nCONFIG=$cfg\nGENERIC=[get_property GENERIC [get_filesets sources_1]]"
close $fh
close_project

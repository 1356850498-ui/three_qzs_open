set root [file normalize [file join [file dirname [info script]] .. ..]]
set cfg main
if {[llength $argv]} {set cfg [lindex $argv 0]}
set out [file join $root build reports $cfg]
file mkdir $out
open_project [file join $root board project_$cfg cascade_qzs.xpr]
foreach n {main d0 buttons parameters} {
    set f [open [file join $root sim results cascade_$n result.txt]]
    set body [read $f];close $f
    if {![regexp {RESULT=PASS} $body]} {error "Missing PASS $n"}
}
update_compile_order -fileset sources_1
reset_runs synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![string match {*Complete*} [get_property STATUS [get_runs synth_1]]]} {error "Synthesis failed"}
open_run synth_1
source [file join $root build scripts report_cascade.tcl]
close_design
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {![string match {*Complete*} [get_property STATUS [get_runs impl_1]]]} {error "Implementation failed"}
open_run impl_1
set out [file join $root build reports $cfg implementation]
file mkdir $out
source [file join $root build scripts report_cascade.tcl]
set setup [get_timing_paths -delay_type max -max_paths 1]
set hold [get_timing_paths -delay_type min -max_paths 1]
if {[get_property SLACK $setup]<0 || [get_property SLACK $hold]<0} {error "Timing did not close"}
report_drc -ruledecks {default} -file [file join $out final_drc.rpt]
set violations [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]
if {[llength $violations]} {error "DRC errors $violations"}
close_design
if {$cfg eq "main"} {
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {![string match {*Complete*} [get_property STATUS [get_runs impl_1]]]} {error "Bitstream failed"}
    file mkdir [file join $root board bitstream]
    file copy -force [file join $root board project_main cascade_qzs.runs impl_1 cascade_qzs_board_top.bit] [file join $root board bitstream cascade_qzs_d020.bit]
    file copy -force [file join $root board project_main cascade_qzs.gen sources_1 bd ps_clock_reset hw_handoff ps_clock_reset.hwh] [file join $root board bitstream cascade_qzs_d020.hwh]
}
close_project

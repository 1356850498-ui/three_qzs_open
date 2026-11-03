report_utilization -hierarchical -file [file join $out utilization.rpt]
report_clocks -file [file join $out clocks.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -max_paths 10 -file [file join $out timing.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
report_cdc -details -file [file join $out cdc.rpt]
report_exceptions -file [file join $out exceptions.rpt]
report_io -file [file join $out io.rpt]
set fh [open [file join $out checks.txt] w]
set bb [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]
set la [get_cells -quiet -hier -filter {REF_NAME =~ LD*}]
puts $fh "BLACKBOX=[llength $bb]\nLATCHES=[llength $la]"
if {[llength $bb] || [llength $la]} {error "Unexpected black box or latch"}
set clocks [get_clocks]
puts $fh "CLOCKS=$clocks"
if {[llength $clocks]!=1 || abs([get_property PERIOD $clocks]-10.0)>0.001} {error "Wrong clock"}
foreach s {start fault clear} {
    set a [get_pins u_logic/u_controls/u_${s}_sync/sync_ff1_reg/Q]
    set b [get_pins u_logic/u_controls/u_${s}_sync/sync_ff2_reg/D]
    set paths [get_timing_paths -from $a -to $b -max_paths 1]
    if {[llength $paths]!=1} {error "Synchronizer second stage is not timed"}
    puts $fh "SYNC_$s=[get_property SLACK $paths]"
}
close $fh
write_checkpoint -force [file join $out design.dcp]

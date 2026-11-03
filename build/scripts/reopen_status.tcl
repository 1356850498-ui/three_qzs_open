set root [file normalize [file join [file dirname [info script]] .. ..]]
foreach cfg {main d0} {
    open_project [file join $root board project_$cfg cascade_qzs.xpr]
    set f [open [file join $root build reports $cfg final_run_state.txt] w]
    puts $f "TOP=[get_property TOP [get_filesets sources_1]]"
    puts $f "GENERIC=[get_property GENERIC [get_filesets sources_1]]"
    foreach n {synth_1 impl_1} {
        set run [get_runs $n]
        puts $f "$n STATUS=[get_property STATUS $run] PROGRESS=[get_property PROGRESS $run] NEEDS_REFRESH=[get_property NEEDS_REFRESH $run]"
        if {[get_property NEEDS_REFRESH $run]} {error "Unexpected stale run $cfg/$n"}
    }
    close $f
    close_project
}

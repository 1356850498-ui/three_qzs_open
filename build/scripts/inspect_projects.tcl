set root [file normalize [file join [file dirname [info script]] .. ..]]
set logdir [file join $root build reproduction_logs]
file mkdir $logdir
set fh [open [file join $logdir project_dependency_check.txt] w]
foreach cfg {main d0} {
    open_project [file join $root board project_$cfg cascade_qzs.xpr]
    update_compile_order -fileset sources_1
    set expected cascade_qzs_board_top
    if {$cfg eq "d0"} {set expected cascade_qzs_d0_board_top}
    if {[get_property TOP [get_filesets sources_1]] ne $expected} {error "Unexpected top: $cfg"}
    set missing 0
    foreach f [get_files -all] {
        set path [get_property NAME $f]
        if {![file exists $path]} {incr missing;puts $fh "MISSING=$path"}
    }
    puts $fh "CONFIG=$cfg TOP=$expected MISSING=$missing"
    if {$missing} {close $fh;error "Missing files: $cfg"}
    close_project
}
puts $fh "RESULT=PASS"
close $fh
puts "PROJECT_DEPENDENCIES=PASS"

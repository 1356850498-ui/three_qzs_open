set root [file normalize [file join [file dirname [info script]] .. ..]]
foreach cfg {main d0} {
    open_project [file join $root board project_$cfg cascade_qzs.xpr]
    set out [file join $root build reports $cfg]
    set bd [get_files */ps_clock_reset.bd]
    open_bd_design $bd
    validate_bd_design
    save_bd_design
    set fh [open [file join $out dependency_audit.txt] w]
    puts $fh "TOP=[get_property TOP [get_filesets sources_1]]"
    puts $fh "GENERIC=[get_property GENERIC [get_filesets sources_1]]"
    puts $fh "BD_VALIDATED=1"
    set missing 0
    foreach f [get_files -all] {
        set p [get_property NAME $f]
        if {![file exists $p]} {incr missing; puts $fh "MISSING=$p"}
        if {[file exists $p] && ![string match -nocase "$root/*" [file normalize $p]] && ![string match -nocase "*AMDDesignTools*" $p]} {
            error "Unexpected external file: $p"
        }
        puts $fh "FILE=$p"
    }
    puts $fh "MISSING=$missing"
    close $fh
    if {$missing} {error "Missing project dependencies"}
    foreach fs {sim_main sim_d0 sim_buttons sim_parameters} {
        set n [string range $fs 4 end]
        set_property xsim.view [list [file join $root sim cascade_$n.wcfg]] [get_filesets $fs]
        set_property xsim.elaborate.debug_level all [get_filesets $fs]
        set_property xsim.simulate.log_all_signals false [get_filesets $fs]
    }
    if {$cfg eq "main"} {current_fileset -simset [get_filesets sim_main]} else {current_fileset -simset [get_filesets sim_d0]}
    update_compile_order -fileset sources_1
    if {$cfg eq "main"} {
        launch_simulation -simset sim_parameters -mode behavioral
        run all
        close_sim
        current_fileset -simset [get_filesets sim_main]
    }
    close_project
}

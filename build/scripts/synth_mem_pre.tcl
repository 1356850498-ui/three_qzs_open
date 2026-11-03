# The core keeps its verified $readmemh basename. Ensure that basename exists in
# the Vivado-managed synthesis working directory from the packaged source MEM.
set package_root [file normalize [file join [file dirname [info script]] .. ..]]
set source_mem [file join $package_root src rtl core spwm_duty.mem]
if {![file exists $source_mem]} {error "Missing packaged MEM: $source_mem"}
file copy -force $source_mem [file join [pwd] spwm_duty.mem]
puts "BOARD_MEM_SOURCE=$source_mem BOARD_MEM_RUNTIME=[pwd]/spwm_duty.mem"

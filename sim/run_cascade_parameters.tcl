create_wave_config
log_wave {/cascade_parameters_tb/clk}
add_wave {/cascade_parameters_tb/clk}
log_wave {/cascade_parameters_tb/gates}
add_wave {/cascade_parameters_tb/gates}
log_wave {/cascade_parameters_tb/run_active}
add_wave {/cascade_parameters_tb/run_active}
log_wave {/cascade_parameters_tb/latched}
add_wave {/cascade_parameters_tb/latched}
save_wave_config ../../cascade_parameters.wcfg
run all
quit

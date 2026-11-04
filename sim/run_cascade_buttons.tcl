create_wave_config
log_wave {/cascade_buttons_tb/clk}
add_wave {/cascade_buttons_tb/clk}
log_wave {/cascade_buttons_tb/gates}
add_wave {/cascade_buttons_tb/gates}
log_wave {/cascade_buttons_tb/run_active}
add_wave {/cascade_buttons_tb/run_active}
log_wave {/cascade_buttons_tb/latched}
add_wave {/cascade_buttons_tb/latched}
save_wave_config ../../cascade_buttons.wcfg
run all
quit

log_wave -r /board_tb/dut/*
log_wave /board_tb/clk /board_tb/reset_n /board_tb/btn_start /board_tb/btn_fault /board_tb/btn_clear /board_tb/gates
run all
quit

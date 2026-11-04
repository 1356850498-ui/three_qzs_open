log_wave /hbridge_spwm_tb/clk /hbridge_spwm_tb/rst_n /hbridge_spwm_tb/enable_req /hbridge_spwm_tb/fault_sync /hbridge_spwm_tb/clear_fault
log_wave /hbridge_spwm_tb/s1 /hbridge_spwm_tb/s2 /hbridge_spwm_tb/s3 /hbridge_spwm_tb/s4
log_wave /hbridge_spwm_tb/gates /hbridge_spwm_tb/run_active /hbridge_spwm_tb/fault_latched
log_wave /hbridge_spwm_tb/dut/carrier /hbridge_spwm_tb/dut/sample_tick /hbridge_spwm_tb/dut/u_carrier/div_10k_cnt
log_wave /hbridge_spwm_tb/dut/ref_l /hbridge_spwm_tb/dut/ref_r /hbridge_spwm_tb/dut/ref_valid /hbridge_spwm_tb/dut/sample_index /hbridge_spwm_tb/dut/u_ref/next_addr
log_wave /hbridge_spwm_tb/dut/req_l /hbridge_spwm_tb/dut/req_r /hbridge_spwm_tb/dut/req_ready
log_wave /hbridge_spwm_tb/dut/gate_l_hi /hbridge_spwm_tb/dut/gate_l_lo /hbridge_spwm_tb/dut/gate_r_hi /hbridge_spwm_tb/dut/gate_r_lo
run all
quit

`timescale 1ns/1ps
module single_spwm_logic #(
    parameter integer DEBOUNCE_CYCLES=2_000_000,
    parameter integer FAULT_RELEASE_CYCLES=2_000_000
)(
    input wire clk_100m, input wire reset_async_n,
    input wire btn_start, input wire btn_fault, input wire btn_clear,
    output wire pwm_s1, output wire pwm_s2, output wire pwm_s3, output wire pwm_s4,
    output wire led_run, output wire led_fault
);
    wire rst_n, enable_req, fault_sync, clear_fault;
    board_reset_sync u_reset(clk_100m,reset_async_n,rst_n);
    board_controls #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),
        .FAULT_RELEASE_CYCLES(FAULT_RELEASE_CYCLES)) u_controls(
        .clk(clk_100m),.rst_n(rst_n),.btn_start(btn_start),.btn_fault(btn_fault),
        .btn_clear(btn_clear),.fault_latched(led_fault),.enable_req(enable_req),
        .fault_sync(fault_sync),.clear_fault(clear_fault));
    hbridge_spwm_top #(.CLK_HZ(100_000_000),.TABLE_LEN(200),.DEAD_CYCLES(100)) u_core(
        .clk_sys(clk_100m),.rst_n(rst_n),.enable_req(enable_req),
        .fault_sync(fault_sync),.clear_fault(clear_fault),
        .pwm_s1(pwm_s1),.pwm_s2(pwm_s2),.pwm_s3(pwm_s3),.pwm_s4(pwm_s4),
        .run_active(led_run),.fault_latched(led_fault));
endmodule

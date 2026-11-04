`timescale 1ns/1ps
`include "cascade_config.vh"
// 可直接仿真的逻辑包装；板级顶层仅连接PS与本模块。
module cascade_logic #(
    parameter integer ST_D_PPM=`QZS_MAIN_D_PPM,
    parameter integer DEBOUNCE_CYCLES=`QZS_BUTTON_TICKS,
    parameter integer FAULT_RELEASE_CYCLES=`QZS_BUTTON_TICKS
)(
    input wire clk_100m, reset_async_n, btn_start, btn_fault, btn_clear,
    output wire [11:0] gates,
    output wire led_run,led_fault,led_ready,led_startup,
    output wire [3:0] fault_sources
);
    wire rst_n,enable_req,fault_sync,clear_fault,all_started,all_ready;
    board_reset_sync u_reset(.clk(clk_100m),.async_reset_n(reset_async_n),.rst_n(rst_n));
    board_controls #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.FAULT_RELEASE_CYCLES(FAULT_RELEASE_CYCLES)) u_controls(
        .clk(clk_100m),.rst_n(rst_n),.btn_start(btn_start),.btn_fault(btn_fault),.btn_clear(btn_clear),
        .fault_latched(led_fault),.enable_req(enable_req),.fault_sync(fault_sync),.clear_fault(clear_fault));
    cascade_core #(.ST_D_PPM(ST_D_PPM)) u_core(
        .clk(clk_100m),.rst_n(rst_n),.enable_req(enable_req),.fault_sync(fault_sync),.clear_fault(clear_fault),
        .gates(gates),.run_active(led_run),.fault_latched(led_fault),.fault_sources(fault_sources),.all_started(all_started),.all_ready(all_ready));
    // 故障时LED3:LED2显示首个单元来源：01单元1、10单元2、11单元3、00按钮。
    wire [1:0] fault_code=fault_sources[0]?2'd1:fault_sources[1]?2'd2:fault_sources[2]?2'd3:2'd0;
    assign led_ready=led_fault?fault_code[0]:(rst_n && all_ready);
    assign led_startup=led_fault?fault_code[1]:(led_run && !all_started);
endmodule

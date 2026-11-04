`timescale 1ns/1ps
`include "cascade_config.vh"
module cascade_qzs_d0_board_top(
    inout wire [14:0] DDR_addr, inout wire [2:0] DDR_ba,
    inout wire DDR_cas_n, DDR_ck_n, DDR_ck_p, DDR_cke, DDR_cs_n,
    inout wire [3:0] DDR_dm, inout wire [31:0] DDR_dq,
    inout wire [3:0] DDR_dqs_n, DDR_dqs_p,
    inout wire DDR_odt, DDR_ras_n, DDR_reset_n, DDR_we_n,
    inout wire FIXED_IO_ddr_vrn, FIXED_IO_ddr_vrp,
    inout wire [53:0] FIXED_IO_mio,
    inout wire FIXED_IO_ps_clk, FIXED_IO_ps_porb, FIXED_IO_ps_srstb,
    input wire btn_start, btn_fault, btn_clear,
    output wire u1_s1,u1_s2,u1_s3,u1_s4,u2_s1,u2_s2,u2_s3,u2_s4,u3_s1,u3_s2,u3_s3,u3_s4,
    output wire led_run, led_fault, led_ready, led_startup
);
    wire clk_100m, reset_async_n;
    ps_clock_reset_wrapper u_ps(
        .DDR_addr(DDR_addr),.DDR_ba(DDR_ba),.DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),.DDR_ck_p(DDR_ck_p),.DDR_cke(DDR_cke),.DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),.DDR_dq(DDR_dq),.DDR_dqs_n(DDR_dqs_n),.DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),.DDR_ras_n(DDR_ras_n),.DDR_reset_n(DDR_reset_n),.DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),.FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),.FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),.FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .clk_100m(clk_100m),.reset_async_n(reset_async_n));
    wire [11:0] gates;
    wire [3:0] fault_sources;
    cascade_logic #(.ST_D_PPM(0)) u_logic(
        .clk_100m(clk_100m),.reset_async_n(reset_async_n),
        .btn_start(btn_start),.btn_fault(btn_fault),.btn_clear(btn_clear),
        .gates(gates),.led_run(led_run),.led_fault(led_fault),
        .led_ready(led_ready),.led_startup(led_startup),.fault_sources(fault_sources));
    assign {u1_s1,u1_s2,u1_s3,u1_s4,u2_s1,u2_s2,u2_s3,u2_s4,u3_s1,u3_s2,u3_s3,u3_s4}=gates;
endmodule

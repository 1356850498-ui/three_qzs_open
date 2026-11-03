`timescale 1ns / 1ps

// Single H-bridge SPWM core. Gate outputs are active-high logical commands.
// Control inputs must already be synchronous to clk_sys. Release rst_n
// synchronously. This normal H-bridge mode does not insert shoot-through.
module hbridge_spwm_top #(
    parameter integer CLK_HZ      = 100_000_000,
    parameter integer TABLE_LEN   = 200,
    parameter integer DEAD_CYCLES = 100
)(
    input  wire clk_sys,
    input  wire rst_n,
    input  wire enable_req,
    input  wire fault_sync,
    input  wire clear_fault,
    output wire pwm_s1,
    output wire pwm_s2,
    output wire pwm_s3,
    output wire pwm_s4,
    output wire run_active,
    output wire fault_latched
);

// ---------- 载波模块输出 ----------
wire [13:0] carrier;          // 公共三角载波，0～5000
wire        sample_tick;     // 每100 us一次的参考更新通知

// ---------- 正弦参考模块输出 ----------
wire [9:0]  ref_l;            // 左参考
wire [9:0]  ref_r;            // 右参考
wire        ref_valid;       // 参考已完成预装
wire [7:0]  sample_index;     // 当前参考对应的表地址，0～199

// ---------- 双路比较模块输出 ----------
wire        req_l;           // 左桥臂上管原始请求
wire        req_r;           // 右桥臂上管原始请求
wire        req_ready;       // 0号参考的比较请求已准备好

// ---------- 运行管理模块输出 ----------
wire        run_permit;      // 公共运行许可
wire        seq_run;         // 同一许可用于控制序列推进

// ---------- 左桥臂死区模块输出 ----------
wire        gate_l_hi;       // 左上管命令，最终对应S1
wire        gate_l_lo;       // 左下管命令，最终对应S2

// ---------- 右桥臂死区模块输出 ----------
wire        gate_r_hi;       // 右上管命令，最终对应S3
wire        gate_r_lo;       // 右下管命令，最终对应S4

    initial begin
        if (CLK_HZ != 100_000_000)
            $fatal(1, "Existing comparator requires CLK_HZ=100000000"); // 时钟参数不等于100 MHz就报错
        if (TABLE_LEN != 200)
            $fatal(1, "Existing sine_ref_pair requires TABLE_LEN=200"); // 表长参数不等于200就报错
        if (DEAD_CYCLES < 1)
            $fatal(1, "DEAD_CYCLES must be at least 1"); // 死区小于1拍就报错
    end

    assign seq_run = run_permit;

    carrier_tick_gen #(
        .CLK_HZ (CLK_HZ)
    ) u_carrier (
        .clk_sys     (clk_sys),
        .rst_n       (rst_n),
        .seq_run     (seq_run),
        .carrier     (carrier),
        .sample_tick (sample_tick)
    );

    sine_ref_pair #(
        .CLK_HZ (CLK_HZ)
    ) u_ref (
        .clk_sys      (clk_sys),
        .rst_n        (rst_n),
        .seq_run      (seq_run),
        .sample_tick  (sample_tick),
        .ref_l        (ref_l),
        .ref_r        (ref_r),
        .ref_valid    (ref_valid),
        .sample_index (sample_index)
    );

    spwm_compare_pair u_compare (
        .clk_sys      (clk_sys),
        .rst_n        (rst_n),
        .seq_run      (seq_run),
        .sample_index (sample_index),
        .carrier      (carrier),
        .ref_l        (ref_l),
        .ref_r        (ref_r),
        .ref_valid    (ref_valid),
        .req_l        (req_l),
        .req_r        (req_r),
        .req_ready    (req_ready)
    );

    run_fault_ctrl u_run_ctrl (
        .clk_sys       (clk_sys),
        .rst_n         (rst_n),
        .enable_req    (enable_req),
        .fault_sync    (fault_sync),
        .clear_fault   (clear_fault),
        .ref_valid     (ref_valid),
        .req_ready     (req_ready),
        .run_permit    (run_permit),
        .fault_latched (fault_latched)
    );

    dt_half_bridge #(
        .DEAD_CYCLES (DEAD_CYCLES)
    ) u_dead_l (
        .clk_sys    (clk_sys),
        .rst_n      (rst_n),
        .run_permit (run_permit),
        .pwm_req    (req_l),
        .gate_h     (gate_l_hi),
        .gate_l     (gate_l_lo)
    );

    dt_half_bridge #(
        .DEAD_CYCLES (DEAD_CYCLES)
    ) u_dead_r (
        .clk_sys    (clk_sys),
        .rst_n      (rst_n),
        .run_permit (run_permit),
        .pwm_req    (req_r),
        .gate_h     (gate_r_hi),
        .gate_l     (gate_r_lo)
    );


    assign pwm_s1 = rst_n & run_permit & gate_l_hi;
    assign pwm_s2 = rst_n & run_permit & gate_l_lo;
    assign pwm_s3 = rst_n & run_permit & gate_r_hi;
    assign pwm_s4 = rst_n & run_permit & gate_r_lo;
    assign run_active = run_permit;

endmodule

`timescale 1ns/1ps
`include "cascade_config.vh"
// 三单元公共协调：公共时基、公共ROM、全局故障联动。无ADC/闭环/动态D。
module cascade_core #(
    parameter integer ST_D_PPM=`QZS_MAIN_D_PPM,
    parameter integer DEAD_CYCLES=`QZS_DEAD_TICKS,
    parameter integer REF_MIN=`QZS_REF_MIN, REF_MAX=`QZS_REF_MAX
)(
    input   wire        clk     , 
    input   wire        rst_n   , 
    input   wire        enable_req, 
    input   wire        fault_sync, 
    input   wire        clear_fault,
    
    output  wire [11:0] gates   ,
    output  wire        run_active, 
    output  wire        fault_latched,
    (* KEEP="TRUE", DONT_TOUCH="TRUE" *) 
    output  reg  [3:0]  fault_sources,
    output  wire        all_started, 
    output  wire        all_ready
);
    wire            seq_run     ;
    wire    [13:0]  master_phase;
    wire            sample_tick ;
    wire    [9:0]   common_ref_l;
    wire    [9:0]   common_ref_r;
    wire            common_valid;
    wire    [7:0]   common_index;
    wire    [2:0]   unit_ready  ;
    wire    [2:0]   unit_error  ;
    wire    [2:0]   unit_started;
    wire    [11:0]  candidates  ;
    
    wire    fault_live  =fault_sync || |unit_error;
    wire    final_permit=rst_n && seq_run && enable_req && !clear_fault && !fault_live && !fault_latched;
    
    
    cascade_timebase u_timebase(
        .clk        (clk        ),
        .rst_n      (rst_n      ),
        .seq_run    (seq_run    ),
        .phase      (master_phase),
        .sample_tick(sample_tick)
    );
        
    sine_ref_pair #(.CLK_HZ(`QZS_CLOCK_HZ)) u_ref(
        .clk_sys    (clk        ),
        .rst_n      (rst_n      ),
        .seq_run    (seq_run    ),
        .sample_tick(sample_tick),
        .ref_l      (common_ref_l),
        .ref_r      (common_ref_r),
        .ref_valid  (common_valid),
        .sample_index(common_index)
    );
        
    run_fault_ctrl u_supervisor(
        .clk_sys    (clk        ),
        .rst_n      (rst_n      ),
        .enable_req (enable_req && !clear_fault),
        .fault_sync (fault_live ),
        .clear_fault(clear_fault),
        .ref_valid  (common_valid),
        .req_ready  (&unit_ready),
        .run_permit (seq_run    ),
        .fault_latched(fault_latched)
    );
    
    // 来源位0/1/2分别是单元1/2/3，位3是BTN1模拟故障；保持至合法清除。
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
            fault_sources<=4'b0000;
        else if (fault_live) 
            fault_sources<=fault_sources | {fault_sync,unit_error};
        else if (clear_fault && !enable_req) 
            fault_sources<=4'b0000;
    end
    
    genvar g;
    generate for(g=0;g<3;g=g+1) begin: units    // 生成三个单元，同样的三个电路
    
    /////////////////  计算三个单元的相位关系  //////////////////////
        localparam integer DELAY=(g==0)?`QZS_DELAY_U1:(g==1)?`QZS_DELAY_U2:`QZS_DELAY_U3;   // 这行给每个单元选择自己的延迟值。
        localparam [13:0] OFFSET=DELAY;
        localparam [13:0] WRAP=10000-DELAY;
        wire [13:0] local_phase=(master_phase>=OFFSET)?master_phase-OFFSET:master_phase+WRAP;   // 用公共相位 master_phase，算出本单元的局部相位 local_phase。
        
        wire    [13:0]  carrier  ;
        wire    [9:0]   ref_l    ;
        wire    [9:0]   ref_r    ;
        wire    [7:0]   ref_index;
        
        
        cascade_unit #(
        .ST_D_PPM   (ST_D_PPM   ),
        .DEAD_CYCLES(DEAD_CYCLES),
        .PHASE_DELAY(DELAY      ),
        .REF_MIN    (REF_MIN    ),
        .REF_MAX    (REF_MAX    )
        ) u_unit(
            .clk            (clk        ),
            .rst_n          (rst_n      ),
            .seq_run        (seq_run    ),
            .global_fault   (fault_sync || fault_latched),
            .phase          (local_phase),
            .common_ref_l   (common_ref_l),
            .common_ref_r   (common_ref_r),
            .common_valid   (common_valid),
            .common_index   (common_index),
            .gates          (candidates[11-4*g -:4]),
            .ready          (unit_ready[g]),
            .error_now      (unit_error[g]),
            .started        (unit_started[g]),
            .carrier        (carrier    ),
            .ref_l          (ref_l      ),
            .ref_r          (ref_r      ),
            .ref_index      (ref_index  )
        );
    end endgenerate
    
    // 最后一层全局许可覆盖12路，任何单元错误均立即撤销普通和直通候选。
    assign gates=final_permit?candidates:12'b0;
    assign run_active=final_permit;
    assign all_started=&unit_started;
    assign all_ready=&unit_ready;
endmodule

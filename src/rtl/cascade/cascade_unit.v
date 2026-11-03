`timescale 1ns/1ps
`include "cascade_config.vh"
// 一个功率单元。复用已验证window/interlock/arbiter，不在本模块重写其功能。
// phase是公共时基换算的局部相位；ref只在谷值边界锁存，一个周期内保持。
module cascade_unit #(
    parameter integer ST_D_PPM=`QZS_MAIN_D_PPM,
    parameter integer DEAD_CYCLES=`QZS_DEAD_TICKS,
    parameter integer PHASE_DELAY=0,
    parameter integer REF_MIN=`QZS_REF_MIN, REF_MAX=`QZS_REF_MAX
)(
    input   wire            clk         , 
    input   wire            rst_n       , 
    input   wire            seq_run     , 
    input   wire            global_fault,
    input   wire    [13:0]  phase       ,
    input   wire    [9:0]   common_ref_l, 
    input   wire    [9:0]   common_ref_r,
    input   wire            common_valid,
    input   wire    [7:0]   common_index,
    
    output  wire    [3:0]   gates       ,
    output  wire            ready       , 
    output  wire            error_now   ,
    output  reg             started     ,
    output  reg     [13:0]  carrier     ,
    output  reg     [9:0]   ref_l       , 
    output  reg     [9:0]   ref_r       ,
    output  reg     [7:0]   ref_index
);
    reg             ref_valid   ;
    wire            config_ok   ;
    wire            reference_ok;
    wire            request_error;
    wire            st_left     ;
    wire            st_right    ;
    wire            raw_st_left ;
    wire            raw_st_right;
    wire    [3:0]   st_vector   ;
    wire    [3:0]   candidate   ;
    wire            nlh         ;
    wire            nll         ;
    wire            nrh         ;
    wire            nrl         ;
    wire run_local = seq_run && started;
    
    
    localparam [13:0] INITIAL_CARRIER=(PHASE_DELAY<=5000)?PHASE_DELAY:10000-PHASE_DELAY;
    
    // 沿用carrier_tick_gen的每拍加/减1；方向由唯一公共相位决定。
    // 寄存载波打断“移相算术->折返->窗口->互锁”长组合路径，无新增比较延迟。
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
            carrier<=INITIAL_CARRIER;
        else if (!seq_run) 
            carrier<=INITIAL_CARRIER;
        else if (phase<14'd5000) 
            carrier<=carrier+14'd1;
        else 
            carrier<=carrier-14'd1;
    end
    
    // 停机预装0号参考，启动后各单元只在自己的谷值采用公共值。
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin 
            ref_l<=10'd500; 
            ref_r<=10'd500; 
            ref_index<=8'd0; 
        end
        else if (!seq_run || phase==14'd0) 
        begin
            ref_l<=common_ref_l; 
            ref_r<=common_ref_r; 
            ref_index<=common_index;
        end
    end
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
            ref_valid<=1'b0;
        else 
            ref_valid<=common_valid;
    end
    // 只在谷值开启首帧；谷值距最近比较边界至少500拍，先完成普通开通等待。
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
            started<=1'b0;
        else if (!seq_run) 
            started<=1'b0;
        else if (phase==14'd0) 
            started<=1'b1;
    end
    
    wire [12:0] ql={1'b0,ref_l,2'b00}+{3'b0,ref_l};
    wire [12:0] qr={1'b0,ref_r,2'b00}+{3'b0,ref_r};
    
    qzs_window #(
        .ST_D_PPM(ST_D_PPM),
        .REF_MIN(REF_MIN),
        .REF_MAX(REF_MAX)
    ) u_window(
        .clk_sys    (clk        ),
        .rst_n      (rst_n      ),
        .run_permit (run_local  ),
        .ref_valid  (ref_valid  ),
        .carrier    (carrier    ),
        .ref_l      (ref_l      ),
        .ref_r      (ref_r      ),
        .config_ok  (config_ok  ),
        .reference_ok(reference_ok),
        .st_left    (st_left    ),
        .st_right   (st_right   ),
        .st_vector  (st_vector  ),
        .raw_st_left(raw_st_left),
        .raw_st_right(raw_st_right)
    );
    
    // D0也保留普通换向等待；与旧D0寄存比较器的延迟差异另作说明和独立模型验证。
    qzs_normal_interlock #(
        .DEAD_CYCLES(DEAD_CYCLES)
    ) u_interlock_l(
        .clk(clk),
        .rst_n(rst_n),
        .run_permit(run_local),
        .request_next(ref_valid && carrier<{1'b0,ql}),
        .st_next(raw_st_left),
        .hi(nlh),
        .lo(nll)
    );
    
    qzs_normal_interlock #(
    .DEAD_CYCLES(DEAD_CYCLES)
    ) u_interlock_r(
        .clk(clk),
        .rst_n(rst_n),
        .run_permit(run_local),
        .request_next(ref_valid && carrier<{1'b0,qr}),
        .st_next(raw_st_right),
        .hi(nrh),
        .lo(nrl)
    );
        
    qzs_gate_arbiter u_arbiter(
        .rst_n(rst_n),
        .run_permit(run_local),
        .enable_req(seq_run),
        .fault_sync(global_fault),
        .fault_latched(1'b0),
        .config_ok(config_ok),
        .reference_ok(reference_ok),
        .normal_vector({nlh,nll,nrh,nrl}),
        .st_left(st_left),
        .st_right(st_right),
        .st_vector(st_vector),
        .gates(candidate),
        .request_error(request_error)
    );
        
        
    assign ready=config_ok && ref_valid && reference_ok && DEAD_CYCLES>=1;
    assign error_now=!config_ok || DEAD_CYCLES<1 || (ref_valid && !reference_ok) || request_error;
    assign gates=candidate;
endmodule

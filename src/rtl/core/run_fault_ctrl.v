`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/15 15:50:38
// Design Name: 
// Module Name: run_fault_ctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module run_fault_ctrl(
    input       clk_sys     ,
    input       rst_n       ,
    
    input       enable_req  , // 保持高；停机准备就绪后接受启动
    input       fault_sync  , // 故障优先，置位fault_latched并撤销运行许可
    input       clear_fault , // 只在enable_req为0且故障源已解除时接受
    input       ref_valid   , // 
    input       req_ready   , // 两者已有效且无故障时接受启动；不再等后续tick
    
    output      run_permit  , // 公共许可；同一信号作为载波和参考的seq_run
    output      fault_latched // 故障锁存状态，记住故障，直到合法清除
    );
    
    reg     run_permit_reg      ;
    reg     fault_latched_reg   ;
    
    always@(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin
            run_permit_reg <= 1'b0;
        end
        else
        begin
            if(fault_sync) // 有故障
                run_permit_reg <= 1'b0;
            else if(fault_latched_reg) // 故障没清
                run_permit_reg <= 1'b0;
            else if(!enable_req) // 位置0还没开始
                run_permit_reg <= 1'b0;
            else if(ref_valid && req_ready) // 参考有效且导通信号就绪
                run_permit_reg <= 1'b1;
            // 其他情况不赋值，保持原状态
        end
    end
    
    always@(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin
            fault_latched_reg <= 1'b0;
        end
        else
        begin
            if(fault_sync) // 故障锁存状态，记住故障，直到合法清除
            begin
                fault_latched_reg <= 1'b1;
            end
            else if(!enable_req && clear_fault) // 不在运行且清除故障
            begin
                fault_latched_reg <= 1'b0;
            end
        end
    end
    
    assign run_permit = run_permit_reg;
    assign fault_latched = fault_latched_reg;
    
endmodule

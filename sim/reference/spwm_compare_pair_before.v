`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/15 15:50:38
// Design Name: 
// Module Name: spwm_compare_pair
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


module spwm_compare_pair_before(
    input           clk_sys ,
    input           rst_n   ,
    
    input           seq_run ,
    input   [7:0]   sample_index,
    input   [13:0]  carrier ,
    input   [9:0]   ref_l   ,
    input   [9:0]   ref_r   ,
    input           ref_valid,
    
    output          req_l   ,
    output          req_r   ,
    output          req_ready
    );
    
    reg             req_l_reg   ; 
    reg             req_r_reg   ;
    reg             req_ready_reg;

//////////////////  希望管导通的原始请求  /////////////////    
    always@(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin
            req_l_reg <= 1'b0;
        end
        else
        begin
            if(ref_valid)
            begin
                if(carrier[13:0] < (5000*ref_l/1000)) // 5000 = DIV_10KHZ/2 三角载波的一半/2
                begin
                    req_l_reg <= 1'b1;
                end
                else
                begin
                    req_l_reg <= 1'b0;
                end
            end
            else
            begin
                req_l_reg <= 1'b0;
            end
        end
    end
    
    always@(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin
            req_r_reg <= 1'b0;
        end
        else
        begin
            if(ref_valid)
            begin
                if(carrier[13:0] < (5000*ref_r/1000)) // 5000 = DIV_10KHZ/2 三角载波的一半/2
                begin
                    req_r_reg <= 1'b1;
                end
                else
                begin
                    req_r_reg <= 1'b0;
                end
            end
            else
            begin
                req_r_reg <= 1'b0;
            end
        end
    end
 
////////////////   导通信号已准备  //////////////////////
    always@(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin
            req_ready_reg <= 1'b0;
        end
        else
        begin
            req_ready_reg <= !seq_run && ref_valid && (sample_index[7:0] == 8'd0) && (carrier[13:0] == 14'd0); // 位置0且参考就绪且周期开始
        end
    end
    
    assign req_l = req_l_reg ;
    assign req_r = req_r_reg ;
    assign req_ready = req_ready_reg;
    
endmodule

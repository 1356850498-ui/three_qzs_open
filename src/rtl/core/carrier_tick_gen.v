`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/15 15:50:38
// Design Name: 
// Module Name: carrier_tick_gen
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


module carrier_tick_gen #(
    parameter integer CLK_HZ     = 100_000_000  // PS 给的 FCLK_CLK0
    
)(
    input           clk_sys ,
    input           rst_n   ,
    
    input           seq_run , // 连接run_permit；为0时计数与载波保持0
    output  [13:0]  carrier ,
    output          sample_tick
    );
    
    localparam integer DIV_10KHZ  = CLK_HZ/10_000;
    
    reg     [15:0]  div_10k_cnt ;
    reg     [13:0]  carrier_reg ;
    
    wire            change      ;
    
    always@(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin
            div_10k_cnt[15:0] <= 16'd0;
        end
        else
        begin
            if(!seq_run)
            begin
                div_10k_cnt[15:0] <= 16'd0;
            end
            else
            begin
                if(div_10k_cnt[15:0] == DIV_10KHZ - 1'b1)
                begin
                    div_10k_cnt[15:0] <= 16'd0;
                end
                else
                begin
                    div_10k_cnt[15:0] <= div_10k_cnt[15:0] + 1'b1;  // 10k计数分频
                end
            end
        end
    end
    
    assign change = (div_10k_cnt[15:0] > (DIV_10KHZ/2 - 1'b1)) ? 1'b1 : 1'b0; // 三角波加减改变信号
    assign sample_tick = rst_n && seq_run && (div_10k_cnt == DIV_10KHZ - 1); // 每10000拍出现一次，宽1拍,周期末
    
    always@(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin
            carrier_reg[13:0] <= 14'd0;
        end
        else
        begin
            if(!seq_run)
            begin
                carrier_reg[13:0] <= 14'd0;
            end
            else
            begin
                if(!change)
                begin
                    carrier_reg[13:0] <= carrier_reg[13:0] + 1'b1; // 先加到5000，再减到0的三角波
                end
                else
                begin
                    carrier_reg[13:0] <= carrier_reg[13:0] - 1'b1;
                end
            end
        end
    end
    
    assign carrier[13:0] = carrier_reg[13:0];
    
endmodule

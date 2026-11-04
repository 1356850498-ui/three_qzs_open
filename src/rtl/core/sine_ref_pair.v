`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/15 15:50:38
// Design Name: 
// Module Name: sine_ref_pair
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


module sine_ref_pair #(
    parameter integer CLK_HZ     = 100_000_000  // PS 给的 FCLK_CLK0
    
)(
    input           clk_sys     ,
    input           rst_n       ,
    
    input               seq_run     ,
    input               sample_tick ,
    output  reg [9:0]   ref_l       ,
    output  reg [9:0]   ref_r       ,
    output  reg         ref_valid   ,
    output  reg [7:0]   sample_index
    );
    
    localparam integer DUTY_MAX = 1000;
    
    reg     [9:0]   spwm_duty [0:199];
    reg     [7:0]   next_addr;


//////////////////  参考值地址  //////////////////////////    
    always@(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin
            sample_index[7:0] <= 8'd0;
            next_addr   [7:0] <= 8'd1;
        end
        else
        begin
            if(!seq_run)
            begin
                sample_index[7:0] <= 8'd0;
                next_addr   [7:0] <= 8'd1;
            end
            else
            begin
                if(sample_tick)
                begin
                    sample_index[7:0] <= next_addr[7:0];
                    if(next_addr[7:0] == 8'd199)
                    begin
                        next_addr[7:0] <= 8'd0;
                    end
                    else
                    begin
                        next_addr[7:0] <= next_addr[7:0] + 1'b1;
                    end
                end
            end
        end
    end
    
    initial 
    begin
        $readmemh("spwm_duty.mem", spwm_duty,0,199);
    end
    
    always @(posedge clk_sys or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            ref_valid <= 1'b0;
        end 
        else 
        begin
            if(!seq_run)
            begin
                ref_valid <= 1'b1; // ref_valid = 1之后seq_run才会拉高，表示位置0已配置完成
            end
        end
    end

///////////////////////  左右管参考值读取  ///////////////////////////   
    always @(posedge clk_sys or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            ref_l[9:0] <= 10'd500;
            ref_r[9:0] <= 10'd500;
        end 
        else 
        begin
            if(!seq_run) // 位置0
            begin
                ref_l[9:0] <= spwm_duty[0];
                ref_r[9:0] <= DUTY_MAX - spwm_duty[0];
            end
            else
            begin
                if (sample_tick) 
                begin
                    ref_l[9:0] <= spwm_duty[next_addr];
                    ref_r[9:0] <= DUTY_MAX - spwm_duty[next_addr];
                end
            end
        end
    end
    
endmodule

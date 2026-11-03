`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/15 15:50:38
// Design Name: 
// Module Name: dt_half_bridge
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


module dt_half_bridge #(
    parameter integer DEAD_CYCLES = 100
)(
    input       clk_sys ,
    input       rst_n   ,
    
    input       run_permit  ,
    input       pwm_req     ,
    output      gate_h      ,
    output      gate_l      
    );
    
    
    localparam integer OFF      = 5'b0_0001;
    localparam integer WAIT_HI  = 5'b0_0010;
    localparam integer RUN_HI   = 5'b0_0100;
    localparam integer WAIT_LO  = 5'b0_1000;
    localparam integer RUN_LO   = 5'b1_0000;
    
    reg     [4:0]   cur_state   ;
    reg     [4:0]   next_state  ;
    
    localparam integer COUNT_WIDTH = (DEAD_CYCLES < 2) ? 1 : $clog2(DEAD_CYCLES + 1);

    reg     [COUNT_WIDTH-1:0]   high_cnt    ;
    reg     [COUNT_WIDTH-1:0]   low_cnt     ;
    reg             gate_h_reg  ;
    reg             gate_l_reg  ;
    

///////////////  死区时间计数  //////////////////////////   
    always@(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin
            high_cnt[COUNT_WIDTH-1:0] <= {COUNT_WIDTH{1'b0}};
        end
        else
        begin
            if(!run_permit)
            begin
                high_cnt[COUNT_WIDTH-1:0] <= {COUNT_WIDTH{1'b0}};
            end
            else if(cur_state == WAIT_HI)
            begin
                high_cnt[COUNT_WIDTH-1:0] <= high_cnt[COUNT_WIDTH-1:0] + 1'b1;
            end
            else
            begin
                high_cnt[COUNT_WIDTH-1:0] <= {COUNT_WIDTH{1'b0}};
            end
        end
    end
    
    always@(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin
            low_cnt[COUNT_WIDTH-1:0] <= {COUNT_WIDTH{1'b0}};
        end
        else
        begin
            if(!run_permit)
            begin
                low_cnt[COUNT_WIDTH-1:0] <= {COUNT_WIDTH{1'b0}};
            end
            else if(cur_state == WAIT_LO)
            begin
                low_cnt[COUNT_WIDTH-1:0] <= low_cnt[COUNT_WIDTH-1:0] + 1'b1;
            end
            else
            begin
                low_cnt[COUNT_WIDTH-1:0] <= {COUNT_WIDTH{1'b0}};
            end
        end
    end

/////////////////  状态机  ////////////////////////////

    
    always@(posedge clk_sys or negedge rst_n)
    begin
        if(!rst_n)
        begin
            cur_state[4:0] <= OFF;
        end
        else
        begin
            cur_state[4:0] <= next_state[4:0];
        end
    end
    
    always@(*)
    begin
        next_state[4:0] = cur_state[4:0];
        case(cur_state)
            OFF    :begin
                        if(run_permit)
                        begin
                            if(pwm_req)
                                next_state = WAIT_HI;
                            else
                                next_state = WAIT_LO;
                        end
                    end
            WAIT_HI:begin
                        if(!run_permit)
                            next_state = OFF;
                        else if(!pwm_req)
                            next_state = WAIT_LO;
                        else if(high_cnt[COUNT_WIDTH-1:0] == DEAD_CYCLES - 1'b1)
                            next_state = RUN_HI;
                    end
            RUN_HI :begin
                        if(!run_permit)
                            next_state = OFF;
                        else if(!pwm_req)
                            next_state = WAIT_LO;
                    end 
            WAIT_LO:begin
                        if(!run_permit)
                            next_state = OFF;
                        else if(pwm_req)
                            next_state = WAIT_HI;
                        else if(low_cnt[COUNT_WIDTH-1:0] == DEAD_CYCLES - 1'b1)
                            next_state = RUN_LO;
                    end
            RUN_LO :begin
                        if(!run_permit)
                            next_state = OFF;
                        else if(pwm_req)
                            next_state = WAIT_HI;
                    end 
            default:begin
                        next_state = OFF;
                    end
        endcase
    end

////////////////  门信号赋值  ///////////////////////
    always@(*)
    begin
        if(!rst_n)
        begin
            gate_h_reg = 1'b0;
            gate_l_reg = 1'b0;
        end
        else
        begin
            case(cur_state)
                OFF    :begin
                            gate_h_reg = 1'b0;
                            gate_l_reg = 1'b0;
                        end
                WAIT_HI:begin
                            gate_h_reg = 1'b0;
                            gate_l_reg = 1'b0;
                        end
                RUN_HI :begin
                            gate_h_reg = 1'b1;
                            gate_l_reg = 1'b0;
                        end
                WAIT_LO:begin
                            gate_h_reg = 1'b0;
                            gate_l_reg = 1'b0;
                        end
                RUN_LO :begin
                            gate_h_reg = 1'b0;
                            gate_l_reg = 1'b1;
                        end
                default:begin
                            gate_h_reg = 1'b0;
                            gate_l_reg = 1'b0;
                        end
            endcase
        end
    end
    
    assign gate_h = gate_h_reg;
    assign gate_l = gate_l_reg;
    
endmodule

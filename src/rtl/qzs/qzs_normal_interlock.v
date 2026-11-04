`timescale 1ns/1ps
// Normal commutation interlock with explicit memory of controlled ST.
// st_next and request_next describe the SAME comparison sample. During ST the
// final arbiter emits its whitelisted vector; normal outputs below are zero.
// On ST exit, select a subset of the previously conducting pair, adding no edge.
module qzs_normal_interlock #(
    parameter integer DEAD_CYCLES=100
)(
    input   wire    clk     ,
    input   wire    rst_n   ,
    input   wire    run_permit,
    input   wire    request_next,
    input   wire    st_next ,       // 进入受控直通
    
    output  wire    hi,
    output  wire    lo
);

///////////////  状态  /////////////////////
    localparam [5:0] OFF          =6'b00_0001;
    localparam [5:0] WAIT_H       =6'b00_0010; // 两管关闭，等待开上管
    localparam [5:0] HIGH         =6'b00_0100; // 上管开、下管关
    localparam [5:0] WAIT_L       =6'b00_1000; // 两管关闭，等待开下管
    localparam [5:0] LOW          =6'b01_0000; // 上管关、下管开
    localparam [5:0] CONTROLLED_ST=6'b10_0000; // 记住正在受控直通，由仲裁器输出直通命令
    
    localparam integer CW=(DEAD_CYCLES<2)?1:$clog2(DEAD_CYCLES+1);
    
    reg     [5:0]       state;
    reg     [CW-1:0]    count;
    
    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin 
            state<=OFF;
            count<=0;
        end
        else if(!run_permit)
        begin 
            state<=OFF;
            count<=0;
        end
        else if(st_next)
        begin 
            state<=CONTROLLED_ST;
            count<=0;
        end
        else case(state)
                OFF    :begin 
                            state<=request_next?WAIT_H:WAIT_L;
                            count<=0;
                        end
                WAIT_H :begin
                            if(!request_next)
                            begin 
                                state<=WAIT_L;
                                count<=0;
                            end
                            else if(count==DEAD_CYCLES-1)
                            begin 
                                state<=HIGH;
                                count<=0;
                            end
                            else 
                                count<=count+1'b1;
                        end
                WAIT_L :begin
                            if(request_next)
                            begin 
                                state<=WAIT_H;
                                count<=0;
                            end
                            else if(count==DEAD_CYCLES-1)
                            begin 
                                state<=LOW;
                                count<=0;
                            end
                            else 
                                count<=count+1'b1;
                        end
                HIGH   :begin 
                            count<=0;
                            if(!request_next)
                                state<=WAIT_L;
                        end
                LOW    :begin 
                            count<=0;
                            if(request_next)
                                state<=WAIT_H;
                        end
                CONTROLLED_ST:begin 
                                state<=request_next?HIGH:LOW;
                                count<=0;
                              end
                default:begin 
                            state<=OFF;
                            count<=0;
                        end
        endcase
    end
    
    
    assign hi=rst_n && run_permit && state==HIGH;
    assign lo=rst_n && run_permit && state==LOW;
 
endmodule


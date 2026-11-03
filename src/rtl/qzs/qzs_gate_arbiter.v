`timescale 1ns/1ps
module qzs_gate_arbiter(
    input   wire            rst_n       ,
    input   wire            run_permit  ,
    input   wire            enable_req  ,
    input   wire            fault_sync  ,
    input   wire            fault_latched,
    input   wire            config_ok   ,   // 参数有效
    input   wire            reference_ok,   // 数据有效
    input   wire    [3:0]   normal_vector, 
    input   wire            st_left     ,   // 申请左桥臂直通
    input   wire            st_right    ,   // 申请右桥臂直通
    input   wire    [3:0]   st_vector   , 
    
    output  reg     [3:0]   gates       ,
    output  reg             request_error   // 提交的候选或标志是否存在错误
);
    reg     normal_ok;
    reg     shoot_ok ;
    
    
    always @(*)
    begin
        normal_ok=0;shoot_ok=0;gates=0;request_error=0;
        case(normal_vector) // 普通候选正常与否
            4'b0000,4'b1000,4'b0100,4'b0010,4'b0001,
            4'b1001,4'b0110,4'b1010,4'b0101:normal_ok=1;
            default:normal_ok=0;
        endcase
        case({st_left,st_right,st_vector})
            6'b10_1101,6'b10_1110,6'b01_1011,6'b01_0111:shoot_ok=1; // 直通和开的管需要对应
            default:shoot_ok=0;
        endcase
        case({st_left,st_right})
            2'b00  :begin
                        if(st_vector!=0 || !normal_ok) request_error=1;
                        else gates=normal_vector;
                    end
            2'b01,2'b10:begin
                            if(!shoot_ok || !normal_ok) request_error=1;
                            else gates=st_vector;
                        end
            default:request_error=1;
        endcase
        // Fail closed on every invalid/unknown safety value. ST has no path around it.
        case({rst_n,run_permit,enable_req,fault_sync,fault_latched,config_ok,reference_ok})
            7'b1110011:begin end
            default:gates=0;
        endcase
    end
endmodule

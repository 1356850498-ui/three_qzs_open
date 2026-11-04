`timescale 1ns/1ps
module board_reset_sync(
    input   wire    clk , 
    input   wire    async_reset_n, 
    output  wire    rst_n); 
    
////////////////////// 复位同步释放 //////////////
    
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) 
    //  ASYNC_REG="TRUE"  这是同步链中的寄存器，请按同步器处理。
    // SHREG_EXTRACT="NO" 保留为触发器，不要改造成 LUT 内的移位寄存器结构
    
    reg release_ff1=0;
    reg release_ff2=0;
    
    always @(posedge clk or negedge async_reset_n) // async_reset_n  来自bd，低有效
    begin
        if (!async_reset_n) 
        begin 
            release_ff1<=0; 
            release_ff2<=0; 
        end
        else 
        begin 
            release_ff1<=1; 
            release_ff2<=release_ff1; 
        end
    end
    
    assign rst_n=release_ff2;
endmodule

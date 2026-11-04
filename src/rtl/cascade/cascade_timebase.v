`timescale 1ns/1ps
// 唯一公共时间轴。保留单单元carrier_tick_gen原算法；新增phase输出用于移相。
// 所有计数仅在seq_run时推进；停机归零，重新启动可重复。
module cascade_timebase(
    input   wire        clk     , 
    input   wire        rst_n   , 
    input   wire        seq_run ,
    
    output  reg [13:0]  phase   ,
    output  wire        sample_tick
);
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) phase <= 14'd0;
        else if (!seq_run || phase == 14'd9999) phase <= 14'd0;
        else phase <= phase + 14'd1;
    end
    assign sample_tick = rst_n && seq_run && phase == 14'd9999;
endmodule

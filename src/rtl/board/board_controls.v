`timescale 1ns/1ps
module board_controls #(
    parameter integer DEBOUNCE_CYCLES=2_000_000,
    parameter integer FAULT_RELEASE_CYCLES=2_000_000
)(
    input   wire    clk         , 
    input   wire    rst_n       ,
    input   wire    btn_start   , 
    input   wire    btn_fault   , 
    input   wire    btn_clear   ,
    input   wire    fault_latched,
    
    output  reg     enable_req  , 
    output  wire    fault_sync  , 
    output  wire    clear_fault
);
    wire    start_level; 
    wire    fault_level; 
    wire    clear_level; 
    wire    start_event; 
    wire    clear_event;
    
    button_sync u_start_sync(.clk(clk),.rst_n(rst_n),.async_in(btn_start),.sync_out(start_level));
    
    button_sync #(
    .RESET_VALUE(1'b0)) 
        u_fault_sync(.clk(clk),.rst_n(rst_n),.async_in(btn_fault),.sync_out(fault_level));
    
    button_sync u_clear_sync(.clk(clk),.rst_n(rst_n),.async_in(btn_clear),.sync_out(clear_level));

///////////////////////////////////////////////////////////////////    
    button_event #(
    .STABLE_CYCLES(DEBOUNCE_CYCLES)) 
        u_start_event(.clk(clk),.rst_n(rst_n),.button_sync(start_level),.press_event(start_event));
    
    button_event #(
    .STABLE_CYCLES(DEBOUNCE_CYCLES)) 
        u_clear_event(.clk(clk),.rst_n(rst_n),.button_sync(clear_level),.press_event(clear_event));
        
    localparam integer FW=(FAULT_RELEASE_CYCLES<2)?1:$clog2(FAULT_RELEASE_CYCLES); // $clog2() 算出所需位数，即以2为底的对数向上取整
    localparam [FW-1:0] FLAST=FAULT_RELEASE_CYCLES-1;
    
    // localparam integer FW = 21;
    // localparam [20:0] FLAST = 1999999;
    // 相当于这个
    
    reg     [FW-1:0]    release_count;
    reg                 fault_hold   ; // 把故障信号保持了20ms

    assign fault_sync=fault_level | fault_hold;
    
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin 
            fault_hold<=0; 
            release_count<=0; 
        end
        else if (fault_level) 
        begin 
            fault_hold<=1; 
            release_count<=0; 
        end
        else if (fault_hold)
        begin
            if (release_count==FLAST) 
            begin 
                fault_hold<=0; 
                release_count<=0; 
            end
            else 
                release_count<=release_count+1'b1;
        end 
        else 
            release_count<=0;
    end

    assign clear_fault=rst_n && clear_event && !fault_sync && !enable_req;
    
    // Priority: reset > fault source > clear event > latch inhibit > start/stop.
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) enable_req<=0;
        else if (fault_sync) enable_req<=0;
        else if (clear_event) enable_req<=0;
        else if (fault_latched) enable_req<=0;
        else if (start_event) enable_req<=!enable_req;
    end
endmodule


`timescale 1ns/1ps
// Real vendor Processor System Reset IP, not a behavioural reset substitute.
module reset_tb;
    reg clk=0; always #5 clk=~clk;
    reg ps_reset_n=0;
    wire [0:0] peripheral_n;
    wire reset_n;
    integer errors=0, n, f;
    ps_clock_reset_rst_100m_0 dut(.slowest_sync_clk(clk),.ext_reset_in(ps_reset_n),
        .aux_reset_in(1'b0),.mb_debug_sys_rst(1'b0),.dcm_locked(1'b1),
        .mb_reset(),.bus_struct_reset(),.peripheral_reset(),
        .interconnect_aresetn(),.peripheral_aresetn(peripheral_n));
    board_reset_sync sync_reset(clk,ps_reset_n & peripheral_n[0],reset_n);
    task automatic ck(input bit ok,input string label_name);
        if(!ok) begin errors++;$display("FAIL reset %s at %0t",label_name,$time);end
    endtask
    task automatic wait_release;
        n=0;
        while(reset_n!==1'b1 && n<150) begin @(posedge clk);#1;n++;end
        ck(reset_n===1,"reset IP and board synchronizer release with clock");
        ck(n>=2,"reset release sequenced");
    endtask
    always @(posedge reset_n) ck(clk===1,"reset release only on clock rising edge");
    initial begin
        #1;ck(reset_n===0,"initial reset asserted");
        repeat(20) @(posedge clk);@(negedge clk);ps_reset_n=1;wait_release();
        @(negedge clk);#2;ps_reset_n=0;#1;ck(reset_n===0,"raw PS reset guard asserts asynchronously");
        repeat(20) @(posedge clk);#1;ck(peripheral_n===0,"low-active external reset reaches IP output");
        @(negedge clk);#2;ps_reset_n=1;#1;ck(reset_n===0,"cannot release asynchronously");wait_release();
        f=$fopen("result_reset.txt","w");$fdisplay(f,"ERRORS=%0d",errors);
        if(errors==0) $fdisplay(f,"RESULT=PASS");else $fdisplay(f,"RESULT=FAIL");
        $fclose(f);$finish;
    end
    initial begin #100_000;$fatal(1,"RESET TIMEOUT");end
endmodule

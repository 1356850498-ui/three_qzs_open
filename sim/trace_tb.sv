`timescale 1ns/1ps
module trace_tb;
reg clk=0;always #5 clk=~clk;
reg rst=0,en=0,fault=0,clear=0;wire [3:0] gates;wire run,latch;
qzs_spwm_top #(.ST_D_PPM(200000)) dut(clk,rst,en,fault,clear,gates[3],gates[2],gates[1],gates[0],run,latch);
integer f,cnt=0,errors=0;
always @(posedge clk)begin #1;
if(run&&(dut.sample_index==0||dut.sample_index==25||dut.sample_index==125))
$fdisplay(f,"%0t,%0d,%0d,%0d,%b,%b,%b",$time,dut.sample_index,dut.carrier,dut.ref_l,gates,dut.st_left,dut.st_right);
end
initial begin
f=$fopen("key_trace.csv","w");$fdisplay(f,"time_ps,index,carrier,reference,gates,st_left,st_right");
repeat(5)@(negedge clk);rst=1;repeat(5)@(negedge clk);en=1;
wait(dut.sample_index==126);@(negedge clk);en=0;repeat(5)@(negedge clk);
// Corrupt reference during a controlled window. Restore data before legal clear.
en=1;wait(gates==4'b1101);@(negedge clk);force dut.ref_l=10'd199;force dut.ref_r=10'd801;
#1;if(gates!==0)errors++;repeat(3)@(negedge clk);if(!latch||run)errors++;
release dut.ref_l;release dut.ref_r;en=0;repeat(5)@(negedge clk);clear=1;repeat(3)@(negedge clk);clear=0;
if(latch||run)errors++;
en=1;repeat(6)@(negedge clk);if(!run||dut.sample_index!=0)errors++;
en=0;repeat(5)@(negedge clk);$fclose(f);
f=$fopen("result_trace.txt","w");$fdisplay(f,"RESULT=%s\nREFERENCE_CORRUPTION_CASES=1\nERRORS=%0d",errors?"FAIL":"PASS",errors);$fclose(f);
if(errors)$fatal(1,"trace reference corruption");$display("TRACE PASS");$finish;
end
endmodule

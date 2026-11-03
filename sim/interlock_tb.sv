`timescale 1ns/1ps
module one_interlock #(parameter integer DEAD=100)(output reg done=0,output integer errors=0,checks=0);
reg clk=0;always #5 clk=~clk;reg rst=0,run=0,req=1,st=0;wire h,l;
qzs_normal_interlock #(.DEAD_CYCLES(DEAD)) dut(clk,rst,run,req,st,h,l);
integer gap=0,age=0;reg prev_run=0,prev_req=1,prev_st=0;reg pre_req,pre_st,pre_run;
task automatic ck(input bit x);checks++;if(!x)begin errors++;if(errors<5)$display("FAIL interlock DEAD=%0d t=%0t",DEAD,$time);end endtask
always @(posedge clk)begin
pre_req=req;pre_st=st;pre_run=run;
if(!rst||!run)age=0;
else if(prev_st)age=DEAD+1;else if(!prev_run||req!=prev_req)age=0;else age++;
#1;
ck(!(h&&l));if(!rst||!run||st)ck(!h&&!l);
if(rst&&pre_run&&!pre_st)begin
 if(prev_st)ck({h,l}===(pre_req?2'b10:2'b01));
 // A normal request reversal must stay off for DEAD complete clocks.
 else if(!prev_run||pre_req!=prev_req)ck(!h&&!l);
 else if(age<DEAD)ck(!h&&!l);
 else if(age>=DEAD+1)ck({h,l}===(pre_req?2'b10:2'b01));
end
prev_run=pre_run;prev_req=pre_req;prev_st=pre_st;
end
task automatic step(input integer n);repeat(n)@(negedge clk);endtask
initial begin
step(3);rst=1;step(3);run=1;step(DEAD+5);
repeat(4)begin req=~req;step(DEAD+5);end
// Explicit ST entry/exit is allowed to overlap through the final arbiter and
// returns to a subset without a one-microsecond notch.
st=1;step(20);req=~req;step(3);st=0;step(DEAD+5);
// Re-arm the independent normal-history checker after controlled ST.
run=0;step(3);run=1;step(DEAD+5);
repeat(10)begin req=~req;step(1);req=~req;step(DEAD+5);end
st=1;step(2);#2;rst=0;#1;ck(!h&&!l);run=0;step(3);done=1;
end
endmodule
module interlock_tb;
wire [2:0] done;wire [31:0] e0,e1,e2,c0,c1,c2;integer f;
one_interlock #(100) A(done[0],e0,c0);one_interlock #(1) B(done[1],e1,c1);one_interlock #(2) C(done[2],e2,c2);
initial begin wait(&done);#2;f=$fopen("result_interlock.txt","w");$fdisplay(f,"RESULT=%s\nCHECKS=%0d\nERRORS=%0d",(e0+e1+e2)?"FAIL":"PASS",c0+c1+c2,e0+e1+e2);$fclose(f);if(e0+e1+e2)$fatal(1,"interlock errors");$display("INTERLOCK PASS");$finish;end
endmodule


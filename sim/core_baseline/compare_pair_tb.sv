`timescale 1ns/1ps
module compare_pair_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,seq_run=0,valid=0;
 reg [7:0] index=0;reg [13:0] carrier=0;reg [9:0] l=500,r=500;
 wire ql,qr,ready;
 spwm_compare_pair dut(clk,rst_n,seq_run,index,carrier,l,r,valid,ql,qr,ready);
 integer checks=0,errors=0,f,a,b,k,t;
 reg el,er,ey;
 task automatic vector(input integer cv,input integer lv,input integer rv,input bit vv,input bit runv,input integer iv);
 begin
   @(negedge clk);carrier=cv;l=lv;r=rv;valid=vv;seq_run=runv;index=iv;
   // Mathematical thresholds with 64-bit arithmetic, rather than DUT expression width.
   el=vv && (64'(cv)<(64'd5000*lv)/1000);
   er=vv && (64'(cv)<(64'd5000*rv)/1000);
   ey=!runv && vv && iv==0 && cv==0;
   @(posedge clk);#1;checks++;
   if({ql,qr,ready} !== {el,er,ey}) begin
     errors++;
     if(errors<15) $display("FAIL COMPARE t=%0t carrier=%0d ref_l=%0d ref_r=%0d valid=%b seq=%b index=%0d expected=%b%b%b actual=%b%b%b",$time,cv,lv,rv,vv,runv,iv,el,er,ey,ql,qr,ready);
   end
 end endtask
 initial begin
   repeat(3) @(negedge clk);rst_n=1;
   vector(0,500,500,0,0,0);vector(0,500,500,1,0,0);
   vector(0,500,500,1,1,0);vector(0,500,500,1,0,1);
   vector(1,500,500,1,0,0);
   for(a=0;a<=1023;a++) begin
     t=(5000*a)/1000;
     vector(0,a,1023-a,1,1,23);
     if(t>0) vector(t-1,a,1023-a,1,1,23);
     vector(t,a,1023-a,1,1,23);vector(t+1,a,1023-a,1,1,23);
     vector(16383,a,1023-a,1,1,23);
   end
   for(b=0;b<=5000;b++) begin
     vector(b,200,800,1,1,0);vector(b,500,500,1,1,0);vector(b,800,200,1,1,0);
   end
   vector(0,800,800,0,0,0);
   f=$fopen("result_compare.txt","w");$fdisplay(f,"checks=%0d errors=%0d",checks,errors);
   if(errors==0) begin $fdisplay(f,"RESULT=PASS");$display("COMPARE_RESULT=PASS checks=%0d",checks);end
   else begin $fdisplay(f,"RESULT=FAIL");$display("COMPARE_RESULT=FAIL errors=%0d",errors);end
   $fclose(f);$finish;
 end
 initial begin #1000000;$fatal(1,"COMPARE TIMEOUT");end
endmodule

`timescale 1ns/1ps
module deadtime_half_bridge_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,permit=0,req=0;
 wire hi,lo;
 dt_half_bridge #(.DEAD_CYCLES(100)) dut(clk,rst_n,permit,req,hi,lo);
 integer checks,errors,openings,reversals,min_gap;
 gate_deadline_checker #(.ID(3)) checker100(clk,rst_n,permit,req,hi,lo,checks,errors,openings,reversals,min_gap);
 wire h1,l1,h2,l2;
 dt_half_bridge #(.DEAD_CYCLES(1)) dut1(clk,rst_n,permit,req,h1,l1);
 dt_half_bridge #(.DEAD_CYCLES(2)) dut2(clk,rst_n,permit,req,h2,l2);
 integer c1,e1,o1,r1,g1,c2,e2,o2,r2,g2;
 gate_deadline_checker #(.DEAD(1),.ID(4)) checker1(clk,rst_n,permit,req,h1,l1,c1,e1,o1,r1,g1);
 gate_deadline_checker #(.DEAD(2),.ID(5)) checker2(clk,rst_n,permit,req,h2,l2,c2,e2,o2,r2,g2);
 integer scenario=0,j,k,f,coverage=0;reg [31:0] rng=32'h69104721;
 task automatic drive(input bit p,input bit r,input integer n,input string description);
 begin
   @(negedge clk);permit=p;req=r;scenario++;
   $display("SCENARIO %0d t=%0t %s permit=%b req=%b clocks=%0d",scenario,$time,description,p,r,n);
   repeat(n) begin @(posedge clk);#2;end
 end endtask
 initial begin
   repeat(4) @(negedge clk);rst_n=1;
   drive(1,1,120,"first opening high");
   drive(1,0,120,"high to low E0 to E100");
   drive(1,1,120,"low to high E0 to E100");coverage++;
   drive(1,0,40,"short low request");drive(1,1,110,"cancel pending low and full new wait");coverage++;
   drive(1,0,100,"advance to E99");drive(1,1,110,"reverse exactly at E100, cancel old opening");coverage++;
   drive(1,0,99,"advance to E98");drive(1,1,110,"reverse one clock before expiry");coverage++;
   drive(1,0,101,"allow E100 opening");drive(1,1,110,"reverse just after expiry");coverage++;
   drive(1,0,50,"pending opening");drive(0,0,150,"disable interrupts wait");
   drive(1,0,110,"fresh low startup after disable");coverage++;
   drive(1,1,50,"pending high");@(negedge clk);#2;rst_n=0;#1;
   if({hi,lo}!==0) $fatal(1,"asynchronous reset failed t=%0t actual=%b%b",$time,hi,lo);
   drive(0,1,150,"reset clears pending direction");@(negedge clk);rst_n=1;
   drive(1,0,110,"fresh low startup after reset");coverage++;
   drive(1,1,100,"low to high wait through E99");
   drive(1,0,110,"cancel high exactly on E100");coverage++;
   drive(1,1,100,"pending high through E99");
   drive(0,1,110,"disable exactly on E100 cancels high");
   drive(1,0,110,"fresh start after expiry disable");coverage++;
   // Repeated one-clock alternating requests never mature for DEAD=100.
   for(j=0;j<30;j++) drive(1,j[0],1,"alternating narrow requests");
   drive(1,1,110,"settle after narrow requests");coverage++;
   // Deterministic pseudo-random external requests and enable durations.
   for(k=0;k<180;k++) begin
     rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);
     drive((rng%9)!=0,rng[15],1+(rng%151),"deterministic random request/disable");
   end
   drive(0,0,4,"finish disabled");
   f=$fopen("result_deadtime.txt","w");
   $fdisplay(f,"DEAD100 checks=%0d errors=%0d openings=%0d reversals=%0d min_gap=%0d",checks,errors,openings,reversals,min_gap);
   $fdisplay(f,"DEAD1 checks=%0d errors=%0d; DEAD2 checks=%0d errors=%0d; directed_categories=%0d",c1,e1,c2,e2,coverage);
   if(errors+e1+e2==0 && openings>5 && reversals>20 && min_gap>=100 && coverage==10) begin
     $fdisplay(f,"RESULT=PASS");$display("DEADTIME_RESULT=PASS");
   end else begin $fdisplay(f,"RESULT=FAIL");$display("DEADTIME_RESULT=FAIL");end
   $fclose(f);$finish;
 end
 initial begin #1000000;$fatal(1,"DEADTIME TIMEOUT");end
endmodule

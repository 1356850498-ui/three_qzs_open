`timescale 1ns/1ps
module parameter_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,run=1;reg [9:0] l=500,r=500;reg [13:0] c=2500;
 localparam integer D[0:9]='{0,1,7999,8000,300000,300001,-400,100001,300000,300000};
 localparam integer MN[0:9]='{200,200,200,200,200,200,200,200,151,150};
 localparam bit OK[0:9]='{1,0,0,1,1,0,0,1,1,0};
 wire [9:0] ok,rok,sl,sr;wire [3:0] v[0:9];
 genvar g;generate for(g=0;g<10;g++)begin:U
 qzs_window #(.ST_D_PPM(D[g]),.REF_MIN(MN[g]),.REF_MAX(1000-MN[g])) dut(clk,rst,run,1'b1,c,l,r,ok[g],rok[g],sl[g],sr[g],v[g],,);
 end endgenerate
 integer errors=0,checks=0,f;integer phase,sgn,total;reg [3:0] expv;
 wire [3:0] badg;wire badrun,badfault;
 qzs_spwm_top #(.ST_D_PPM(1)) badcore(clk,rst,1'b1,1'b0,1'b0,badg[3],badg[2],badg[1],badg[0],badrun,badfault);
 task automatic ck(input bit x);checks++;if(!x)errors++;endtask
 initial begin
 #2;rst=1;repeat(10)@(negedge clk);
 for(integer i=0;i<10;i++)begin ck(ok[i]===OK[i]);if(!OK[i])ck(v[i]===0&&!sl[i]&&!sr[i]);end
 ck(!badrun&&badfault&&badg==0);
 l=199;r=801;#1;ck(!rok[7]);@(negedge clk);ck(v[7]==0);
 l=500;r=499;#1;ck(!rok[7]);
 l=500;r=500;#1;ck(rok[7]);run=0;@(negedge clk);ck(v[7]==0);

 // Closest legal modulation envelope at D=.3: REF_MIN151 => M=.698.
 // Independent event list on a monotonic axis, including both sides of wrap.
 for(sgn=0;sgn<2;sgn++)begin
 run=1;l=sgn?849:151;r=1000-l;total=0;
 for(phase=0;phase<10000;phase++)begin
 @(negedge clk);c=(phase<=5000)?phase:10000-phase;
 expv=0;
 if((phase>=5&&phase<755)||(phase>=9246&&phase<9996))expv=sgn?4'b1011:4'b1110;
 if((phase>=4245&&phase<4995)||(phase>=5006&&phase<5756))expv=sgn?4'b1101:4'b0111;
 @(posedge clk);#1;ck(v[8]===expv);ck(ok[8]&&rok[8]);
 if(v[8]!=0)total++;
 end
 ck(total==3000);
 end
 f=$fopen("result_parameter.txt","w");$fdisplay(f,"RESULT=%s\nCHECKS=%0d\nERRORS=%0d",errors?"FAIL":"PASS",checks,errors);$fclose(f);
 if(errors)$fatal(1,"parameter failures %0d",errors);$display("PARAMETER PASS %0d",checks);$finish;
 end
endmodule

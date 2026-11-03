`timescale 1ns/1ps
module arbiter_tb;
 reg [6:0] safe;reg [3:0] normal,st;reg sl,sr;wire [3:0] gates;wire err;
 qzs_gate_arbiter dut(safe[6],safe[5],safe[4],safe[3],safe[2],safe[1],safe[0],normal,sl,sr,st,gates,err);
 integer errors=0,checks=0,f;reg nok,sok;reg [3:0] expect_g;
 initial begin
 for(integer n=0;n<16;n++)for(integer w=0;w<4;w++)for(integer v=0;v<16;v++)for(integer s=0;s<128;s++)begin
 normal=n;{sl,sr}=w;st=v;safe=s;#1;
 // Independent truth predicates, not DUT case-table duplication.
 nok= !(normal[3]&&normal[2]) && !(normal[1]&&normal[0]);
 sok=(sl&&!sr&&st[3:2]==3&&(st[1:0]==1||st[1:0]==2))||
     (sr&&!sl&&st[1:0]==3&&(st[3:2]==1||st[3:2]==2));
 expect_g=0;
 if(safe==7'b1110011&&nok)begin
 if(w==0&&st==0)expect_g=normal;else if(sok)expect_g=st;end
 checks++;if(gates!==expect_g)begin errors++;if(errors<5)$display("FAIL arbiter %b %b %b",safe,gates,expect_g);end
 checks++;if(err!==(!nok||(w==0?(st!=0):!sok)))errors++;
 end
 safe=7'b1110011;normal=9;{sl,sr}=1;st=11;#1;safe[3]=1'bx;#1;checks++;if(gates!==0)errors++;
 f=$fopen("result_arbiter.txt","w");$fdisplay(f,"RESULT=%s\nCHECKS=%0d\nERRORS=%0d",errors?"FAIL":"PASS",checks,errors);$fclose(f);
 if(errors)$fatal(1,"arbiter");$display("ARBITER PASS %0d",checks);$finish;
 end
endmodule

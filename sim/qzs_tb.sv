`timescale 1ns/1ps
module qzs_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,en=0,fault=0,clear=0;
 wire [3:0] gates[0:5];wire [5:0] run,latch;
 localparam integer P[0:5]='{0,8000,50000,100001,200000,300000};
 genvar g;
 generate for(g=0;g<6;g=g+1)begin:U
 qzs_spwm_top #(.ST_D_PPM(P[g])) dut(clk,rst,en,fault,clear,
 gates[g][3],gates[g][2],gates[g][1],gates[g][0],run[g],latch[g]);
 end endgenerate
 wire [3:0] base;wire br,bf;
 hbridge_spwm_top baseline(clk,rst,en,fault,clear,base[3],base[2],base[1],base[0],br,bf);
 integer errors=0,checks=0,t=0,idx=0,cycles=0,starts=0,k,n,h,fp;
 localparam integer CUT_W=P[4]/400;
 integer cutfp;
 integer segment_ticks[0:5],union_pulses[0:5];
 reg last_any[0:5];
 integer union_count[0:5],left_count[0:5],right_count[0:5],windows[0:5];
 reg [3:0] lastst[0:5];reg [9:0] rom[0:199];
 reg wasrun;reg [3:0] expected[0:5];reg pre;
 integer witness[0:3][0:3][0:1];integer cut_kind,cut_phase,cut_action;
 reg [1:0] kind,previous_kind=0;integer delay_n;
 task automatic ck(input bit ok,input string s);
 checks++;if(!ok)begin errors++;if(errors<25)$display("FAIL %0t t=%0d idx=%0d %s",$time,t,idx,s);end
 endtask
 // Independent event timeline: switching instants derived from the ROM
 // on a monotonic 10000-tick axis, then expanded toward a zero vector.
 // No DUT carrier/window/threshold is consulted to obtain the expectation.
 function automatic [3:0] event_model(input integer phase,ri,w);
 integer l,r;bit positive;
 begin
 l=5*ri;r=5000-l;positive=ri>=500;event_model=0;
 if(w>0)begin
 if(positive)begin
 if((phase>=r-w && phase<r)||(phase>=10001-r && phase<10001-r+w))event_model=4'b1011;
 if((phase>=l && phase<l+w)||(phase>=10001-l-w && phase<10001-l))event_model=4'b1101;
 end else begin
 if((phase>=l-w && phase<l)||(phase>=10001-l && phase<10001-l+w))event_model=4'b1110;
 if((phase>=r && phase<r+w)||(phase>=10001-r-w && phase<10001-r))event_model=4'b0111;
 end end
 end endfunction

 always @(posedge clk)begin
 pre=run[4];
 if(pre)for(integer j=0;j<6;j++)expected[j]=event_model(t,rom[idx],P[j]/400);
 #1;
 ck({gates[0],run[0],latch[0]}==={base,br,bf},"D0 direct RTL equivalence at edge");
 for(integer j=0;j<6;j++)begin
 if(!rst||!run[j])ck(gates[j]===0,"stopped gates zero");
 if(j>0 && (!en||fault))ck(gates[j]===0,"final permission closes immediately");
 if(pre && run[j] && rst && en && !fault)begin
 if(lastst[j]!=0 && lastst[j]!=expected[j])ck(segment_ticks[j]==P[j]/400,"each completed labelled window is W ticks");
 if(expected[j]!=lastst[j])segment_ticks[j]=0;
 if(expected[j]!=0)segment_ticks[j]++;
 if((gates[j][3:2]==3 || gates[j][1:0]==3) && !last_any[j])union_pulses[j]++;
 last_any[j]=(gates[j][3:2]==3 || gates[j][1:0]==3);
 if(last_any[j])union_count[j]++;
 if(expected[j]!=0)begin
 ck(gates[j]===expected[j],$sformatf("event schedule vector D=%0d expected=%b got=%b",P[j],expected[j],gates[j]));
 if(lastst[j]!=expected[j])windows[j]++;
 if(gates[j][3:2]==3)left_count[j]++;if(gates[j][1:0]==3)right_count[j]++;
 end else ck(!(gates[j][3]&&gates[j][2])&&!(gates[j][1]&&gates[j][0]),"no overlap outside independent interval");
 ck(gates[j]!=15,"no all-four overlap");lastst[j]=expected[j];
 end
 end
 if(pre && run[4] && rst && en && !fault)begin
 if(t==9999)begin
 for(integer j=0;j<6;j++)begin
 ck(union_count[j]==4*(P[j]/400),"per-cycle union is 4W");
 ck(left_count[j]==2*(P[j]/400) && right_count[j]==2*(P[j]/400),"each arm gets 2W");
 ck(windows[j]==((j==0)?0:4),"four labelled windows per period");
 ck(union_pulses[j]==((j==0)?0:((rom[idx]==500)?2:4)),"actual time-union pulse count at zero crossing");
 $fdisplay(fp,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycles,idx,P[j],union_count[j],left_count[j],right_count[j],windows[j],union_pulses[j]);
 union_count[j]=0;left_count[j]=0;right_count[j]=0;windows[j]=0;lastst[j]=0;segment_ticks[j]=0;union_pulses[j]=0;last_any[j]=0;
 end
 cycles++;idx=(idx==199)?0:idx+1;t=0;
 end else t++;
 end else if(!run[4])begin
 t=0;idx=0;
 for(integer j=0;j<6;j++)begin union_count[j]=0;left_count[j]=0;right_count[j]=0;windows[j]=0;lastst[j]=0;segment_ticks[j]=0;union_pulses[j]=0;last_any[j]=0;end
 end
 if(run[4]&&!wasrun)begin starts++;ck(U[4].dut.sample_index==0&&U[4].dut.carrier==0,"restart reference0/carrier0");end
 wasrun=run[4];
 end
 always @(negedge clk)begin #1;
 ck({gates[0],run[0],latch[0]}==={base,br,bf},"D0 direct RTL equivalence midcycle");
 end
 task automatic step(input integer n);repeat(n)begin @(posedge clk);#2;end endtask
 task automatic stop;@(negedge clk);en=0;step(5);ck(!run[4]&&gates[4]==0,"stop complete");endtask
 task automatic start;@(negedge clk);en=1;step(5);ck(run[4],"start accepted");endtask
 task automatic clear_latch;@(negedge clk);en=0;fault=0;clear=1;step(3);clear=0;step(3);ck(!latch[4]&&!run[4],"clear keeps stopped");endtask
 initial begin
 $readmemh("spwm_duty.mem",rom);fp=$fopen("period_statistics.csv","w");
 $fdisplay(fp,"period,index,D_ppm,union_ticks,left_ticks,right_ticks,labelled_windows,union_pulses");
 cutfp=$fopen("interruption_cases.csv","w");$fdisplay(cutfp,"window,phase,action,D_ppm,W_ticks,sample_phase,gates_before_cut");
 for(integer j=0;j<6;j++)begin union_count[j]=0;left_count[j]=0;right_count[j]=0;windows[j]=0;lastst[j]=0;segment_ticks[j]=0;union_pulses[j]=0;last_any[j]=0;end
 for(integer a=0;a<4;a++)for(integer b=0;b<4;b++)for(integer c=0;c<2;c++)witness[a][b][c]=0;
 step(5);rst=1;step(6);start();
 // Two complete fundamental cycles check every ROM entry and both wrap edges.
 wait(cycles>=400);step(20);stop();
 // Four windows of reference index 25, all four cut positions, stop and fault.
 for(cut_kind=0;cut_kind<4;cut_kind++)for(cut_phase=0;cut_phase<4;cut_phase++)for(cut_action=0;cut_action<2;cut_action++)begin
 clear_latch();start();
 // Explicit switching-event times for the independently read reference.
 h=(cut_kind==0)?5000-5*rom[25]-CUT_W:
   (cut_kind==1)?5*rom[25]:
   (cut_kind==2)?10001-5*rom[25]-CUT_W:10001-(5000-5*rom[25]);
 n=h+1+((cut_phase==0)?-1:(cut_phase==1)?0:(cut_phase==2)?CUT_W/2:CUT_W);
 wait(idx==25 && t==n);
 @(negedge clk);
 if(cut_phase==1 || cut_phase==2)ck(gates[4]===event_model(n-1,rom[25],CUT_W) && (gates[4][3:2]==3 || gates[4][1:0]==3),"cut actually inside target D0.2 window");
 else ck(!(gates[4][3:2]==3 || gates[4][1:0]==3),"cut actually outside target D0.2 window");
 $fdisplay(cutfp,"%0d,%0d,%0d,200000,%0d,%0d,%b",cut_kind,cut_phase,cut_action,CUT_W,n-1,gates[4]);
 if(cut_action==0)en=0;else fault=1;
 #1;ck(gates[4]===0,"cut before sampling leaves no ST");
 step(2);ck(!run[4]&&gates[4]===0,"cut closes output");
 if(cut_action==1)ck(latch[4],"fault latched");
 witness[cut_kind][cut_phase][cut_action]++;
 en=0;fault=0;step(4);
 end
 clear_latch();start();wait(gates[4]==4'b1101);@(negedge clk);#2;rst=0;#1;ck(gates[4]===0,"async reset inside ST");en=0;step(4);rst=1;step(6);ck(!run[4],"reset stays stopped");
 // Fault and enable together. Clear while requested must fail.
 @(negedge clk);fault=1;en=1;step(3);ck(latch[4]&&!run[4],"fault wins start");
 fault=0;clear=1;step(3);ck(latch[4],"invalid clear while requested rejected");
 clear=0;clear_latch();start();step(15000);stop();
 for(integer a=0;a<4;a++)for(integer b=0;b<4;b++)for(integer c=0;c<2;c++)ck(witness[a][b][c]==1,"injection coverage");
 $fclose(cutfp);$fclose(fp);fp=$fopen("result_qzs.txt","w");
 $fdisplay(fp,"RESULT=%s\nCHECKS=%0d\nERRORS=%0d\nFULL_CARRIER_PERIODS=%0d\nSTARTS=%0d\nCUT_CASES=32",(errors==0)?"PASS":"FAIL",checks,errors,cycles,starts);$fclose(fp);
 if(errors)$fatal(1,"qzs failures %0d",errors);$display("QZS PASS checks=%0d cycles=%0d starts=%0d",checks,cycles,starts);$finish;
 end
 initial begin #200000000;$fatal(1,"TIMEOUT");end
endmodule

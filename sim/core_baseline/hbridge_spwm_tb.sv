`timescale 1ns/1ps
module hbridge_spwm_tb;
 reg clk=0; always #5 clk=~clk;
 reg rst_n=0, enable_req=1, fault_sync=0, clear_fault=0;
 wire s1,s2,s3,s4,run_active,fault_latched;
 hbridge_spwm_top dut(.clk_sys(clk),.rst_n(rst_n),.enable_req(enable_req),
 .fault_sync(fault_sync),.clear_fault(clear_fault),.pwm_s1(s1),.pwm_s2(s2),
 .pwm_s3(s3),.pwm_s4(s4),.run_active(run_active),.fault_latched(fault_latched));
 wire [3:0] gates={s1,s2,s3,s4};
 integer checks[0:7], errors[0:7];
 integer cycle=0, t0=0, starts=0, age, phase, idx, expected_carrier,events;
 reg first_on_l=0,first_on_r=0;
 integer ticks=0, completed_periods=0, wraps=0, i, f, total_errors;
 integer state_seen[0:15], first_l[0:199], first_r[0:199];
 integer second_matches=0, normal_starts=0, stop_events=0;
 integer raw_l_count=0, raw_r_count=0, out_l_count=0, out_r_count=0;
 integer stable_period_checks=0, raw_sum_min=20000,raw_sum_max=0;
 integer next_l,next_r,expected_index,analytic;
 reg [9:0] rom[0:199];
 reg pre_run,pre_valid,pre_ready,pre_fault,pre_req_l,pre_req_r;
 reg expected_run,expected_latch,expected_req_l,expected_req_r,expected_ready;
 reg previous_tick=0;
 integer pre_carrier,pre_l,pre_r,pre_index;
 integer dl_checks,dl_errors,dl_open,dl_rev,dl_gap;
 integer dr_checks,dr_errors,dr_open,dr_rev,dr_gap;
 gate_deadline_checker #(.ID(1)) check_left(clk,rst_n,dut.run_permit,dut.req_l,dut.gate_l_hi,dut.gate_l_lo,dl_checks,dl_errors,dl_open,dl_rev,dl_gap);
 gate_deadline_checker #(.ID(2)) check_right(clk,rst_n,dut.run_permit,dut.req_r,dut.gate_r_hi,dut.gate_r_lo,dr_checks,dr_errors,dr_open,dr_rev,dr_gap);
 task automatic ck(input integer group_id,input bit ok,input string signal_name,input integer expected,input integer actual);
 begin
   checks[group_id]++;
   if(!ok) begin
     errors[group_id]++;
     if(errors[group_id]<=12) $display("FAIL group=%0d t=%0t cycle=%0d signal=%s expected=%0d actual=%0d",group_id,$time,cycle,signal_name,expected,actual);
   end
 end endtask
 task automatic step(input integer n);
   repeat(n) begin @(posedge clk); #2; end
 endtask
 task automatic event_row(input string kind);
   $fdisplay(events,"%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%b,%b,%b",cycle*10-5,kind,starts,cycle-t0,dut.sample_index,dut.carrier,dut.ref_l,dut.ref_r,dut.req_l,dut.req_r,gates);
 endtask
 task automatic control(input bit en,input bit fault_in,input bit clr);
   @(negedge clk); enable_req=en; fault_sync=fault_in; clear_fault=clr;
 endtask
 task automatic wait_start(input string label_name);
 integer n;
 begin
   n=0;
   while(!run_active && n<30) begin step(1); n++; end
   ck(0,run_active===1,label_name,1,run_active);
   $display("SCENARIO %s t=%0t start_count=%0d",label_name,$time,starts);
 end endtask
 initial begin
   events=$fopen("events_core.csv","w");
   $fdisplay(events,"edge_time_ns,event,start_id,cycles_since_T0,index,carrier,ref_l,ref_r,req_l,req_r,S1S2S3S4");
   for(i=0;i<8;i++) begin checks[i]=0;errors[i]=0;end
   for(i=0;i<16;i++) state_seen[i]=0;
   for(i=0;i<200;i++) begin rom[i]='x;first_l[i]=-1;first_r[i]=-1;end
   $readmemh("spwm_duty.mem",rom);
   #1;
   for(i=0;i<200;i++) begin
     analytic=$rtoi(500.0+300.0*$sin(6.283185307179586*i/200.0)+0.5);
     ck(2,(^rom[i])!==1'bx && rom[i]>=200 && rom[i]<=800,"MEM range",analytic,rom[i]);
     ck(2,rom[i]>=analytic-1 && rom[i]<=analytic+1,"MEM sine quantization +/-1",analytic,rom[i]);
     ck(2,dut.u_ref.spwm_duty[i]===rom[i],"loaded DUT ROM",rom[i],dut.u_ref.spwm_duty[i]);
   end
   ck(2,rom[0]===500 && rom[50]===800 && rom[100]===500 && rom[150]===200,"MEM cardinal samples",1,0);
 end
 // Sample all synchronous inputs before NBA; compare outputs after propagation.
 always @(posedge clk) begin
   cycle++;
   pre_run=run_active;pre_valid=dut.ref_valid;pre_ready=dut.req_ready;pre_fault=fault_latched;
   pre_req_l=dut.req_l;pre_req_r=dut.req_r;
   pre_carrier=dut.carrier;pre_l=dut.ref_l;pre_r=dut.ref_r;pre_index=dut.sample_index;
   expected_run=pre_run;expected_latch=pre_fault;
   if(!rst_n) begin expected_run=0;expected_latch=0;end
   else begin
     if(fault_sync || pre_fault || !enable_req) expected_run=0;
     else if(pre_valid && pre_ready) expected_run=1;
     if(fault_sync) expected_latch=1;
     else if(!enable_req && clear_fault) expected_latch=0;
   end
   // Integer reference uses 64-bit unsigned arithmetic and the architectural scale.
   expected_req_l=rst_n && pre_valid && (64'(pre_carrier) < (64'd5000*pre_l)/1000);
   expected_req_r=rst_n && pre_valid && (64'(pre_carrier) < (64'd5000*pre_r)/1000);
   expected_ready=rst_n && !pre_run && pre_valid && pre_index==0 && pre_carrier==0;
   #1;
   ck(6,run_active===expected_run,"run_permit priority/readiness",expected_run,run_active);
   ck(6,fault_latched===expected_latch,"fault latch priority",expected_latch,fault_latched);
   ck(3,dut.req_l===expected_req_l,"left registered comparison",expected_req_l,dut.req_l);
   ck(3,dut.req_r===expected_req_r,"right registered comparison",expected_req_r,dut.req_r);
   ck(3,dut.req_ready===expected_ready,"registered ready",expected_ready,dut.req_ready);
   ck(4,!(s1&&s2) && !(s3&&s4) && (^gates)!==1'bx,"four gate mutual exclusion",1,!(s1&&s2)&&!(s3&&s4));
   ck(4,gates === ({dut.gate_l_hi,dut.gate_l_lo,dut.gate_r_hi,dut.gate_r_lo}&{4{rst_n&&run_active}}),"S1 S2 S3 S4 mapping",0,gates);
   ck(4,run_active===dut.seq_run && run_active===dut.run_permit,"common sequence permit",run_active,dut.seq_run);
   state_seen[gates]++;
   if(!rst_n) begin
     ck(6,gates===0 && !run_active && !fault_latched,"reset logical outputs",0,gates);
     ck(2,dut.ref_l===500 && dut.ref_r===500 && !dut.ref_valid,"reset reference",500,dut.ref_l);
     previous_tick=0;
   end else if(!pre_run) begin
     ck(1,dut.carrier===0 && dut.u_carrier.div_10k_cnt===0,"stopped carrier/phase",0,dut.carrier);
     ck(2,dut.sample_index===0 && dut.ref_l===rom[0] && dut.ref_r===1000-rom[0] && dut.u_ref.next_addr===1,"preload and hold zero",0,dut.sample_index);
     ck(2,dut.ref_valid===1,"preload valid",1,dut.ref_valid);
     if(run_active) begin
       starts++; t0=cycle; ticks=0;first_on_l=0;first_on_r=0;
       ck(0,pre_valid && pre_ready && pre_index==0 && pre_carrier==0,"T0 readiness",1,pre_ready);
       ck(0,pre_req_l===1 && pre_req_r===1,"T0 prepared requests",3,{pre_req_l,pre_req_r});
       $display("T0 #%0d t=%0t cycle=%0d index=%0d carrier=%0d",starts,$time,cycle,dut.sample_index,dut.carrier);
       event_row("T0");
     end
     previous_tick=0;
   end else begin
     age=cycle-t0; phase=age%10000; idx=(age/10000)%200;
     expected_carrier=(phase<=5000)?phase:10000-phase;
     ck(1,dut.carrier===expected_carrier,"carrier from T0",expected_carrier,dut.carrier);
     ck(1,dut.u_carrier.div_10k_cnt===phase,"phase range/period",phase,dut.u_carrier.div_10k_cnt);
     ck(2,dut.sample_index===idx,"index from elapsed T0",idx,dut.sample_index);
     ck(2,dut.ref_l===rom[idx] && dut.ref_r===1000-rom[idx],"exact ROM reference and complement",rom[idx],dut.ref_l);
     ck(2,dut.ref_l+dut.ref_r==1000,"same-edge reference sum",1000,dut.ref_l+dut.ref_r);
     ck(2,dut.u_ref.next_addr===((idx+1)%200),"next address",(idx+1)%200,dut.u_ref.next_addr);
     if(phase==0) event_row("SAMPLE_UPDATE");
     if(run_active) begin
       ck(1,dut.sample_tick===(phase==9999),"tick position",phase==9999,dut.sample_tick);
       ck(1,!(previous_tick && dut.sample_tick),"tick one cycle width",0,previous_tick&&dut.sample_tick);
       previous_tick=dut.sample_tick;
     end else begin stop_events++;previous_tick=0;event_row("STOP");end
     if(starts==1 && age<=4000000) begin
       // Count registered requests corresponding to each entire sampled carrier cycle.
       raw_l_count+=dut.req_l;raw_r_count+=dut.req_r;
       out_l_count+=s1;out_r_count+=s3;
       if(phase==0) begin
         completed_periods++;
         expected_index=((age/10000)-1)%200;
         // Strict '<' on a discrete triangle gives 2*threshold-1 high samples.
         ck(7,raw_l_count==10*rom[expected_index]-1,"raw left cycle high count",10*rom[expected_index]-1,raw_l_count);
         ck(7,raw_r_count==10*(1000-rom[expected_index])-1,"raw right cycle high count",10*(1000-rom[expected_index])-1,raw_r_count);
         if(raw_l_count+raw_r_count<raw_sum_min) raw_sum_min=raw_l_count+raw_r_count;
         if(raw_l_count+raw_r_count>raw_sum_max) raw_sum_max=raw_l_count+raw_r_count;
         // Startup excluded. With 100 dead cycles each upper pulse loses 100 clocks.
         if(completed_periods>1) begin
           ck(7,out_l_count==raw_l_count-100,"steady final left high count",raw_l_count-100,out_l_count);
           ck(7,out_r_count==raw_r_count-100,"steady final right high count",raw_r_count-100,out_r_count);
           stable_period_checks++;
         end
         if(completed_periods<=200) begin first_l[expected_index]=raw_l_count;first_r[expected_index]=raw_r_count;end
         else begin
           ck(7,raw_l_count==first_l[expected_index] && raw_r_count==first_r[expected_index],"two-cycle repeatability",first_l[expected_index],raw_l_count);
           second_matches++;
         end
         raw_l_count=0;raw_r_count=0;out_l_count=0;out_r_count=0;
         if(idx==0) begin wraps++;$display("WRAP t=%0t elapsed_cycles=%0d periods=%0d",$time,age,completed_periods);end
       end
     end
   end
   if(run_active && (s1||s2) && !first_on_l) begin first_on_l=1;event_row("FIRST_LEFT_CONDUCTION");end
   if(run_active && (s3||s4) && !first_on_r) begin first_on_r=1;event_row("FIRST_RIGHT_CONDUCTION");end
 end
 initial begin : scenarios
   step(5);
   @(posedge clk); #2; rst_n=1; // ideal synchronized release, after edge samples reset
   wait_start("cold start, enable already asserted");
   step(4000001); // two complete 20ms periods plus observation margin
   ck(0,completed_periods==400 && wraps==2 && second_matches==200,"40ms coverage",400,completed_periods);
   control(0,0,0);step(1);ck(6,!run_active && gates===0,"disable next edge",0,gates);
   step(35000);control(1,0,0);wait_start("restart after 350us disabled");step(10002);
   // Reset while running, including asynchronous assertion between edges.
   @(negedge clk);#2;rst_n=0;#1;ck(6,gates===0 && !run_active,"asynchronous reset assertion",0,gates);
   step(4);@(posedge clk);#2;rst_n=1;
   wait_start("restart after reset");step(10002);
   // Fault while both upper gates are on, measured to next active edge.
   control(1,1,1);step(1);
   ck(6,!run_active && fault_latched && gates===0,"fault beats clear/enable within one edge",0,gates);
   control(1,0,0);step(12000);ck(6,!run_active && fault_latched,"no automatic fault recovery",0,run_active);
   control(1,0,1);step(3);ck(6,fault_latched,"illegal clear while enabled rejected",1,fault_latched);
   control(0,1,1);step(3);ck(6,fault_latched,"clear while source active rejected",1,fault_latched);
   control(0,0,1);step(1);ck(6,!fault_latched && !run_active,"legal clear while disabled",0,fault_latched);
   control(0,0,0);step(8);control(1,0,0);wait_start("restart after legal fault clear");step(10002);
   // Disable and fault during the startup dead-time wait; no internal forcing.
   control(0,0,0);step(10);control(1,0,0);wait_start("disable during startup wait");step(49);
   control(0,0,0);step(150);ck(6,gates===0 && !run_active,"disable cancels pending opening",0,gates);
   control(1,0,0);wait_start("fault during startup wait");step(49);
   control(1,1,0);step(150);ck(6,gates===0 && fault_latched,"fault cancels pending opening",0,gates);
   control(0,0,1);step(2);control(0,0,0);step(8);control(1,0,0);wait_start("second fault recovery");step(10002);
   // Minimal disable pulse at an arbitrary sample; stale ready must not skip preparation.
   step(12345);control(0,0,0);step(1);control(1,0,0);wait_start("one-clock disable restart");step(10002);
   control(0,0,0);step(5);
   // Explicit reset > fault > clear priority, while no further start is requested.
   control(0,1,1);step(1);ck(6,fault_latched,"fault set before reset priority case",1,fault_latched);
   @(negedge clk);#2;rst_n=0;#1;
   ck(6,!fault_latched && !run_active && gates===0,"reset dominates active fault and clear",0,fault_latched);
   step(3);@(posedge clk);#2;rst_n=1;step(1);
   ck(6,fault_latched && !run_active,"active source re-latches after reset release",1,fault_latched);
   control(0,0,1);step(2);control(0,0,0);step(3);
   ck(0,starts==8,"all startup scenarios reached",8,starts);
   ck(4,state_seen[9]>0 && state_seen[6]>0 && state_seen[10]>0 && state_seen[5]>0,"positive negative and both zero states covered",1,0);
   ck(5,dl_errors==0 && dr_errors==0,"integrated dead-time deadlines",0,dl_errors+dr_errors);
   ck(5,dl_rev>400 && dr_rev>400 && dl_gap>=100 && dr_gap>=100,"both arms many reversals and minimum gap",100,dl_gap);
   $display("COVERAGE starts=%0d periods=%0d wraps=%0d repeat_samples=%0d stable_periods=%0d raw_sum_min=%0d raw_sum_max=%0d",starts,completed_periods,wraps,second_matches,stable_period_checks,raw_sum_min,raw_sum_max);
   $display("DEAD_COVERAGE L_checks=%0d errors=%0d openings=%0d reversals=%0d min_gap=%0d R_checks=%0d errors=%0d openings=%0d reversals=%0d min_gap=%0d",dl_checks,dl_errors,dl_open,dl_rev,dl_gap,dr_checks,dr_errors,dr_open,dr_rev,dr_gap);
   f=$fopen("result_core.txt","w");total_errors=0;
   for(i=0;i<8;i++) begin $fdisplay(f,"GROUP %0d checks=%0d errors=%0d",i,checks[i],errors[i]);total_errors+=errors[i];end
   total_errors+=dl_errors+dr_errors;
   $fdisplay(f,"TOTAL_ERRORS=%0d",total_errors);
   if(total_errors==0) begin $fdisplay(f,"RESULT=PASS");$display("CORE_RESULT=PASS");end
   else begin $fdisplay(f,"RESULT=FAIL");$display("CORE_RESULT=FAIL errors=%0d",total_errors);end
   $fclose(f);$fclose(events);$finish;
 end
 initial begin #60000000; $display("FAIL TIMEOUT t=%0t run=%b index=%0d phase=%0d",$time,run_active,dut.sample_index,dut.u_carrier.div_10k_cnt);$fatal(1,"CORE TIMEOUT");end
endmodule

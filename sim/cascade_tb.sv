`timescale 1ns/1ps
// 期望仅使用独立整数时间轴和MEM，不用DUT窗口/载波/参考作为答案。
module cascade_test #(parameter integer D=200000);
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,en=0,fault=0,clear=0;
    wire [11:0] gates;
    wire run_active,latched,started,ready;
    wire [3:0] sources;
    cascade_core #(.ST_D_PPM(D)) dut(.clk(clk),.rst_n(rst_n),.enable_req(en),.fault_sync(fault),
        .clear_fault(clear),.gates(gates),.run_active(run_active),.fault_latched(latched),
        .fault_sources(sources),.all_started(started),.all_ready(ready));
    reg [9:0] rom[0:199];
    integer tick=0,checks=0,errors=0,restarts=0;
    integer delay_ticks[0:2]='{0,1667,3333};
    integer ri[0:2],unions[0:2],lefts[0:2],rights[0:2],periods[0:2],labels[0:2];
    integer arm_state[0:2][0:1],arm_target[0:2][0:1],deadline[0:2][0:1];
    bit arm_st[0:2][0:1],begun[0:2];
    reg [3:0] last_st[0:2];
    integer stats,trace,inj,result,cutcases=0,errorcases=0;
    integer target_unit,window_id,where_id,action_id,event_start,cut_tick,idx;
    bit was_running=0, pre,check_enabled=1;
    bit [6:0] levels_seen=0;
    task automatic ck(input bit ok,input string msg);
        checks++;
        if(!ok)begin errors++; if(errors<30)$display("FAIL D=%0d tick=%0d %s",D,tick,msg); end
    endtask
    function automatic [3:0] event_vector(input integer p,refval,w);
        integer low_event,high_event;
        begin
            low_event=5*((refval<500)?refval:1000-refval);
            high_event=5000-low_event;
            event_vector=0;
            if(w>0)begin
                if((p>=low_event-w && p<low_event) || (p>=10001-low_event && p<10001-low_event+w))
                    event_vector=(refval>=500)?4'b1011:4'b1110;
                if((p>=high_event && p<high_event+w) || (p>=10001-high_event-w && p<10001-high_event))
                    event_vector=(refval>=500)?4'b1101:4'b0111;
            end
        end
    endfunction
    function automatic integer voltage(input reg [3:0] v);
        case(v)
            4'b1001: voltage=1;
            4'b0110: voltage=-1;
            4'b1010,4'b0101,4'b1101,4'b1110,4'b1011,4'b0111:voltage=0;
            default:voltage=99; // 死区/全关的端电压由电流和二极管决定，模型标为未知。
        endcase
    endfunction
    task automatic clear_model;
        tick=0;
        for(integer u=0;u<3;u++)begin
            ri[u]=0;unions[u]=0;lefts[u]=0;rights[u]=0;labels[u]=0;last_st[u]=0;begun[u]=0;
            for(integer a=0;a<2;a++)begin arm_state[u][a]=0;arm_target[u][a]=-1;deadline[u][a]=0;arm_st[u][a]=0;end
        end
    endtask
    always @(posedge clk)begin : independent_check
        reg [11:0] expected;
        reg [3:0] sv,normal,v;
        integer p,c,request_value,ref_before,vt,total;
        bit model_run,valid_sum;
        pre=run_active;
        expected=0;
        if(pre && rst_n && en && !fault && check_enabled)begin
            for(integer u=0;u<3;u++)begin
                p=(tick-delay_ticks[u]+10000)%10000;
                c=(p<=5000)?p:10000-p;
                ref_before=rom[ri[u]];
                sv=event_vector(p,ref_before,D/400);
                normal=0;
                model_run=begun[u];
                for(integer a=0;a<2;a++)begin
                    request_value=(c<5*((a==0)?ref_before:1000-ref_before))?1:0;
                    if(!model_run)begin arm_state[u][a]=0;arm_target[u][a]=-1;arm_st[u][a]=0; end
                    else if ((a==0 && sv[3:2]==2'b11)||(a==1 && sv[1:0]==2'b11))begin
                        arm_state[u][a]=0;arm_st[u][a]=1;
                    end else if(arm_st[u][a])begin
                        arm_state[u][a]=request_value?2:1;arm_target[u][a]=request_value;arm_st[u][a]=0;
                    end else if(arm_target[u][a]!=request_value)begin
                        arm_state[u][a]=0;arm_target[u][a]=request_value;deadline[u][a]=tick+100;
                    end else if(arm_state[u][a]==0 && tick>=deadline[u][a])arm_state[u][a]=request_value?2:1;
                    if(a==0)normal[3:2]=arm_state[u][a][1:0];else normal[1:0]=arm_state[u][a][1:0];
                end
                v=model_run?((sv!=0)?sv:normal):4'b0000;
                expected[11-4*u -:4]=v;
                // 谷值采样之后才用新参考，故当前比较仍用上一周期保持值。
                if(p==0)begin
                    if(begun[u])begin
                        ck(unions[u]==4*(D/400),$sformatf("unit%0d period union",u+1));
                        ck(lefts[u]==2*(D/400) && rights[u]==2*(D/400),"per-arm duration");
                        ck(labels[u]==((D==0)?0:4),"four labelled windows");
                        $fdisplay(stats,"%0d,%0d,%0d,%0d,%0d,%0d,%0d",u+1,periods[u],ri[u],unions[u],lefts[u],rights[u],labels[u]);
                        periods[u]++;
                    end
                    unions[u]=0;lefts[u]=0;rights[u]=0;labels[u]=0;last_st[u]=0;
                    ri[u]=(tick/10000)%200;begun[u]=1;
                end
            end
        end
        #1;
        if(!rst_n || !en || fault || latched)ck(gates===0,"global safety zero");
        if(pre && run_active && check_enabled)begin
            ck(gates===expected,$sformatf("independent full-vector expected %h got %h",expected,gates));
            total=0;valid_sum=1;
            for(integer u=0;u<3;u++)begin
                v=gates[11-4*u -:4];p=(tick-delay_ticks[u]+10000)%10000;
                c=(tick+1-delay_ticks[u]+10000)%10000;
                c=(c<=5000)?c:10000-c;
                // 载波相位及参考核对只作被检查量，绝不回填期望模型。
                if(u==0)begin ck(dut.units[0].carrier==c,"u1 carrier");ck(dut.units[0].ref_index==ri[u],"u1 held index");end
                if(u==1)begin ck(dut.units[1].carrier==c,"u2 carrier");ck(dut.units[1].ref_index==ri[u],"u2 held index");end
                if(u==2)begin ck(dut.units[2].carrier==c,"u3 carrier");ck(dut.units[2].ref_index==ri[u],"u3 held index");end
                // carrier在采样沿后已推进一拍，下面的phase检查在下一段单独处理。
                if(v[3:2]==3 || v[1:0]==3)unions[u]++;
                if(v[3:2]==3)lefts[u]++;
                if(v[1:0]==3)rights[u]++;
                sv=event_vector(p,rom[ri[u]],D/400);
                if(sv!=0 && sv!=last_st[u])labels[u]++;
                last_st[u]=sv;
                ck(v!=15,"no four-switch ST");
                vt=voltage(v);if(vt==99)valid_sum=0;else total+=vt;
            end
            if(valid_sum)levels_seen[total+3]=1;
            if(D==200000 && (tick<40000 || (tick>=250000&&tick<280000) || (tick>=1250000&&tick<1280000)))
                $fdisplay(trace,"%0d,%0d,%03h,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",tick,run_active,gates,ri[0],ri[1],ri[2],voltage(gates[11:8]),voltage(gates[7:4]),voltage(gates[3:0]),valid_sum,total,
                    dut.units[0].carrier,dut.units[1].carrier,dut.units[2].carrier,dut.units[0].ref_l,dut.units[1].ref_l,dut.units[2].ref_l);
            tick++;
        end else if(!run_active)clear_model();
        if(run_active && !was_running)restarts++;
        was_running=run_active;
    end
    task automatic step(input integer n);repeat(n)begin @(posedge clk);#2;end endtask
    task automatic stop_clear;
        @(negedge clk);en=0;fault=0;clear=0;step(4);
        clear=1;step(3);clear=0;step(5);ck(!run_active&&!latched,"clear stays stopped");
    endtask
    task automatic start;
        @(negedge clk);en=1;step(4);ck(run_active,"start accepted");
    endtask
    initial begin
        $readmemh("spwm_duty.mem",rom);
        stats=$fopen("period_statistics.csv","w");$fdisplay(stats,"unit,period,reference_index,union_ticks,left_ticks,right_ticks,labelled_windows");
        trace=$fopen("key_trace.csv","w");$fdisplay(trace,"tick,run,gates_hex,index1,index2,index3,v1,v2,v3,sum_valid,sum,carrier1,carrier2,carrier3,ref1,ref2,ref3");
        inj=$fopen("interruption_cases.csv","w");$fdisplay(inj,"unit,window,position,action,tick,gates_before");
        for(integer u=0;u<3;u++)periods[u]=0;
        clear_model();step(5);rst_n=1;step(8);start();
        wait(tick>=4024000);stop_clear(); // 两个完整50Hz基波并留出移相尾部。
        if(D!=0)begin
            for(target_unit=0;target_unit<3;target_unit++)
            for(window_id=0;window_id<4;window_id++)
            for(where_id=0;where_id<4;where_id++)
            for(action_id=0;action_id<3;action_id++)begin
                start();
                case(window_id)
                    0:event_start=5000-5*rom[1]-D/400;
                    1:event_start=5*rom[1];
                    2:event_start=10001-5*rom[1]-D/400;
                    3:event_start=10001-(5000-5*rom[1]);
                endcase
                cut_tick=10000+delay_ticks[target_unit]+event_start+1+
                    ((where_id==0)?-1:(where_id==1)?0:(where_id==2)?D/800:D/400);
                wait(tick==cut_tick);@(negedge clk);
                $fdisplay(inj,"%0d,%0d,%0d,%0d,%0d,%03h",target_unit+1,window_id,where_id,action_id,tick,gates);
                if(where_id==1||where_id==2)ck(voltage(gates[11-4*target_unit -:4])==0 &&
                    (gates[11-4*target_unit -:2]==3 || gates[9-4*target_unit -:2]==3),"cut inside intended ST");
                if(action_id==0)en=0;else if(action_id==1)fault=1;else rst_n=0;
                #1;ck(gates===0,"asynchronous safety mask all12");step(3);
                if(action_id==1)ck(latched&&sources[3],"external fault recorded");
                en=0;fault=0;rst_n=1;step(8);stop_clear();cutcases++;
            end
            // 每个单元内部错误都能触发全局停机并保留来源。仅验证联动，不声称可检测任意SEU。
            for(target_unit=0;target_unit<3;target_unit++)begin
                start();wait(tick>4000);@(negedge clk);check_enabled=0;
                case(target_unit)
                    0:force dut.units[0].u_unit.ref_l=10'd999;
                    1:force dut.units[1].u_unit.ref_l=10'd999;
                    2:force dut.units[2].u_unit.ref_l=10'd999;
                endcase
                #1;ck(gates===0,"unit error kills all12 before edge");step(3);
                ck(latched&&sources[target_unit],"unit source latched");
                case(target_unit)
                    0:release dut.units[0].u_unit.ref_l;
                    1:release dut.units[1].u_unit.ref_l;
                    2:release dut.units[2].u_unit.ref_l;
                endcase
                en=0;step(8);stop_clear();check_enabled=1;errorcases++;
            end
        end
        // 27种完整普通状态组合验证七电平能力，与当前M下实际出现电平分开统计。
        begin bit [6:0] ability;ability=0;
            for(integer a=-1;a<=1;a++)for(integer b=-1;b<=1;b++)for(integer c=-1;c<=1;c++)ability[a+b+c+3]=1;
            ck(ability==7'b1111111,"ideal equal-bus seven level capability");
        end
        $fclose(stats);$fclose(trace);$fclose(inj);
        result=$fopen("result.txt","w");
        $fdisplay(result,"RESULT=%s\nD_PPM=%0d\nCHECKS=%0d\nERRORS=%0d\nPERIODS=%0d,%0d,%0d\nSTARTS=%0d\nCUT_CASES=%0d\nUNIT_ERROR_CASES=%0d\nACTUAL_VALID_LEVEL_MASK=%07b",errors?"FAIL":"PASS",D,checks,errors,periods[0],periods[1],periods[2],restarts,cutcases,errorcases,levels_seen);
        $fclose(result);if(errors)$fatal(1,"cascade failures %0d",errors);$finish;
    end
    initial begin #120000000;$fatal(1,"TIMEOUT");end
endmodule
module cascade_main_tb; cascade_test #(.D(200000)) test(); endmodule
module cascade_d0_tb; cascade_test #(.D(0)) test(); endmodule

module cascade_buttons_tb;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,start_key=0,fault_key=0,clear_key=0;
    wire [11:0] gates;wire run_active,latched,ready,startup;wire [3:0] sources;
    cascade_logic #(.DEBOUNCE_CYCLES(8),.FAULT_RELEASE_CYCLES(8)) dut(
        .clk_100m(clk),.reset_async_n(rst),.btn_start(start_key),.btn_fault(fault_key),.btn_clear(clear_key),
        .gates(gates),.led_run(run_active),.led_fault(latched),.led_ready(ready),.led_startup(startup),.fault_sources(sources));
    integer checks=0,errors=0,f;
    task automatic ck(input bit ok,input string msg);checks++;if(!ok)begin errors++;$display("FAIL %s",msg);end endtask
    task automatic step(input integer n);repeat(n)begin @(posedge clk);#2;end endtask
    task automatic keys(input bit a,b,c);@(negedge clk);start_key=a;fault_key=b;clear_key=c;endtask
    initial begin
        step(4);rst=1;step(40);ck(!run_active&&gates===0,"reset stopped");
        repeat(4)begin keys(1,0,0);step(2);keys(0,0,0);step(2);end
        ck(!run_active,"bounce ignored");keys(1,0,0);step(30);ck(run_active,"press starts");
        step(15000);ck(run_active&&!startup,"hold once and all units start");
        keys(0,0,0);step(30);keys(1,0,0);step(30);ck(!run_active&&gates===0,"second press stops");
        rst=0;step(4);rst=1;step(40);ck(!run_active,"held across reset cannot start");
        keys(0,0,0);step(30);keys(1,0,0);step(30);ck(run_active,"fresh press starts");
        keys(0,1,1);step(30);ck(latched&&!run_active&&gates===0,"fault beats clear");
        keys(0,0,0);step(40);ck(latched&&!run_active,"fault release does not restart");
        keys(1,0,1);step(30);ck(!latched&&!run_active,"clear plus start keeps stopped");
        step(30);ck(!run_active,"held start after clear ignored");keys(0,0,0);step(30);
        keys(1,0,1);step(30);ck(!run_active,"clear plus start without latch keeps stopped");
        keys(0,0,0);step(30);keys(1,0,0);step(30);ck(run_active,"new press after clear");
        keys(0,0,0);step(30);keys(1,1,0);step(30);ck(latched&&!run_active&&gates===0,"fault plus start wins");
        for(integer u=0;u<3;u++)begin
            keys(0,0,0);step(40);keys(0,0,1);step(30);keys(0,0,0);step(30);
            keys(1,0,0);step(5000);
            case(u)
                0:force dut.u_core.units[0].u_unit.ref_l=10'd999;
                1:force dut.u_core.units[1].u_unit.ref_l=10'd999;
                2:force dut.u_core.units[2].u_unit.ref_l=10'd999;
            endcase
            step(5);ck(latched&&!run_active&&gates===0&&!dut.enable_req,"unit fault cancels start request");
            ck({startup,ready}==u+1,"unit fault LED code");
            case(u)
                0:release dut.u_core.units[0].u_unit.ref_l;
                1:release dut.u_core.units[1].u_unit.ref_l;
                2:release dut.u_core.units[2].u_unit.ref_l;
            endcase
            step(10);
        end
        f=$fopen("result.txt","w");$fdisplay(f,"RESULT=%s\nCHECKS=%0d\nERRORS=%0d\nDEBOUNCE_SIM_TICKS=8\nBOARD_TICKS=2000000",errors?"FAIL":"PASS",checks,errors);$fclose(f);
        if(errors)$fatal(1,"buttons failures");$finish;
    end
endmodule

module cascade_parameters_tb;
    reg clk=0;always #5 clk=~clk;
    reg rst=0;wire [11:0] gates[0:5];wire [5:0] run_active,latched;
    localparam integer DS[0:5]='{-1,1,7999,300001,200000,200000};
    genvar g;
    generate for(g=0;g<6;g++)begin: cases
        cascade_core #(.ST_D_PPM(DS[g]),.REF_MIN(g==4?100:200),.REF_MAX(g==4?900:800),.DEAD_CYCLES(g==5?0:100)) dut(
            .clk(clk),.rst_n(rst),.enable_req(1'b1),.fault_sync(1'b0),.clear_fault(1'b0),
            .gates(gates[g]),.run_active(run_active[g]),.fault_latched(latched[g]),.fault_sources(),.all_started(),.all_ready());
    end endgenerate
    integer errors=0,checks=0,f;
    initial begin
        repeat(5)@(negedge clk);rst=1;repeat(30)@(negedge clk);
        for(integer u=0;u<6;u++)begin checks++;if(gates[u]!==0||run_active[u]||!latched[u])errors++;end
        f=$fopen("result.txt","w");$fdisplay(f,"RESULT=%s\nCHECKS=%0d\nERRORS=%0d\nINVALID_CASES=6",errors?"FAIL":"PASS",checks,errors);$fclose(f);
        if(errors)$fatal(1,"parameter failures");$finish;
    end
endmodule

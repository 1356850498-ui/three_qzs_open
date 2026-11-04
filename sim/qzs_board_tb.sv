`timescale 1ns/1ps
module qzs_board_tb;
    reg clk=0; always #5 clk=~clk;
    reg reset_n=0, btn_start=0, btn_fault=0, btn_clear=0;
    wire s1,s2,s3,s4,run_active,fault_latched;
    localparam integer DB=8, FR=8;
    single_qzs_logic #(.ST_D_PPM(200000),.DEBOUNCE_CYCLES(DB),.FAULT_RELEASE_CYCLES(FR)) dut(
        clk,reset_n,btn_start,btn_fault,btn_clear,s1,s2,s3,s4,run_active,fault_latched);
    wire [3:0] gates={s1,s2,s3,s4};
    integer errors=0, checks=0, starts=0, events=0, clears=0, n, f;
    integer simultaneous_fault_start=0, simultaneous_clear_start=0;
    integer left_checks,left_errors,left_open,left_rev,left_gap;
    integer right_checks,right_errors,right_open,right_rev,right_gap;
    reg previous_run=0;
    reg [3:0] seen=0;
    gate_deadline_checker #(.ID(11)) check_left(clk,dut.rst_n,dut.u_core.run_permit,
        dut.u_core.req_l,dut.u_core.gate_l_hi,dut.u_core.gate_l_lo,
        left_checks,left_errors,left_open,left_rev,left_gap);
    gate_deadline_checker #(.ID(12)) check_right(clk,dut.rst_n,dut.u_core.run_permit,
        dut.u_core.req_r,dut.u_core.gate_r_hi,dut.u_core.gate_r_lo,
        right_checks,right_errors,right_open,right_rev,right_gap);
    task automatic ck(input bit ok,input string label_name);
        checks++;
        if(!ok) begin errors++; $display("FAIL t=%0t %s gates=%b run=%b fault=%b en=%b",$time,label_name,gates,run_active,fault_latched,dut.enable_req); end
    endtask
    task automatic step(input integer cycles);
        repeat(cycles) begin @(posedge clk); #2; end
    endtask
    task automatic drive(input bit a,input bit b,input bit c);
        @(negedge clk); #1; btn_start=a;btn_fault=b;btn_clear=c;
    endtask
    task automatic idle_keys;
        drive(0,0,0);step(DB+FR+12);
    endtask
    task automatic start_press;
        drive(1,0,0);step(DB+10);
    endtask
    task automatic clear_press;
        drive(0,0,1);step(DB+10);
    endtask
    task automatic stopped(input string label_name);
        ck(!run_active && gates===0 && !dut.enable_req,label_name);
    endtask
    always @(posedge clk) begin
        #1;
        if(dut.rst_n) begin
            ck((!(s1&&s2) && !(s3&&s4)) || dut.u_core.st_left || dut.u_core.st_right,"controlled overlap only");
            ck(gates === {dut.u_core.pwm_s1,dut.u_core.pwm_s2,dut.u_core.pwm_s3,dut.u_core.pwm_s4},"four-channel mapping");
            ck(run_active || gates===0,"gates off without permission");
            if(run_active && !previous_run) begin
                starts++;
                ck(dut.u_core.sample_index==0 && dut.u_core.carrier==0 && dut.u_core.ref_l==500 && dut.u_core.ref_r==500,"restart from reference zero");
            end
            if(dut.u_controls.start_event) events++;
            if(dut.u_controls.start_event && dut.u_controls.fault_sync) simultaneous_fault_start++;
            if(dut.u_controls.start_event && dut.u_controls.clear_event) simultaneous_clear_start++;
            if(dut.clear_fault) clears++;
            seen=seen | gates;
        end
        previous_run=run_active;
    end
    initial begin
        $display("BOARD TEST DB=%0d cycles FR=%0d cycles clock=100MHz deadtime=100 cycles",DB,FR);
        #1;step(4); reset_n=1; step(2);
        ck(dut.rst_n,"two-clock reset release");
        step(30);stopped("power-up default stopped");ck(!fault_latched,"no fabricated startup fault");
        start_press();ck(run_active,"first press starts");
        step(12000);ck(run_active && dut.enable_req,"long hold only one toggle");ck(events==1,"one start event on long hold");
        idle_keys();start_press();stopped("second press stops");
        idle_keys();
        repeat(4) begin drive(1,0,0);step(2);drive(0,0,0);step(2);end
        stopped("press bounce does not start");
        start_press();ck(run_active,"stable press after bounce starts once");
        repeat(4) begin drive(0,0,0);step(2);drive(1,0,0);step(2);end
        ck(run_active,"release bounce does not rearm");step(30);ck(run_active,"held after bounce no retrigger");
        // Assert reset between clock edges while the START button is held.
        @(negedge clk);#2;reset_n=0;#1;ck(!dut.rst_n && gates===0,"asynchronous reset asserts and gates close");
        step(4);reset_n=1;step(40);stopped("reset release with START held cannot start");
        idle_keys();start_press();ck(run_active,"new release and press after reset starts");
        idle_keys();step(11000);
        // Fault assertion latency must not depend on the long release/debounce filter.
        drive(0,1,0);n=0;
        while(!fault_latched && n<6) begin step(1);n++;end
        ck(fault_latched && n<=3,"fault latches within three sampled clock edges");
        stopped("fault cancels run request and closes gates");
        drive(1,1,0);step(DB+12);stopped("start during active fault ignored");
        drive(0,1,1);step(DB+12);ck(fault_latched && !dut.clear_fault,"clear while source present rejected");
        // Keep CLEAR held while fault source goes away: event must be consumed.
        drive(0,0,1);step(FR+DB+20);ck(fault_latched,"holding clear through source release cannot clear");
        stopped("fault source removed stays stopped");
        step(12000);ck(fault_latched,"released source remains latched");
        idle_keys();clear_press();ck(!fault_latched,"fresh legal clear releases latch");stopped("clear keeps stopped");
        n=clears;step(50);ck(clears==n,"long clear only one pulse");
        idle_keys();step(100);stopped("old run request cannot auto resume");
        start_press();ck(run_active,"explicit new press after clear starts");
        idle_keys();start_press();stopped("stop before simultaneous clear/start");idle_keys();
        drive(1,0,1);step(DB+12);stopped("simultaneous clear/start: clear wins");
        idle_keys();
        // Align filtered START event acceptance with first synchronized fault.
        drive(1,0,0);step(DB);drive(1,1,0);step(8);
        ck(fault_latched,"fault coincident with start event latches");stopped("fault wins simultaneous start");
        idle_keys();ck(fault_latched,"fault remains latched after release");
        drive(1,0,1);step(DB+12);ck(!fault_latched,"simultaneous clear and start clears latch");stopped("same-cycle clear cannot start");
        idle_keys();start_press();ck(run_active,"restart after simultaneous case");step(22000);
        // Fault release bounce extends hold; a one-cycle high reasserts promptly.
        drive(1,1,0);step(5);stopped("repeated fault while START held");
        drive(1,0,0);step(3);drive(1,1,0);step(3);drive(1,0,0);step(3);
        ck(dut.fault_sync,"unstable fault release stays asserted");step(FR+10);
        ck(!dut.fault_sync && fault_latched,"stable fault release only removes source");
        // Reset with CLEAR held must not create a pulse, nor auto start.
        drive(1,0,1);@(negedge clk);reset_n=0;step(5);reset_n=1;step(50);
        stopped("reset recovery with keys held");ck(!dut.clear_fault,"clear held across reset gives no pulse");
        idle_keys();start_press();ck(run_active,"final explicit restart");step(22000);
        ck(seen==4'b1111,"all four PWM outputs exercised");
        ck(left_errors==0 && right_errors==0,"inherited deadtime deadline checkers pass");
        ck(starts>=6,"multiple reference-zero restarts observed");
        ck(simultaneous_fault_start>=1 && simultaneous_clear_start>=2,"coincident priority inputs actually covered");
        f=$fopen("result_board.txt","w");
        $fdisplay(f,"CHECKS=%0d ERRORS=%0d STARTS=%0d START_EVENTS=%0d CLEAR_PULSES=%0d",checks,errors,starts,events,clears);
        $fdisplay(f,"LEFT_DEADTIME_CHECKS=%0d ERRORS=%0d RIGHT_DEADTIME_CHECKS=%0d ERRORS=%0d",left_checks,left_errors,right_checks,right_errors);
        $fdisplay(f,"SIMULTANEOUS_FAULT_START=%0d SIMULTANEOUS_CLEAR_START=%0d",simultaneous_fault_start,simultaneous_clear_start);
        if(errors==0) begin $fdisplay(f,"RESULT=PASS");$display("BOARD RESULT=PASS checks=%0d",checks);end
        else begin $fdisplay(f,"RESULT=FAIL");$display("BOARD RESULT=FAIL errors=%0d",errors);end
        $fclose(f);$finish;
    end
    initial begin #5_000_000; $fatal(1,"BOARD TIMEOUT");end
endmodule

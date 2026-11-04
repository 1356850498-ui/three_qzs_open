`timescale 1ns/1ps
// Actual pre-change and optimized RTL, compared after every sampled edge.
// Cover all 1024 references x all 16384 carrier values for both channels.
module compare_equivalence_tb;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, seq_run=0, valid=0;
    reg [7:0] index=0;
    reg [13:0] carrier=0;
    reg [9:0] ref_l=0, ref_r=0;
    wire new_l,new_r,new_ready,old_l,old_r,old_ready;
    spwm_compare_pair dut(clk,rst_n,seq_run,index,carrier,ref_l,ref_r,valid,
                          new_l,new_r,new_ready);
    spwm_compare_pair_before golden(clk,rst_n,seq_run,index,carrier,ref_l,ref_r,valid,
                                    old_l,old_r,old_ready);
    integer checks=0, errors=0, a,b,c,d,f;
    integer sweep_vectors=0, control_vectors=0, reset_checks=0;
    task automatic compare_outputs;
        checks++;
        if ({new_l,new_r,new_ready} !== {old_l,old_r,old_ready}) begin
            errors++;
            if(errors<10) $display("FAIL EQUIV t=%0t ref=%h/%h carrier=%h valid=%b run=%b index=%h new=%b%b%b old=%b%b%b",
                $time,ref_l,ref_r,carrier,valid,seq_run,index,new_l,new_r,new_ready,old_l,old_r,old_ready);
        end
    endtask
    task automatic step;
        @(posedge clk);#1;compare_outputs();
    endtask
    initial begin
        #1;compare_outputs();
        repeat(3) step();
        @(negedge clk);rst_n=1;
        for(a=0;a<1024;a++) begin
            for(b=0;b<16384;b++) begin
                @(negedge clk);
                ref_l=a;ref_r=1023-a;carrier=b;valid=1;
                seq_run=b[0];index=b[7:0];
                step();sweep_vectors++;
            end
        end
        for(a=0;a<2;a++) for(b=0;b<2;b++)
            for(c=0;c<256;c++) for(d=0;d<3;d++) begin
                @(negedge clk);valid=a;seq_run=b;index=c;
                carrier=(d==0)?0:((d==1)?1:16383);
                ref_l=1023;ref_r=0;step();control_vectors++;
            end
        // Also retain four-state simulation semantics and asynchronous reset.
        @(negedge clk);valid=1'bx;carrier=0;ref_l=500;ref_r=500;step();
        @(negedge clk);valid=1;ref_l=10'bx;ref_r=10'bz;step();
        @(negedge clk);ref_l=500;ref_r=500;carrier=14'bx;step();
        @(negedge clk);valid=0;step();
        @(negedge clk);valid=1;carrier=0;seq_run=0;index=0;step();
        @(negedge clk);#2;rst_n=0;#1;compare_outputs();reset_checks++;
        if({new_l,new_r,new_ready}!==3'b000) begin errors++;$display("FAIL async reset outputs");end
        step();@(negedge clk);rst_n=1;step();reset_checks++;
        if(sweep_vectors!=16777216 || control_vectors!=3072) begin errors++;$display("FAIL coverage count");end
        f=$fopen("result_equivalence.txt","w");
        $fdisplay(f,"CHECKS=%0d ERRORS=%0d SWEEP_VECTORS=%0d CONTROL_VECTORS=%0d RESET_CHECKS=%0d",checks,errors,sweep_vectors,control_vectors,reset_checks);
        if(errors==0) begin $fdisplay(f,"RESULT=PASS");$display("EQUIVALENCE RESULT=PASS checks=%0d",checks);end
        else begin $fdisplay(f,"RESULT=FAIL");$display("EQUIVALENCE RESULT=FAIL errors=%0d",errors);end
        $fclose(f);$finish;
    end
    initial begin #200_000_000;$fatal(1,"EQUIVALENCE TIMEOUT");end
endmodule

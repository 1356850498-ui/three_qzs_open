`timescale 1ns/1ps
// Independent time-of-request model: no DUT state or counter is read.
module gate_deadline_checker #(parameter integer DEAD=100, ID=0)(
 input clk, rst_n, permit, req, hi, lo,
 output integer checks=0, errors=0, openings=0, reversals=0,
 output integer min_gap=2147483647);
 integer cycle=0, eligible=0, last_off=0, gap;
 reg prev_permit=0, prev_req=0, old_hi=0, old_lo=0;
 reg want_hi, want_lo, sampled_permit, sampled_req;
 always @(posedge clk) begin
   cycle=cycle+1;
   sampled_permit=permit; sampled_req=req;
   if (!rst_n) begin
     prev_permit=0; prev_req=0; eligible=cycle+DEAD;
     want_hi=0; want_lo=0;
   end else if (!sampled_permit) begin
     want_hi=0; want_lo=0; prev_permit=0; eligible=cycle+DEAD;
   end else begin
     if (!prev_permit || sampled_req != prev_req) begin
       eligible=cycle+DEAD;
       if (prev_permit) reversals=reversals+1;
     end
     want_hi=(cycle>=eligible) && sampled_req;
     want_lo=(cycle>=eligible) && !sampled_req;
     prev_permit=1; prev_req=sampled_req;
   end
   #1;
   checks=checks+1;
   if ({hi,lo} !== {want_hi,want_lo}) begin
     errors=errors+1;
     if(errors<=12) $display("FAIL DEAD id=%0d t=%0t cycle=%0d permit=%b req=%b eligible=%0d expected=%b%b actual=%b%b",ID,$time,cycle,sampled_permit,sampled_req,eligible,want_hi,want_lo,hi,lo);
   end
   if ((old_hi||old_lo) && !(hi||lo)) last_off=cycle;
   if (!(old_hi||old_lo) && (hi||lo)) begin
     openings=openings+1;
     gap=cycle-last_off;
     if(last_off>0 && gap<min_gap) min_gap=gap;
   end
   old_hi=hi; old_lo=lo;
 end
endmodule

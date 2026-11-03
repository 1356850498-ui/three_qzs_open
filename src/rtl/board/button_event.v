`timescale 1ns/1ps
// A new event requires a stable release followed by a stable press.
// Reset starts in the pressed, unarmed state, so a held key cannot start.
module button_event #(parameter integer STABLE_CYCLES=2_000_000)
(
    input   wire    clk     , 
    input   wire    rst_n   , 
    input   wire    button_sync,
    output  reg     press_event
);
    localparam integer CW=(STABLE_CYCLES<2)?1:$clog2(STABLE_CYCLES);
    localparam [CW-1:0] LAST=STABLE_CYCLES-1;
    
    reg [CW-1:0]    count       ;
    reg             armed       ;
    reg             stable_level;
    
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            count<=0; stable_level<=1; armed<=0; press_event<=0;
        end 
        else 
        begin
            press_event<=0;
            if (button_sync==stable_level) 
                count<=0;
            else if (count==LAST) 
            begin
                count<=0;
                stable_level<=button_sync;
                if (!button_sync) 
                    armed<=1;
                else 
                begin 
                    press_event<=armed; armed<=0; 
                end
            end 
            else 
                count<=count+1'b1;
        end
    end
endmodule

`timescale 1ns/1ps

// Registered comparison for the fixed 100 MHz / 10 kHz carrier (peak 5000).
// 5000 * ref / 1000 is exactly 5 * ref for every unsigned 10-bit ref.
// Explicitly widened shifts and additions preserve the comparison width.
// No extra pipeline stage: request and ready timing match the verified core.
module spwm_compare_pair (
    input  wire        clk_sys,
    input  wire        rst_n,
    input  wire        seq_run,
    input  wire [7:0]  sample_index,
    input  wire [13:0] carrier,
    input  wire [9:0]  ref_l,
    input  wire [9:0]  ref_r,
    input  wire        ref_valid,
    output wire        req_l,
    output wire        req_r,
    output wire        req_ready
);
    // Largest threshold: 5 * 1023 = 5115, which fits in 13 bits.
    // Widen before shifting; shifting a 10-bit expression would truncate it.
    wire [12:0] threshold_l = {1'b0, ref_l, 2'b00} + {3'b000, ref_l};
    wire [12:0] threshold_r = {1'b0, ref_r, 2'b00} + {3'b000, ref_r};

    reg req_l_reg, req_r_reg, req_ready_reg;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            req_l_reg     <= 1'b0;
            req_r_reg     <= 1'b0;
            req_ready_reg <= 1'b0;
        end else begin
            // Keep procedural if semantics for invalid/unknown inputs too.
            if (ref_valid && (carrier < {1'b0, threshold_l}))
                req_l_reg <= 1'b1;
            else
                req_l_reg <= 1'b0;

            if (ref_valid && (carrier < {1'b0, threshold_r}))
                req_r_reg <= 1'b1;
            else
                req_r_reg <= 1'b0;

            req_ready_reg <= !seq_run && ref_valid &&
                             (sample_index == 8'd0) && (carrier == 14'd0);
        end
    end

    assign req_l     = req_l_reg;
    assign req_r     = req_r_reg;
    assign req_ready = req_ready_reg;
endmodule

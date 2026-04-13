`timescale 1ns / 1ps

module fixed_resize #(
    parameter integer WI_IN   = 4, WF_IN   = 4,
                      WI_OUT  = 4, WF_OUT  = 4,
                      W_IN    = WI_IN  + WF_IN,
                      W_OUT   = WI_OUT + WF_OUT
)(
    input  signed [W_IN-1:0]  in,
    output signed [W_OUT-1:0] out
);
    localparam integer FRAC_SHIFT = WF_IN - WF_OUT;

    wire signed [W_IN-1:0] shifted;

    generate
        if (FRAC_SHIFT > 0) begin : GEN_SHIFT_RIGHT
            // too many frac bits → shift right
            assign shifted = in >>> FRAC_SHIFT;
        end else if (FRAC_SHIFT < 0) begin : GEN_SHIFT_LEFT
            // too few frac bits → shift left
            assign shifted = in <<< (-FRAC_SHIFT);
        end else begin : GEN_NO_SHIFT
            assign shifted = in;
        end
    endgenerate

    // Take the LOW bits; sign bit is shifted[W_OUT-1] → correct sign if it fits
    assign out = shifted[W_OUT-1:0];

endmodule

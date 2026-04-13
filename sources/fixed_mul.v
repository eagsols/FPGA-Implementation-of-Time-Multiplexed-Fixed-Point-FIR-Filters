`timescale 1ns / 1ps

module fixed_mul #(
    parameter integer WI1 = 4, WF1 = 4,
                      WI2 = 4, WF2 = 4,
                      // desired output format:
                      WIO = WI1 + WI2,
                      WFO = WF1 + WF2,
                      TW  = WIO + WFO
)(
    input  signed [WI1+WF1-1:0] in1,
    input  signed [WI2+WF2-1:0] in2,
    output signed [TW-1:0]      out
);
    // Full product width and frac bits from raw operands
    localparam integer W1        = WI1 + WF1;
    localparam integer W2        = WI2 + WF2;
    localparam integer FULL_W    = W1 + W2;
    localparam integer FULL_FRAC = WF1 + WF2;

    wire signed [FULL_W-1:0] prod_full = in1 * in2;

    // Adjust fractional bits from FULL_FRAC -> WFO
    localparam integer SHIFT = FULL_FRAC - WFO;
    wire signed [FULL_W-1:0] prod_scaled;

    generate
        if (SHIFT > 0) begin : GEN_SHIFT_RIGHT
            // more frac bits than needed → arithmetic right shift
            assign prod_scaled = prod_full >>> SHIFT;
        end else if (SHIFT < 0) begin : GEN_SHIFT_LEFT
            // fewer frac bits than needed → left shift
            assign prod_scaled = prod_full <<< (-SHIFT);
        end else begin : GEN_NO_SHIFT
            assign prod_scaled = prod_full;
        end
    endgenerate

    // Now prod_scaled is Q(?, WFO). Clip to TW bits (keep sign).
    localparam integer MSB = FULL_W-1;
    localparam integer LSB = (FULL_W > TW) ? (FULL_W - TW) : 0;

    assign out = prod_scaled[MSB:LSB];

endmodule

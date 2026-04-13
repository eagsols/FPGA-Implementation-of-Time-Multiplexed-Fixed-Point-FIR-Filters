`timescale 1ns / 1ps

module fixed_adder#(
    parameter integer WI1 = 4, WF1 = 4,
                      WI2 = 4, WF2 = 4,
                      WIO = (WI1 > WI2) ? WI1 : WI2 ,
                      WFO = (WF1 > WF2) ? WF1 : WF2,
                      TW  = WIO + WFO
)(
    input  signed [WI1+WF1-1:0] in1,
    input  signed [WI2+WF2-1:0] in2,
    output signed [TW-1:0] out
);

    wire signed [TW-1:0] in1_aligned =
        { {(WIO-WI1){in1[WI1+WF1-1]}}, in1, {(WFO-WF1){1'b0}} };
    wire signed [TW-1:0] in2_aligned = 
        { {(WIO-WI2){in2[WI2+WF2-1]}}, in2, {(WFO-WF2){1'b0}} };
           
    assign out = in1_aligned + in2_aligned;
  
endmodule


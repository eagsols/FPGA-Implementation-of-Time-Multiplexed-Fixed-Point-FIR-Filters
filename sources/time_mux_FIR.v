`timescale 1ns / 1ps

module time_mux_FIR #(parameter 
                    N_TAPS = 64, 
                    M_MACS = 4,
                    IN_WI  = 2,  IN_WF  = 10,
                    IN_WL  = IN_WI + IN_WF,
                    OUT_WI = 2,  OUT_WF  = 10,
                    OUT_WL  = OUT_WI + OUT_WF,
                    COEF_WI= 1,  COEF_WF= 15,
                    ACC_WI = 2,  ACC_WF = 30,

                    DATA_W = IN_WI  + IN_WF,
                    COEF_W = COEF_WI+ COEF_WF,
                    ACC_W  = ACC_WI + ACC_WF,
                    SRL_REG     = 0        // 0: regs, 1: SRL style
)(
    input  clk,
    input  rst,

    input  signed [DATA_W-1:0] sample_in,
    input  sample_valid,
    output reg sample_ready,
    
    output reg signed [OUT_WL-1:0]  y_out,
    output reg y_valid
);

    // --------------------------------------------------------------------
    // Delay line with SRL_REG switch
    // --------------------------------------------------------------------
    generate
    if (SRL_REG == 0) begin : DELAY
        // FF-based delay line WITH reset
        (* shreg_extract = "no" *)
        reg signed [DATA_W-1:0] delay_line [0:N_TAPS-1];
        integer j;
    
        always @(posedge clk) begin
            if (rst) begin
                for (j = 0; j < N_TAPS; j = j + 1)
                    delay_line[j] <= 0;
            end else if (sample_valid && sample_ready) begin
                for (j = N_TAPS-1; j > 0; j = j - 1)
                    delay_line[j] <= delay_line[j-1];
                delay_line[0] <= sample_in;
            end
        end
    
    end else begin : DELAY
        // SRL-style delay line: NO reset, but initialized once
        (* shreg_extract = "yes" *)
        reg signed [DATA_W-1:0] delay_line [0:N_TAPS-1];
        integer j;
    
        // Initialize to 0 so sim doesn't start with Xs
        initial begin
            for (j = 0; j < N_TAPS; j = j + 1)
                delay_line[j] = 0;
        end
    
        always @(posedge clk) begin
            if (sample_valid && sample_ready) begin
                for (j = N_TAPS-1; j > 0; j = j - 1)
                    delay_line[j] <= delay_line[j-1];
                delay_line[0] <= sample_in;
            end
        end
    
    end
    endgenerate

    
    // ----------------------------------------------------------------
    // 2. Coefficient memory
    // ----------------------------------------------------------------
    reg signed [COEF_W-1:0] coef_mem [0:N_TAPS-1];

    initial begin
        $readmemh("coeffs.hex", coef_mem);
    end

    // ----------------------------------------------------------------
    // 3. Control and accumulator (using fixed_mul / fixed_adder)
    // ----------------------------------------------------------------
    // Q formats:
    localparam integer CYCLES_PER_OUT = (N_TAPS + M_MACS - 1) / M_MACS;

    reg [$clog2(N_TAPS):0]        tap_index;
    reg [$clog2(CYCLES_PER_OUT):0] cycle_cnt;
    reg                           processing;

    // accumulator in Q2.30
    reg  signed [ACC_W-1:0] acc;
    
    // needed for the first cycle
    reg warmup;

    // tap values per MAC (Q2.10 / Q1.15)
    reg  signed [DATA_W-1:0] x_tap   [0:M_MACS-1];
    reg  signed [COEF_W-1:0] h_tap   [0:M_MACS-1];

    // products per MAC in Q2.30
    wire signed [ACC_W-1:0] prod_q2_30 [0:M_MACS-1];

    // adder chain to sum all products (and include acc)
    wire signed [ACC_W-1:0] sum_chain  [0:M_MACS];
    wire signed [ACC_W-1:0] acc_next;

    integer i;
    genvar  gi;

    // Select taps for each MAC (or zero if beyond N_TAPS)
    always @(*) begin
        for (i = 0; i < M_MACS; i = i + 1) begin
            if (tap_index + i < N_TAPS) begin
                x_tap[i] = DELAY.delay_line[tap_index + i];  // NOTE: DELAY.delay_line
                h_tap[i] = coef_mem[tap_index + i];
            end else begin
                x_tap[i] = 0;
                h_tap[i] = 0;
            end
        end
    end


    // Instantiate one fixed_mul per MAC: Q2.10 * Q1.15 -> Q2.30 (32 bits)
    generate
        for (gi = 0; gi < M_MACS; gi = gi + 1) begin : GEN_MAC_MUL
            fixed_mul #(
                .WI1(IN_WI),   .WF1(IN_WF),   // input  (Q2.10)
                .WI2(COEF_WI), .WF2(COEF_WF), // coeff  (Q1.15)
                .WIO(ACC_WI),  .WFO(ACC_WF),  // output (Q2.30)
                .TW (ACC_W)
            ) u_mul (
                .in1(x_tap[gi]),
                .in2(h_tap[gi]),
                .out(prod_q2_30[gi])          // Q2.30
            );
        end
    endgenerate

    // Start adder chain from current acc (so acc_next = acc + sum(products))
    assign sum_chain[0] = acc;

    // Sum all MAC products into acc_next using fixed_adder chain, all Q2.30
    generate
        for (gi = 0; gi < M_MACS; gi = gi + 1) begin : GEN_MAC_ADD
            fixed_adder #(
                .WI1(ACC_WI), .WF1(ACC_WF),
                .WI2(ACC_WI), .WF2(ACC_WF),
                .WIO(ACC_WI), .WFO(ACC_WF),
                .TW (ACC_W)
            ) u_add (
                .in1(sum_chain[gi]),
                .in2(prod_q2_30[gi]),
                .out(sum_chain[gi+1])
            );
        end
    endgenerate

    assign acc_next = sum_chain[M_MACS];  // Q2.30 sum for this cycle
    wire signed [OUT_WL-1:0] y_out_q2_10;
        
        fixed_resize #(
            .WI_IN (ACC_WI), .WF_IN (ACC_WF),    // 2.30
            .WI_OUT(OUT_WI), .WF_OUT(OUT_WF)     // 2.10
        ) u_out_resize (
            .in (acc_next),
            .out(y_out_q2_10)
        );


    // The rest of your sequential control logic (uses acc_next instead of
    // "acc + sum_products" and removes the old combinational "+"):

    always @(posedge clk) begin
        if (rst) begin
            tap_index    <= 0;
            cycle_cnt    <= 0;
            processing   <= 0;
            warmup       <= 0;
            acc          <= 0;
            y_out        <= 0;
            y_valid      <= 0;
            sample_ready <= 1;
        end else begin
            // default: no valid output this cycle
            y_valid <= 0;
    
            if (!processing) begin
                // idle: wait for new sample
                if (sample_valid && sample_ready) begin
                    processing   <= 1;
                    warmup       <= 1;    // one-cycle warmup
                    acc          <= 0;
                    tap_index    <= 0;
                    cycle_cnt    <= 0;
                    sample_ready <= 0;
                end
            end else begin
                // processing == 1
                if (warmup) begin
                    // give x_tap/h_tap/prod_q2_30 one cycle to settle
                    warmup <= 0;
                    // keep acc, tap_index, cycle_cnt unchanged
                end else begin
                    // normal accumulation
                    acc       <= acc_next;
                    tap_index <= tap_index + M_MACS;
                    cycle_cnt <= cycle_cnt + 1;
    
                    if (cycle_cnt == CYCLES_PER_OUT-1) begin
                        // acc_next now holds full sum
                        y_out        <= y_out_q2_10;  // resized Q2.10 result
                        y_valid      <= 1;
                        processing   <= 0;
                        sample_ready <= 1;
                    end
                end
            end
        end
    end

endmodule


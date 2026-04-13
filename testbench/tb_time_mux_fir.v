module tb_fir_time_mux;
parameter 
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
                    ACC_W  = ACC_WI + ACC_WF;

    reg clk, rst;

    reg  signed [DATA_W-1:0] sample_in;
    reg  sample_valid;
    wire sample_ready0, sample_ready1;

    wire signed [OUT_WL-1:0] y_out0, y_out1;
    wire y_valid0, y_valid1;

    integer fin, fout0, fout1;
    integer scan;
    integer cycle;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT0: SRL_REG = 0
    time_mux_FIR dut0 (
        .clk(clk),
        .rst(rst),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .sample_ready(sample_ready0), 
        .y_out(y_out0),
        .y_valid(y_valid0)
    );

    // DUT1: SRL_REG = 1
    time_mux_FIR #(
        .SRL_REG(1)
    ) dut1 (
        .clk(clk),
        .rst(rst),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .sample_ready(sample_ready1),
        .y_out(y_out1),
        .y_valid(y_valid1)
    );

    initial begin
        rst = 1;
        sample_in    = 0;
        sample_valid = 0;
        #20;
        rst = 0;

        fin   = $fopen("Neural_Signal_Sample.txt", "r");
        fout0 = $fopen("fir_out_srl0.txt", "w");
        fout1 = $fopen("fir_out_srl1.txt", "w");

        if (fin == 0) begin
            $display("ERROR: cannot open input file");
            $finish;
        end

        cycle = 0;

        while (!$feof(fin)) begin
            // wait until both are ready to take a new sample
            @(posedge clk);
            if (sample_ready0 && sample_ready1) begin
                scan = $fscanf(fin, "%b\n", sample_in);
                sample_valid = 1;
            end else begin
                sample_valid = 0;
            end

            // dump outputs when valid
            if (y_valid0) $fwrite(fout0, "%b\n", y_out0);
            if (y_valid1) $fwrite(fout1, "%b\n", y_out1);

            cycle = cycle + 1;
        end

        // drain pipeline for some extra cycles
        repeat (200) begin
            @(posedge clk);
            sample_valid = 0;
            if (y_valid0) $fwrite(fout0, "%b\n", y_out0);
            if (y_valid1) $fwrite(fout1, "%b\n", y_out1);
        end

        $fclose(fin);
        $fclose(fout0);
        $fclose(fout1);

        $finish;
    end

endmodule

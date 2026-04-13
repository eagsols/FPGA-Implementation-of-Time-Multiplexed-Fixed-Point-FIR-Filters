# FPGA-Implementation-of-Time-Multiplexed-Fixed-Point-FIR-Filters
This repository presents a hardware-efficient implementation of a finite impulse response (FIR) filter using time-multiplexing and fixed-point arithmetic, targeting FPGA architectures. The design trades off throughput for significant reductions in resource utilization by reusing arithmetic units across multiple filter taps.

The core module (time_mux_FIR.v) implements a sequential FIR structure where a single multiplier–adder pair is reused across clock cycles to compute the convolution, rather than instantiating a fully parallel tap structure. This approach is well-suited for resource-constrained designs or applications where latency is acceptable.

To support fixed-point DSP operations, the design includes custom arithmetic modules:

fixed_mul.v: parameterized fixed-point multiplier
fixed_adder.v: fixed-point addition with proper bit growth handling
fixed_resize.v: scaling and truncation for maintaining numerical precision across stages

A testbench (tb_time_mux_fir.v) is provided to verify functionality, using a real-world neural signal dataset as input stimulus. This demonstrates the filter’s behavior under realistic signal conditions rather than synthetic test vectors.

Key Features
Time-multiplexed FIR architecture for reduced DSP and LUT usage
Fully fixed-point implementation (no floating-point overhead)
Modular arithmetic blocks for reuse and scalability
Parameterizable design for different filter lengths and word sizes
Real signal validation using neural data
Applications
Embedded DSP systems
Biomedical signal processing (e.g., neural signal filtering)
Low-resource FPGA deployments
Power-constrained designs

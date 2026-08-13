// ============================================================================
// Module:  discriminant
// Project: Ray-Sphere Intersection Accelerator (RTU)
// Lead:    Visnu (Math Modules)
// Aux:     Harsh, Logan
// ============================================================================
//
// DESCRIPTION:
//   Computes the discriminant of the ray-sphere quadratic:
//
//     disc = in1 - in2
//
//   where in1 and in2 are pre-computed Q16.16 products passed in from
//   upstream (e.g. half_b² and a*c from the dot product / coeff stages).
//
//   valid_in[1:0] is pipelined through two registers so valid_out[1:0]
//   arrives exactly in sync with disc — 2 cycles after valid_in.
//
// PIPELINE:
//   Cycle 1: latch in1, in2 into registers; pipeline valid_in → valid_pipe[0]
//   Cycle 2: subtract in1_reg - in2_reg → disc_reg; valid_pipe[0] → valid_pipe[1]
//   valid_out and disc are both valid on cycle 2.
//
// HARDWARE COST:
//   2 × 32-bit input registers + 1 × 32-bit subtractor register
//   + 2-stage 2-bit valid shift register
//
// ============================================================================

module discriminant (
    input  wire        clk,
    input  wire        rst_n,

    // Pre-computed Q16.16 inputs
    input  wire [31:0] in1,      // e.g. half_b²
    input  wire [31:0] in2,      // e.g. a * c

    // Control — 2-bit valid pipelined 2 cycles to stay synced with disc
    input  wire [1:0]  valid_in,
    output wire [1:0]  valid_out,

    // Result
    output wire [31:0] disc      // disc = in1 - in2 (Q16.16)
);

    // -----------------------------------------------------------------------
    // Stage 1 registers — latch inputs on first clock edge
    // -----------------------------------------------------------------------
    reg signed [31:0] in1_reg;
    reg signed [31:0] in2_reg;

    // -----------------------------------------------------------------------
    // Stage 2 register — subtraction result
    // -----------------------------------------------------------------------
    reg signed [31:0] disc_reg;

    // -----------------------------------------------------------------------
    // Valid pipeline — 2-bit valid shifted through 2 register stages
    //   valid_pipe[0] : 1 cycle after valid_in
    //   valid_pipe[1] : 2 cycles after valid_in  (== valid_out, aligned with disc)
    // -----------------------------------------------------------------------
    reg [1:0] valid_pipe [0:1];

    assign disc      = disc_reg;
    assign valid_out = valid_pipe[1];

    always @(posedge clk) begin
        if (!rst_n) begin
            in1_reg        <= 32'sd0;
            in2_reg        <= 32'sd0;
            disc_reg       <= 32'sd0;
            valid_pipe[0]  <= 2'b00;
            valid_pipe[1]  <= 2'b00;
        end else begin
            // Stage 1 — register inputs and pipeline valid
            in1_reg       <= $signed(in1);
            in2_reg       <= $signed(in2);
            valid_pipe[0] <= valid_in;

            // Stage 2 — subtract registered inputs, advance valid
            disc_reg      <= in1_reg - in2_reg;
            valid_pipe[1] <= valid_pipe[0];
        end
    end

endmodule



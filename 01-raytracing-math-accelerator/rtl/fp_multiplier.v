// ============================================================================
// Module:  fp_multiplier
// Project: Ray-Sphere Intersection Accelerator (RTU)
// Lead:    Visnu (Math Modules)
// Aux:     Harsh, Logan
// ============================================================================
//
// DESCRIPTION:
//   Fixed-point Q16.16 multiplier. This is the most reused arithmetic unit
//   in the entire RTU - the dot product, discriminant, and coefficient
//   stages all depend on it.
//
//   Q16.16 format: 1 sign bit + 15 integer bits + 16 fractional bits,
//   stored in a 32-bit signed integer. "1.0" = 0x00010000 (65536).
//
//   Operation:
//     1. Multiply two signed 32-bit Q16.16 values → 64-bit intermediate.
//     2. Arithmetic right-shift by 16 to re-align the radix point.
//     3. Truncate to 32 bits for the Q16.16 result.
//
// ============================================================================
module fp_multiplier (
    input  wire clk_i,
    input  wire rst_n,
    // Operands (Q16.16 signed)
    input  wire signed [31:0] a,
    input  wire signed [31:0] b,
    // Control
    input  wire valid_in,
    input wire [1:0] ctrl_in,
    output wire valid_out,
    output wire [1:0] ctrl_out,
    // Results
    output wire signed [31:0] product,      // Q16.16 truncated result
    output wire signed [63:0] product_full  // Full 64-bit intermediate (Q16.32)
);


    // PIPELINED VERSION (3 stages)

    // Stage 1 registers - capture inputs on first clock edge
    reg signed [31:0] a_reg;
    reg signed [31:0] b_reg;
    reg valid_reg1;
    reg [1:0] ctrl_reg1; // Control tag for tracking which multiplication is in-flight

    // Stage 2 registers - capture multiplication result on second clock edge
    reg signed [63:0] product_reg;
    reg valid_reg2;
    reg [1:0] ctrl_reg2; // Control tag for tracking which multiplication is in-flight

    assign valid_out = valid_reg2;
    assign product = product_reg[47:16];
    assign product_full = product_reg;
    assign ctrl_out = ctrl_reg2;

    always @(posedge clk_i) begin
        if (!rst_n) begin
            a_reg <= 32'b0;
            b_reg <= 32'b0;
            valid_reg1 <= 1'b0;
            product_reg <= 64'b0;
            valid_reg2 <= 1'b0;
            ctrl_reg1 <= 2'b00;
            ctrl_reg2 <= 2'b00;
        end
        else begin
            // Stage 1 - register inputs
            a_reg <= a;
            b_reg <= b;
            valid_reg1 <= valid_in;
            ctrl_reg1 <= ctrl_in;

            // Stage 2 - multiply and register 64-bit result
            product_reg <= a_reg * b_reg;
            valid_reg2  <= valid_reg1;
            ctrl_reg2 <= ctrl_reg1;
        end
    end
endmodule


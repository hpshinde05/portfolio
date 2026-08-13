// ============================================================================
// Module:  dot_product
// Project: Ray-Sphere Intersection Accelerator (RTU)
// Lead:    Visnu (Math Modules)
// Aux:     Harsh, Logan
// ============================================================================
//
// DESCRIPTION:
//   Computes the dot product of two 3-component Q16.16 vectors:
//     result = A.x*B.x + A.y*B.y + A.z*B.z
//
//   This unit is used THREE times per ray-sphere intersection:
//     - a      = D · D    (ray direction self-dot)
//     - half_b = L · D    (offset dotted with direction)
//     - L_dot  = L · L    (offset self-dot)
//
//   The controller instantiates 3 of these staggered by 1 cycle each,
//   with ctrl tags labeling which result is which:
//     2'b00 = D·D  (a)
//     2'b01 = L·D  (half_b)
//     2'b10 = L·L  (Ldot)
//   Staggering is handled at the top level (rtu_top.v).
//
// ARCHITECTURE:
//   Internally instantiates 3 fp_multiplier units (one per component)
//   and sums their outputs combinationally with 2 adders:
//     result = mul_x + mul_y + mul_z
//
//   Pipeline Latency: 2 Cycles total
//       - 2 cycles through fp_multiplier
//       - Addition is combinational — no extra cycle
//
//   If area-constrained, this can be replaced with 1 multiplier +
//   an accumulator running over 3 cycles (see resource sharing table
//   in reference doc section 5).
//
// HARDWARE COST:
//   3 × fp_multiplier + 2 × 32-bit signed combinational adders
//
// ============================================================================
module dot_product (
    input  wire        clk_i,
    input  wire        rst_n,
    // Vector A components (Q16.16 signed)
    input  wire signed [31:0] a_x,
    input  wire signed [31:0] a_y,
    input  wire signed [31:0] a_z,
    // Vector B components (Q16.16 signed)
    input  wire signed [31:0] b_x,
    input  wire signed [31:0] b_y,
    input  wire signed [31:0] b_z,
    // Control
    input  wire        valid_in,
    input  wire [1:0]  ctrl_in,   // 2'b00=D·D, 2'b01=L·D, 2'b10=L·L
    output wire        valid_out,
    output wire [1:0]  ctrl_out,  // ctrl tag forwarded to discriminant
    // Result (Q16.16 scalar)
    output wire signed [31:0] result
);

    // Full-precision 64-bit product wires (Q32.32)
    // Using product_full from each fp_multiplier to defer truncation
    // until after the addition — only one truncation error total
    wire signed [63:0] prod_x, prod_y, prod_z;
    wire valid_mul_x, valid_mul_y, valid_mul_z;
    wire [1:0] ctrl_mul_x;
    // valid_mul_y/z intentionally unused — all three muls are in lockstep
    // since they share clk and valid_in. Only valid_mul_x is forwarded.
    // ctrl_mul_y/z intentionally unused — same reason, all in lockstep.

    fp_multiplier mul_x (
        .clk_i(clk_i),
        .rst_n(rst_n),
        .a(a_x),
        .b(b_x),
        .valid_in(valid_in),
        .ctrl_in(ctrl_in),
        .valid_out(valid_mul_x),
        .ctrl_out(ctrl_mul_x),
        .product(),
        .product_full(prod_x)
    );
    fp_multiplier mul_y (
        .clk_i(clk_i),
        .rst_n(rst_n),
        .a(a_y),
        .b(b_y),
        .valid_in(valid_in),
        .ctrl_in(ctrl_in),
        .valid_out(valid_mul_y),
        .ctrl_out(),
        .product(),
        .product_full(prod_y)
    );
    fp_multiplier mul_z (
        .clk_i(clk_i),
        .rst_n(rst_n),
        .a(a_z),
        .b(b_z),
        .valid_in(valid_in),
        .ctrl_in(ctrl_in),
        .valid_out(valid_mul_z),
        .ctrl_out(),
        .product(),
        .product_full(prod_z)
    );

    // Combinational addition — no extra pipeline stage
    // Sum the three 64-bit products and extract Q16.16 result
    wire signed [63:0] sum_wire;
    assign sum_wire = prod_x + prod_y + prod_z;

    // Convert from Q32.32 to Q16.16
    assign result    = sum_wire[47:16];
    assign valid_out = valid_mul_x;
    assign ctrl_out  = ctrl_mul_x;

endmodule

module lab3_structural(
    input [1:0] x,
    input init,
    input clk,
    output dispense,
    output [1:0] change,
    output [1:0] q
);

    wire Q1_next, Q0_next;
    wire NQ1, NQ0, NX1, NX0;
    wire Q1_1, Q1_2, D1, D, C0_1, C0_2, Q0_1, Q0_2;


    // Inverter (NOT)
    sn7404_NOT n1(
        .p01_1_a(q[1]), .p02_1_y(NQ1),
        .p03_2_a(q[0]), .p04_2_y(NQ0),
        .p05_3_a(x[1]), .p06_3_y(NX1),
        .p13_6_a(x[0]), .p12_6_y(NX0)
    );

    sn7408_AND A1 (

        // Next state Q1*
        .p01_1_a(x[0]), .p02_1_b(q[0]), .p03_1_y(Q1_1),
        .p04_2_a(x[0]), .p05_2_b(q[1]), .p06_2_y(Q1_2),

        // C1 logic
        .p09_3_a(x[1]), .p10_3_b(q[1]), .p08_3_y(change[1]),

        // D1
        .p12_4_a(NX0), .p13_4_b(NX1), .p11_4_y(D1)
    );

    sn7408_AND A2(
        .p01_1_a(x[1]), .p02_1_b(q[0]), .p03_1_y(C0_1),
        .p04_2_a(x[0]), .p05_2_b(q[1]), .p06_2_y(C0_2),

        // D logic
        .p09_3_a(D1), .p10_3_b(q[1]), .p08_3_y(dispense)
    );

    sn7410_NAND NA(
        .p01_1_a(x[0]), .p02_1_b(NQ1), .p13_1_c(NQ0), .p12_1_y(Q0_1),
        .p03_2_a(NX1), .p04_2_b(NX0), .p05_2_c(q[0]), .p06_2_y(Q0_2),
        .p09_3_a(Q0_1), .p10_3_b(Q0_2), .p11_3_c(1'b1), .p08_3_y(Q0_next)
    );

    sn7432_OR O1(
        // Q1*
        .p01_1_a(Q1_1), .p02_1_b(Q1_2), .p03_1_y(Q1_next),

        // C0
        .p04_2_a(C0_1), .p05_2_b(C0_2), .p06_2_y(change[0])
    );

    sn7474_DFF dff_pair (
        .p01_1_clr_n(init),
        .p02_1_d(Q1_next),
        .p03_1_clk(clk),
        .p04_1_pre_n(1'b1),
        .p05_1_q(q[1]),
        .p09_2_q(q[0]),
        .p10_2_pre_n(1'b1),
        .p11_2_clk(clk),
        .p12_2_d(Q0_next),
        .p13_2_clr_n(init)
    );



endmodule

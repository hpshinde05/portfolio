
module sn7474_DFF(
    input p01_1_clr_n,
    input p02_1_d,
    input p03_1_clk,
    input p04_1_pre_n,
    output reg p05_1_q,
    output reg p06_1_q_n,
    output reg p08_2_q_n,
    output reg p09_2_q,
    input p10_2_pre_n,
    input p11_2_clk,
    input p12_2_d,
    input p13_2_clr_n
);
    always @ (posedge p03_1_clk or negedge p01_1_clr_n or negedge p04_1_pre_n) begin
        if(!p01_1_clr_n) begin
            p05_1_q <= 0;
            p06_1_q_n <= 1;
        end else if (!p04_1_pre_n) begin
            p05_1_q <= 1;
            p06_1_q_n <= 0;
        end else begin
            p05_1_q <= p02_1_d;
            p06_1_q_n <= ~p02_1_d;
        end 
    end

    always @ (posedge p11_2_clk or negedge p13_2_clr_n or negedge p10_2_pre_n) begin
        if(!p13_2_clr_n) begin
            p09_2_q <= 0;
            p08_2_q_n <= 1;
        end else if (!p10_2_pre_n) begin
            p09_2_q <= 1;
            p08_2_q_n <= 0;
        end else begin
            p09_2_q <= p12_2_d;
            p08_2_q_n <= ~p12_2_d;
        end 
    end
endmodule

module sn7408_AND(
    input p01_1_a,
    input p02_1_b,
    output p03_1_y,
    input p04_2_a,
    input p05_2_b,
    output p06_2_y,
    output p08_3_y,
    input p09_3_a,
    input p10_3_b,
    output p11_4_y,
    input p12_4_a,
    input p13_4_b
);
    assign p03_1_y = p01_1_a & p02_1_b;
    assign p06_2_y = p04_2_a & p05_2_b;
    assign p08_3_y = p09_3_a & p10_3_b;
    assign p11_4_y = p12_4_a & p13_4_b;
endmodule

module sn7432_OR(
    input p01_1_a,
    input p02_1_b,
    output p03_1_y,
    input p04_2_a,
    input p05_2_b,
    output p06_2_y,
    output p08_3_y,
    input p09_3_a,
    input p10_3_b,
    output p11_4_y,
    input p12_4_a,
    input p13_4_b
);
    assign p03_1_y = p01_1_a | p02_1_b;
    assign p06_2_y = p04_2_a | p05_2_b;
    assign p08_3_y = p09_3_a | p10_3_b;
    assign p11_4_y = p12_4_a | p13_4_b;
endmodule

module sn74153_MUX(

);

endmodule

module sn7404_NOT(
    input p01_1_a,
    output p02_1_y,
    input p03_2_a,
    output p04_2_y,
    input p05_3_a,
    output p06_3_y,
    output p08_4_y,
    input p09_4_a,
    output p10_5_y,
    input p11_5_a,
    output p12_6_y,
    input p13_6_a
);
    assign p02_1_y = ~p01_1_a;
    assign p04_2_y = ~p03_2_a;
    assign p06_3_y = ~p05_3_a;
    assign p08_4_y = ~p09_4_a;
    assign p10_5_y = ~p11_5_a;
    assign p12_6_y = ~p13_6_a;
endmodule

module sn7410_NAND(
    input p01_1_a,
    input p02_1_b,
    input p03_2_a,
    input p04_2_b,
    input p05_2_c,
    output p06_2_y,
    output p08_3_y,
    input p09_3_a,
    input p10_3_b,
    input p11_3_c,
    output p12_1_y,
    input p13_1_c
);
    assign p12_1_y = ~(p01_1_a & p02_1_b & p13_1_c);
    assign p06_2_y = ~(p03_2_a & p04_2_b & p05_2_c);
    assign p08_3_y = ~(p09_3_a & p10_3_b & p11_3_c);
endmodule

module sn7486_XOR(
    input p01_1_a,
    input p02_1_b,
    output p03_1_y,
    input p04_2_a,
    input p05_2_b,
    output p06_2_y,
    output p08_3_y,
    input p09_3_a,
    input p10_3_b,
    output p11_4_y,
    input p12_4_a,
    input p13_4_b
);
    assign p03_1_y = p01_1_a ^ p02_1_b;
    assign p06_2_y = p04_2_a ^ p05_2_b;
    assign p08_3_y = p09_3_a ^ p10_3_b;
    assign p11_4_y = p12_4_a ^ p13_4_b;
endmodule
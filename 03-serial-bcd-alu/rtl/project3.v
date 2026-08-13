`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Class: ECE - 310 
// Engineer: Harsh Shinde
// 
// Create Date: 04/21/2026 11:46:56 PM
// Design Name: Project_3
// Module Name: Project3
//////////////////////////////////////////////////////////////////////////////////

// =========================================================
// BCD_ALU Submodule
// =========================================================
module BCD_ALU (
    input  wire [15:0] A,
    input  wire [15:0] B,
    input  wire        op,
    output wire [19:0] result
);

    // ------- B digit breakdown -------
    wire [3:0] b0 = B[3:0];
    wire [3:0] b1 = B[7:4];
    wire [3:0] b2 = B[11:8];
    wire [3:0] b3 = B[15:12];

    // ------- 9's complement of each B digit -------
    wire [3:0] b0_9c = 4'd9 - b0;
    wire [3:0] b1_9c = 4'd9 - b1;
    wire [3:0] b2_9c = 4'd9 - b2;
    wire [3:0] b3_9c = 4'd9 - b3;

    // ------- Mux: B or 9's-comp(B) per digit -------
    wire [3:0] b0_eff = op ? b0_9c : b0;
    wire [3:0] b1_eff = op ? b1_9c : b1;
    wire [3:0] b2_eff = op ? b2_9c : b2;
    wire [3:0] b3_eff = op ? b3_9c : b3;

    // carry_in to digit 0: 0 for ADD, 1 for SUB (the "+1" of 10's complement)
    wire cin0 = op;

    // ------- Digit 0 adder + BCD correction -------
    wire [4:0] raw0  = {1'b0, A[3:0]}   + {1'b0, b0_eff} + {4'b0, cin0};
    wire       c0    = (raw0 > 5'd9);
    wire [4:0] corr0 = c0 ? (raw0 + 5'd6) : raw0;
    wire [3:0] res0  = corr0[3:0];
    wire       cout0 = corr0[4];

    // ------- Digit 1 adder + BCD correction -------
    wire [4:0] raw1  = {1'b0, A[7:4]}   + {1'b0, b1_eff} + {4'b0, cout0};
    wire       c1    = (raw1 > 5'd9);
    wire [4:0] corr1 = c1 ? (raw1 + 5'd6) : raw1;
    wire [3:0] res1  = corr1[3:0];
    wire       cout1 = corr1[4];

    // ------- Digit 2 adder + BCD correction -------
    wire [4:0] raw2  = {1'b0, A[11:8]}  + {1'b0, b2_eff} + {4'b0, cout1};
    wire       c2    = (raw2 > 5'd9);
    wire [4:0] corr2 = c2 ? (raw2 + 5'd6) : raw2;
    wire [3:0] res2  = corr2[3:0];
    wire       cout2 = corr2[4];

    // ------- Digit 3 adder + BCD correction -------
    wire [4:0] raw3  = {1'b0, A[15:12]} + {1'b0, b3_eff} + {4'b0, cout2};
    wire       c3    = (raw3 > 5'd9);
    wire [4:0] corr3 = c3 ? (raw3 + 5'd6) : raw3;
    wire [3:0] res3  = corr3[3:0];
    wire       cout3 = corr3[4];

    // ------- Digit 4 (5th BCD digit / carry out) -------
    // SUB: discard final carry (borrow behavior) -> digit 4 = 0
    // ADD: cout3 is the 5th digit (0 or 1)
    wire [3:0] res4 = op ? 4'b0 : {3'b0, cout3};

    assign result = {res4, res3, res2, res1, res0};

endmodule


// =========================================================
// Project3 - Top-level Serial BCD ALU
// =========================================================
module Project3 (
    input  wire clock,
    input  wire reset,
    input  wire din,
    output wire result
);

    // =========================================================
    // SIPO - 41-bit rolling shift register
    // =========================================================
    reg [40:0] shift_reg;

    wire valid_packet;
    assign valid_packet = (shift_reg[40:33] == 8'h67);

    always @(posedge clock) begin
        if (reset)
            shift_reg <= 41'b0;
        else if (valid_packet)
            shift_reg <= 41'b0;          // non-overlapping clear
        else
            shift_reg <= {shift_reg[39:0], din};
    end

    // =========================================================
    // Input Registers - latch A, B, op on valid_packet
    // =========================================================
    reg [15:0] A_reg, B_reg;
    reg        op_reg;
    reg        compute_en;   // one-cycle pulse: triggers output register load

    always @(posedge clock) begin
        if (reset) begin
            A_reg      <= 16'b0;
            B_reg      <= 16'b0;
            op_reg     <= 1'b0;
            compute_en <= 1'b0;
        end else begin
            compute_en <= valid_packet;
            if (valid_packet) begin
                op_reg <= shift_reg[32];
                A_reg  <= shift_reg[31:16];
                B_reg  <= shift_reg[15:0];
            end
        end
    end

    // =========================================================
    // BCD ALU instantiation
    // =========================================================
    wire [19:0] alu_result;

    BCD_ALU alu_inst (
        .A      (A_reg),
        .B      (B_reg),
        .op     (op_reg),
        .result (alu_result)
    );

    // =========================================================
    // PISO - 28-bit shift register {8'hA5, alu_result[19:0]}
    // =========================================================
    reg [27:0] piso_reg;
    reg [4:0]  out_cnt;
    reg        piso_active;

    always @(posedge clock) begin
        if (reset) begin
            piso_reg    <= 28'b0;
            out_cnt     <= 5'd0;
            piso_active <= 1'b0;
        end else if (compute_en) begin
            piso_reg    <= {8'hA5, alu_result};
            out_cnt     <= 5'd0;
            piso_active <= 1'b1;
        end else if (piso_active) begin
            if (out_cnt == 5'd27) begin
                piso_active <= 1'b0;
                out_cnt     <= 5'd0;
            end else begin
                piso_reg <= {piso_reg[26:0], 1'b0};
                out_cnt  <= out_cnt + 5'd1;
            end
        end
    end

    assign result = piso_active ? piso_reg[27] : 1'b0;

endmodule

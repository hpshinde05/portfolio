`timescale 1ns/1ps

module discriminant_tb;

    // -----------------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------------
    reg        clk;
    reg        rst_n;
    reg [31:0] in1;
    reg [31:0] in2;
    reg [1:0]  valid_in;

    wire [1:0]  valid_out;
    wire [31:0] disc;

    // -----------------------------------------------------------------------
    // Clock: 10 ns period
    // -----------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    discriminant dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .in1      (in1),
        .in2      (in2),
        .valid_in (valid_in),
        .valid_out(valid_out),
        .disc     (disc)
    );

    // -----------------------------------------------------------------------
    // Q16.16 helper - convert real → fixed-point integer
    // -----------------------------------------------------------------------
    function [31:0] to_q;
        input real x;
        to_q = $rtoi(x * 65536.0);
    endfunction

    // -----------------------------------------------------------------------
    // Task: apply one input vector, wait 2 cycles, check result
    // -----------------------------------------------------------------------
    task apply_test;
        input [31:0]  t_in1;
        input [31:0]  t_in2;
        input [1:0]   t_valid;
        input [31:0]  t_expected_disc;
        input [255:0] t_name;
        begin
            @(posedge clk); #1;     // small delay past clock edge
            in1      = t_in1;
            in2      = t_in2;
            valid_in = t_valid;

            @(posedge clk); #1;     // cycle 1 - inputs latched
            valid_in = 2'b00;       // drop valid after one pulse

            @(posedge clk); #1;     // cycle 2 - disc and valid_out ready

            // Check disc
            if ($signed(disc) === $signed(t_expected_disc))
                $display("PASS  [%0s] disc = %0d (expected %0d), valid_out = %02b",
                          t_name, $signed(disc), $signed(t_expected_disc), valid_out);
            else
                $display("FAIL  [%0s] disc = %0d (expected %0d), valid_out = %02b",
                          t_name, $signed(disc), $signed(t_expected_disc), valid_out);

            // Check valid passthrough
            if (valid_out !== t_valid)
                $display("      WARNING: valid_out=%02b but valid_in was %02b",
                          valid_out, t_valid);
        end
    endtask

    // -----------------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("discriminant_tb.vcd");
        $dumpvars(0, discriminant_tb);

        // Initialize
        rst_n    = 0;
        in1      = 0;
        in2      = 0;
        valid_in = 2'b00;

        // Hold reset for 4 cycles
        repeat (4) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ---- Test 1: positive disc (HIT) ---------------------------------
        // in1 = half_b^2 = 4.0,  in2 = a*c = 1.0
        // disc = 4.0 - 1.0 = 3.0
        apply_test(
            to_q(4.0),
            to_q(1.0),
            2'b01,
            to_q(3.0),
            "T1 disc>0 HIT"
        );

        // ---- Test 2: negative disc (MISS) --------------------------------
        // in1 = 1.0,  in2 = 4.0
        // disc = 1.0 - 4.0 = -3.0
        apply_test(
            to_q(1.0),
            to_q(4.0),
            2'b01,
            to_q(-3.0),
            "T2 disc<0 MISS"
        );

        // ---- Test 3: zero disc (tangent) ---------------------------------
        // in1 = 4.0,  in2 = 4.0
        // disc = 0.0
        apply_test(
            to_q(4.0),
            to_q(4.0),
            2'b01,
            to_q(0.0),
            "T3 disc=0 tangent"
        );

        // ---- Test 4: valid_in = 2'b00 (no op) ---------------------------
        // disc should not change, valid_out should be 2'b00
        apply_test(
            to_q(2.0),
            to_q(1.0),
            2'b00,
            disc,       // whatever disc currently holds - we just check valid
            "T4 no valid"
        );

        // ---- Test 5: large values ----------------------------------------
        // in1 = 100.0,  in2 = 50.0
        // disc = 50.0
        apply_test(
            to_q(100.0),
            to_q(50.0),
            2'b11,
            to_q(50.0),
            "T5 large values"
        );

        #20;
        $display("Done.");
        $finish;
    end

endmodule

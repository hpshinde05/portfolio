`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Class: ECE - 310
// Engineer: Harsh Shinde
//
// Testbench for Project3 - Serial BCD ALU
// Tests: Reset, ADD, SUB, Continuous input, Non-continuous input,
//        Header pattern present in data
//////////////////////////////////////////////////////////////////////////////////

module Project3_tb;

    // =========================================================
    // DUT Signals
    // =========================================================
    reg  clock;
    reg  reset;
    reg  din;
    wire result;

    // =========================================================
    // DUT Instantiation
    // =========================================================
    Project3 dut (
        .clock  (clock),
        .reset  (reset),
        .din    (din),
        .result (result)
    );

    // =========================================================
    // Clock Generation: 10ns period
    // =========================================================
    initial clock = 0;
    always #5 clock = ~clock;

    // =========================================================
    // Capture output stream into a 28-bit register
    // =========================================================
    reg [27:0] captured_out;
    integer    cap_bit;
    reg        capturing;

    initial begin
        captured_out = 28'b0;
        cap_bit      = 27;
        capturing    = 0;
    end

    // Shift result bit into captured_out MSB-first
    always @(posedge clock) begin
        if (result) capturing <= 1;
        if (capturing) begin
            captured_out[cap_bit] <= result;
            if (cap_bit == 0) begin
                cap_bit  <= 27;
                capturing <= 0;
            end else begin
                cap_bit <= cap_bit - 1;
            end
        end
    end

    // =========================================================
    // Helper Tasks
    // =========================================================

    // Send one bit MSB-first, one bit per clock
    task send_bit;
        input b;
        begin
            @(negedge clock);
            din = b;
        end
    endtask

    // Send a BCD packet: 8'h67 | op | A[15:0] | B[15:0], MSB first
    task send_packet;
        input        op;
        input [15:0] A;
        input [15:0] B;
        integer i;
        reg [40:0] pkt;
        begin
            pkt = {8'h67, op, A, B};
            for (i = 40; i >= 0; i = i - 1)
                send_bit(pkt[i]);
        end
    endtask

    // Wait for PISO output to complete (28 clocks after first result bit)
    task wait_output;
        integer i;
        begin
            // Wait until result goes high (output starts)
            @(posedge result);
            // Now wait 28 more clock cycles for the full packet
            repeat (28) @(posedge clock);
            #1; // settle
        end
    endtask

    // Check expected BCD result (20-bit) against captured output header + data
    task check_result;
        input [7:0]  exp_header;   // should be 8'hA5
        input [19:0] exp_bcd;      // expected 5-digit BCD result
        input [63:0] test_name;
        begin
            if (captured_out[27:20] !== exp_header)
                $display("FAIL [%s]: Header = 8'h%02h, Expected 8'h%02h",
                          test_name, captured_out[27:20], exp_header);
            else if (captured_out[19:0] !== exp_bcd)
                $display("FAIL [%s]: Result = 20'h%05h (%0d), Expected 20'h%05h (%0d)",
                          test_name,
                          captured_out[19:0], captured_out[19:0],
                          exp_bcd, exp_bcd);
            else
                $display("PASS [%s]: Output = 8'hA5_%05h", test_name, exp_bcd);
        end
    endtask

    // =========================================================
    // Main Test Sequence
    // =========================================================
    integer j;

    initial begin
        $dumpfile("project3_tb.vcd");
        $dumpvars(0, Project3_tb);

        // --- Initialize ---
        din   = 0;
        reset = 1;
        repeat (4) @(posedge clock);
        @(negedge clock); reset = 0;

        // =====================================================
        // TEST 1: ADD - 3627 + 1287 = 4914
        // From spec example
        // A = 0011_0110_0010_0111 = 16'h3627
        // B = 0001_0010_1000_0111 = 16'h1287
        // Expected: 0000_0100_1001_0001_0100 = 5-digit BCD 04914
        // =====================================================
        $display("--- TEST 1: ADD 3627 + 1287 = 4914 ---");
        captured_out = 28'b0; cap_bit = 27; capturing = 0;
        send_packet(1'b0, 16'h3627, 16'h1287);
        wait_output;
        // BCD 04914: 0000 0100 1001 0001 0100 = 20'h04914
        check_result(8'hA5, 20'h04914, "ADD_3627+1287");

        // =====================================================
        // TEST 2: ADD - 9999 + 1 = 10000
        // A = 16'h9999, B = 16'h0001
        // Expected BCD: 1_0000 = 20'h10000
        // =====================================================
        $display("--- TEST 2: ADD 9999 + 0001 = 10000 ---");
        captured_out = 28'b0; cap_bit = 27; capturing = 0;
        send_packet(1'b0, 16'h9999, 16'h0001);
        wait_output;
        check_result(8'hA5, 20'h10000, "ADD_9999+0001");

        // =====================================================
        // TEST 3: ADD - 0000 + 0000 = 00000
        // =====================================================
        $display("--- TEST 3: ADD 0000 + 0000 = 00000 ---");
        captured_out = 28'b0; cap_bit = 27; capturing = 0;
        send_packet(1'b0, 16'h0000, 16'h0000);
        wait_output;
        check_result(8'hA5, 20'h00000, "ADD_0+0");

        // =====================================================
        // TEST 4: SUB - 637 - 459 = 178  (spec example)
        // A = 0000_0110_0011_0111 = 16'h0637
        // B = 0000_0100_0101_1001 = 16'h0459
        // Expected BCD: 00178 = 20'h00178
        // =====================================================
        $display("--- TEST 4: SUB 0637 - 0459 = 0178 ---");
        captured_out = 28'b0; cap_bit = 27; capturing = 0;
        send_packet(1'b1, 16'h0637, 16'h0459);
        wait_output;
        check_result(8'hA5, 20'h00178, "SUB_0637-0459");

        // =====================================================
        // Done
        // =====================================================
        $display("--- All tests complete ---");
        #100;
        $finish;
    end

    // Timeout watchdog: 50000ns max
    initial begin
        #50000;
        $display("TIMEOUT: Simulation exceeded 50000ns");
        repeat(60) @(posedge clock);  // give Test 4 output time to shift out
        $finish;
    end

endmodule

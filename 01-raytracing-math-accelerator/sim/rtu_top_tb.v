`timescale 1ns/1ps

module rtu_top_tb;

    reg clk_i;
    reg rst_n;

    reg [31:0] ray_origin_x;
    reg [31:0] ray_origin_y;
    reg [31:0] ray_origin_z;
    reg [31:0] ray_dir_x;
    reg [31:0] ray_dir_y;
    reg [31:0] ray_dir_z;

    reg [31:0] sphere_center_x;
    reg [31:0] sphere_center_y;
    reg [31:0] sphere_center_z;
    reg [31:0] sphere_radius;

    reg start;

    wire        done;
    wire        hit;
    wire [31:0] t_value;

    integer timeout_cycles;

    initial clk_i = 1'b0;
    always #5 clk_i = ~clk_i;

    rtu_top dut (
        .clk_i           (clk_i),
        .rst_n           (rst_n),

        .ray_origin_x    (ray_origin_x),
        .ray_origin_y    (ray_origin_y),
        .ray_origin_z    (ray_origin_z),
        .ray_dir_x       (ray_dir_x),
        .ray_dir_y       (ray_dir_y),
        .ray_dir_z       (ray_dir_z),

        .sphere_center_x (sphere_center_x),
        .sphere_center_y (sphere_center_y),
        .sphere_center_z (sphere_center_z),
        .sphere_radius   (sphere_radius),

        .start           (start),
        .done            (done),
        .hit             (hit),
        .t_value         (t_value)
    );

    function [31:0] to_q;
        input real x;
        begin
            to_q = $rtoi(x * 65536.0);
        end
    endfunction

    task launch_request;
        input [255:0] test_name;

        input [31:0] o_x;
        input [31:0] o_y;
        input [31:0] o_z;

        input [31:0] d_x;
        input [31:0] d_y;
        input [31:0] d_z;

        input [31:0] c_x;
        input [31:0] c_y;
        input [31:0] c_z;
        input [31:0] radius;

        begin
            @(negedge clk_i);
            ray_origin_x    = o_x;
            ray_origin_y    = o_y;
            ray_origin_z    = o_z;

            ray_dir_x       = d_x;
            ray_dir_y       = d_y;
            ray_dir_z       = d_z;

            sphere_center_x = c_x;
            sphere_center_y = c_y;
            sphere_center_z = c_z;
            sphere_radius   = radius;

            // One-cycle launch pulse. rtu_top routes successive launches
            // round-robin to one of three controller instances.
            start = 1'b1;

            @(negedge clk_i);
            start = 1'b0;

            $display("------------------------------------------------------------");
            $display("RTU REQUEST [%0s]", test_name);

            timeout_cycles = 0;
            while ((done !== 1'b1) && (timeout_cycles < 200)) begin
                @(posedge clk_i);
                timeout_cycles = timeout_cycles + 1;
            end

            if (done === 1'b1) begin
                $display("RTU DONE [%0s] after %0d cycles", test_name, timeout_cycles);
                $display("  hit=%b  t_value(raw)=%0d  t_value(Q16.16)=%f",
                         hit,
                         $signed(t_value),
                         $itor($signed(t_value)) / 65536.0);
            end else begin
                $display("RTU TIMEOUT [%0s] after 200 cycles", test_name);
                $display("  Inspect the controller instances and scheduler in GTKWave.");
            end

            repeat (4) @(posedge clk_i);
        end
    endtask

    initial begin
        $dumpfile("tb_rtu_top.vcd");
        $dumpvars(0, tb_rtu_top);

        rst_n           = 1'b0;
        start           = 1'b0;

        ray_origin_x    = 32'd0;
        ray_origin_y    = 32'd0;
        ray_origin_z    = 32'd0;
        ray_dir_x       = 32'd0;
        ray_dir_y       = 32'd0;
        ray_dir_z       = 32'd0;

        sphere_center_x = 32'd0;
        sphere_center_y = 32'd0;
        sphere_center_z = 32'd0;
        sphere_radius   = 32'd0;

        repeat (4) @(posedge clk_i);
        rst_n = 1'b1;
        @(posedge clk_i);

        // First transaction: should target controller instance 0.
        launch_request(
            "Controller 0 / center hit",
            to_q(0.0), to_q(0.0), to_q(-5.0),
            to_q(0.0), to_q(0.0), to_q(1.0),
            to_q(0.0), to_q(0.0), to_q(0.0),
            to_q(1.0)
        );

        // Second transaction: should target controller instance 1.
        launch_request(
            "Controller 1 / offset miss",
            to_q(3.0), to_q(0.0), to_q(-5.0),
            to_q(0.0), to_q(0.0), to_q(1.0),
            to_q(0.0), to_q(0.0), to_q(0.0),
            to_q(1.0)
        );

        // Third transaction: should target controller instance 2.
        launch_request(
            "Controller 2 / tangent",
            to_q(1.0), to_q(0.0), to_q(-5.0),
            to_q(0.0), to_q(0.0), to_q(1.0),
            to_q(0.0), to_q(0.0), to_q(0.0),
            to_q(1.0)
        );

        $display("============================================================");
        $display("RTU top-level integration smoke test complete.");
        $display("Review tb_rtu_top.vcd in GTKWave.");
        $finish;
    end

endmodule

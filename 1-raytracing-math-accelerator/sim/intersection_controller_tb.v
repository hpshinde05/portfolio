`timescale 1ns/1ps

module tb_intersection_controller;

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

    wire        busy;
    wire        done;
    wire        hit;
    wire [31:0] t_value;
    wire [1:0]  error_flags;

    integer timeout_cycles;

    initial clk_i = 1'b0;
    always #5 clk_i = ~clk_i;

    intersection_controller dut (
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
        .busy            (busy),
        .done            (done),
        .hit             (hit),
        .t_value         (t_value),
        .error_flags     (error_flags)
    );

    function [31:0] to_q;
        input real x;
        begin
            to_q = $rtoi(x * 65536.0);
        end
    endfunction

    task clear_inputs;
        begin
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
            start           = 1'b0;
        end
    endtask

    task launch_case;
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

            start = 1'b1;

            @(negedge clk_i);
            start = 1'b0;

            $display("------------------------------------------------------------");
            $display("START [%0s]", test_name);
            $display("  O = (%0d, %0d, %0d)",
                     $signed(o_x), $signed(o_y), $signed(o_z));
            $display("  D = (%0d, %0d, %0d)",
                     $signed(d_x), $signed(d_y), $signed(d_z));
            $display("  C = (%0d, %0d, %0d), r = %0d",
                     $signed(c_x), $signed(c_y), $signed(c_z),
                     $signed(radius));

            timeout_cycles = 0;

            while ((done !== 1'b1) && (timeout_cycles < 150)) begin
                @(posedge clk_i);
                timeout_cycles = timeout_cycles + 1;
            end

            if (done === 1'b1) begin
                $display("DONE  [%0s] after %0d cycles", test_name, timeout_cycles);
                $display("  hit=%b  t_value(raw)=%0d  t_value(Q16.16)=%f  errors=%b",
                         hit,
                         $signed(t_value),
                         $itor($signed(t_value)) / 65536.0,
                         error_flags);
            end else begin
                $display("TIMEOUT [%0s] after 150 cycles", test_name);
                $display("  This may indicate incomplete controller integration,");
                $display("  unavailable dependent RTL, or a pipeline/control issue.");
            end

            repeat (4) @(posedge clk_i);
        end
    endtask

    initial begin
        $dumpfile("tb_intersection_controller.vcd");
        $dumpvars(0, tb_intersection_controller);

        clear_inputs();
        rst_n = 1'b0;

        repeat (4) @(posedge clk_i);
        rst_n = 1'b1;

        @(posedge clk_i);

        // Ray: O=(0,0,-5), D=(0,0,1); sphere: C=(0,0,0), r=1.
        // Expected geometric behavior: hit, nearest t approximately 4.0.
        launch_case(
            "Center hit",
            to_q(0.0),  to_q(0.0),  to_q(-5.0),
            to_q(0.0),  to_q(0.0),  to_q(1.0),
            to_q(0.0),  to_q(0.0),  to_q(0.0),
            to_q(1.0)
        );

        // Ray offset from the sphere. Expected geometric behavior: miss.
        launch_case(
            "Offset miss",
            to_q(3.0),  to_q(0.0),  to_q(-5.0),
            to_q(0.0),  to_q(0.0),  to_q(1.0),
            to_q(0.0),  to_q(0.0),  to_q(0.0),
            to_q(1.0)
        );

        // Ray tangent to unit sphere at x=1. Expected discriminant: zero.
        launch_case(
            "Tangent case",
            to_q(1.0),  to_q(0.0),  to_q(-5.0),
            to_q(0.0),  to_q(0.0),  to_q(1.0),
            to_q(0.0),  to_q(0.0),  to_q(0.0),
            to_q(1.0)
        );

        $display("============================================================");
        $display("Intersection-controller smoke test complete.");
        $display("Review tb_intersection_controller.vcd in GTKWave.");
        $finish;
    end

endmodule

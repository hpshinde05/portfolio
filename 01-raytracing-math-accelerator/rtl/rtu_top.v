// ============================================================================
// Module:  rtu_top
// Project: Ray-Sphere Intersection Accelerator (RTU)
// Lead:    Harsh (MMIO Register Interface)
// Aux:     Ravi
// ============================================================================
//
// DESCRIPTION:
//   Top-level FPGA module that wraps the intersection_controller and
//   exposes it to the CPU (RocketChip or other) through a memory-mapped
//   register interface. This is "the top module of the top module."
//
//   The CPU writes ray and sphere parameters into input registers,
//   then sets the START bit in the control register. The RTU computes
//   the intersection and asserts an active-high interrupt when done.
//   The CPU reads back the hit flag, t value, and status.
//
// MMIO REGISTER MAP (active-high active-low TBD by RocketChip research):
//   Offset  Dir   Name             Description
//   ------  ----  ---------------  ------------------------------------
//   0x00    W     RAY_ORIGIN_X     Ray origin X component (Q16.16)
//   0x04    W     RAY_ORIGIN_Y     Ray origin Y component (Q16.16)
//   0x08    W     RAY_ORIGIN_Z     Ray origin Z component (Q16.16)
//   0x0C    W     RAY_DIR_X        Ray direction X component (Q16.16)
//   0x10    W     RAY_DIR_Y        Ray direction Y component (Q16.16)
//   0x14    W     RAY_DIR_Z        Ray direction Z component (Q16.16)
//   0x18    W     SPHERE_CENTER_X  Sphere center X (Q16.16)
//   0x1C    W     SPHERE_CENTER_Y  Sphere center Y (Q16.16)
//   0x20    W     SPHERE_CENTER_Z  Sphere center Z (Q16.16)
//   0x24    W     SPHERE_RADIUS    Sphere radius (Q16.16)
//   0x28    R/W   CONTROL          [0] = START (write 1 to begin)
//                                  [1] = BUSY  (read-only)
//                                  [2] = DONE  (read-only, sticky)
//                                  [3] = ERROR (read-only)
//                                  Write 0 to [2] to clear DONE/interrupt
//   0x2C    R     HIT_FLAG         [0] = 1 if hit, 0 if miss
//   0x30    R     T_VALUE          Intersection t parameter (Q16.16)
//   0x34    R     STATUS           [1:0] = error_flags from controller
//
// BUS INTERFACE:
//   This stub uses a simple synchronous bus with addr/wdata/rdata/wen/ren.
//   Harsh: adapt this to whatever the RocketChip TileLink / AXI / APB
//   interface provides. Research the RocketChip MMIO attachment points
//   and clock domain — the RTU clock may differ from the CPU clock.
//
// INTERRUPT:
//   Active-high interrupt line (irq) asserted when computation completes.
//   Directly usable as a PLIC source on RocketChip.
//
// ============================================================================

module rtu_top (
    input  wire        clk_i,
    input  wire        rst_n,

    // ---- Ray inputs (Q16.16) ----
    input  wire [31:0] ray_origin_x,
    input  wire [31:0] ray_origin_y,
    input  wire [31:0] ray_origin_z,
    input  wire [31:0] ray_dir_x,
    input  wire [31:0] ray_dir_y,
    input  wire [31:0] ray_dir_z,

    // ---- Sphere inputs (Q16.16) ----
    input  wire [31:0] sphere_center_x,
    input  wire [31:0] sphere_center_y,
    input  wire [31:0] sphere_center_z,
    input  wire [31:0] sphere_radius,

    // ---- Control ----
    input  wire        start,       // Pulse to begin intersection test
    //output reg         busy,        // High while computation is in progress
    output reg         done,        // Pulsed when result is ready

    // ---- Results ----
    output reg         hit,         // 1 = HIT, 0 = MISS
    output reg  [31:0] t_value     // Intersection parameter t (Q16.16)
                                    // Valid only when hit == 1
);

    reg [1:0] controller_counter; // For round-robin scheduling of multiple controllers
    wire [2:0] ic_start; // Start signals for each controller instance
    wire [2:0] ctrl_busy;
    wire [3:0] ctrl_done;
    wire [3:0] ctrl_hit;
    wire [31:0] ctrl_t_value [0:2];

    assign ic_start = (!start) ? 3'b000 :
                      (controller_counter == 0) ? 3'b001 :
                      (controller_counter == 1) ? 3'b010 :
                      (controller_counter == 2) ? 3'b100 : 3'b000;
                      
    assign ctrl_done[3] = |ctrl_done[2:0]; // Any controller done
    assign ctrl_hit[3] = |ctrl_hit[2:0];   // Any controller hit

    // Simple round-robin scheduler for 3 intersection controllers
    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            controller_counter <= 0;
            done <= 0;
            hit <= 0;
            t_value <= 0;
        end else begin
            if (start) begin
                if (controller_counter == 2'd2) begin
                    controller_counter <= 0;
                end
                else begin
                    controller_counter <= controller_counter + 1;
                end
            end

            done <= ctrl_done[3];
            hit <= ctrl_hit[3];

            case (ctrl_done[2:0])
                3'b001: t_value <= ctrl_t_value[0];
                3'b010: t_value <= ctrl_t_value[1];
                3'b100: t_value <= ctrl_t_value[2];
                default: t_value <= 0;
            endcase
        end
    end


    // -----------------------------------------------------------------------
    // Intersection Controller Instance
    // -----------------------------------------------------------------------

    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin : ic_instances
            intersection_controller u_controller (
                .clk_i            (clk_i),
                .rst_n            (rst_n),

                .ray_origin_x     (ray_origin_x),
                .ray_origin_y     (ray_origin_y),
                .ray_origin_z     (ray_origin_z),
                .ray_dir_x        (ray_dir_x),
                .ray_dir_y        (ray_dir_y),
                .ray_dir_z        (ray_dir_z),

                .sphere_center_x  (sphere_center_x),
                .sphere_center_y  (sphere_center_y),
                .sphere_center_z  (sphere_center_z),
                .sphere_radius    (sphere_radius),

                .start            (ic_start[i]),
                //.busy             (ctrl_busy[i]),
                .done             (ctrl_done[i]),

                .hit              (ctrl_hit[i]),
                .t_value          (ctrl_t_value[i])
            );
        end
    endgenerate

endmodule

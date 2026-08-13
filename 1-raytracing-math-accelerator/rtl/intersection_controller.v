// ============================================================================
// Module:  intersection_controller
// Project: Ray-Sphere Intersection Accelerator (RTU)
// Lead:    Logan
// Aux:     Harsh
// ============================================================================
//
// DESCRIPTION:
//   This is the TOP-LEVEL CONTROLLER for the ray-sphere intersection
//   accelerator. Despite being called "Intersection Controller (FSM)"
//   in the original spec, this is effectively the internal top module
//   that instantiates every compute unit and orchestrates data flow
//   through the 8-stage pipeline.
//
//   The person in charge must have a high-level understanding of how
//   all modules work and how they are timed, since different units
//   have different latencies. The FSM component manages scheduling —
//   for example, instantiating two sqrt units and alternating between
//   them if upstream data arrives faster than one unit can finish.
//
// PIPELINE STAGES (from reference doc):
//   Stage 1: Vector Setup         — L = O - C  (3 parallel subs, ~1 cycle)
//   Stage 2: Dot Products         — a, half_b, L_dot via dot_product unit
//                                   (1 unit × 3 passes, or 3 parallel units)
//   Stage 3: Quadratic Coeffs     — r_sq = r*r, c = L_dot - r_sq
//   Stage 4: Discriminant         — disc = half_b² - a*c  (discriminant unit)
//   Stage 5: Branch               — if disc < 0 → MISS, done (early exit)
//   Stage 6: Square Root          — sqrt_disc = sqrt(disc)  (~24 cycles)
//   Stage 7: t Calculation        — t = (-half_b - sqrt_disc) / a  (~32 cyc)
//   Stage 8: Sign Check & Output  — if t > 0 → HIT; else try 2nd root
//
//   Total estimated latency: ~40–60 cycles (non-pipelined).
//
// MODULE INSTANTIATIONS:
//   - fp_multiplier  (shared or dedicated, used in stages 2–4)
//   - dot_product    (1 instance reused 3×, or 3 parallel instances)
//   - discriminant   (1 instance)
//   - sqrt_unit      (1–8 instances depending on pipelining strategy)
//   - fp_divider     (1 instance, or bypassed if D is pre-normalized)
//
// RESOURCE SHARING STRATEGY (recommended for first tapeout):
//   Single dot-product unit with 3 multipliers, reused over 3 passes.
//   This gives ~50-cycle latency with medium area — a good balance
//   between performance and verifiability.
//
// ============================================================================

module intersection_controller (
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
    output reg         busy,        // High while computation is in progress
    output reg         done,        // Pulsed when result is ready

    // ---- Results ----
    output reg         hit,         // 1 = HIT, 0 = MISS
    output reg  [31:0] t_value,     // Intersection parameter t (Q16.16)
                                    // Valid only when hit == 1
    output reg  [1:0]  error_flags  // [0] = div_by_zero, [1] = reserved
);

    // -----------------------------------------------------------------------
    // TODO: Implementation
    //   - FSM state register and next-state logic
    //   - Instantiate submodules:
    //       * dot_product   dot_prod_inst  (.clk, .rst_n, ...);
    //       * discriminant  disc_inst      (.clk, .rst_n, ...);
    //       * sqrt_units     sqrt_inst      (.clk, .rst_n, ...);
    //       * fp_multiplier mul_inst       (.clk, .rst_n, ...);
    //         (for r*r in stage 3; may share with dot_product internals)
    //   - Mux input vectors into the shared dot_product unit per state
    //   - Latch intermediate results into stage registers
    //   - Handle early-exit on MISS at S_BRANCH
    //   - Handle two-root check at S_CHECK (try second root if first t <= 0)
    //   - Drive outputs: hit, t_value, done, error_flags
    // -----------------------------------------------------------------------

    // -----------------------------------------------------------------------
    // FSM State Register
    // -----------------------------------------------------------------------

    reg [1:0] state0;
    wire [1:0] state1, state2;

    // -----------------------------------------------------------------------
    // Internal Signals
    // -----------------------------------------------------------------------
    reg signed [31:0] O_x, O_y, O_z; // Ray origin
    reg signed [31:0] D_x, D_y, D_z; // Ray direction
    reg signed [31:0] C_x, C_y, C_z; // Sphere center
    reg signed [31:0] r; // Sphere radius
    
    reg signed [31:0] a_x, a_y, a_z; // Dot product vector A
    reg signed [31:0] b_x, b_y, b_z; // Dot product vector B
    wire [1:0] dot_valid_in, dot_valid_out;
    wire signed [31:0] dot_result; // Dot product result

    wire [1:0] disc_valid_in, disc_valid_out;
    reg  signed [31:0] disc_in1, disc_in2; 
    wire signed [31:0] disc_out;
    wire disc_is_miss;

    wire signed [31:0] L_x, L_y, L_z; // Stage 1 outputs

    reg [31:0] a_prod [0:2]; // For storing intermediate products if needed for pipelining
    wire [31:0] c_prod; // Ldot - r_sq product
    reg [31:0] half_b_sq; // For storing half_b^2 if needed for pipelining

    wire signed [31:0] disc_comb; // combinational discriminant result for early exit check
    wire disc_valid; // valid signal for the registered discriminant

    wire signed [31:0] sqrt_disc; // Output of sqrt unit
    wire sqrt_valid_out; // Valid signal from sqrt unit
    wire sqrt_busy; // Busy signal from sqrt unit
    wire sqrt_is_miss; // MISS signal from sqrt unit (if it has its own early exit check)
    wire signed [31:0] sqrt_half_b_out; // half_b output from sqrt unit for timing alignment
    reg signed [31:0] sqrt_disc_reg; // Registered sqrt_disc for timing alignment with the pipeline
    reg signed [31:0] sqrt_half_b_reg; // Registered half_b from sqrt unit for timing alignment
    reg sqrt_is_miss_reg; // Registered MISS signal from sqrt unit for timing alignment
    reg sqrt_is_valid_reg; // Registered valid signal from sqrt unit for timing alignment

    wire signed [31:0] numerator; // -half_b - sqrt_disc
    wire signed [31:0] t_candidate; // Result of division for t calculation
    wire t_valid; // Signal indicating t_candidate is valid and can be checked for HIT/MISS

    // -----------------------------------------------------------------------
    // Submodule Instantiations
    // -----------------------------------------------------------------------
    dot_product dot_prod_inst(
        .clk_i(clk_i),
        .rst_n(rst_n),
        // Vector A components (Q16.16 signed)
        .a_x(a_x),
        .a_y(a_y),
        .a_z(a_z),
        // Vector B components (Q16.16 signed)
        .b_x(b_x),
        .b_y(b_y),
        .b_z(b_z),
        // Control
        .ctrl_in(dot_valid_in),
        .ctrl_out(dot_valid_out),
        // Result (Q16.16 scalar)
        .result(dot_result)
    );
    
    fp_multiplier mul_inst( // takes place of discriminant multipliers
        .clk_i(clk_i),
        .rst_n(rst_n),
        .a(disc_in1),
        .b(disc_in2),
        .ctrl_in(disc_valid_in),
        .ctrl_out(disc_valid_out),
        .product(disc_out)
    );

    sqrt_array sqrt_inst(
        .clk_i(clk_i),
        .rst_n(rst_n),
        .radicand(disc_comb),
        .half_b(a_prod[2]), // should be "half_b" from stage 2
        .miss(disc_is_miss),
        .start(disc_valid), // Start sqrt when discriminant is valid
        .busy(sqrt_busy), // Not used in this example, but can be used for flow control
        .valid_out(sqrt_valid_out), // Can be used to trigger next stage when sqrt is done
        .root(sqrt_disc), // Output of sqrt to be used in t calculation
        .is_miss(sqrt_is_miss), // Can be used to confirm MISS condition if needed
        .half_b_out(sqrt_half_b_out) // Output half_b for timing alignment if needed
    );

    // -----------------------------------------------------------------------
    // Stage 0: Registering Inputs
    // -----------------------------------------------------------------------
    always@(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers and outputs
            busy <= 1'b0;
            done <= 1'b0;
            hit <= 1'b0;
            t_value <= 32'd0;
            error_flags <= 2'b00;

            O_x <= 32'd0;
            O_y <= 32'd0;
            O_z <= 32'd0;
            D_x <= 32'd0;
            D_y <= 32'd0;
            D_z <= 32'd0;
            C_x <= 32'd0;
            C_y <= 32'd0;
            C_z <= 32'd0;
            r <= 32'd0;

            state0 <= 0;
            a_prod[0] <= 32'd0;
            a_prod[1] <= 32'd0;
            a_prod[2] <= 32'd0;
            half_b_sq <= 32'd0;
            sqrt_disc_reg <= 32'd0;
            sqrt_half_b_reg <= 32'd0;
            sqrt_is_miss_reg <= 1'b0;
            sqrt_is_valid_reg <= 1'b0;

        end else begin
            a_prod[0] <= dot_result; // should be "a" when needed
            a_prod[1] <= a_prod[0]; // Shift product pipeline
            a_prod[2] <= a_prod[1]; // Shift product pipeline
            half_b_sq <= disc_out; // Store half_b^2 for stage 4

            sqrt_disc_reg <= sqrt_disc; // Register sqrt_disc for timing alignment
            sqrt_half_b_reg <= sqrt_half_b_out; // Register half_b from sqrt unit for timing alignment
            sqrt_is_miss_reg <= sqrt_is_miss; // Register MISS signal from sqrt unit for timing alignment
            sqrt_is_valid_reg <= sqrt_valid_out; // Register valid signal from sqrt unit for timing alignment

            hit <= t_valid && sqrt_is_valid_reg;
            t_value <= t_candidate;
            done <= sqrt_is_valid_reg; // Done when sqrt output is valid (t is calculated and can be checked for HIT/MISS)

            if (start) begin
                O_x <= ray_origin_x;
                O_y <= ray_origin_y;
                O_z <= ray_origin_z;
                D_x <= ray_dir_x;
                D_y <= ray_dir_y;
                D_z <= ray_dir_z;
                C_x <= sphere_center_x;
                C_y <= sphere_center_y;
                C_z <= sphere_center_z;
                r <= sphere_radius;
            end

            // state0 next state logic
            if (state0 == 2'd0) begin
                if (start) begin
                    state0 <= 1;
                end
            end
            else if (state0 == 2'd3) begin
                if (start) begin
                   state0 <= 1; 
                end
                else begin
                    state0 <= 0;
                end
            end
            else begin
                state0 <= state0 + 1;
            end

        end
    end

    always@(*) begin
        case(state0) 
            2'd1: begin // calculate "a"
                a_x = D_x;
                a_y = D_y;
                a_z = D_z;
                b_x = D_x;
                b_y = D_y;
                b_z = D_z;
            end
            2'd2: begin // calculate "half_b"
                a_x = L_x;
                a_y = L_y;
                a_z = L_z;
                b_x = D_x;
                b_y = D_y;
                b_z = D_z;
            end
            2'd3: begin // calculate "L_dot"
                a_x = L_x;
                a_y = L_y;
                a_z = L_z;
                b_x = L_x;
                b_y = L_y;
                b_z = L_z;
            end
            default: begin
                a_x = 32'd0;
                a_y = 32'd0;
                a_z = 32'd0;
                b_x = 32'd0;
                b_y = 32'd0;
                b_z = 32'd0;
            end
        endcase

        case (state1)
            2'd1: begin // calculate "rsq"
                disc_in1 = r;
                disc_in2 = r;
            end
            2'd2: begin // calculate "half_b^2"
                disc_in1 = dot_result; // should be "half_b" from stage 2
                disc_in2 = dot_result;
            end
            2'd3: begin // calculate "a*c"
                disc_in1 = a_prod[1]; // should be "a" from stage 2
                disc_in2 = c_prod;    // should be "c" from stage 3
            end
            default: begin
                disc_in1 = 32'd0;
                disc_in2 = 32'd0;
            end
        endcase
    end

    assign L_x = O_x - C_x;
    assign L_y = O_y - C_y;
    assign L_z = O_z - C_z;

    assign dot_valid_in = state0;
    assign disc_valid_in = dot_valid_out;
    assign state1 = disc_valid_in;

    assign c_prod = dot_result - disc_out;
    assign disc_comb = half_b_sq - disc_out; // combinational discriminant for early exit
    assign disc_is_miss = disc_comb[31]; // Sign bit indicates if disc < 0
    assign state2 = disc_valid_out;
    assign disc_valid = (state2 == 2'd3); // Discriminant is valid in state 3

    assign numerator = -sqrt_half_b_reg - sqrt_disc_reg; // Calculate numerator for t using registered values for timing alignment
    assign t_candidate = numerator; // For simplicity, we can assume a pre-normalized D where division by a is just a shift, no divider needed
    assign t_valid = !sqrt_is_miss_reg && !t_candidate[31]; // t is valid when sqrt output is valid and t_candidate is positive

endmodule

module sqrt_array #(
  	parameter INT_WIDTH 		= 16,
  	parameter FRAC_WIDTH 		= 16)
  (
    input  wire        clk_i,
    input  wire        rst_n,

    // Input (Q16.16, must be non-negative)
    input  wire signed [INT_WIDTH + FRAC_WIDTH -1 :0] radicand,
    input  wire signed [31:0] half_b,
    input  wire miss, // Signal indicating if the discriminant is negative (MISS)

    // Control
    input  wire        start,      // Pulse to begin computation
    output wire        busy,       // High while computing
    output wire        valid_out,  // Pulsed when result is ready

    // Result (Q16.16)
    output reg signed [INT_WIDTH + FRAC_WIDTH -1 :0] root,
    output reg  is_miss,    // High if radicand was negative (MISS)
    output reg signed [31:0]  half_b_out // half_b for timing alignment with the pipeline
);

reg [2:0] sqrt_state; // State register for controlling the sqrt array FSM
reg [31:0] half_b_reg [0:7]; // Register to hold half_b for timing alignment
reg miss_reg [0:7]; // Register to hold miss signal for timing alignment
wire [31:0] sqrt_result [0:7]; // Output from the sqrt unit
wire [31:0] sqrt_radicand; // Input to the sqrt unit
wire [7:0] sqrt_valid_out; // Valid signal from the sqrt unit
wire [7:0] sqrt_busy; // Busy signal from the sqrt unit
reg [7:0] sqrt_start; // Start signals for each sqrt instance

assign sqrt_radicand = miss ? 32'd0 : radicand; // If MISS, set radicand to 0 to avoid invalid sqrt
assign valid_out = |sqrt_valid_out; // valid_out is high if any of the sqrt units has a valid output
assign busy = |sqrt_busy; // busy is high if any of the sqrt units is busy

always@(*) begin
    if (!start) sqrt_start = 8'b00000000; // No sqrt starts if not starting
    else case (sqrt_state) // assign sqrt_start
        3'd0: sqrt_start = 8'b00000001; // Start first sqrt
        3'd1: sqrt_start = 8'b00000010; // Start second sqrt
        3'd2: sqrt_start = 8'b00000100; // Start third sqrt
        3'd3: sqrt_start = 8'b00001000; // Start fourth sqrt
        3'd4: sqrt_start = 8'b00010000; // Start fifth sqrt
        3'd5: sqrt_start = 8'b00100000; // Start sixth sqrt
        3'd6: sqrt_start = 8'b01000000; // Start seventh sqrt
        3'd7: sqrt_start = 8'b10000000; // Start eighth sqrt
        default: sqrt_start = 8'b00000000;
    endcase

    case (sqrt_valid_out) // assign root and valid_out
        8'b00000001: begin
            root = sqrt_result[0];
            is_miss = miss_reg[0]; // Output the registered miss signal for timing alignment
            half_b_out = half_b_reg[0]; // Output the registered half_b for timing alignment
        end
        8'b00000010: begin
            root = sqrt_result[1];
            is_miss = miss_reg[1];
            half_b_out = half_b_reg[1];
        end
        8'b00000100: begin
            root = sqrt_result[2];
            is_miss = miss_reg[2];
            half_b_out = half_b_reg[2];
        end
        8'b00001000: begin
            root = sqrt_result[3];
            is_miss = miss_reg[3];
            half_b_out = half_b_reg[3];
        end
        8'b00010000: begin
            root = sqrt_result[4];
            is_miss = miss_reg[4];
            half_b_out = half_b_reg[4];
        end
        8'b00100000: begin
            root = sqrt_result[5];
            is_miss = miss_reg[5];
            half_b_out = half_b_reg[5];
        end
        8'b01000000: begin
            root = sqrt_result[6];
            is_miss = miss_reg[6];
            half_b_out = half_b_reg[6];
        end
        8'b10000000: begin
            root = sqrt_result[7];
            is_miss = miss_reg[7];
            half_b_out = half_b_reg[7];
        end
        default: begin
            root = 32'd0;
            is_miss = 1'b0;
            half_b_out = 32'd0;
        end
    endcase
end

// generate block to make 8 instances of the sqrt module
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : sqrt_instances
            sqrt_unit sqrt_inst (
                .clk_i(clk_i),
                .rst_n(rst_n),
                .radicand(sqrt_radicand),
                .start(sqrt_start[i]),
                .busy(sqrt_busy[i]),
                .valid_out(sqrt_valid_out[i]),
                .root(sqrt_result[i])
            );
        end
    endgenerate

always@(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin
        sqrt_state <= 0;
        half_b_reg[0] <= 32'd0;
        half_b_reg[1] <= 32'd0;
        half_b_reg[2] <= 32'd0;
        half_b_reg[3] <= 32'd0;
        half_b_reg[4] <= 32'd0;
        half_b_reg[5] <= 32'd0;
        half_b_reg[6] <= 32'd0;
        half_b_reg[7] <= 32'd0;
        miss_reg[0] <= 1'b0;
        miss_reg[1] <= 1'b0;
        miss_reg[2] <= 1'b0;
        miss_reg[3] <= 1'b0;
        miss_reg[4] <= 1'b0;
        miss_reg[5] <= 1'b0;
        miss_reg[6] <= 1'b0;
        miss_reg[7] <= 1'b0;
    end else begin
        if (start) begin
            sqrt_state <= sqrt_state + 1; // Move to next state on each start pulse
            half_b_reg[sqrt_state] <= half_b; // Register half_b for timing alignment
            miss_reg[sqrt_state] <= miss; // Register miss signal for timing alignment
        end
    end
end

endmodule

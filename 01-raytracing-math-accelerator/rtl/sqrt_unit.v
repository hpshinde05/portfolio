// ============================================================================
// Module:  sqrt_unit
// Project: Ray-Sphere Intersection Accelerator (RTU)
// Lead:    Ravi
// Aux:     Visnu
// ============================================================================
//
// DESCRIPTION:
//   Computes the integer square root of a Q16.16 fixed-point value
//   using a bit-by-bit (non-restoring) algorithm. Purely iterative
//   with shift/add/compare — no lookup tables or DSP blocks needed.
//
//   This is the key module of the entire accelerator and the reason
//   the RTU is useful as a hardware unit: square root is extremely
//   expensive in software but compact in dedicated logic.
//
//   Input:  32-bit Q16.16 non-negative value (the discriminant)
//   Output: 32-bit Q16.16 square root of that value
//
// ALGORITHM (bit-by-bit / non-restoring):
//   For a Q16.16 input, we need the square root to also be Q16.16.
//   To achieve this, treat the input as a 48-bit integer by
//   left-shifting it by 16 (so sqrt of the shifted value gives a
//   Q16.16 result directly). Then perform standard binary square
//   root bit extraction over 24 bits (covering 8 integer + 16 frac).
//
// TIMING:
//   ~24 clock cycles per computation (1 bit resolved per cycle).
//   This is the second-most-expensive operation after division.
//
// PIPELINING NOTE (from Ravi's spec):
//   Because this unit is small and self-contained, multiple instances
//   can be instantiated in the controller to prevent it from becoming
//   a bottleneck. The spec envisions up to 8 instances in a fully
//   pipelined FSM, switching between them as upstream data arrives.
//
// HARDWARE COST:
//   Comparator + subtractor + shift register + control counter.
//   Very small — "most self-contained module, great for one person
//   to own" (reference doc).
//
// ============================================================================

module sqrt_unit #(
  	parameter INT_WIDTH 		= 16,
  	parameter FRAC_WIDTH 		= 16)
  (
    input  wire        clk_i,
    input  wire        rst_n,

    // Input (Q16.16, must be non-negative)
    input  wire [INT_WIDTH + FRAC_WIDTH -1 :0] radicand,

    // Control
    input  wire        start,      // Pulse to begin computation
    output reg         busy,       // High while computing
    output reg         valid_out,  // Pulsed when result is ready

    // Result (Q16.16)
    output reg  [INT_WIDTH + FRAC_WIDTH -1 :0] root
);

    // -----------------------------------------------------------------------
    // TODO: Implementation
    //   - On `start`: latch radicand, left-shift by 16 into 48-bit working reg
    //   - Iterate 24 times (1 bit per cycle, MSB first):
    //       * Trial subtraction: remainder -= (current_root_guess << 1 | 1)
    //       * If remainder >= 0: keep subtraction, set bit in result
    //       * If remainder <  0: restore remainder, leave bit as 0
    //   - After 24 cycles: assert valid_out, output root
    // -----------------------------------------------------------------------
  
  // Local parameters
  localparam ITERATION		= (INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH)/2;
  localparam ITERATION_WIDTH 	= $clog2(ITERATION);
  
  // Register declarations
  reg [INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH -1:0] 	radicand_d;	// Latched input and left shifted by 2 for every iteration
  reg [INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH +1:0] 	acc;	
  reg [INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH +1:0] 	test;
  reg [INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH -1:0] 	quotient;
  reg [INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH -1:0] 	radicand_d_next;
  reg [INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH +1:0] 	acc_next;
  reg [INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH +1:0] 	test_next;
  reg [INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH -1:0] 	quotient_next;
  
  reg [ITERATION_WIDTH -1:0] 				counter;	// Iteration counter
  
  // Square root logic

  // Combinational logic
  always@(*) begin
    test_next	= acc - {quotient,2'b01};
    if(test_next[INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH +1] == 0) begin	// If a positive test value
      acc_next = {(test_next << 2) | radicand_d[INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH -2 +:  2]};
      quotient_next = (quotient << 1) | 1'b1;
      radicand_d_next = radicand_d << 2;
    end
    else begin	// If a negative test value
      acc_next = {(acc << 2) | radicand_d[INT_WIDTH + FRAC_WIDTH + FRAC_WIDTH -2 +:  2]};
      quotient_next = (quotient << 1);
      radicand_d_next = radicand_d << 2;
    end
  end
  
  // Sequential logic
  always@(posedge clk_i or negedge rst_n) begin
    if(~rst_n) begin
      radicand_d 	<= 'b0;
      acc 			<= 'b0;
      test 			<= 'b0;
      quotient 		<= 'b0;
      counter 		<= 'b0;
      busy			<= 'b0;
      valid_out		<= 'b0;
      root			<= 'b0;
    end
    else begin
      // Process only one input at a time. Hence, once started, complete the entire iteration
      if(busy) begin	
        if(counter > 0) begin
          	acc 		<= acc_next;
          	radicand_d 	<= radicand_d_next;
          	counter 	<= counter - 1'b1;
        	test 		<= test_next;
        	quotient 	<= quotient_next;
        end
        else begin
        	counter 	<= ITERATION-1;
          	busy 		<= 1'b0;
          	valid_out	<= 1'b1;
          	root		<= quotient_next;
        end
      end
      // Start a new iteration only when the pipeline is not busy
      else if(start) begin
        {acc,radicand_d} <= (radicand << (FRAC_WIDTH + 2));	// Latch the left shifted version of input 
        test		<= 'b0;	// Clear the reg
        quotient	<= 'b0;	// Clear the reg
        counter 	<= ITERATION-1;	// Set the counter
        busy 		<= 1'b1;
      end
      // Assert valid only for a single cycle
      else begin
        valid_out <= 'b0;
      end
    end
  end
  
endmodule

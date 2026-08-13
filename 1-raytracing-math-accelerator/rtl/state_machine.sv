module state_machine (
    // Clock and reset
    input  wire        clk_i,
    input  wire        rst_n_i,
    // Inputs from MCU
    input  wire        trigger_i,
    // Outputs to MCU
    output wire        pulse_trigger_o,
    // Inputs from AFE
    input  wire        comp_i,
    input  wire        analog_ready_i,
    // Outputs to AFE
    output wire        idle_o,
    output wire        auto_zero_o,
    output wire        integrate_o,
    output wire        deintegrate_o,
    output wire        ref_sign_o,
    // Inputs from Counters
    input  wire [4:0]  cycle_count_i,
    input  wire [9:0]  pulse_count_i,
    input  wire [11:0] measurement_count_i,
    // Outputs to Counters
    output wire        measurement_en_o,
    output wire        measurement_clear_o
);

    //------------------------------------------------------------------------------
    // State and Range Parameters
    //------------------------------------------------------------------------------
    localparam S_IDLE        = 2'd0, 
               S_AUTO_ZERO   = 2'd1, 
               S_INTEGRATE   = 2'd2, 
               S_DEINTEGRATE = 2'd3;

    localparam R1 = 2'b00, R2 = 2'b01, R3 = 2'b10, R4 = 2'b11;

    // Cycle Constants
    localparam CYC_AZ1 = 5'd1,  CYC_INT1 = 5'd2,  CYC_DEINT1 = 5'd6;
    localparam CYC_AZ2 = 5'd3,  CYC_INT2 = 5'd4,  CYC_DEINT2 = 5'd8;
    localparam CYC_AZ3 = 5'd5,  CYC_INT3 = 5'd6,  CYC_DEINT3 = 5'd10;
    localparam CYC_AZ4 = 5'd7,  CYC_INT4 = 5'd17, CYC_DEINT4 = 5'd21;
    localparam CYC_MAX = 5'd24;

    //------------------------------------------------------------------------------
    // Registers
    //------------------------------------------------------------------------------
    reg [1:0]  curr_state, next_state;
    reg [1:0]  curr_range, next_range;
    reg [4:0]  tgt_cyc,    next_tgt_cyc;
    reg [9:0]  tgt_pulse,  next_tgt_pulse;
    reg [3:0]  afe_ctrl,   next_afe_ctrl; // [3]=idle, [2]=az, [1]=int, [0]=deint
    reg        trig_latch, next_trig_latch;
    reg        comp_latch;

    //------------------------------------------------------------------------------
    // Sequential Block
    //------------------------------------------------------------------------------
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            curr_state <= S_IDLE;
            curr_range <= R1;
            tgt_cyc    <= CYC_AZ1;
            tgt_pulse  <= 10'd9;
            afe_ctrl   <= 4'b1000;
            trig_latch <= 1'b0;
            comp_latch <= 1'b0;
        end else begin
            curr_state <= next_state;
            curr_range <= next_range;
            tgt_cyc    <= next_tgt_cyc;
            tgt_pulse  <= next_tgt_pulse;
            afe_ctrl   <= next_afe_ctrl;
            trig_latch <= next_trig_latch;
            if (curr_state == S_INTEGRATE && next_state == S_DEINTEGRATE)
                comp_latch <= comp_i;
        end
    end

    //------------------------------------------------------------------------------
    // Combinational Logic
    //------------------------------------------------------------------------------
    always @(*) begin
        // Defaults
        next_state      = curr_state;
        next_trig_latch = (trigger_i) ? 1'b1 : trig_latch;
        next_tgt_cyc    = tgt_cyc;
        next_range      = curr_range;
        next_tgt_pulse  = tgt_pulse;

        case (curr_state)
            S_IDLE: begin
                if (trig_latch && analog_ready_i) begin
                    next_state = S_AUTO_ZERO;
                    next_trig_latch = 1'b0;
                    next_tgt_cyc = CYC_AZ1;
                    next_range = R1;
                    next_tgt_pulse = 10'd9;
                end
            end

            S_AUTO_ZERO: begin
                if (cycle_count_i == tgt_cyc) begin
                    next_state = S_INTEGRATE;
                    case (tgt_cyc)
                        CYC_AZ1: next_tgt_cyc = CYC_INT1;
                        CYC_AZ2: next_tgt_cyc = CYC_INT2;
                        CYC_AZ3: next_tgt_cyc = CYC_INT3;
                        CYC_AZ4: next_tgt_cyc = CYC_INT4;
                    endcase
                end else if (cycle_count_i == CYC_MAX) begin
                    next_state = S_IDLE;
                end
            end

            S_INTEGRATE: begin
                if (cycle_count_i == tgt_cyc) begin
                    next_state = S_DEINTEGRATE;
                    case (tgt_cyc)
                        CYC_INT1: next_tgt_cyc = CYC_DEINT1;
                        CYC_INT2: next_tgt_cyc = CYC_DEINT2;
                        CYC_INT3: next_tgt_cyc = CYC_DEINT3;
                        CYC_INT4: next_tgt_cyc = CYC_DEINT4;
                    endcase
                end
                // Pulse logic for distributed integration (R1/R2)
                if (pulse_count_i == tgt_pulse && (curr_range == R1 || curr_range == R2))
                    next_tgt_pulse = tgt_pulse + 10'd1;
            end

            S_DEINTEGRATE: begin
                if ((cycle_count_i == tgt_cyc) || (comp_i != comp_latch)) begin
                    next_state = S_AUTO_ZERO;
                    // Autoranging and Target Update
                    if (tgt_cyc == CYC_DEINT4 || measurement_count_i >= 12'd360) begin
                        next_tgt_cyc   = CYC_AZ1;
                        next_range     = R1;
                        next_tgt_pulse = 10'd9;
                    end else begin
                        case (tgt_cyc)
                            CYC_DEINT1: begin next_tgt_cyc = CYC_AZ2; next_range = R2; next_tgt_pulse = 10'd99; end
                            CYC_DEINT2: begin next_tgt_cyc = CYC_AZ3; next_range = R3; end
                            CYC_DEINT3: begin next_tgt_cyc = CYC_AZ4; next_range = R4; end
                        endcase
                    end
                end
            end
        endcase
    end

    // AFE Control Signal Mapping
    always @(*) begin
        next_afe_ctrl = 4'b0000;
        case (next_state)
            S_IDLE:        next_afe_ctrl[3] = 1'b1;
            S_AUTO_ZERO:   next_afe_ctrl[2] = 1'b1;
            S_DEINTEGRATE: next_afe_ctrl[0] = 1'b1;
            S_INTEGRATE: begin
                if ((curr_range == R1 || curr_range == R2) && (pulse_count_i == tgt_pulse))
                    next_afe_ctrl[3] = 1'b1; // Pulse high = idle (low sensitivity mode)
                else
                    next_afe_ctrl[1] = 1'b1;
            end
        endcase
    end

    //------------------------------------------------------------------------------
    // Output Logic
    //------------------------------------------------------------------------------
    assign idle_o              = afe_ctrl[3];
    assign auto_zero_o         = afe_ctrl[2];
    assign integrate_o         = afe_ctrl[1];
    assign deintegrate_o       = afe_ctrl[0];
    
    assign ref_sign_o          = ~comp_i;
    assign measurement_en_o    = (curr_state == S_DEINTEGRATE && next_state != S_AUTO_ZERO);
    assign measurement_clear_o = (curr_state == S_INTEGRATE   && next_state == S_DEINTEGRATE);
    assign pulse_trigger_o     = (curr_state == S_IDLE        && next_state == S_AUTO_ZERO);

endmodule
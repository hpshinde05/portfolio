
module lab3_behavioral(
    input [1:0] x,
    input init,
    input clk,
    output reg dispense,
    output reg [1:0] change,
    output reg [1:0] q
);

    reg [1:0] next_q;

    always @ (posedge clk or negedge init) begin
        if(!init) q <= 2'b0;
        else q <= next_q;
    end

    always @(*) begin
        case(q)
            2'b00: begin
                change = 2'b00;
                dispense = 0;
                case(x)
                    2'b00: next_q = 2'b00;
                    2'b01: next_q = 2'b01;
                    2'b10: next_q = 2'b00;
                endcase
            end
            2'b01: begin
                case(x)
                    2'b00: begin
                        next_q = 2'b01;
                        change = 2'b00;
                        dispense = 0;
                    end
                    2'b01: begin
                        next_q = 2'b10;
                        change = 2'b00;
                        dispense = 0;
                    end
                    2'b10: begin
                        next_q = 2'b00;
                        change = 2'b01;
                        dispense = 0;
                    end
                endcase
            end
            2'b10: begin
                case(x)
                    2'b00: begin
                        next_q = 2'b00;
                        change = 2'b00;
                        dispense = 1;
                    end
                    2'b01: begin
                        next_q = 2'b10;
                        change = 2'b01;
                        dispense = 0;
                    end
                    2'b10: begin
                        next_q = 2'b00;
                        change = 2'b10;
                        dispense = 0;
                    end
                endcase
            end
            default: begin
                next_q = 2'b00;
                change = 2'b00;
                dispense = 0;
            end
        endcase
    end
endmodule


module vend_struct_tb();

    initial begin
        $dumpfile("test_struct_vend_tb.vcd");
        $dumpvars(0, vend_struct_tb);
    end
    
    reg [1:0] x;
    reg init;
    reg clk;
    wire dispense;
    wire [1:0] change;
    wire [1:0] state;

    lab3_structural uut(.x(x), .init(init), .clk(clk), .dispense(dispense), .change(change), .q(state));

    always begin
        #5
        clk = ~clk;
    end

    localparam NICKEL = 2'b1;
    localparam SELECT = 2'b0;
    localparam COIN_RET = 2'b10;

    integer outfile;
    initial begin
        outfile = $fopen("out.txt", "w");
        $fdisplay(outfile, "\nTesting selecting water from states 01 and 10:\n");
        x = NICKEL;
        init = 1;
        clk = 0;
        #1
        init = 0;
        #5
        init = 1;
        x = NICKEL;
        #1
        $fdisplay(outfile, "State:    %b\tx: %b\tChange: %b\tDisp: %b\nExpected: %b\t   %b\t        %b\t      %b\n", 
            state, x, change, dispense,
            2'b0, x, 2'b0, 1'b0); 
        #9
        x = SELECT;
        #1
        $fdisplay(outfile, "State:    %b\tx: %b\tChange: %b\tDisp: %b\nExpected: %b\t   %b\t        %b\t      %b\n", 
            state, x, change, dispense,
            2'b1, x, 2'b0, 1'b0); 
        #9
        x = NICKEL;
        #1
        $fdisplay(outfile, "State:    %b\tx: %b\tChange: %b\tDisp: %b\nExpected: %b\t   %b\t        %b\t      %b\n", 
            state, x, change, dispense,
            2'b1, x, 2'b0, 1'b0); 
        #9
        x = NICKEL;
        #1
        $fdisplay(outfile, "State:    %b\tx: %b\tChange: %b\tDisp: %b\nExpected: %b\t   %b\t        %b\t      %b\n", 
            state, x, change, dispense,
            2'b10, x, 2'b01, 1'b0); 
        #9
        x = SELECT;
        #1
        $fdisplay(outfile, "State:    %b\tx: %b\tChange: %b\tDisp: %b\nExpected: %b\t   %b\t        %b\t      %b\n", 
            state, x, change, dispense,
            2'b10, x, 2'b0, 1'b1); 
        #9
        x = NICKEL;
        #1
        $fdisplay(outfile, "State:    %b\tx: %b\tChange: %b\tDisp: %b\nExpected: %b\t   %b\t        %b\t      %b\n", 
            state, x, change, dispense,
            2'b0, x, 2'b0, 1'b0); 
        #9

        $finish;
    end

endmodule

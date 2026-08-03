`timescale 1ns/1ps

module alu_fix2(
    input   logic   signed  [7:0] a, b,
    input   logic           [1:0] op,
    output  logic   signed  [7:0] y
);
    
    always_comb begin
        y = '0; 
        case (op)
            2'b00: y = a + b;
            2'b01: y = a - b;
            2'b10: y = a & b;
        endcase
    end

endmodule
`timescale 1ns/1ps
//=====================================================================
//  Ejercicio 6 -- Variantes de la misma ALU combinacional
//=====================================================================

// ---------------------------------------------------------------
// Version original: case incompleto -> la sintesis infiere latch
// ---------------------------------------------------------------
module alu_buggy (
    input  logic signed [7:0] a, b,
    input  logic        [1:0] op,
    output logic signed [7:0] y
);
    always_comb begin
        case (op)
            2'b00: y = a + b;
            2'b01: y = a - b;
            2'b10: y = a & b;
        endcase
    end
endmodule

// ---------------------------------------------------------------
// Fix 1: rama default dentro del case
// ---------------------------------------------------------------
module alu_fix1 (
    input  logic signed [7:0] a, b,
    input  logic        [1:0] op,
    output logic signed [7:0] y
);
    always_comb begin
        case (op)
            2'b00:   y = a + b;
            2'b01:   y = a - b;
            2'b10:   y = a & b;
            default: y = '0;
        endcase
    end
endmodule

// ---------------------------------------------------------------
// Fix 2: pre-asignacion incondicional antes del case
// ---------------------------------------------------------------
module alu_fix2 (
    input  logic signed [7:0] a, b,
    input  logic        [1:0] op,
    output logic signed [7:0] y
);
    always_comb begin
        y = '0;                    // valor de reposo, incondicional
        case (op)
            2'b00: y = a + b;
            2'b01: y = a - b;
            2'b10: y = a & b;
        endcase
    end
endmodule

// ---------------------------------------------------------------
// Variante descartada (alt): cuarta rama explicita 2'b11
// Se incluye solo como evidencia: completa los opcodes legales
// pero no cubre op con bits en X o Z.
// ---------------------------------------------------------------
module alu_alt (
    input  logic signed [7:0] a, b,
    input  logic        [1:0] op,
    output logic signed [7:0] y
);
    always_comb begin
        case (op)
            2'b00: y = a + b;
            2'b01: y = a - b;
            2'b10: y = a & b;
            2'b11: y = '0;
        endcase
    end
endmodule

`timescale 1ns/1ps

module mod_mult_lut #(
    parameter integer MOD = 7,   // módulo del canal
    parameter integer W   = 3    // ancho de cada residuo
) (
    a, b, val
);
    input  wire [W-1:0] a;
    input  wire [W-1:0] b;
    output wire [W-1:0] val;

    localparam integer DEPTH = 1 << (2*W);   // 64 para W=3

    reg [W-1:0] tabla [0:DEPTH-1];
    integer i, ai, bi;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            ai = i >> W;             // mitad alta  → operando a
            bi = i & ((1 << W) - 1);  // mitad baja  → operando b
            tabla[i] = (ai * bi) % MOD;
        end
    end

    assign val = tabla[{a, b}];

endmodule
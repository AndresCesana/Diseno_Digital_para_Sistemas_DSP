module mod_lut #(
    parameter integer MOD   = 7,   // módulo de reducción
    parameter integer IN_W  = 6,   // ancho del índice
    parameter integer OUT_W = 3    // ancho del resultado
) (
    input  wire [IN_W-1:0]  idx,
    output wire [OUT_W-1:0] val
);
    reg [OUT_W-1:0] tabla [0:(1<<IN_W)-1];
    integer i;

    initial
        for (i = 0; i < (1<<IN_W); i = i + 1)
            tabla[i] = i % MOD;      // ← i es variable de lazo, no señal

    assign val = tabla[idx];
endmodule
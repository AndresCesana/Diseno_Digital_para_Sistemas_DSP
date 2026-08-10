module suma_punto_fijo #(
    parameter integer NB1  = 6,
    parameter integer NBF1 = 4,
    parameter integer NB2  = 8,
    parameter integer NBF2 = 5,
    parameter integer NBI1 = NB1 - NBF1,
    parameter integer NBI2 = NB2 - NBF2,
    parameter integer NBFO = (NBF1 > NBF2) ? NBF1 : NBF2,
    parameter integer NBIO = ((NBI1 > NBI2) ? NBI1 : NBI2) + 1,
    parameter integer NBO  = NBIO + NBFO
)(
    input  wire signed [NB1-1:0] a,
    input  wire signed [NB2-1:0] b,
    output wire signed [NBO-1:0] o
);

    wire signed [NBO-1:0] a_ext, b_ext;

    // extensión de signo a la izquierda + relleno de ceros a la derecha
    assign a_ext = $signed({{(NBIO-NBI1){a[NB1-1]}}, a}) <<< (NBFO-NBF1);
    assign b_ext = $signed({{(NBIO-NBI2){b[NB2-1]}}, b}) <<< (NBFO-NBF2);

    assign o = a_ext + b_ext;

endmodule
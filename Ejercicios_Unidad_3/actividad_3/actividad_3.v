module actividad_3 #(
    parameter integer NB1  = 11,
    parameter integer NBF1 = 6,

    parameter integer NB2  = 7,
    parameter integer NBF2 = 3,

    parameter integer NB3  = 5,
    parameter integer NBF3 = 3
)(
    input  wire signed [NB1-1:0] x1, // x = 5.5625
    input  wire signed [NB1-1:0] x2, // y = 8.75

    // Salidas Parte A
    output wire signed [NB2-1:0] o1_trunc,
    output wire signed [NB2-1:0] o2_round,

    // Salidas Parte B
    output wire signed [NB3-1:0] o3_wrap,
    output wire signed [NB3-1:0] o4_sat
);

    assign o1_trunc = x1[NBF1 + NB2 - NBF2 - 1 : NBF1 - NBF2];
    wire bit_redondeo;

    assign bit_redondeo = x1[NBF1 - NBF2 - 1];
    assign o2_round = o1_trunc + bit_redondeo;
    assign o3_wrap = x2[NBF1 + NB3 - NBF3 - 1 : NBF1 - NBF3];

    wire overflow;

    assign overflow =
        (x2[NB1-1] != x2[NBF1 + NB3 - NBF3 - 1]) ||
        (x2[NB1-2] != x2[NBF1 + NB3 - NBF3 - 1]) ||
        (x2[NB1-3] != x2[NBF1 + NB3 - NBF3 - 1]);

    wire [NB3-1:0] max_pos = 5'b01111;
    wire [NB3-1:0] max_neg = 5'b10000;
    assign o4_sat =
        overflow ?
        (x2[NB1-1] ? max_neg : max_pos) :
        o3_wrap;

endmodule
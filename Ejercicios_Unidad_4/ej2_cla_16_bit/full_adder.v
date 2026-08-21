`timescale 1ns/1ps

module full_adder #(
    parameter TXOR = 3,
    parameter TAND = 2,
    parameter TOR  = 2
)(
    input  logic ai, bi, c_in,
    output logic si, c_out
);
    logic p, g, pc;

    xor #(TXOR) u_p  (p,     ai, bi);
    xor #(TXOR) u_s  (si,    p,  c_in);
    and #(TAND) u_g  (g,     ai, bi);
    and #(TAND) u_pc (pc,    p,  c_in);
    or  #(TOR)  u_co (c_out, g,  pc);
endmodule
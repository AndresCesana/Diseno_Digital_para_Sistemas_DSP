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

module rca #(
    parameter N = 4,
    parameter TXOR = 3,
    parameter TAND = 2,
    parameter TOR  = 2

)(
    input [N-1:0] a, b,
    input c_in,
    output [N-1:0] s,
    output c_out
);

    wire [N:0] c; assign c[0] = c_in;
    genvar i;
    generate 
        for (i = 0; i < N; i = i+1)
            full_adder u(a[i], b[i], c[i], s[i], c[i+1]);
    endgenerate
    assign c_out = c[N];
endmodule
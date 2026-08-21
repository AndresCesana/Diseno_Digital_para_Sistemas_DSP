`timescale 1ns/1ps

module cla_lookahead #(
    parameter TAND = 2,
    parameter TOR  = 2
)(
    input  logic [3:0] p, g,
    input  logic       c0,
    output logic [3:0] c,   // c[0]=c0, c[1..3] internos
    output logic       c4
);
    logic pc0, p1g0, p1p0c0;
    logic p2g1, p2p1g0, p2p1p0c0;
    logic p3g2, p3p2g1, p3p2p1g0, p3p2p1p0c0;

    assign c[0] = c0;

    and #(TAND) a1 (pc0, p[0], c0);
    or  #(TOR)  o1 (c[1], g[0], pc0);

    and #(TAND) a2a (p1g0, p[1], g[0]);
    and #(TAND) a2b (p1p0c0, p[1], p[0], c0);
    or  #(TOR)  o2 (c[2], g[1], p1g0, p1p0c0);

    and #(TAND) a3a (p2g1, p[2], g[1]);
    and #(TAND) a3b (p2p1g0, p[2], p[1], g[0]);
    and #(TAND) a3c (p2p1p0c0, p[2], p[1], p[0], c0);
    or  #(TOR)  o3 (c[3], g[2], p2g1, p2p1g0, p2p1p0c0);

    and #(TAND) a4a (p3g2, p[3], g[2]);
    and #(TAND) a4b (p3p2g1, p[3], p[2], g[1]);
    and #(TAND) a4c (p3p2p1g0, p[3], p[2], p[1], g[0]);
    and #(TAND) a4d (p3p2p1p0c0, p[3], p[2], p[1], p[0], c0);
    or  #(TOR)  o4 (c4, g[3], p3g2, p3p2g1, p3p2p1g0, p3p2p1p0c0);
endmodule
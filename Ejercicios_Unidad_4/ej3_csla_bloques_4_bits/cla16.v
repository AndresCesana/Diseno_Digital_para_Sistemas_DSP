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

module pg_gen #(
    parameter TXOR = 3,
    parameter TAND = 2
)(
    input  logic ai, bi,
    output logic p, g
);
    xor #(TXOR) u_p (p, ai, bi);
    and #(TAND) u_g (g, ai, bi);
endmodule

module group_pg #(
    parameter TAND = 2,
    parameter TOR  = 2
)(
    input  logic [3:0] p, g,   // p,g locales del grupo (bit-level)
    output logic       Pg, Gg
);
    logic g3pc, g3p2g1, g3p2p1g0;

    and #(TAND) uPg (Pg, p[0], p[1], p[2], p[3]);

    and #(TAND) a1 (g3pc,    p[3], g[2]);
    and #(TAND) a2 (g3p2g1,  p[3], p[2], g[1]);
    and #(TAND) a3 (g3p2p1g0,p[3], p[2], p[1], g[0]);
    or  #(TOR)  o1 (Gg, g[3], g3pc, g3p2g1, g3p2p1g0);
endmodule

module cla4 #(
    parameter TXOR = 3, TAND = 2, TOR = 2
)(
    input  logic [3:0] a, b,
    input  logic       cin,
    output logic [3:0] s,
    output logic        Pg, Gg   // salidas de grupo, hacia el nivel 2
);
    logic [3:0] p, g, c;

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : pg
            pg_gen #(TXOR, TAND) u_pg (a[i], b[i], p[i], g[i]);
        end
    endgenerate

    cla_lookahead #(TAND, TOR) u_local (p, g, cin, c, /*c4 interno no se usa*/);

    genvar j;
    generate
        for (j = 0; j < 4; j++) begin : sum
            xor #(TXOR) u_s (s[j], p[j], c[j]);
        end
    endgenerate

    group_pg #(TAND, TOR) u_gpg (p, g, Pg, Gg);
endmodule

module cla16 #(
    parameter TXOR = 3, 
    parameter TAND = 2, 
    parameter TOR = 2
)(
    input  logic [15:0] a, b,
    input  logic         c0,
    output logic [15:0] s,
    output logic         c16
);
    logic [3:0] Pg, Gg;      // P,G de cada grupo
    logic [3:0] C;           // C[0]=c0, C[1]=C4, C[2]=C8, C[3]=C12

    // Nivel 2: lookahead entre grupos (mismo módulo genérico)
    cla_lookahead #(TAND, TOR) u_group_la (Pg, Gg, c0, C, c16);

    // 4 bloques de 4 bits, cada uno con su carry-in resuelto en paralelo
    cla4 #(TXOR,TAND,TOR) g0 (a[3:0],   b[3:0],   C[0], s[3:0],   Pg[0], Gg[0]);
    cla4 #(TXOR,TAND,TOR) g1 (a[7:4],   b[7:4],   C[1], s[7:4],   Pg[1], Gg[1]);
    cla4 #(TXOR,TAND,TOR) g2 (a[11:8],  b[11:8],  C[2], s[11:8],  Pg[2], Gg[2]);
    cla4 #(TXOR,TAND,TOR) g3 (a[15:12], b[15:12], C[3], s[15:12], Pg[3], Gg[3]);
endmodule
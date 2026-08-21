`timescale 1ns/1ps

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
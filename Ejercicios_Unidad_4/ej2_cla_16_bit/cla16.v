`timescale 1ns/1ps

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
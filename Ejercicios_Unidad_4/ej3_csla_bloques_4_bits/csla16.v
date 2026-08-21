`timescale 1ns/1ps

module mux2 #(
    parameter W    = 4,
    parameter TMUX = 2
)(
    input  logic [W-1:0] d0,   
    input  logic [W-1:0] d1,  
    input  logic         sel,
    output logic [W-1:0] y
);
    assign #(TMUX) y = sel ? d1 : d0;
endmodule

module csla16 #(
    parameter TXOR = 3,
    parameter TAND = 2,
    parameter TOR = 2,
    parameter TMUX = 2
)(
    input logic [15:0] a, b,
    input logic c_in, 
    output logic [15:0] o,
    output logic c_out
);
    localparam int NB = 4;   // cantidad de bloques
    localparam int W  = 4;   // bits por bloque

    logic [W-1:0] s0 [NB];
    logic [W-1:0] s1 [NB];
    logic co0 [NB];
    logic co1 [NB];

    logic [NB:0] csel;
    assign csel[0] = c_in;

    genvar k;
    generate
        for (k=0; k < NB; k = k+1) begin : g_blk

            rca #(W, TXOR, TAND, TOR, TMUX) u_rca0 (
                a[W*k + W - 1: k*W], 
                b[W*k + W - 1: k*W], 
                1'b0, 
                s0[k], 
                co0[k]
            );
            rca #(W, TXOR, TAND, TOR, TMUX) u_rca1 (
                a[W*k + W - 1: k*W], 
                b[W*k + W - 1: k*W], 
                1'b1, 
                s1[k], 
                co1[k]
            );

            mux2 #(W, TMUX) u_mux_s (
                s0[k],
                s1[k],
                csel[k],
                o[W*k + W - 1: W*k]
            );

            mux2 #(1, TMUX) u_mux_c (
                co0[k],
                co1[k],
                csel[k],
                csel[k+1]
            );
        end
    endgenerate

    assign c_out = csel[NB];

endmodule

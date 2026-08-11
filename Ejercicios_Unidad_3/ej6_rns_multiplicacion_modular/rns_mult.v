`timescale 1ns/1ps

module rns_mult #(
    parameter   integer m0 = 3,
    parameter   integer m1 = 5,
    parameter   integer m2 = 7
) (
    X, Y, O
);

    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1)
                v = v >> 1;
        end
    endfunction

    function integer mod_inv;
        input integer a;
        input integer m;
        integer k;
        begin
            mod_inv = 0;
            for (k = 1; k < m; k = k + 1)
                if (((a * k) % m) == 1) mod_inv = k;
        end
    endfunction

    localparam integer M = m0 * m1 * m2;
    localparam integer XW = clog2(M);
    localparam integer W0 = clog2(m0);
    localparam integer W1 = clog2(m1);
    localparam integer W2 = clog2(m2);
    localparam integer WMAX = (W0 > W1) ? ((W0 > W2) ? W0 : W2)
                                        : ((W1 > W2) ? W1 : W2);
    
    localparam integer MI0 = M / m0;
    localparam integer MI1 = M / m1;
    localparam integer MI2 = M / m2;

    localparam integer E0 = MI0 * mod_inv(MI0 % m0, m0);
    localparam integer E1 = MI1 * mod_inv(MI1 % m1, m1);
    localparam integer E2 = MI2 * mod_inv(MI2 % m2, m2);

    localparam integer SMAX = E0*(m0-1) + E1*(m1-1) + E2*(m2-1);
    localparam integer SW = clog2(SMAX + 1);
  
    input   wire [XW-1:0] X;
    input   wire [XW-1:0] Y;
    output  wire [XW-1:0] O;

    wire [WMAX-1:0] x [0:2];
    wire [WMAX-1:0] y [0:2];
    wire [WMAX-1:0] o [0:2];
    wire [SW-1:0]   suma_crt;

    mod_lut #(.MOD(m0), .IN_W(XW), .OUT_W(WMAX)) enc_x0 (.idx(X), .val(x[0]));
    mod_lut #(.MOD(m1), .IN_W(XW), .OUT_W(WMAX)) enc_x1 (.idx(X), .val(x[1]));
    mod_lut #(.MOD(m2), .IN_W(XW), .OUT_W(WMAX)) enc_x2 (.idx(X), .val(x[2]));

    mod_lut #(.MOD(m0), .IN_W(XW), .OUT_W(WMAX)) enc_y0 (.idx(Y), .val(y[0]));
    mod_lut #(.MOD(m1), .IN_W(XW), .OUT_W(WMAX)) enc_y1 (.idx(Y), .val(y[1]));
    mod_lut #(.MOD(m2), .IN_W(XW), .OUT_W(WMAX)) enc_y2 (.idx(Y), .val(y[2]));

    mod_mult_lut #(.MOD(m0), .W(WMAX)) mul0 (.a(x[0]), .b(y[0]), .val(o[0]));
    mod_mult_lut #(.MOD(m1), .W(WMAX)) mul1 (.a(x[1]), .b(y[1]), .val(o[1]));
    mod_mult_lut #(.MOD(m2), .W(WMAX)) mul2 (.a(x[2]), .b(y[2]), .val(o[2]));

    assign suma_crt = (o[0]*E0) + (o[1]*E1) + (o[2]*E2);

    mod_lut #(.MOD(M), .IN_W(SW), .OUT_W(XW)) red_crt (.idx(suma_crt), .val(O));



endmodule
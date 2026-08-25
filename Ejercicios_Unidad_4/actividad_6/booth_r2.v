`timescale 1ns/1ps

// =========================================================
// Full Adder
// =========================================================

module full_adder(
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire s,
    output wire cout
);

    assign s    = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);

endmodule
// =========================================================
// Booth Radix-2 8x8 Signed Multiplier
// =========================================================

module booth_r2 #(
    parameter N = 8
)(
    input  wire signed [N-1:0] A,
    input  wire signed [N-1:0] B,

    output wire signed [2*N-1:0] P
);
    wire [N:0] B_ext;

    assign B_ext = {B, 1'b0};

    wire signed [2*N-1:0] pp [0:N-1];

    genvar i;

    generate

        for (i = 0; i < N; i = i + 1) begin : GEN_BOOTH

            // A extendido a 16 bits
            wire signed [2*N-1:0] A_ext;

            // -A
            wire signed [2*N-1:0] neg_A;

            assign A_ext = {{N{A[N-1]}}, A};

            assign neg_A = -A_ext;

            assign pp[i] =
                (B_ext[i+1:i] == 2'b01) ?
                    (A_ext <<< i) :

                (B_ext[i+1:i] == 2'b10) ?
                    (neg_A <<< i) :

                    {2*N{1'b0}};

        end

    endgenerate

    assign P =
        pp[0] +
        pp[1] +
        pp[2] +
        pp[3] +
        pp[4] +
        pp[5] +
        pp[6] +
        pp[7];

endmodule
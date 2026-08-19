module full_adder #(
    input logic ai, bi, c_in,
    output logic si, c_out
);

    assign {c_out, si} = ai + bi + c_in;
endmodule
module rca #(
    parameter N = 8
)(
    input [N-1:0] a, b,
    input c_in,
    output [N-1:0] s,
    output c_out
);

    wire [N:0] c; assign c[0] = c_in;
    genvar i;
    generate for (i = 0; i < N; i = i+1)
        full_adder u(a[i], b[i], c[i], s[i], c[i+1]);
    endgenerate
    assign c_out = c[N];
endmodule
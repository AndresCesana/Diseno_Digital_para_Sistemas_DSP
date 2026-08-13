module actividad_5 #(
    parameter integer N = 4
)(
    input  wire signed [N-1:0] A,
    input  wire signed [N-1:0] B,

    output wire signed [2*N-1:0] producto
);
    integer i;
    reg signed [2*N-1:0] A_ext;
    reg signed [2*N-1:0] A_neg;
    reg signed [2*N-1:0] parcial;
    reg b_prev;

    always @(*) begin
        A_ext = {{N{A[N-1]}}, A};
        A_neg = -A_ext;
        parcial = 0;
        b_prev = 1'b0;
        for (i = 0; i < N; i = i + 1) begin
            case ({B[i], b_prev})
                2'b01: begin
                    parcial = parcial + (A_ext <<< i);
                end
                2'b10: begin
                    parcial = parcial + (A_neg <<< i);
                end
                2'b00: begin
                    parcial = parcial;
                end
                2'b11: begin
                    parcial = parcial;
                end
            endcase
            b_prev = B[i];
        end
    end
    assign producto = parcial;
endmodule
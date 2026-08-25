// Modulos auxiliares
module full_adder(input a, b, cin, output s, cout);
    assign #1 s = a ^ b ^ cin;
    assign #1 cout = (a & b) | (b & cin) | (a & cin);
endmodule

// Multiplicador Array 8x8 (Unsigned)
module array_mul (
    input  [7:0] A, // Multiplicando
    input  [7:0] B, // Multiplicador
    output [15:0] P_out // Producto
);

    // 1. Generación de Productos Parciales (PP) con compuertas AND
    wire [7:0] PP [0:7];
    genvar i, j;
    generate
        for(i = 0; i < 8; i = i + 1) begin : pp_gen
            assign PP[i] = A & {8{B[i]}};
        end
    endgenerate

    // Matrices de cables para Sumas (S) y Acarreos (C) de las 7 filas de reducción
    wire [7:0] S [1:7];
    wire [7:0] C [1:7];

    // 2. Primera fila de Full Adders (recibe PP0 y PP1)
    generate
        for (j = 0; j < 8; j = j + 1) begin : row1
            if (j < 7)
                // Desplazamiento diagonal: PP[0] entra desplazado
                full_adder fa1 (PP[1][j], PP[0][j+1], 1'b0, S[1][j], C[1][j]);
            else
                // El último bit no tiene bit correspondiente de PP[0]
                full_adder fa1_msb (PP[1][7], 1'b0, 1'b0, S[1][7], C[1][7]);
        end
    endgenerate

    // 3. Filas 2 a 7 (Estructura CSA: propaga hacia abajo, no a los lados)
    generate
        for (i = 2; i < 8; i = i + 1) begin : rows
            for (j = 0; j < 8; j = j + 1) begin : cols
                if (j < 7)
                    full_adder fa (PP[i][j], S[i-1][j+1], C[i-1][j], S[i][j], C[i][j]);
                else
                    full_adder fa_msb (PP[i][7], 1'b0, C[i-1][7], S[i][7], C[i][7]);
            end
        end
    endgenerate

    // 4. Asignación directa de los LSB del producto
    assign P_out[0] = PP[0][0];
    assign P_out[1] = S[1][0];
    assign P_out[2] = S[2][0];
    assign P_out[3] = S[3][0];
    assign P_out[4] = S[4][0];
    assign P_out[5] = S[5][0];
    assign P_out[6] = S[6][0];
    assign P_out[7] = S[7][0];

    // 5. Fila Final (CPA - Ripple Carry Adder) para los MSB
    wire [8:0] cpa_c; // Cadena de propagación de acarreo
    assign cpa_c[0] = 1'b0;

    generate
        for (j = 0; j < 7; j = j + 1) begin : cpa
            full_adder fa_cpa (S[7][j+1], C[7][j], cpa_c[j], P_out[j+8], cpa_c[j+1]);
        end
    endgenerate
    
    // El bit más significativo absorbe el último acarreo que cae de la matriz
    full_adder fa_cpa_msb (1'b0, C[7][7], cpa_c[7], P_out[15], cpa_c[8]);

endmodule
`timescale 1ns/1ps

module TB;

    reg [7:0] A;
    reg [7:0] B;

    wire [15:0] P;

    integer i;
    integer j;
    integer errores;
    integer vectores;

    reg [15:0] esperado;


    // =====================================================
    // DUT
    // =====================================================

    array_mul dut (
        .A     (A),
        .B     (B),
        .P_out (P)
    );


    // =====================================================
    // TEST EXHAUSTIVO
    // =====================================================

    initial begin
        $dumpfile("tb_array_mult.vcd");
        $dumpvars(0, TB);
        A = 0;
        B = 0;

        errores = 0;
        vectores = 0;

        $display("==============================================");
        $display(" TEST EXHAUSTIVO ARRAY MULTIPLIER 8x8");
        $display("==============================================");
        $display("Vectores a probar: 65536");
        $display("----------------------------------------------");


        // Recorrer todos los valores posibles de A
        for (i = 0; i < 256; i = i + 1) begin

            // Recorrer todos los valores posibles de B
            for (j = 0; j < 256; j = j + 1) begin

                A = i;
                B = j;

                // Esperar propagacion combinacional
                #20;

                // Modelo de referencia
                esperado = A * B;

                vectores = vectores + 1;

                // Comparacion
                if (P !== esperado) begin

                    $display(
                        "ERROR: A=%0d B=%0d -> P=%0d esperado=%0d",
                        A,
                        B,
                        P,
                        esperado
                    );

                    errores = errores + 1;

                end

            end

            // Mostrar progreso cada 32 valores de A
            if ((i % 32) == 0)
                $display("Progreso: A = %0d / 255", i);

        end


        // =================================================
        // RESULTADO FINAL
        // =================================================

        $display("----------------------------------------------");
        $display("Vectores probados: %0d", vectores);
        $display("Errores: %0d", errores);

        if (errores == 0) begin
            $display("RESULTADO: PASS");
        end
        else begin
            $display("RESULTADO: FAIL");
        end

        $display("==============================================");

        $finish;

    end

endmodule
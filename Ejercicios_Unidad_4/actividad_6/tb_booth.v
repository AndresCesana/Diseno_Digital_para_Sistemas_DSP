`timescale 1ns/1ps

module TB;

    reg signed [7:0] A;
    reg signed [7:0] B;

    wire signed [15:0] P;

    reg signed [15:0] esperado;

    integer i;
    integer j;

    integer errores;
    integer vectores;


    // =====================================================
    // DUT
    // =====================================================

    booth_r2 dut (
        .A(A),
        .B(B),
        .P(P)
    );


    // =====================================================
    // TEST EXHAUSTIVO
    // =====================================================

    initial begin

        $dumpfile("tb_booth.vcd");
        $dumpvars(0, TB);

        A = 0;
        B = 0;

        errores  = 0;
        vectores  = 0;


        $display("==============================================");
        $display(" TEST EXHAUSTIVO BOOTH RADIX-2 8x8");
        $display("==============================================");
        $display("Rango A: -128 ... 127");
        $display("Rango B: -128 ... 127");
        $display("Vectores: 65536");
        $display("----------------------------------------------");


        // =================================================
        // Barrido de todos los valores
        // =================================================

        for (i = -128; i <= 127; i = i + 1) begin

            for (j = -128; j <= 127; j = j + 1) begin

                A = i;
                B = j;

                // Modelo de referencia
                esperado = A * B;

                // Propagación combinacional
                #1;

                vectores = vectores + 1;


                // Comparación
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


            // Mostrar progreso
            if ((i % 32) == 0)
                $display(
                    "Progreso: A = %0d / 127",
                    i
                );

        end


        // =================================================
        // Resultado
        // =================================================

        $display("----------------------------------------------");

        $display(
            "Vectores probados: %0d",
            vectores
        );

        $display(
            "Errores: %0d",
            errores
        );


        if (errores == 0)
            $display("RESULTADO: PASS");
        else
            $display("RESULTADO: FAIL");


        $display("==============================================");

        $finish;

    end

endmodule
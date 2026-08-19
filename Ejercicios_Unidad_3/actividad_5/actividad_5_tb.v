`timescale 1ns/1ps

module actividad_5_tb;

    reg signed [3:0] A;
    reg signed [3:0] B;

    wire signed [7:0] producto;

    reg signed [7:0] gold_producto;

    integer errores;

    actividad_5 uut (
        .A(A),
        .B(B),
        .producto(producto)
    );

    initial begin

        errores = 0;

        $dumpfile("actividad_5_tb.vcd");
        $dumpvars(0, actividad_5_tb);

        // =====================================================
        // DATOS DEL EJERCICIO
        // A = +6 = 0110
        // B = -5 = 1011
        // b_-1 = 0
        // =====================================================

        A = 4'b0110;
        B = 4'b1011;

        gold_producto = -8'sd30;

        #10;

        $display("==========================================");
        $display("       EJERCICIO 5 - BOOTH RADIX-2");
        $display("==========================================");

        $display("A             = %b", A);
        $display("B             = %b", B);
        $display("b_-1          = 0");

        $display("------------------------------------------");

        $display("Producto DUT  = %b (%0d)", producto, producto);
        $display("Producto GOLD = %b (%0d)", gold_producto, gold_producto);

        $display("------------------------------------------");

        if (producto !== gold_producto) begin

            $display("ERROR: producto incorrecto");

            errores = errores + 1;

        end

        $display("==========================================");

        if (errores == 0) begin

            $display("[PASS] Todos los casos correctos.");

        end
        else begin

            $display("[FAIL] Se encontraron %0d errores.", errores);

        end

        $display("==========================================");

        $finish;

    end

endmodule
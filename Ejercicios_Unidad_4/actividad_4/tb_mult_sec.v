`timescale 1ns / 1ps

module tb_mult_sec();

    parameter N = 8;

    reg clk;
    reg rst;
    reg start;
    reg [N-1:0] A;
    reg [N-1:0] B;

    wire [2*N-1:0] producto;
    wire done;

    // DUT
    mult_sec #(.N(N)) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .A(A),
        .B(B),
        .producto(producto),
        .done(done)
    );

    // Reloj
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Variables del testbench
    integer i;
    integer errores;
    integer ciclos;
    integer ciclo_inicio;

    initial begin

        // VCD
        $dumpfile("tb_mult_sec.vcd");
        $dumpvars(0, tb_mult_sec);

        // Inicialización
        rst = 1;
        start = 0;
        A = 0;
        B = 0;

        errores = 0;
        ciclos = 0;

        // Reset
        #25;
        rst = 0;

        #10;

        $display("Iniciando Testbench con 200 vectores aleatorios...");
        $display("--------------------------------------------------");

        for (i = 0; i < 200; i = i + 1) begin

            // Preparar datos antes del flanco positivo
            @(negedge clk);

            A = $random % 256;
            B = $random % 256;
            start = 1;

            ciclo_inicio = $time;

            // DUT captura start
            @(posedge clk);

            // Desactivar start
            @(negedge clk);
            start = 0;

            // Esperar DONE
            while (!done) begin
                @(posedge clk);
            end

            // Latencia
            ciclos = ($time - ciclo_inicio) / 10;

            // Verificación
            if (producto !== (A * B)) begin

                $display(
                    "ERROR en test %0d: %0d * %0d = %0d (Esperado: %0d)",
                    i,
                    A,
                    B,
                    producto,
                    A * B
                );

                errores = errores + 1;
            end

        end

        $display("--------------------------------------------------");

        if (errores == 0)
            $display("EXITO: 0 errores en 200 multiplicaciones.");
        else
            $display("FALLO: Se encontraron %0d errores.", errores);

        $display("Latencia medida: %0d ciclos por operacion.", ciclos);

        $display("--------------------------------------------------");

        $finish;

    end

endmodule
//==============================================================
//  tb_mult23.v - Testbench self-checking, multiplicacion por K = 23
//
//  Los vectores y los valores esperados los genera gen_vectors.py
//  usando fxpmath como modelo de referencia en punto fijo:
//
//     x.hex        entradas   S(N, NF)   -> memoria x_mem
//     expected.hex esperados  S(W, NF)   -> memoria exp_mem
//     params.vh    N_BITS / N_FRAC / W_BITS / N_VEC
//
//  El testbench NO recalcula el resultado: lo compara contra el
//  oraculo externo. Asi el modelo de referencia y el DUT son
//  independientes.
//==============================================================
`timescale 1ns/1ps
`include "params.vh"

module tb_mult23;

    localparam N   = `N_BITS;
    localparam NF  = `N_FRAC;
    localparam W   = `W_BITS;
    localparam NV  = `N_VEC;

    //----------------------------------------------------------
    // Memorias de vectores
    //----------------------------------------------------------
    reg [N-1:0] x_mem   [0:NV-1];
    reg [W-1:0] exp_mem [0:NV-1];

    reg  signed [N-1:0] x;
    reg  signed [W-1:0] y_exp;
    wire signed [W-1:0] y_csd;
    wire signed [W-1:0] y_bin;

    integer k, errors, checks;
    real    scale;                 // 2^NF, para mostrar el valor real

    //----------------------------------------------------------
    // DUTs
    //----------------------------------------------------------
    mult23_csd #(.N(N)) u_csd (.x(x), .y(y_csd));
    mult23_bin #(.N(N)) u_bin (.x(x), .y(y_bin));

    //----------------------------------------------------------
    task check;
        input [8*12:1]       nombre;
        input signed [W-1:0] obtenido;
        begin
            checks = checks + 1;
            if (obtenido !== y_exp) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("  ERROR [%0d] %0s : x=%0d  obtenido=%0d  esperado=%0d",
                             k, nombre, x, obtenido, y_exp);
            end
        end
    endtask

    //----------------------------------------------------------
    initial begin
        errors = 0;
        checks = 0;
        scale  = 2.0 ** NF;

        $dumpfile("tb_mult23.vcd");
        $dumpvars(0, tb_mult23);

        $readmemh("x.hex",        x_mem);
        $readmemh("expected.hex", exp_mem);

        $display("==================================================");
        $display(" Multiplicacion por K = 23");
        $display("   K_bin = 10111         (16+4+2+1) -> 3 sumadores");
        $display("   K_csd = 1 0 -1 0 0 -1 (32-8-1)   -> 2 sumadores");
        $display("--------------------------------------------------");
        $display("   Entrada : S(%0d, %0d)", N, NF);
        $display("   Salida  : S(%0d, %0d)", W, NF);
        $display("   Vectores: %0d  (referencia: fxpmath)", NV);
        $display("==================================================");

        // ---- Muestra de los primeros vectores ----
        $display("\n--- Primeros 8 vectores ---");
        for (k = 0; k < ((NV < 8) ? NV : 8); k = k + 1) begin
            x     = x_mem[k];
            y_exp = exp_mem[k];
            #1;
            $display("  x = %8.3f  ->  CSD = %10.3f   BIN = %10.3f   ref = %10.3f",
                     x / scale, y_csd / scale, y_bin / scale, y_exp / scale);
            check("csd", y_csd);
            check("bin", y_bin);
        end

        // ---- Barrido completo ----
        $display("\n--- Recorriendo los %0d vectores ---", NV);
        for (k = 0; k < NV; k = k + 1) begin
            x     = x_mem[k];
            y_exp = exp_mem[k];
            #1;
            check("csd", y_csd);
            check("bin", y_bin);
        end

        // ---- Resumen ----
        $display("\n==================================================");
        $display(" Vectores            : %0d", NV);
        $display(" Chequeos realizados : %0d", checks);
        $display(" Errores             : %0d", errors);
        if (errors == 0) $display(" RESULTADO: TEST PASSED");
        else             $display(" RESULTADO: TEST FAILED");
        $display("==================================================");

        if (errors != 0) $fatal(1);
        $finish;
    end

endmodule
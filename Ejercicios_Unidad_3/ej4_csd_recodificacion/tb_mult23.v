//==============================================================
//  Testbench autoverificable - multiplicacion por K = 23
//
//  Oraculo: x * 23 (multiplicacion directa del simulador).
//  Barrido exhaustivo de todos los valores signados de N bits.
//==============================================================
`timescale 1ns/1ps

module tb_mult23;

    parameter  N     = 8;                  // 8 bits -> 256 casos
    localparam W     = N + 5;              // ancho del resultado
    localparam MIN_X = -(2**(N-1));        // -128
    localparam MAX_X =  (2**(N-1)) - 1;    // +127

    reg  signed [N-1:0] x;
    wire signed [W-1:0] y_csd;
    wire signed [W-1:0] y_bin;
    reg  signed [W-1:0] y_ref;             // oraculo

    integer i, errors, checks;

    mult23_csd #(.N(N)) u_csd (.x(x), .y(y_csd));
    mult23_bin #(.N(N)) u_bin (.x(x), .y(y_bin));

    //----------------------------------------------------------
    task check;
        input [8*12:1]       nombre;
        input signed [W-1:0] obtenido;
        begin
            checks = checks + 1;
            if (obtenido !== y_ref) begin
                errors = errors + 1;
                $display("  ERROR %0s : x=%0d  obtenido=%0d  esperado=%0d",
                         nombre, x, obtenido, y_ref);
            end
        end
    endtask

    //----------------------------------------------------------
    initial begin
        errors = 0;
        checks = 0;

        $dumpfile("tb_mult23.vcd");
        $dumpvars(0, tb_mult23);

        $display("==================================================");
        $display(" Multiplicacion por K = 23");
        $display("   K_bin = 10111         (16+4+2+1) -> 3 sumadores");
        $display("   K_csd = 1 0 -1 0 0 -1 (32-8-1)   -> 2 sumadores");
        $display("   N = %0d bits, ancho de salida = %0d bits", N, W);
        $display("==================================================");

        // ---- Casos dirigidos ----
        $display("\n--- Casos dirigidos ---");
        for (i = 0; i < 7; i = i + 1) begin
            case (i)
                0: x = 0;
                1: x = 1;
                2: x = -1;
                3: x = 7;
                4: x = MAX_X;              // +127 -> 2921
                5: x = MIN_X;              // -128 -> -2944
                6: x = MIN_X + 1;
            endcase
            y_ref = x * 23;
            #1;
            $display("  x = %5d  ->  CSD = %6d   BIN = %6d   ref = %6d",
                     x, y_csd, y_bin, y_ref);
            check("csd", y_csd);
            check("bin", y_bin);
        end

        // ---- Barrido exhaustivo ----
        $display("\n--- Barrido exhaustivo (%0d valores) ---", 2**N);
        for (i = MIN_X; i <= MAX_X; i = i + 1) begin
            x     = i;
            y_ref = x * 23;
            #1;
            check("csd", y_csd);
            check("bin", y_bin);
        end

        // ---- Resumen ----
        $display("\n==================================================");
        $display(" Chequeos realizados : %0d", checks);
        $display(" Errores             : %0d", errors);
        if (errors == 0) $display(" RESULTADO: TEST PASSED");
        else             $display(" RESULTADO: TEST FAILED");
        $display("==================================================");

        $finish;
    end

endmodule
`timescale 1ns/1ps
`include "params.vh"

//==============================================================
//  tb_rns_mult.v - Testbench autoverificable
//
//  Consume los archivos generados por gen_vectors.py y compara
//  la salida del DUT contra el modelo de referencia.
//
//  Ademas verifica que las constantes que el RTL deriva en
//  elaboracion coincidan con las que calculo Python.
//==============================================================
module tb_rns_mult;

    localparam integer XW = `XW_BITS;
    localparam integer NV = `N_VEC;
    localparam integer MAX_REPORTES = 10;

    reg  [XW-1:0] X, Y;
    wire [XW-1:0] O;

    reg [XW-1:0] x_mem [0:NV-1];
    reg [XW-1:0] y_mem [0:NV-1];
    reg [XW-1:0] e_mem [0:NV-1];
    reg [0:0]    v_mem [0:NV-1];

    integer i;
    integer errores;
    integer reportados;
    integer sin_desborde;
    integer err_sin_desborde;

    //----------------------------------------------------------
    //  DUT
    //----------------------------------------------------------
    rns_mult #(
        .m0(`M0),
        .m1(`M1),
        .m2(`M2)
    ) dut (
        .X(X),
        .Y(Y),
        .O(O)
    );

    //----------------------------------------------------------
    //  Chequeo de constantes derivadas en elaboracion
    //
    //  Referencia jerarquica a los localparam del DUT. Si la
    //  herramienta no lo soporta, comentar este bloque.
    //----------------------------------------------------------
    task check_const;
        input [8*12-1:0] nombre;
        input integer    obtenido;
        input integer    esperado;
        begin
            if (obtenido !== esperado) begin
                $display("  [CONST] %0s = %0d  (esperado %0d)  <-- ERROR",
                         nombre, obtenido, esperado);
                errores = errores + 1;
            end else begin
                $display("  [CONST] %0s = %0d  OK", nombre, obtenido);
            end
        end
    endtask

    //----------------------------------------------------------
    //  Secuencia principal
    //----------------------------------------------------------
    initial begin
        errores          = 0;
        reportados       = 0;
        sin_desborde     = 0;
        err_sin_desborde = 0;

        $display("==============================================");
        $display(" tb_rns_mult  -  base {%0d, %0d, %0d}  M = %0d",
                 `M0, `M1, `M2, `M_TOT);
        $display("==============================================");

        check_const("M",    dut.M,    `M_TOT);
        check_const("XW",   dut.XW,   `XW_BITS);
        check_const("WMAX", dut.WMAX, `WMAX);
        check_const("E0",   dut.E0,   `E0_REF);
        check_const("E1",   dut.E1,   `E1_REF);
        check_const("E2",   dut.E2,   `E2_REF);
        check_const("SMAX", dut.SMAX, `SMAX);
        check_const("SW",   dut.SW,   `SW_BITS);

        if (errores != 0) begin
            $display("");
            $display(" ABORTA: las constantes del RTL no coinciden");
            $display(" con el modelo de referencia.");
            $finish;
        end

        $readmemh("x.hex",        x_mem);
        $readmemh("y.hex",        y_mem);
        $readmemh("expected.hex", e_mem);
        $readmemh("valid.hex",    v_mem);

        $display("");
        $display("  Vectores cargados: %0d", NV);
        $display("");

        #1;

        for (i = 0; i < NV; i = i + 1) begin
            X = x_mem[i];
            Y = y_mem[i];
            #1;

            if (v_mem[i] === 1'b1)
                sin_desborde = sin_desborde + 1;

            if (O !== e_mem[i]) begin
                errores = errores + 1;
                if (v_mem[i] === 1'b1)
                    err_sin_desborde = err_sin_desborde + 1;

                if (reportados < MAX_REPORTES) begin
                    $display("  [%0d] X=%0d Y=%0d -> O=%0d  (esperado %0d)%0s",
                             i, X, Y, O, e_mem[i],
                             (v_mem[i] === 1'b1) ? "" : "   [desborda]");
                    reportados = reportados + 1;
                    if (reportados == MAX_REPORTES)
                        $display("  ... (se omiten los siguientes)");
                end
            end
        end

        $display("");
        $display("----------------------------------------------");
        $display("  Vectores probados      : %0d", NV);
        $display("  Sin desborde (X*Y < M) : %0d  (%0d %%)",
                 sin_desborde, (100 * sin_desborde) / NV);
        $display("  Errores totales        : %0d", errores);
        $display("  Errores sin desborde   : %0d", err_sin_desborde);
        $display("----------------------------------------------");

        if (errores == 0)
            $display("  RESULTADO: PASS");
        else
            $display("  RESULTADO: FAIL");
        $display("");

        $finish;
    end

    //----------------------------------------------------------
    //  Volcado opcional de formas de onda
    //----------------------------------------------------------
`ifdef DUMP
    initial begin
        $dumpfile("tb_rns_mult.vcd");
        $dumpvars(0, tb_rns_mult);
    end
`endif

endmodule
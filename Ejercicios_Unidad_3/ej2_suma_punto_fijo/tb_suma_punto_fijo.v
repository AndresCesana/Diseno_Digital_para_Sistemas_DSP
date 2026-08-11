`timescale 1ns/1ps
`include "params.vh"

module tb_suma_punto_fijo;

    localparam integer NB1  = `NB1,  NBF1 = `NBF1, NBI1 = NB1 - NBF1;
    localparam integer NB2  = `NB2,  NBF2 = `NBF2, NBI2 = NB2 - NBF2;
    localparam integer NBFO = (NBF1 > NBF2) ? NBF1 : NBF2;
    localparam integer NBIO = ((NBI1 > NBI2) ? NBI1 : NBI2) + 1;
    localparam integer NBO  = NBIO + NBFO;
    localparam integer NVEC = `NVEC;
    localparam integer MAX_MSG = 10;      // tope de errores impresos

    reg [NB1-1:0] mem_a [0:NVEC-1];
    reg [NB2-1:0] mem_b [0:NVEC-1];
    reg [NBO-1:0] mem_o [0:NVEC-1];

    reg  signed [NB1-1:0] a;
    reg  signed [NB2-1:0] b;
    reg  signed [NBO-1:0] esperado;
    wire signed [NBO-1:0] o;

    integer i, errores, mostrados;

    suma_punto_fijo dut (.a(a), .b(b), .o(o));

    initial begin
        $dumpfile("tb_suma_punto_fijo.vcd");
        $dumpvars(0, tb_suma_punto_fijo);

        $readmemh("a.hex",        mem_a);
        $readmemh("b.hex",        mem_b);
        $readmemh("expected.hex", mem_o);

        $display("==================================================");
        $display(" S(%0d,%0d) + S(%0d,%0d) -> S(%0d,%0d)",
                 NB1, NBF1, NB2, NBF2, NBO, NBFO);
        $display("   rango salida : [%f ; %f]",
                 -(2.0**(NBIO-1)), (2.0**(NBIO-1)) - (2.0**(-NBFO)));
        $display("   resolucion   : %f", 2.0**(-NBFO));
        $display("   vectores     : %0d  (ref: fxpmath)", NVEC);
        $display("==================================================");

        errores = 0;  mostrados = 0;

        for (i = 0; i < NVEC; i = i + 1) begin
            a        = mem_a[i];
            b        = mem_b[i];
            esperado = mem_o[i];
            #1;

            if (o !== esperado) begin
                errores = errores + 1;
                if (mostrados < MAX_MSG) begin
                    mostrados = mostrados + 1;
                    $display("[%0d] MISMATCH", i);
                    $display("   A = S(%0d,%0d) %b = %0d/2^%0d = %f",
                             NB1, NBF1, a, a, NBF1, $itor(a)/(2.0**NBF1));
                    $display("   B = S(%0d,%0d) %b = %0d/2^%0d = %f",
                             NB2, NBF2, b, b, NBF2, $itor(b)/(2.0**NBF2));
                    $display("   DUT = %b = %f   REF = %b = %f",
                             o, $itor(o)/(2.0**NBFO),
                             esperado, $itor(esperado)/(2.0**NBFO));
                end
            end
        end

        if (errores > MAX_MSG)
            $display("... (%0d errores mas omitidos)", errores - MAX_MSG);

        $display("==================================================");
        if (errores == 0)
            $display(" PASS  -  %0d/%0d casos OK", NVEC, NVEC);
        else
            $display(" FAIL  -  %0d/%0d fallaron", errores, NVEC);
        $display("==================================================");

        $finish;
    end
endmodule
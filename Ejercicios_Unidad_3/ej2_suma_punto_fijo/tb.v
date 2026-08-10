`timescale 1ns/1ps

module tb;

    // formato de cada señal — unica fuente de verdad
    localparam integer NB1  = 6,  NBF1 = 4,  NBI1 = NB1 - NBF1;
    localparam integer NB2  = 8,  NBF2 = 5,  NBI2 = NB2 - NBF2;
    localparam integer NBFO = (NBF1 > NBF2) ? NBF1 : NBF2;
    localparam integer NBIO = ((NBI1 > NBI2) ? NBI1 : NBI2) + 1;
    localparam integer NBO  = NBIO + NBFO;

    reg  signed [NB1-1:0] a;
    reg  signed [NB2-1:0] b;
    wire signed [NBO-1:0] o;

    integer esperado;
    integer errores = 0;

    suma_punto_fijo dut (.a(a), .b(b), .o(o));

    task check;
        input signed [NB1-1:0] a_in;
        input signed [NB2-1:0] b_in;
        input integer          exp;
        input [8*32:1]         nombre;
        begin
            a = a_in;  b = b_in;  esperado = exp;  #1;
            $display("--- %0s", nombre);
            $display("  A = S(%0d,%0d)  %b = %d/2^%0d = %f",
                     NB1, NBF1, a, a, NBF1, $itor(a)/(2.0**NBF1));
            $display("  B = S(%0d,%0d)  %b = %d/2^%0d = %f",
                     NB2, NBF2, b, b, NBF2, $itor(b)/(2.0**NBF2));
            $display("  O = S(%0d,%0d)  %b = %d/2^%0d = %f   (esp %f)",
                     NBO, NBFO, o, o, NBFO, $itor(o)/(2.0**NBFO),
                     $itor(esperado)/(2.0**NBFO));
            if (o === esperado)
                $display("  OK");
            else begin
                $display("  ERROR");
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        $display("========================================");
        $display("S(%0d,%0d) + S(%0d,%0d) -> S(%0d,%0d)",
                 NB1, NBF1, NB2, NBF2, NBO, NBFO);
        $display("  rango salida : [%f ; %f]",
                 -(2.0**(NBIO-1)), (2.0**(NBIO-1)) - (2.0**(-NBFO)));
        $display("  resolucion   : %f", 2.0**(-NBFO));
        $display("========================================");

        check(6'b110010, 8'b00011110,    2, "mixto:   -0.875 + 0.9375");
        check(6'b100000, 8'b10000000, -192, "min+min: -2 + -4");
        check(6'b011111, 8'b01111111,  189, "max+max: 1.9375 + 3.96875");

        $display("========================================");
        if (errores == 0) $display("TODOS LOS CASOS OK");
        else              $display("%0d CASO(S) CON ERROR", errores);
        $finish;
    end
endmodule
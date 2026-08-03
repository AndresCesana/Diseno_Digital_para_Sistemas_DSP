`timescale 1ns/1ps

module tb_alu;

    localparam int N_VEC = 256;

    // ---------------- estimulo compartido ----------------
    logic signed [7:0] a, b;
    logic        [1:0] op;

    // ---------------- salidas de cada DUT ----------------
    logic signed [7:0] y_bug, y_f1, y_f2;

    alu_bad u_bad (.a(a), .b(b), .op(op), .y(y_bug));
    alu_fix1  u_f1  (.a(a), .b(b), .op(op), .y(y_f1));
    alu_fix2  u_f2  (.a(a), .b(b), .op(op), .y(y_f2));

    int errors_f1     = 0;   // fix1 vs su modelo de referencia
    int errors_f2     = 0;   // fix2 vs su modelo de referencia
    int errors_core   = 0;   // desacuerdo entre DUTs en op != 11
    int latch_hits    = 0;   // veces que buggy retuvo el valor anterior
    int n_op11        = 0;

    logic signed [7:0] bug_hold = 'x;

    function automatic logic signed [7:0] ref_core(
        input logic signed [7:0] aa, bb,
        input logic        [1:0] oo
    );
        case (oo)
            2'b00:   ref_core = aa + bb;
            2'b01:   ref_core = aa - bb;
            2'b10:   ref_core = aa & bb;
            default: ref_core = 8'hxx;   // no definido por la spec
        endcase
    endfunction

    task automatic check_vector(input int idx);
        logic signed [7:0] exp_core, exp_f1, exp_f2, exp_bug;

        exp_core = ref_core(a, b, op);

        // valor esperado de cada implementacion
        exp_f1 = (op == 2'b11) ? 8'sd0 : exp_core;
        exp_f2  = (op == 2'b11) ? 8'sd0    : exp_core;
        exp_bug = (op == 2'b11) ? bug_hold : exp_core;

        if (y_f1 !== exp_f1) begin
            errors_f1++;
            $display("[%0t] ERROR fix1  vec=%0d op=%b a=%0d b=%0d  got=%0d exp=%0d",
                     $time, idx, op, a, b, y_f1, exp_f1);
        end

        if (y_f2 !== exp_f2) begin
            errors_f2++;
            $display("[%0t] ERROR fix2  vec=%0d op=%b a=%0d b=%0d  got=%0d exp=%0d",
                     $time, idx, op, a, b, y_f2, exp_f2);
        end

        // en las operaciones definidas las 3 DEBEN coincidir
        if (op != 2'b11) begin
            if ((y_bug !== y_f1) || (y_f1 !== y_f2)) begin
                errors_core++;
                $display("[%0t] MISMATCH nucleo vec=%0d op=%b a=%0d b=%0d  bug=%0d f1=%0d f2=%0d",
                         $time, idx, op, a, b, y_bug, y_f1, y_f2);
            end
        end
        else begin
            n_op11++;
            // el latch se manifiesta cuando buggy conserva un valor
            // previo valido en vez de producir algo definido
            if ((y_bug === bug_hold) && !$isunknown(bug_hold))
                latch_hits++;
        end

        // actualizar el estado del latch modelado
        bug_hold = y_bug;
    endtask

    // ------------------------------------------------------------
    // Secuencia principal
    // ------------------------------------------------------------
    int i;
    logic signed [7:0] dir_a [0:7];
    logic signed [7:0] dir_b [0:7];
    logic        [1:0] dir_o [0:7];

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);

        // ---- vectores dirigidos: bordes del signed y las 4 ops ----
        dir_a[0]= 8'sd127; dir_b[0]= 8'sd1;    dir_o[0]=2'b00; // overflow +
        dir_a[1]=-8'sd128; dir_b[1]= 8'sd1;    dir_o[1]=2'b01; // overflow -
        dir_a[2]= 8'sd0;   dir_b[2]= 8'sd0;    dir_o[2]=2'b00;
        dir_a[3]= 8'shFF;  dir_b[3]= 8'shF0;   dir_o[3]=2'b10;
        dir_a[4]= 8'sd55;  dir_b[4]= 8'sd55;   dir_o[4]=2'b01; // resta nula
        dir_a[5]= 8'sd42;  dir_b[5]= 8'sd7;    dir_o[5]=2'b11; // <-- latch
        dir_a[6]=-8'sd1;   dir_b[6]= 8'sd1;    dir_o[6]=2'b00;
        dir_a[7]= 8'sd99;  dir_b[7]= 8'sd12;   dir_o[7]=2'b11; // <-- latch

        $display("=== 256 vectores : buggy / fix1 / fix2 ===");

        for (i = 0; i < N_VEC; i++) begin
            if (i < 8) begin
                a  = dir_a[i];
                b  = dir_b[i];
                op = dir_o[i];
            end
            else begin
                a  = $urandom;
                b  = $urandom;
                op = $urandom_range(0, 3);
            end

            #5;                 // deja propagar la combinacional
            check_vector(i);
            #5;
        end

        // ---------------- reporte ----------------
        $display("--------------------------------------------------");
        $display("vectores aplicados .......... %0d", N_VEC);
        $display("vectores con op=2'b11 ....... %0d", n_op11);
        $display("errores fix1 ................ %0d", errors_f1);
        $display("errores fix2 ................ %0d", errors_f2);
        $display("desacuerdos en op!=11 ....... %0d", errors_core);
        $display("retenciones de latch (buggy)  %0d", latch_hits);
        $display("--------------------------------------------------");

        if (errors_f1 == 0 && errors_f2 == 0 && errors_core == 0)
            $display(">>> PASS : fix1 y fix2 correctas; nucleo identico en las 3");
        else
            $display(">>> FAIL");

        if (latch_hits > 0)
            $display(">>> LATCH CONFIRMADO en alu_buggy: retuvo el valor previo %0d veces con op=2'b11", latch_hits);

        $finish;
    end

endmodule
`timescale 1ns/1ps
module tb_alu;
    localparam int N_VEC = 256;
    logic signed [7:0] a, b;
    logic        [1:0] op;
    logic signed [7:0] y_bug, y_f1, y_f2;
    alu_bad  u_bad (.a(a), .b(b), .op(op), .y(y_bug));
    alu_fix1 u_f1  (.a(a), .b(b), .op(op), .y(y_f1));
    alu_fix2 u_f2  (.a(a), .b(b), .op(op), .y(y_f2));
    int errors_f1=0, errors_f2=0, errors_core=0, latch_hits=0, n_op11=0;
    int errors_xz=0, latch_xz=0;
    logic signed [7:0] bug_hold = 'x;
    function automatic logic signed [7:0] ref_core(input logic signed [7:0] aa, bb, input logic [1:0] oo);
        case (oo)
            2'b00: ref_core = aa + bb;
            2'b01: ref_core = aa - bb;
            2'b10: ref_core = aa & bb;
            default: ref_core = 8'hxx;
        endcase
    endfunction
    task automatic check_vector(input int idx);
        logic signed [7:0] exp_core, exp_f1, exp_f2, exp_bug;
        exp_core = ref_core(a, b, op);
        exp_f1 = (op == 2'b11) ? 8'sd0 : exp_core;
        exp_f2 = (op == 2'b11) ? 8'sd0 : exp_core;
        exp_bug = (op == 2'b11) ? bug_hold : exp_core;
        if (y_f1 !== exp_f1) errors_f1++;
        if (y_f2 !== exp_f2) errors_f2++;
        if (op != 2'b11) begin
            if ((y_bug !== y_f1) || (y_f1 !== y_f2)) errors_core++;
        end
        else begin
            n_op11++;
            if ((y_bug === bug_hold) && !$isunknown(bug_hold)) latch_hits++;
        end
        // ---- NUEVO: traza de los vectores dirigidos ----
        if (idx < 8)
            $display("%4d | %b | %5d | %5d | %6d | %5d | %5d",
                     idx, op, a, b, y_bug, y_f1, y_f2);
        bug_hold = y_bug;
    endtask
    // ------------------------------------------------------------
    // Sondeo con op no binario. No pasa por check_vector porque las
    // comparaciones con 2'b11 devuelven x cuando op tiene bits x/z.
    // ------------------------------------------------------------
    task automatic probe_xz(input logic [1:0] op_in, input string nota);
        begin
            op = op_in;
            #5;
            $display(" %b | %-22s | %6d | %5d | %5d",
                     op, nota, y_bug, y_f1, y_f2);
            if (!$isunknown(op_in)) begin
                // referencia conocida: las tres deben coincidir
                if ((y_bug !== y_f1) || (y_f1 !== y_f2)) errors_xz++;
            end
            else begin
                // ninguna rama del case hace match: las correcciones
                // deben quedar definidas en 0; buggy retiene.
                if ((y_f1 !== 8'sd0) || (y_f2 !== 8'sd0)) errors_xz++;
                if (y_bug === bug_hold && !$isunknown(bug_hold)) latch_xz++;
            end
            bug_hold = y_bug;
            #5;
        end
    endtask

    int i;
    logic signed [7:0] dir_a [0:7];
    logic signed [7:0] dir_b [0:7];
    logic        [1:0] dir_o [0:7];
    initial begin
        dir_a[0]= 8'sd127; dir_b[0]= 8'sd1;  dir_o[0]=2'b00;
        dir_a[1]=-8'sd128; dir_b[1]= 8'sd1;  dir_o[1]=2'b01;
        dir_a[2]= 8'sd0;   dir_b[2]= 8'sd0;  dir_o[2]=2'b00;
        dir_a[3]= 8'shFF;  dir_b[3]= 8'shF0; dir_o[3]=2'b10;
        dir_a[4]= 8'sd60;  dir_b[4]= 8'sd12; dir_o[4]=2'b10;
        dir_a[5]= 8'sd42;  dir_b[5]= 8'sd7;  dir_o[5]=2'b11;
        dir_a[6]= 8'sd99;  dir_b[6]= 8'sd33; dir_o[6]=2'b00;
        dir_a[7]= 8'sd99;  dir_b[7]= 8'sd12; dir_o[7]=2'b11;
        $display("");
        $display(" vec | op |     a |     b |  buggy |  fix1 |  fix2");
        $display("-----+----+-------+-------+--------+-------+-------");
        for (i = 0; i < N_VEC; i++) begin
            if (i < 8) begin a = dir_a[i]; b = dir_b[i]; op = dir_o[i]; end
            else begin a = $urandom; b = $urandom; op = $urandom_range(0,3); end
            #5; check_vector(i); #5;
        end
        // ---- fase 3: opcodes no binarios ----
        $display("");
        $display(" op | Escenario              |  buggy |  fix1 |  fix2");
        $display("----+------------------------+--------+-------+-------");
        a = 60; b = 12;                     // referencia: a & b = 12
        probe_xz(2'b10, "and, valor conocido");
        probe_xz(2'bx0, "op con bit X");
        probe_xz(2'b10, "and, valor conocido");
        probe_xz(2'bzz, "op en alta impedancia");

        $display("");
        $display("vectores aplicados .......... %0d", N_VEC);
        $display("vectores con op=2'b11 ....... %0d", n_op11);
        $display("retenciones de latch (buggy)  %0d", latch_hits);
        $display("errores en sondeo x/z ....... %0d", errors_xz);
        $display("retenciones ante x/z (buggy)  %0d", latch_xz);
        $finish;
    end
endmodule
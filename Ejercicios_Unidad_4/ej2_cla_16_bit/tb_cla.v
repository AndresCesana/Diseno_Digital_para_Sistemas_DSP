`timescale 1ns/1ps

module tb_cla #(
    parameter N          = 16,   // fijo: la jerarquia esta armada para 16 bits
    parameter N_RANDOM   = 500,
    parameter SETTLE     = 100,  // el CLA NO escala con N (~4 niveles AND/OR + 1 XOR)
    parameter START_TIME = 0,    // offset para serializar instancias
    parameter SEED       = 32'hC0FFEE
);

    initial begin
        if (N != 16) begin
            $display("ERROR: cla_tb solo soporta N=16 (jerarquia fija de 4 grupos de 4 bits).");
            $finish;
        end
    end

    // ---------------- DUT ----------------
    reg  [N-1:0] a, b;
    reg          c_in;
    wire [N-1:0] s;
    wire         c_out;

    cla16 dut (
        .a(a), .b(b), .c0(c_in), .s(s), .c16(c_out)
    );

    // ---------------- Contadores ----------------
    integer n_tests = 0;
    integer n_pass  = 0;
    integer n_fail  = 0;
    integer seed_r;

    // ---------------- Delays medidos ----------------
    time t_last_change;
    time t_delay_cin;    // camino c_in -> c_out (via ambos niveles de lookahead)
    time t_delay_data;   // camino a/b   -> c_out (peor caso desde datos)

    always @(s or c_out) t_last_change = $time;

    // Compuertas primitivas instanciadas en toda la jerarquia (N=16 fijo):
    //   pg_gen:        16 x (1 XOR + 1 AND)                    = 32
    //   cla_lookahead: 5 instancias (4 nivel1 + 1 nivel2) x 14  = 70
    //   group_pg:      4 x 5                                    = 20
    //   xor final:     16 x 1                                    = 16
    localparam GATES = 32 + 70 + 20 + 16; // = 138

    // -------------------------------------------------------------------------
    task check;
        input [N-1:0] ta, tb_;
        input         tc;
        input [255:0] tag;
        input         verbose;
        reg [N:0] expected;
        reg [N:0] got;
        begin
            a    = ta;
            b    = tb_;
            c_in = tc;
            #SETTLE;

            expected = {1'b0, ta} + {1'b0, tb_} + tc;
            got      = {c_out, s};

            n_tests = n_tests + 1;

            if (got === expected) begin
                n_pass = n_pass + 1;
                if (verbose)
                    $display("  [PASS] CLA N=%0d %0s  a=%h b=%h cin=%b -> cout=%b s=%h",
                             N, tag, ta, tb_, tc, c_out, s);
            end else begin
                n_fail = n_fail + 1;
                $display("  [FAIL] CLA N=%0d %0s  a=%h b=%h cin=%b -> got %h, esperado %h",
                         N, tag, ta, tb_, tc, got, expected);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // measure_cin: preset con TODOS los bits en modo propagate (a=FFFF,
    // b=0000) y se levanta c_in. Ejercita el termino p*p*...*c0 de las
    // ecuaciones de lookahead en ambos niveles (grupo y global).
    // -------------------------------------------------------------------------
    task measure_cin;
        time t0;
        begin
            a = {N{1'b1}}; b = {N{1'b0}}; c_in = 1'b0;
            #SETTLE;
            t0 = $time;
            c_in = 1'b1;             // <-- unico evento
            #SETTLE;
            t_delay_cin = t_last_change - t0;
            settle_warn(t_delay_cin, "c_in->out");
        end
    endtask

    // -------------------------------------------------------------------------
    // measure_data: bit0 GENERA (a0=b0=1) y el resto PROPAGA (a_i=1,b_i=0).
    // Es el peor caso clasico para una red de lookahead: fuerza el termino
    // mas largo de las sumas de productos en ambos niveles.
    // -------------------------------------------------------------------------
    task measure_data;
        time t0;
        begin
            a = {N{1'b0}}; b = {N{1'b0}}; c_in = 1'b0;
            #SETTLE;
            t0 = $time;
            a = {N{1'b1}};
            b = {{(N-1){1'b0}}, 1'b1};
            #SETTLE;
            t_delay_data = t_last_change - t0;
            settle_warn(t_delay_data, "a/b->out");
        end
    endtask

    task settle_warn;
        input time d;
        input [63:0] which;
        begin
            if (d * 10 >= SETTLE * 8)
                $display("  [WARN] CLA N=%0d %0s: delay %0d ua vs SETTLE %0d ua.",
                         N, which, d, SETTLE);
        end
    endtask

    // -------------------------------------------------------------------------
    integer k;
    reg [N-1:0] ra, rb;
    reg         rc;

    initial begin
        seed_r = SEED;
        #START_TIME;

        $display("");
        $display("==============================================================");
        $display(" CLA self-check  |  N = %0d bits (jerarquico, 4 grupos de 4)", N);
        $display("==============================================================");

        $display(" -- Casos borde --");
        check({N{1'b0}}, {N{1'b0}}, 1'b0, "borde inferior 0+0+0", 1);
        check({N{1'b1}}, {N{1'b1}}, 1'b1, "borde superior MAX+MAX+1", 1);
        check({N{1'b1}}, {N{1'b1}}, 1'b0, "MAX+MAX+0", 1);

        $display(" -- Casos dirigidos con c_out = 1 --");
        check({1'b1, {(N-1){1'b0}}}, {1'b1, {(N-1){1'b0}}}, 1'b0, "MSB+MSB", 1);
        check({N{1'b1}}, {{(N-1){1'b0}}, 1'b1}, 1'b0, "MAX+1", 1);
        check({N{1'b1}}, {N{1'b0}}, 1'b1, "MAX+0+cin (propagate total)", 1);

        $display(" -- %0d casos random --", N_RANDOM);
        for (k = 0; k < N_RANDOM; k = k + 1) begin
            ra = $random(seed_r);
            rb = $random(seed_r);
            rc = $random(seed_r);
            check(ra, rb, rc, "random", 0);
        end
        $display("  (%0d random completados, solo se listan los FAIL)", N_RANDOM);

        measure_cin();
        measure_data();

        report();

        $display("CSV,CLA,%0d,%0d,%0d,%0d,%0d,%0d",
                 N, GATES, t_delay_cin, t_delay_data, n_pass, n_fail);
    end

    // -------------------------------------------------------------------------
    task report;
        begin
            $display("");
            $display(" --------------------------------------------------------");
            $display("  REPORTE  CLA N = %0d", N);
            $display(" --------------------------------------------------------");
            $display("  Tests corridos ....... %0d", n_tests);
            $display("  PASS ................. %0d", n_pass);
            $display("  FAIL ................. %0d", n_fail);
            $display("  Compuertas totales ... %0d", GATES);
            $display("  Delay c_in -> out .... %0d ua", t_delay_cin);
            $display("  Delay a/b  -> out .... %0d ua", t_delay_data);
            if (n_fail == 0)
                $display("  RESULTADO ............ *** PASS ***");
            else
                $display("  RESULTADO ............ *** FAIL (%0d errores) ***", n_fail);
            $display("");
            $display("  CRITICAL PATH OBSERVADO");
            $display("    g0/c0 -> [nivel1: AND+OR] -> [nivel2: AND+OR] -> XOR final");
            $display("    ~4 niveles de AND/OR + 1 XOR. A diferencia del RCA,");
            $display("    NO escala con N (para esta jerarquia de 16 bits fija).");
            $display(" --------------------------------------------------------");
        end
    endtask

endmodule
`timescale 1ns/1ps

module rca_tb #(
    parameter N          = 8,
    parameter N_RANDOM   = 500,
    parameter SETTLE     = 40*N + 200,  // escala con N: debe superar el
                                        // ripple worst-case (~t_gate*N)
    parameter START_TIME = 0,        // offset para serializar instancias
    parameter SEED       = 32'hC0FFEE
);

    // ---------------- DUT ----------------
    reg  [N-1:0] a, b;
    reg          c_in;
    wire [N-1:0] s;
    wire         c_out;

    rca #(.N(N)) dut (
        .a(a), .b(b), .c_in(c_in), .s(s), .c_out(c_out)
    );

    // ---------------- Contadores ----------------
    integer n_tests = 0;
    integer n_pass  = 0;
    integer n_fail  = 0;
    integer seed_r;

    // ---------------- Delays medidos ----------------
    time t_last_change;
    time t_delay_cin;    // camino c_in -> c_out (ripple puro)
    time t_delay_data;   // camino a/b   -> c_out (peor caso desde datos)

    // Sensor de actividad: cada vez que cambia una salida, anoto el instante.
    // Cuando el circuito se estabiliza, t_last_change queda congelado en el
    // ultimo evento -> ese es el delay de propagacion.
    always @(s or c_out) t_last_change = $time;

    // -------------------------------------------------------------------------
    // check : aplica un vector, espera estabilizacion y compara contra el
    //         modelo de referencia. Imprime PASS/FAIL.
    // -------------------------------------------------------------------------
    task check;
        input [N-1:0] ta, tb_;
        input         tc;
        input [255:0] tag;      // etiqueta ASCII del caso (32 chars)
        input         verbose;  // 1 = imprimir siempre, 0 = solo si falla
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
                    $display("  [PASS] N=%0d %0s  a=%h b=%h cin=%b -> cout=%b s=%h",
                             N, tag, ta, tb_, tc, c_out, s);
            end else begin
                n_fail = n_fail + 1;
                $display("  [FAIL] N=%0d %0s  a=%h b=%h cin=%b -> got %h, esperado %h",
                         N, tag, ta, tb_, tc, got, expected);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // measure_cin : delay del camino c_in -> c_out.
    //   Pre-estado a = 111...1, b = 000...0, c_in = 0  (todas las etapas en
    //   modo PROPAGATE: p[i] = 1). Al levantar c_in el carry debe atravesar
    //   las N etapas. Es el worst case clasico del RCA.
    // -------------------------------------------------------------------------
    task measure_cin;
        time t0;
        begin
            a = {N{1'b1}}; b = {N{1'b0}}; c_in = 1'b0;
            #SETTLE;                 // dejar quieto el circuito
            t0 = $time;
            c_in = 1'b1;             // <-- unico evento
            #SETTLE;
            t_delay_cin = t_last_change - t0;
            settle_warn(t_delay_cin, "c_in->out");
        end
    endtask

    // -------------------------------------------------------------------------
    // measure_data : delay del camino a/b -> c_out.
    //   Desde reposo total se aplica a = 111...1, b = 000...01. La etapa 0
    //   GENERA carry y las N-1 restantes lo PROPAGAN.
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

    // -------------------------------------------------------------------------
    // settle_warn : si el delay medido se acerca al techo de SETTLE, la
    // medicion esta truncada y los checks funcionales muestrean antes de
    // que el circuito se estabilice. Silencioso mata: hay que avisar.
    // -------------------------------------------------------------------------
    task settle_warn;
        input time d;
        input [63:0] which;
        begin
            if (d * 10 >= SETTLE * 8)
                $display("  [WARN] N=%0d %0s: delay %0d ua vs SETTLE %0d ua.",
                         N, which, d, SETTLE);
        end
    endtask

    // -------------------------------------------------------------------------
    // Secuencia principal
    // -------------------------------------------------------------------------
    integer k;
    reg [N-1:0] ra, rb;
    reg         rc;

    initial begin
        seed_r = SEED;
        #START_TIME;

        $display("");
        $display("==============================================================");
        $display(" RCA self-check  |  N = %0d bits", N);
        $display("==============================================================");

        // ---- 1. Borde inferior ----
        $display(" -- Casos borde --");
        check({N{1'b0}}, {N{1'b0}}, 1'b0, "borde inferior 0+0+0", 1);

        // ---- 2. Borde superior ----
        check({N{1'b1}}, {N{1'b1}}, 1'b1, "borde superior MAX+MAX+1", 1);
        check({N{1'b1}}, {N{1'b1}}, 1'b0, "MAX+MAX+0", 1);

        // ---- 3. Casos con carry_out = 1 ----
        $display(" -- Casos dirigidos con c_out = 1 --");
        // MSB + MSB: resultado exacto 2^N -> s = 0, c_out = 1
        check({1'b1, {(N-1){1'b0}}}, {1'b1, {(N-1){1'b0}}}, 1'b0, "MSB+MSB", 1);
        // MAX + 1: wrap-around a cero
        check({N{1'b1}}, {{(N-1){1'b0}}, 1'b1}, 1'b0, "MAX+1", 1);
        // MAX + 0 + cin: el carry entra y se propaga N etapas
        check({N{1'b1}}, {N{1'b0}}, 1'b1, "MAX+0+cin (ripple total)", 1);

        // ---- 4. Random ----
        $display(" -- %0d casos random --", N_RANDOM);
        for (k = 0; k < N_RANDOM; k = k + 1) begin
            ra = $random(seed_r);
            rb = $random(seed_r);
            rc = $random(seed_r);
            check(ra, rb, rc, "random", 0);   // silencioso salvo FAIL
        end
        $display("  (%0d random completados, solo se listan los FAIL)", N_RANDOM);

        // ---- Medicion de delay ----
        measure_cin();
        measure_data();

        // ---- Reporte ----
        report();

        // Linea legible por script (grep CSV)
        $display("CSV,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                 N, N, 5*N, t_delay_cin, t_delay_data, n_pass, n_fail);
    end

    // -------------------------------------------------------------------------
    task report;
        begin
            $display("");
            $display(" --------------------------------------------------------");
            $display("  REPORTE  N = %0d", N);
            $display(" --------------------------------------------------------");
            $display("  Tests corridos ....... %0d", n_tests);
            $display("  PASS ................. %0d", n_pass);
            $display("  FAIL ................. %0d", n_fail);
            $display("  Full adders (N) ...... %0d", N);
            $display("  Compuertas (5 x N) ... %0d   [2 XOR + 2 AND + 1 OR por FA]", 5*N);
            $display("  Delay c_in -> out .... %0d ua", t_delay_cin);
            $display("  Delay a/b  -> out .... %0d ua", t_delay_data);
            $display("  Delay por etapa ...... %0d ua   [AND + OR del camino de carry]",
                     t_delay_cin / N);
            if (n_fail == 0)
                $display("  RESULTADO ............ *** PASS ***");
            else
                $display("  RESULTADO ............ *** FAIL (%0d errores) ***", n_fail);
            $display("");
            $display("  CRITICAL PATH OBSERVADO");
            $display("    Cadena: c[0] -> AND(pc) -> OR(c_out) -> c[1] -> ... -> c[%0d]", N);
            $display("    %0d etapas x 2 compuertas = %0d niveles logicos", N, 2*N);
            $display("    Medido %0d ua = %0d ua/etapa (AND=2 + OR=2). Escala O(N):", 
                     t_delay_cin, t_delay_cin/N);
            $display("    duplicar N duplica el delay -> este es el cuello de");
            $display("    botella que motiva carry-lookahead / carry-select.");
            $display("    Las XOR del camino de suma NO estan en el path critico:");
            $display("    p[i]=a^b se calcula en paralelo (t=%0d) y ya esta listo", 3);
            $display("    cuando llega el carry. Por eso el FA expone solo 2");
            $display("    compuertas al ripple y no 3.");
            $display(" --------------------------------------------------------");
        end
    endtask

endmodule


// =============================================================================
// Top: instancia el TB para N = 4, 8, 16, 32.
// START_TIME escalonado para que los $display no se entrelacen.
// =============================================================================
module tb_top;


    localparam SLOT   = 5_000_000;   // ventana por instancia (holgada)

    rca_tb #(.N(4),  .START_TIME(0*SLOT)) tb04 ();
    rca_tb #(.N(8),  .START_TIME(1*SLOT)) tb08 ();
    rca_tb #(.N(16), .START_TIME(2*SLOT)) tb16 ();
    rca_tb #(.N(32), .START_TIME(3*SLOT)) tb32 ();

    initial begin
        $dumpfile("rca.vcd");
        $dumpvars(0, tb_top.tb08);   // solo N=8 para que el VCD no explote
        #(4*SLOT);
        $display("");
        $display("=== Simulacion finalizada ===");
        $finish;
    end

endmodule
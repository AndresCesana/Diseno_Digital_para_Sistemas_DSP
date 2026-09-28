// tb_dff_sync2.v - Testbench para el sincronizador de doble FF.
//
// Verifica:
//   1. Tres configuraciones del sincronizador (normal, demo y tau real) siguen
//      el mismo pipeline de dos etapas, con reset activo en bajo.
//   2. El modelo estadistico detecta cambios de src_bit cercanos al flanco y
//      reporta los fallos estimados para FF1 y FF2.
//   3. 2000 toggles con fase progresiva generan una muestra reproducible de las
//      ventanas setup/hold y resultados estadisticos dentro de rangos amplios.
//   4. bad_cross (un solo FF, sin sincronizador) pasa a X en cada cambio de
//      src_bit dentro de la ventana critica, mientras que synced nunca pasa a X.
//
// meta_model.v solo genera senales y contadores de diagnostico; no inyecta X ni
// modifica las salidas de los sincronizadores. Por eso las tres salidas deben
// coincidir siempre con el pipeline digital de referencia.
//
// Compilacion desde este directorio:
//   iverilog -g2012 -o sim dff_sync2.v tb_dff_sync2.v && vvp sim
// Ondas para GTKWave: tb_dff_sync2.vcd

`timescale 1ns/1ps
`include "meta_model.v"
`include "bad_cross.v"

module tb_dff_sync2;
    // El reloj de destino tiene un periodo de 5 ns (200 MHz), como el modelo.
    reg dst_clk = 1'b0;
    reg rst = 1'b0;
    reg src_bit = 1'b0;

    // Salidas de las tres instancias y diagnosticos del modelo de metastabilidad.
    wire synced_normal;
    wire synced_demo;
    wire synced_real;

    wire setup_win;
    wire hold_win;
    wire stat_meta_event;
    wire stat_ff1_failed;
    wire sync_ff2_fail_demo;
    wire sync_ff2_fail_real;

    // Salida del cruce sin sincronizador.
    wire bad_q;

    // Referencia independiente: cada flanco desplaza src_bit por dos etapas.
    reg [1:0] expected_pipe = 2'b00;

    // Contadores de pulsos diagnosticos y de toggles aplicados por este TB.
    integer meta_pulses = 0;
    integer ff1_failures = 0;
    integer ff2_demo_failures = 0;
    integer ff2_real_failures = 0;
    integer toggle_count = 0;
    integer bad_x_events = 0;

    always #2.5 dst_clk = ~dst_clk;

    // Se conservan los tres valores TAU_DEMO de la consigna para comparar los
    // casos normal/demo/real. dff_sync2 solo implementa el pipeline digital:
    // este parametro no altera synced; los tau estadisticos se configuran abajo
    // en meta_model, que genera diagnosticos aparte de las salidas del DUT.
    dff_sync2 #(.TAU_DEMO(0)) u_sync (
        .dst_clk(dst_clk), .rst(rst), .src_bit(src_bit), .synced(synced_normal)
    );
    dff_sync2 #(.TAU_DEMO(3000)) u_sync_demo (
        .dst_clk(dst_clk), .rst(rst), .src_bit(src_bit), .synced(synced_demo)
    );
    dff_sync2 #(.TAU_DEMO(50)) u_sync_real (
        .dst_clk(dst_clk), .rst(rst), .src_bit(src_bit), .synced(synced_real)
    );

    // Una unica instancia calcula ambos escenarios estadisticos: TAU_DEMO para
    // la demostracion y TAU_REAL para el caso real; las ventanas setup/hold son
    // visibles en GTKWave junto con los pulsos de fallo.
    meta_model #(.TAU_DEMO(3000), .TAU_REAL(50), .SEED(12345)) u_meta_model (
        .dst_clk(dst_clk),
        .rst(rst),
        .src_bit(src_bit),
        .setup_win(setup_win),
        .hold_win(hold_win),
        .stat_meta_event(stat_meta_event),
        .stat_ff1_failed(stat_ff1_failed),
        .sync_ff2_fail_demo(sync_ff2_fail_demo),
        .sync_ff2_fail_real(sync_ff2_fail_real)
    );

    // Contraejemplo: un unico FF muestrea src_bit sin sincronizador. Usa las
    // mismas ventanas que meta_model (T_SETUP=500 ps, T_HOLD=250 ps), por lo
    // que cada evento meta del modelo debe producir una X en bad_q.
    bad_cross #(.T_SETUP(500), .T_HOLD(250)) u_bad (
        .dst_clk(dst_clk),
        .rst(rst),
        .src_bit(src_bit),
        .q(bad_q)
    );

    // Se chequea despues del NBA del DUT (1 ps mas tarde) para comparar con el
    // pipeline ya actualizado. Esto valida reset y latencia de dos flancos.
    always @(posedge dst_clk) begin
        if (!rst)
            expected_pipe <= 2'b00;
        else
            expected_pipe <= {expected_pipe[0], src_bit};

        #0.001;
        if ({synced_normal, synced_demo, synced_real} !== {3{expected_pipe[1]}})
            $fatal(1, "Synchronizer mismatch: expected %b, got %b%b%b",
                   expected_pipe[1], synced_normal, synced_demo, synced_real);

        if (stat_ff1_failed)
            ff1_failures = ff1_failures + 1;
        if (sync_ff2_fail_demo)
            ff2_demo_failures = ff2_demo_failures + 1;
        if (sync_ff2_fail_real)
            ff2_real_failures = ff2_real_failures + 1;

        // Violacion de setup en bad_cross: el FF captura X en este flanco.
        if (bad_q === 1'bx)
            bad_x_events = bad_x_events + 1;
    end

    // stat_meta_event es un pulso asincrono; FF1/FF2 se cuentan en el flanco de
    // destino porque el modelo los presenta como pulsos alineados al reloj.
    always @(posedge stat_meta_event)
        meta_pulses = meta_pulses + 1;

    // bad_q pasa a X en el cambio de src_bit (violacion de hold) o en el flanco
    // (violacion de setup). Varias violaciones seguidas sin un flanco limpio en
    // el medio forman un unico tramo en X en la onda, por eso no se cuentan las
    // transiciones de bad_q sino cada violacion por separado:
    //   - setup: bad_q es X 1 ps despues del flanco (ver el checker de arriba).
    //   - hold : bad_q es X 1 ps despues de un cambio de src_bit dentro de hold_win.
    always @(src_bit) begin
        #0.001;
        if (rst && hold_win && bad_q === 1'bx)
            bad_x_events = bad_x_events + 1;
    end

    initial begin
        // Capturar tambien las ventanas criticas y los pulsos de estadistica.
        $dumpfile("tb_dff_sync2.vcd");
        $dumpvars(0, tb_dff_sync2);

        // Mantener reset bajo mientras se prepara src_bit=1; tras liberarlo,
        // tres flancos permiten comprobar el desplazamiento completo del dato.
        #8 src_bit = 1'b1;
        #0.001 rst = 1'b1;
        repeat (3) @(posedge dst_clk);
        #0.01;
        if ({synced_normal, synced_demo, synced_real} !== 3'b111)
            $fatal(1, "Reset/shift check failed: expected all synchronizers high");

        // Cada toggle ocurre 100 ps antes respecto del reloj que el anterior:
        // se recorren 50 fases en 5 ns y se repite el barrido 40 veces. El seed
        // fijo del modelo hace reproducibles los contadores estadisticos.
        #1.94;
        repeat (2000) begin
            #4.9 src_bit = ~src_bit;
            toggle_count = toggle_count + 1;
        end

        #10;
        $display("SUMMARY: toggles=%0d meta=%0d FF1=%0d FF2_demo=%0d FF2_real=%0d bad_X=%0d",
                 toggle_count, meta_pulses, ff1_failures,
                 ff2_demo_failures, ff2_real_failures, bad_x_events);

        if (toggle_count != 2000)
            $fatal(1, "Expected 2000 source toggles, got %0d", toggle_count);

        // Las ventanas suman 750 ps por periodo de 5000 ps: se esperan cerca
        // de 300 eventos meta en 2000 cambios. Los rangos toleran la variacion
        // aleatoria de resolucion; con tau=50 ps, FF2 real no debe fallar.
        if (meta_pulses < 150 || meta_pulses > 450)
            $fatal(1, "Unexpected metastability count: %0d", meta_pulses);
        if (ff1_failures < 20 || ff1_failures > 100)
            $fatal(1, "Unexpected FF1 failure count: %0d", ff1_failures);
        if (ff2_demo_failures > 30)
            $fatal(1, "Unexpected demo FF2 failure count: %0d", ff2_demo_failures);
        if (ff2_real_failures != 0)
            $fatal(1, "Unexpected real FF2 failure count: %0d", ff2_real_failures);

        // bad_cross usa las mismas ventanas que meta_model: debe pasar a X una
        // vez por evento meta, y recuperarse en el siguiente flanco limpio.
        if (bad_x_events != meta_pulses)
            $fatal(1, "bad_cross X events (%0d) != meta events (%0d)",
                   bad_x_events, meta_pulses);
        if (bad_q === 1'bx)
            $fatal(1, "bad_cross output stuck at X after the last toggle");

        $display("Testbench passed: toggles=%0d meta=%0d FF1=%0d FF2_demo=%0d FF2_real=%0d bad_X=%0d",
                 toggle_count, meta_pulses, ff1_failures,
                 ff2_demo_failures, ff2_real_failures, bad_x_events);
        $finish;
    end
endmodule
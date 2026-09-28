`timescale 1ns/1ps
// ============================================================================
// meta_model.v - Modelo estadistico de metaestabilidad (SOLO SIMULACION)
//
// Cuando src_bit cambia dentro de la ventana critica (setup/hold) de dst_clk,
// se sortea un tiempo de resolucion exponencial:
//        t_res = -tau * ln(u),   u ~ U(0,1)   =>   P(t_res > t) = exp(-t/tau)
//
//   FF1 no resuelve en 1 periodo   : P = exp(-T/tau)
//   FF2 no resuelve (2 periodos)   : P = exp(-2T/tau)
//
// T = periodo de dst_clk (se mide solo). Con T = 5000 ps (200 MHz):
//   tau = 3000 ps -> exp(-10000/3000) ~ 3.6 %
//   tau =   50 ps -> exp(-200)        ~ 1e-87
//
// El modelo NO modifica 'synced': solo genera senales de diagnostico y
// contadores (un simulador digital no puede representar el estado analogico).
// ============================================================================
module meta_model #(
    parameter integer TAU_DEMO = 0,      // ps. 0 = estadistica desactivada
    parameter integer TAU_REAL = 50,     // ps. tau aproximado de sky130
    parameter integer T_SETUP  = 500,    // ps antes del flanco
    parameter integer T_HOLD   = 250,    // ps despues del flanco
    parameter integer SEED     = 12345
)(
    input  wire dst_clk,
    input  wire rst,                     // activo en BAJO (como tu dff_sync2)
    input  wire src_bit,
    output reg  setup_win,               // ventana de setup antes de cada flanco
    output reg  hold_win,                // ventana de hold despues de cada flanco
    output reg  stat_meta_event,         // pulso: captura metaestable
    output reg  stat_ff1_failed,         // pulso: FF1 no resolvio en 1 periodo
    output reg  sync_ff2_fail_demo,      // pulso: FF2 no resolvio (tau = TAU_DEMO)
    output reg  sync_ff2_fail_real       // pulso: FF2 no resolvio (tau = TAU_REAL)
);
    localparam ENABLE = (TAU_DEMO > 0);

    realtime t_edge      = -1.0;
    realtime t_prev_edge = -1.0;
    realtime t_src       = -1.0e12;
    real     T           = 0.0;          // periodo medido de dst_clk (ps)
    integer  seed        = SEED;

    integer n_toggles = 0, n_meta = 0, n_ff1 = 0, n_ff2_demo = 0, n_ff2_real = 0;

    // Resultado del evento meta asociado al flanco actual
    reg meta_now = 0, f1_now = 0, f2d_now = 0, f2r_now = 0;
    // Retardo extra para mostrar el fallo de FF2 dos flancos despues del evento
    reg f2d_dly = 0, f2r_dly = 0;

    initial begin
        setup_win = 0; hold_win = 0; stat_meta_event = 0;
        stat_ff1_failed = 0; sync_ff2_fail_demo = 0; sync_ff2_fail_real = 0;
    end

    // Sorteo del tiempo de resolucion de un evento metaestable
    task automatic draw_resolution;
        integer r;
        real u, tres_demo, tres_real;
        begin
            r = $random(seed);
            u = ((r & 32'h7fffffff) + 1.0) / 2147483649.0;   // u en (0,1)
            tres_demo = -TAU_DEMO * $ln(u);
            tres_real = -TAU_REAL * $ln(u);

            meta_now = 1'b1;
            f1_now   = (tres_demo > T);
            f2d_now  = (tres_demo > 2.0*T);
            f2r_now  = (tres_real > 2.0*T);

            n_meta     = n_meta     + 1;
            n_ff1      = n_ff1      + f1_now;
            n_ff2_demo = n_ff2_demo + f2d_now;
            n_ff2_real = n_ff2_real + f2r_now;

            stat_meta_event <= 1'b1;
            stat_meta_event <= #0.2 1'b0;
        end
    endtask

    always @(posedge dst_clk) begin
        t_prev_edge = t_edge;
        t_edge      = ($realtime*1000.0);
        if (t_prev_edge >= 0.0) T = t_edge - t_prev_edge;

        // Ventanas criticas (siempre visibles, sirven tambien para bad_cross)
        hold_win  <= 1'b1;
        hold_win  <= #(T_HOLD/1000.0) 1'b0;
        setup_win <= 1'b0;
        if (T > T_SETUP) setup_win <= #((T - T_SETUP)/1000.0) 1'b1;

        // Pulsos de fallo: FF1 un flanco despues del evento, FF2 dos flancos despues
        stat_ff1_failed    <= f1_now;
        sync_ff2_fail_demo <= f2d_dly;
        sync_ff2_fail_real <= f2r_dly;
        f2d_dly  = f2d_now;
        f2r_dly  = f2r_now;
        meta_now = 0; f1_now = 0; f2d_now = 0; f2r_now = 0;

        // Violacion de SETUP: src_bit cambio poco antes de este flanco
        if (ENABLE && rst && T > 0.0 && (t_edge - t_src) < T_SETUP)
            draw_resolution();
    end

    always @(src_bit) begin
        t_src = ($realtime*1000.0);
        if (ENABLE && rst && T > 0.0) begin
            n_toggles = n_toggles + 1;
            // Violacion de HOLD: src_bit cambio poco despues del ultimo flanco
            if (!meta_now && (t_src - t_edge) < T_HOLD)
                draw_resolution();
        end
    end

    // Resumen al terminar la simulacion (requiere $finish en el TB)
    final if (ENABLE)
        $display("[%m] TAU=%0d ps T=%0.0f ps | toggles=%0d meta=%0d FF1_fallos=%0d FF2_demo=%0d FF2_real=%0d",
                 TAU_DEMO, T, n_toggles, n_meta, n_ff1, n_ff2_demo, n_ff2_real);
endmodule
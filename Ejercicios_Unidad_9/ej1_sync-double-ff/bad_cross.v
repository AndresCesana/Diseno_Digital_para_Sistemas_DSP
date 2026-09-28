`timescale 1ns/1ps
// ============================================================================
// bad_cross.v - Cruce de dominio SIN sincronizador (ejemplo de lo que NO hacer)
//
// Un unico FF en dst_clk muestrea src_bit directamente. Si src_bit cambia
// dentro de la ventana critica, la salida se pone en X (modela el FF
// metaestable) hasta el proximo flanco limpio.
// ============================================================================
module bad_cross #(
    parameter integer T_SETUP = 500,     // ps (mismos valores que meta_model)
    parameter integer T_HOLD  = 250      // ps
)(
    input  wire dst_clk,
    input  wire rst,                     // activo en BAJO
    input  wire src_bit,
    output reg  q
);
    realtime t_src  = -1.0e12;
    realtime t_edge = -1.0e12;

    initial q = 1'b0;

    // Violacion de HOLD: cambio justo despues del flanco -> FF metaestable
    always @(src_bit) begin
        t_src = ($realtime*1000.0);
        if (rst && (($realtime*1000.0) - t_edge) < T_HOLD)
            q <= 1'bx;
    end

    always @(posedge dst_clk) begin
        t_edge = ($realtime*1000.0);
        if (!rst)
            q <= 1'b0;
        else if ((($realtime*1000.0) - t_src) < T_SETUP)   // violacion de SETUP
            q <= 1'bx;
        else
            q <= src_bit;
    end
endmodule
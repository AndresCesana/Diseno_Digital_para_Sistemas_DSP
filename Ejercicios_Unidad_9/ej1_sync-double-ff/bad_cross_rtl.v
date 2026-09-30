// bad_cross_rtl.v - Cruce de dominio sin sincronizador, sintetizable.
//
// Un FF en el dominio origen (src_clk) y un unico FF en el dominio destino
// (dst_clk) que lo muestrea directamente: dos flip-flops y un cable, sin
// logica ni reset (un reset compartido seria otro cruce de dominio).
//
// En simulacion RTL nunca muestra X: el simulador no conoce setup/hold.
// Sirve para el STA: el camino src_ff -> dst_ff es el cruce de dominio.
// (La version con X modelada para simulacion es bad_cross.v.)
module bad_cross_rtl (
    input  wire src_clk,
    input  wire dst_clk,
    input  wire src_bit,
    output wire q
);
    reg src_ff;   // dominio origen
    reg dst_ff;   // dominio destino: muestrea src_ff sin sincronizar

    always @(posedge src_clk) src_ff <= src_bit;
    always @(posedge dst_clk) dst_ff <= src_ff;

    assign q = dst_ff;
endmodule
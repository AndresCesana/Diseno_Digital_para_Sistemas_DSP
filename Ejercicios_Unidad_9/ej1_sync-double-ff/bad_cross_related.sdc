# bad_cross_related.sdc - Dos relojes SIN declarar la relacion entre ellos.
#
# OpenSTA asume que ambos relojes arrancan en t = 0 y busca la peor pareja
# de flancos lanzamiento/captura en el periodo comun (MCM de 4.9 y 5.0 ns =
# 245 ns). Los flancos llegan a estar a solo 0.1 ns: el cruce "tiene" que
# llegar en 0.1 ns, cosa imposible. Esto es lo que ve el STA de un CDC sin
# restricciones: una violacion que no se puede arreglar con timing.

create_clock -name src_clk -period 4.9 [get_ports src_clk]
create_clock -name dst_clk -period 5.0 [get_ports dst_clk]

set_input_delay  1.0 -clock src_clk [get_ports src_bit]
set_output_delay 1.0 -clock dst_clk [get_ports q]

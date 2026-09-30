# bad_cross_async.sdc - Los mismos dos relojes, declarados asincronos.
#
# set_clock_groups -asynchronous le dice al STA que no hay relacion de fase
# entre src_clk y dst_clk, asi que deja de analizar los caminos que cruzan.
# La violacion desaparece del reporte, pero el problema fisico sigue ahi:
# el STA ya no puede verificar el cruce. Por eso hace falta un sincronizador.

create_clock -name src_clk -period 4.9 [get_ports src_clk]
create_clock -name dst_clk -period 5.0 [get_ports dst_clk]
set_clock_groups -asynchronous -group {src_clk} -group {dst_clk}

set_input_delay  1.0 -clock src_clk [get_ports src_bit]
set_output_delay 1.0 -clock dst_clk [get_ports q]

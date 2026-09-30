# sta.tcl - Analisis estatico de timing con OpenSTA.
#
# Se ejecuta con:  sta -no_init -no_splash -exit sta.tcl
# Recibe por variables de entorno (las define run_sta.sh):
#   LIB, NETLIST, TOP, SDC
#
# Imprime los reportes completos y, al final, lineas "RESULT <clave> <valor>"
# que run_sta.sh usa para armar el resumen.

read_liberty $::env(LIB)
read_verilog $::env(NETLIST)
link_design  $::env(TOP)
read_sdc     $::env(SDC)

# Camino registro -> registro: en el sincronizador es FF1 -> FF2.
# Su slack de setup es el tiempo de resolucion disponible para FF1.
set ff_clk  [all_registers -clock_pins]
set ff_data [all_registers -data_pins]

puts "\n=== Camino FF1 -> FF2 (setup) ==="
report_checks -from $ff_clk -to $ff_data -path_delay max -digits 3

puts "\n=== Camino FF1 -> FF2 (hold) ==="
report_checks -from $ff_clk -to $ff_data -path_delay min -digits 3

puts "\n=== Peor camino de cada grupo (setup y hold) ==="
report_checks -path_delay min_max -digits 3

puts "\n=== Resumen de violaciones ==="
report_wns
report_tns

# ---- Valores para el resumen de run_sta.sh ----
proc emit_slack {key paths} {
    if {[llength $paths] == 0} {
        puts "RESULT $key none"
    } else {
        puts "RESULT $key [format %.3f [get_property [lindex $paths 0] slack]]"
    }
}
emit_slack reg2reg_setup [find_timing_paths -from $ff_clk -to $ff_data -path_delay max]
emit_slack reg2reg_hold  [find_timing_paths -from $ff_clk -to $ff_data -path_delay min]
emit_slack worst_setup   [find_timing_paths -path_delay max]
emit_slack worst_hold    [find_timing_paths -path_delay min]
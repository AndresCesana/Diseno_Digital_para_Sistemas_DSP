# synth.tcl - Sintesis de un diseno a celdas sky130_fd_sc_hd con Yosys.
#
# Se ejecuta con:  yosys -c synth.tcl
# Recibe todo por variables de entorno (las define run_sta.sh):
#   SRC      archivo Verilog del diseno
#   TOP      nombre del modulo top
#   LIB      liberty de sky130 (esquina tt_025C_1v80)
#   NETLIST  archivo de salida con el netlist sintetizado

yosys read_verilog $::env(SRC)
yosys synth -top $::env(TOP)

# Mapeo de flip-flops y logica combinacional a celdas de la liberty
yosys dfflibmap -liberty $::env(LIB)
yosys abc -liberty $::env(LIB)
yosys opt_clean

# Resumen de celdas y area (queda en el log)
yosys stat -liberty $::env(LIB)

# -noattr: OpenSTA no necesita los atributos (* ... *) de Yosys
yosys write_verilog -noattr $::env(NETLIST)
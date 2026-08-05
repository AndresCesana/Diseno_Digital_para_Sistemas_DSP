#!/bin/bash
# run.sh — compila y simula con Icarus Verilog
set -e
cd "$(dirname "$0")"

echo ">>> Compilando con iverilog..."
iverilog -o sim.out tb_actividad_3.v actividad_3.v 

echo ">>> Ejecutando con vvp..."
vvp sim.out

echo ""
echo "VCD generado: tb_actividad_3.vcd (abrir con: gtkwave tb_actividad_3.vcd)"

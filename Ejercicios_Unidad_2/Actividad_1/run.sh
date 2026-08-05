#!/bin/bash
# run.sh — compila y simula con Icarus Verilog
set -e
cd "$(dirname "$0")"

echo ">>> Compilando con iverilog..."
iverilog -o sim.out tb_actividad_1.v actividad_1.v 

echo ">>> Ejecutando con vvp..."
vvp sim.out

echo ""
echo "VCD generado: tb_actividad_1.vcd (abrir con: gtkwave tb_actividad_1.vcd)"

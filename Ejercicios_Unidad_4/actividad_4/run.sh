#!/bin/bash
# run.sh — compila y simula con Icarus Verilog
set -e
cd "$(dirname "$0")"

echo ">>> Compilando con iverilog..."
iverilog -o sim.out tb_mult_sec.v mult_sec.v 

echo ">>> Ejecutando con vvp..."
vvp sim.out

echo ""
echo "VCD generado: tb_mult_sec.vcd (abrir con: gtkwave tb_mult_sec.vcd)"

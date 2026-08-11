#!/usr/bin/env bash
set -e

echo "== 1. vectores (fxpmath) =="
python3 gen_vectors.py

echo "== 2. compilacion =="
iverilog -g2005 -o sim.out tb_suma_punto_fijo.v suma_punto_fijo.v

echo "== 3. simulacion =="
vvp sim.out

if [ "$1" = "-w" ]; then
    echo "== 4. waveform =="
    gtkwave tb_suma_punto_fijo.vcd &
fi
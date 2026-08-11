#!/usr/bin/env bash
set -e

echo "== 1. vectores (fxpmath) =="
python3 gen_vectors.py

echo "== 2. verificacion del DUT =="
iverilog -g2005 -o sim.out tb_suma_punto_fijo.v suma_punto_fijo.v
vvp sim.out | tee salida.txt

if [ "$1" = "-w" ]; then
    gtkwave tb_suma_punto_fijo.vcd &
fi
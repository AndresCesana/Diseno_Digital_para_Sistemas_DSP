#!/usr/bin/env bash
#==============================================================
#  run.sh - Multiplicacion por constante K = 23
#
#    1) Compila y ejecuta el testbench  (Icarus Verilog)
#    2) Sintetiza cada variante y cuenta celdas  (Yosys)
#
#  Uso:  ./run.sh
#==============================================================
set -euo pipefail

RTL="mult23.v"
TB="tb_mult23.v"
BUILD="build"

mkdir -p "$BUILD"

#--------------------------------------------------------------
# 1) Simulacion funcional
#--------------------------------------------------------------
echo "=============================================="
echo " [1/2] SIMULACION"
echo "=============================================="

iverilog -g2012 -Wall -o "$BUILD/sim" "$RTL" "$TB"
( cd "$BUILD" && vvp sim )

#--------------------------------------------------------------
# 2) Sintesis: conteo de celdas por variante
#--------------------------------------------------------------
echo
echo "=============================================="
echo " [2/2] SINTESIS (conteo de celdas)"
echo "=============================================="

for TOP in mult23_csd mult23_bin; do
    echo
    echo "---------- $TOP ----------"
    yosys -p "
        read_verilog $RTL
        synth -top $TOP -flatten
        abc -g AND,OR,XOR,NAND,NOR,XNOR,ANDNOT,ORNOT
        opt_clean -purge
        stat
        write_json $BUILD/${TOP}.json
    " > "$BUILD/${TOP}_synth.log" 2>&1

    # 'synth' ya imprime su propio stat: nos quedamos con el ULTIMO bloque,
    # que es el posterior al mapeo a compuertas con abc.
    awk '/^=== /{blk=""} {blk = blk $0 "\n"} END{printf "%s", blk}' \
        "$BUILD/${TOP}_synth.log" | grep -E 'Number of cells|^ +\$_'
done

echo
echo "=============================================="
echo " Listo. Salidas en $BUILD/"
echo "   sim              -> ejecutable de simulacion"
echo "   tb_mult23.vcd    -> ondas (gtkwave)"
echo "   *.json           -> netlists sintetizados"
echo "=============================================="
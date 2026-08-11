#!/usr/bin/env bash
#==============================================================
#  run.sh - Multiplicacion por la constante K = 23
#
#    1) Genera vectores con fxpmath      (gen_vectors.py)
#    2) Compila y simula el testbench    (Icarus Verilog)
#    3) Sintetiza y cuenta celdas        (Yosys)
#
#  Uso:
#     ./run.sh                    # exhaustivo, formato entero S(8,0)
#     N_BITS=12 ./run.sh          # otro ancho de entrada
#     N_FRAC=7  ./run.sh          # interpretar X como S(8,7)
#     N_VECTORS=100 ./run.sh      # menos random (solo si N_BITS > 12)
#     ./run.sh --wave             # abrir GTKWave al terminar
#==============================================================
set -euo pipefail

RTL="mult23.v"
TB="tb_mult23.v"
BUILD="build"

WAVE=0
[[ "${1:-}" == "--wave" ]] && WAVE=1

mkdir -p "$BUILD"

# `include busca PRIMERO en el directorio del archivo que incluye. Si quedo
# un params.vh viejo junto al testbench, le gana al de build/ y se compila
# con parametros desactualizados. Lo eliminamos por las dudas.
rm -f params.vh x.hex expected.hex

#--------------------------------------------------------------
# 1) Vectores de referencia (fxpmath)
#--------------------------------------------------------------
echo "=============================================="
echo " [1/3] VECTORES  (modelo de referencia fxpmath)"
echo "=============================================="

python3 -c "import fxpmath" 2>/dev/null || {
    echo "fxpmath no encontrado. Instalando..."
    pip3 install --user fxpmath
}

( cd "$BUILD" && python3 ../gen_vectors.py )

#--------------------------------------------------------------
# 2) Simulacion funcional
#--------------------------------------------------------------
echo
echo "=============================================="
echo " [2/3] SIMULACION"
echo "=============================================="

# -I build: para que `include "params.vh" encuentre el generado
iverilog -g2012 -Wall -I "$BUILD" -o "$BUILD/sim" "$RTL" "$TB"

# se ejecuta dentro de build/ porque el TB abre los .hex por ruta relativa
( cd "$BUILD" && vvp sim )

#--------------------------------------------------------------
# 3) Sintesis: conteo de celdas por variante
#--------------------------------------------------------------
echo
echo "=============================================="
echo " [3/3] SINTESIS (conteo de celdas)"
echo "=============================================="

NB="${N_BITS:-8}"

for TOP in mult23_csd mult23_bin; do
    echo
    echo "---------- $TOP  (N = $NB) ----------"
    yosys -p "
        read_verilog $RTL
        chparam -set N $NB $TOP
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

#--------------------------------------------------------------
echo
echo "=============================================="
echo " Listo. Salidas en $BUILD/"
echo "   x.hex, expected.hex  -> vectores de referencia"
echo "   params.vh            -> parametros del TB"
echo "   sim                  -> ejecutable de simulacion"
echo "   tb_mult23.vcd        -> ondas"
echo "   *.json               -> netlists sintetizados"
echo "=============================================="

[[ $WAVE -eq 1 ]] && gtkwave "$BUILD/tb_mult23.vcd" &
exit 0
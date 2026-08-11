#!/usr/bin/env bash
#==============================================================
#  run.sh - flujo de simulacion del multiplicador RNS
#
#     ./run.sh                    genera vectores y simula
#     ./run.sh -w                 idem, con volcado VCD
#     ./run.sh -b "7 11 13"       prueba otra base
#     ./run.sh -n 5000            cantidad de vectores random
#     ./run.sh --invalida         verifica que una base no coprima falle
#     ./run.sh -c                 limpia archivos generados
#==============================================================
set -euo pipefail

RTL="rns_mult.v mod_lut.v mod_mult_lut.v"
TB="tb_rns_mult.v"
VECTORS="x.hex y.hex expected.hex valid.hex params.vh"
OUT="tb.out"
VCD="tb_rns_mult.vcd"

IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"
PYTHON="${PYTHON:-python3}"

BASE="3 5 7"
NVEC=""
DUMP=0

#--------------------------------------------------------------
#  Parseo de argumentos
#--------------------------------------------------------------
uso() {
    sed -n '3,12p' "$0" | sed 's/^#\s\?//'
    exit "${1:-0}"
}

limpiar() {
    rm -f $OUT $VCD $VECTORS
    echo "  limpiado: $OUT $VCD $VECTORS"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--wave)     DUMP=1; shift ;;
        -b|--base)     BASE="$2"; shift 2 ;;
        -n|--vectors)  NVEC="$2"; shift 2 ;;
        -c|--clean)    limpiar; exit 0 ;;
        -h|--help)     uso 0 ;;
        --invalida)    BASE="4 6 7"; INVALIDA=1; shift ;;
        *) echo "opcion desconocida: $1" >&2; uso 1 ;;
    esac
done

read -r M0 M1 M2 <<< "$BASE"

if [[ -z "${M0:-}" || -z "${M1:-}" || -z "${M2:-}" ]]; then
    echo "ERROR: la base debe tener tres modulos, p.ej. -b \"3 5 7\"" >&2
    exit 1
fi

#--------------------------------------------------------------
#  Chequeo de herramientas
#--------------------------------------------------------------
for cmd in "$PYTHON" "$IVERILOG" "$VVP"; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: no se encuentra '$cmd' en el PATH" >&2
        exit 1
    }
done

for f in $RTL $TB gen_vectors.py; do
    [[ -f "$f" ]] || { echo "ERROR: falta el archivo '$f'" >&2; exit 1; }
done

#--------------------------------------------------------------
#  1) Generacion de vectores
#--------------------------------------------------------------
echo ">> generando vectores  (base {$M0, $M1, $M2})"

if [[ "${INVALIDA:-0}" == "1" ]]; then
    # se espera que aborte: exito = codigo de salida distinto de 0
    if M0=$M0 M1=$M1 M2=$M2 $PYTHON gen_vectors.py; then
        echo ""
        echo "  FALLO: la base {$M0, $M1, $M2} no es coprima y sin embargo"
        echo "  el generador la acepto. Revisar la validacion."
        exit 1
    else
        echo ""
        echo "  OK: la base no coprima fue rechazada como corresponde."
        exit 0
    fi
fi

if [[ -n "$NVEC" ]]; then
    M0=$M0 M1=$M1 M2=$M2 N_VECTORS=$NVEC $PYTHON gen_vectors.py
else
    M0=$M0 M1=$M1 M2=$M2 $PYTHON gen_vectors.py
fi

#--------------------------------------------------------------
#  2) Compilacion
#--------------------------------------------------------------
echo ""
echo ">> compilando"

FLAGS="-g2005"
[[ "$DUMP" == "1" ]] && FLAGS="$FLAGS -DDUMP"

# shellcheck disable=SC2086
$IVERILOG $FLAGS -o "$OUT" $TB $RTL

#--------------------------------------------------------------
#  3) Simulacion
#--------------------------------------------------------------
echo ""
echo ">> simulando"
echo ""

# vvp devuelve 0 aunque el testbench reporte FAIL: se inspecciona la salida
SALIDA=$($VVP "$OUT")
echo "$SALIDA"

if [[ "$DUMP" == "1" ]]; then
    echo "  -> abrir con: gtkwave $VCD"
fi

#--------------------------------------------------------------
#  4) Codigo de salida segun el resultado
#--------------------------------------------------------------
if grep -q "RESULTADO: PASS" <<< "$SALIDA"; then
    exit 0
else
    exit 1
fi
#!/usr/bin/env bash
# run_sta_cdc.sh - STA del cruce de dominio sin sincronizador (bad_cross_rtl).
#
# Sintetiza bad_cross_rtl.v (dos FF en relojes distintos, sin logica) y corre
# el STA dos veces sobre el mismo netlist:
#   A) bad_cross_related.sdc : relojes sin relacion declarada
#   B) bad_cross_async.sdc   : relojes declarados asincronos
# y explica que muestra cada caso.
#
# Usa synth.tcl y sta.tcl (los mismos de run_sta.sh).
# Liberty y OpenSTA se buscan igual que en run_sta.sh (o LIB=... / STA_BIN=...).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

SRC=bad_cross_rtl.v
TOP=bad_cross_rtl
OUTDIR=sta_out
LIB=${LIB:-}
LIB_NAME=sky130_fd_sc_hd__tt_025C_1v80.lib
STA_BIN=${STA_BIN:-}

bar()  { printf '%s\n' "------------------------------------------------------------------"; }
die()  { printf 'ERROR: %s\n' "$1" >&2; exit 1; }
result() { awk -v k="$1" '$1 == "RESULT" && $2 == k { print $3 }' "$2" | tail -1; }

# Tiempo (ns) del flanco de un reloj dentro de la seccion de setup del cruce
edge_time() {
    awk -v clk="$1" '
        /=== Camino FF1 -> FF2 \(setup\) ===/ { on = 1; next }
        on && /slack/                        { exit }
        on && $0 ~ "clock " clk " \\(rise edge\\)" { print $2; exit }' "$2"
}

# ---------------------------------------------------------- verificacion ---
printf 'STA del cruce de dominio sin sincronizador\n'
bar
command -v yosys >/dev/null 2>&1 || die "no se encontro yosys en PATH."
if [[ -z "$STA_BIN" ]]; then
    if command -v sta >/dev/null 2>&1; then STA_BIN=$(command -v sta)
    else
        for c in "$HOME/OpenSTA/build/sta" "$HOME/OpenSTA/app/sta" "$HOME/OpenSTA/bin/sta"; do
            if [[ -x "$c" ]]; then STA_BIN=$c; break; fi
        done
    fi
fi
if [[ -n "$STA_BIN" ]]; then
    [[ -x "$STA_BIN" ]] || die "STA_BIN=$STA_BIN no existe o no es ejecutable."
    STA_CMD=("$STA_BIN" -no_init -no_splash -exit)
elif command -v openroad >/dev/null 2>&1; then
    STA_CMD=(openroad -no_init -no_splash -exit)
else
    die "no se encontro OpenSTA (ni en PATH ni en ~/OpenSTA). Indicalo con STA_BIN=/ruta/a/sta."
fi
if [[ -z "$LIB" ]]; then
    for c in "./$LIB_NAME" \
             "$HOME/skywater-pdk/libraries/sky130_fd_sc_hd/latest/timing/$LIB_NAME" \
             "${PDK_ROOT:-/nonexistent}/sky130A/libs.ref/sky130_fd_sc_hd/lib/$LIB_NAME" \
             "$HOME/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/$LIB_NAME"; do
        if [[ -f "$c" ]]; then LIB=$c; break; fi
    done
    [[ -n "$LIB" ]] || die "no se encontro $LIB_NAME. Indicala con LIB=/ruta/a/la.lib."
fi
[[ -f "$LIB" ]] || die "no existe la liberty $LIB."
for f in "$SRC" synth.tcl sta.tcl bad_cross_related.sdc bad_cross_async.sdc; do
    [[ -f "$f" ]] || die "falta el archivo $f en este directorio."
done
printf 'STA      : %s\n' "${STA_CMD[0]}"
printf 'Liberty  : %s\n' "$LIB"
mkdir -p "$OUTDIR"

# ------------------------------------------------------------- sintesis ---
NETLIST=$OUTDIR/${TOP}_netlist.v
printf '\n[1/3] Sintesis de %s\n' "$SRC"
SRC=$SRC TOP=$TOP LIB=$LIB NETLIST=$NETLIST \
    yosys -q -l "$OUTDIR/${TOP}_synth.log" -c synth.tcl >/dev/null 2>&1 \
    || die "fallo la sintesis (ver $OUTDIR/${TOP}_synth.log)."
printf '  Celdas usadas:\n'
grep -oE 'sky130_fd_sc_hd__[a-z0-9_]+' "$NETLIST" | sort | uniq -c |
    awk '{ printf "    %3d x %s\n", $1, $2 }'
printf '  src_ff en src_clk (4.9 ns), dst_ff en dst_clk (5.0 ns), unidos por un cable.\n'

run_sta() {   # $1 = sdc, $2 = log
    LIB=$LIB NETLIST=$NETLIST TOP=$TOP SDC=$1 "${STA_CMD[@]}" sta.tcl >"$2" 2>&1 \
        || die "fallo el STA con $1 (ver $2)."
}

# ------------------------------------------------ A) relojes relacionados ---
LOG_A=$OUTDIR/${TOP}_sta_related.log
printf '\n[2/3] STA con bad_cross_related.sdc (relojes sin relacion declarada)\n'
run_sta bad_cross_related.sdc "$LOG_A"
setup_a=$(result reg2reg_setup "$LOG_A")
hold_a=$(result reg2reg_hold "$LOG_A")
launch=$(edge_time src_clk "$LOG_A")
capture=$(edge_time dst_clk "$LOG_A")
printf '  Reporte: %s\n' "$LOG_A"
if [[ "$setup_a" == "none" || -z "$setup_a" ]]; then
    printf '  No se encontro el camino src_ff -> dst_ff.\n'
else
    window=$(awk -v a="$launch" -v b="$capture" 'BEGIN { printf "%.3f", b - a }')
    printf '  Camino src_ff -> dst_ff (el cruce)\n'
    printf '    Lanzamiento : flanco de src_clk en %s ns\n' "$launch"
    printf '    Captura     : flanco de dst_clk en %s ns\n' "$capture"
    printf '    Ventana     : %s ns para llegar a dst_ff\n' "$window"
    printf '    Slack setup : %s ns | slack hold: %s ns\n' "$setup_a" "$hold_a"
    printf '\n  Interpretacion\n'
    printf '    El STA asume que ambos relojes arrancan juntos y busca la peor pareja\n'
    printf '    de flancos en el periodo comun (MCM de 4.9 y 5.0 ns = 245 ns). Los\n'
    printf '    flancos llegan a estar a %s ns: solo el clk->Q de src_ff ya no entra.\n' "$window"
    printf '    No hay logica que optimizar ni periodo razonable que lo arregle: es la\n'
    printf '    forma en que el STA "ve" un cruce entre relojes independientes.\n'
fi

# --------------------------------------------------- B) relojes asincronos ---
LOG_B=$OUTDIR/${TOP}_sta_async.log
printf '\n[3/3] STA con bad_cross_async.sdc (set_clock_groups -asynchronous)\n'
run_sta bad_cross_async.sdc "$LOG_B"
setup_b=$(result reg2reg_setup "$LOG_B")
worst_b=$(result worst_setup "$LOG_B")
printf '  Reporte: %s\n' "$LOG_B"
if [[ "$setup_b" == "none" ]]; then
    printf '  Camino src_ff -> dst_ff: no analizado (No paths found)\n'
else
    printf '  Camino src_ff -> dst_ff: slack %s ns (se esperaba que no se analizara)\n' "$setup_b"
fi
printf '  Peor slack de setup restante: %s ns (caminos dentro de cada dominio)\n' "$worst_b"
printf '\n  Interpretacion\n'
printf '    Declarar los relojes asincronos es correcto: no existe una relacion de\n'
printf '    fase que cumplir. Pero el STA deja de mirar el cruce, y la violacion\n'
printf '    "desaparece" del reporte sin que el circuito haya cambiado: dst_ff sigue\n'
printf '    pudiendo quedar metaestable y propagarlo a la logica siguiente.\n'

# ------------------------------------------------------------ conclusion ---
printf '\n'
bar
printf 'Conclusion\n'
bar
printf '  Caso                     | Camino del cruce        | Resultado\n'
printf '  relojes relacionados     | slack %-8s ns       | VIOLATED (imposible de cumplir)\n' "$setup_a"
printf '  relojes asincronos       | %-23s | fuera del analisis\n' "no analizado"
printf '\n'
printf '  El STA no puede verificar un cruce asincrono: o lo marca como violacion\n'
printf '  imposible, o se lo excluye. Lo que lo hace seguro es la estructura del\n'
printf '  circuito: un sincronizador cuyo camino FF1 -> FF2 queda dentro de un solo\n'
printf '  dominio y si se verifica con STA (ver run_sta.sh: t_r ~ 4.5 ns).\n'
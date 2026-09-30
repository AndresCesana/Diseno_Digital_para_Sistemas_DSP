#!/usr/bin/env bash
# run_sta.sh - Sintesis (Yosys) + STA (OpenSTA) del sincronizador dff_sync2.
#
# Para cada diseno de la lista:
#   1. Sintetiza a celdas sky130_fd_sc_hd con synth.tcl.
#   2. Corre el STA con sta.tcl y las restricciones de dff_sync2.sdc.
#   3. Interpreta el camino FF1 -> FF2: su slack de setup es el tiempo de
#      resolucion t_r que tiene FF1 antes de que FF2 lo muestree.
# Al final compara todos los disenos en una tabla.
#
# Uso:  ./run_sta.sh
#       LIB=/otra/ruta/sky130_fd_sc_hd__tt_025C_1v80.lib ./run_sta.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# ---------------------------------------------------------------- config ---
LIB=${LIB:-}
LIB_NAME=sky130_fd_sc_hd__tt_025C_1v80.lib
SDC=${SDC:-./dff_sync2.sdc}
OUTDIR=sta_out
TAU_REAL_NS=0.050      # tau aproximado de sky130 (mismo que meta_model.v)
TAU_DEMO_NS=3.000      # tau de demostracion (mismo que el testbench)

# "archivo:modulo_top", en el orden en que se analizan.
# Los archivos que no existan se saltean con un aviso.
DESIGNS=(
    "dff_sync2.v:dff_sync2"
    "dff_sync2_arst.v:dff_sync2_arst"
)

# ----------------------------------------------------------------- utils ---
bar()  { printf '%s\n' "------------------------------------------------------------------"; }
step() { printf '\n[%s] %s\n' "$1" "$2"; }
die()  { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

# Valor de una linea "RESULT <clave> <valor>" del log de STA
result() { awk -v k="$1" '$1 == "RESULT" && $2 == k { print $3 }' "$2" | tail -1; }

# exp(-t/tau) en notacion cientifica
p_fail() { awk -v t="$1" -v tau="$2" 'BEGIN { printf "%.2e", exp(-t / tau) }'; }

# ---------------------------------------------------------- verificacion ---
printf 'Flujo de sintesis + STA para dff_sync2\n'
bar
command -v yosys >/dev/null 2>&1 || die "no se encontro yosys en PATH."

# OpenSTA: 1) STA_BIN=... si se indica, 2) sta en PATH,
#          3) compilado en ~/OpenSTA (build/ o app/ segun la version), 4) openroad
STA_BIN=${STA_BIN:-}
if [[ -z "$STA_BIN" ]]; then
    if command -v sta >/dev/null 2>&1; then
        STA_BIN=$(command -v sta)
    else
        for cand in "$HOME/OpenSTA/build/sta" "$HOME/OpenSTA/app/sta" "$HOME/OpenSTA/bin/sta"; do
            if [[ -x "$cand" ]]; then STA_BIN=$cand; break; fi
        done
    fi
fi
if [[ -n "$STA_BIN" ]]; then
    [[ -x "$STA_BIN" ]] || die "STA_BIN=$STA_BIN no existe o no es ejecutable."
    STA_CMD=("$STA_BIN" -no_init -no_splash -exit)
elif command -v openroad >/dev/null 2>&1; then
    STA_CMD=(openroad -no_init -no_splash -exit)   # OpenROAD trae OpenSTA adentro
else
    die "no se encontro OpenSTA (ni en PATH ni en ~/OpenSTA). Indicalo con STA_BIN=/ruta/a/sta."
fi
# Liberty: 1) LIB=... si se indica, 2) copia en este directorio,
#          3) ~/skywater-pdk, 4) PDK instalado con open_pdks/volare
if [[ -z "$LIB" ]]; then
    for cand in \
        "./$LIB_NAME" \
        "$HOME/skywater-pdk/libraries/sky130_fd_sc_hd/latest/timing/$LIB_NAME" \
        "${PDK_ROOT:-/nonexistent}/sky130A/libs.ref/sky130_fd_sc_hd/lib/$LIB_NAME" \
        "$HOME/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/$LIB_NAME"; do
        if [[ -f "$cand" ]]; then LIB=$cand; break; fi
    done
    [[ -n "$LIB" ]] || die "no se encontro $LIB_NAME (ni aca ni en ~/skywater-pdk). Indicala con LIB=/ruta/a/la.lib."
fi
[[ -f "$LIB" ]] || die "no existe la liberty $LIB."
for f in synth.tcl sta.tcl "$SDC"; do
    [[ -f "$f" ]] || die "falta el archivo $f en este directorio."
done
# Periodo del reloj, leido del create_clock del .sdc
PERIOD_NS=$(grep -oE -- '-period[[:space:]]+[0-9.]+' "$SDC" | awk '{print $2}' | head -1)
[[ -n "$PERIOD_NS" ]] || die "no se encontro '-period' en $SDC."
printf 'Yosys    : %s\n' "$(yosys -V 2>/dev/null | head -1)"
printf 'STA      : %s\n' "${STA_CMD[0]}"
printf 'Liberty  : %s\n' "$LIB"
printf 'SDC      : %s (periodo %s ns)\n' "$SDC" "$PERIOD_NS"

mkdir -p "$OUTDIR"
SUMMARY_ROWS=()
overall_fail=0

# ------------------------------------------------------------- disenos ---
for entry in "${DESIGNS[@]}"; do
    SRC=${entry%%:*}
    TOP=${entry##*:}

    printf '\n'
    bar
    printf 'Diseno: %s  (top: %s)\n' "$SRC" "$TOP"
    bar

    if [[ ! -f "$SRC" ]]; then
        printf 'AVISO: no existe %s; se saltea.\n' "$SRC"
        continue
    fi

    NETLIST=$OUTDIR/${TOP}_netlist.v
    SYNTH_LOG=$OUTDIR/${TOP}_synth.log
    STA_LOG=$OUTDIR/${TOP}_sta.log

    # ---- 1. Sintesis ----
    step 1/3 "Sintesis con Yosys"
    if ! SRC=$SRC TOP=$TOP LIB=$LIB NETLIST=$NETLIST \
         yosys -q -l "$SYNTH_LOG" -c synth.tcl >/dev/null 2>&1; then
        printf 'ERROR: fallo la sintesis. Ultimas lineas de %s:\n' "$SYNTH_LOG"
        grep -iE "error" "$SYNTH_LOG" | tail -5 || tail -5 "$SYNTH_LOG"
        overall_fail=1
        continue
    fi

    area=$(grep "Chip area" "$SYNTH_LOG" | tail -1 | awk '{print $NF}')
    printf '  Netlist : %s\n' "$NETLIST"
    printf '  Area    : %s um^2\n' "${area:-n/d}"
    printf '  Celdas usadas:\n'
    grep -oE 'sky130_fd_sc_hd__[a-z0-9_]+' "$NETLIST" | sort | uniq -c |
        awk '{ tipo = ($2 ~ /__(s|e)?df|__dl/) ? "flip-flop" : "logica";
               printf "    %3d x %-28s (%s)\n", $1, $2, tipo }'
    n_ff=$(grep -oE 'sky130_fd_sc_hd__(s|e)?df[a-z0-9_]+' "$NETLIST" | wc -l)
    if [[ "$n_ff" -ne 2 ]]; then
        printf '  AVISO: se esperaban 2 flip-flops y hay %s.\n' "$n_ff"
    fi

    # ---- 2. STA ----
    step 2/3 "STA con OpenSTA"
    if ! LIB=$LIB NETLIST=$NETLIST TOP=$TOP SDC=$SDC \
         "${STA_CMD[@]}" sta.tcl >"$STA_LOG" 2>&1; then
        printf 'ERROR: fallo el STA. Ultimas lineas de %s:\n' "$STA_LOG"
        tail -5 "$STA_LOG"
        overall_fail=1
        continue
    fi
    if grep -qiE "^(Error|Warning)" "$STA_LOG"; then
        printf '  Mensajes de OpenSTA:\n'
        grep -iE "^(Error|Warning)" "$STA_LOG" | sed 's/^/    /' | head -5
    fi
    printf '  Reporte completo: %s\n' "$STA_LOG"

    setup=$(result reg2reg_setup "$STA_LOG")
    hold=$(result reg2reg_hold "$STA_LOG")
    worst_setup=$(result worst_setup "$STA_LOG")
    worst_hold=$(result worst_hold "$STA_LOG")

    # Celdas combinacionales en el camino FF1 -> FF2 (seccion de setup)
    logic_cells=$(awk '
        /=== Camino FF1 -> FF2 \(setup\) ===/ { on = 1; next }
        on && /data arrival time/            { exit }
        on {
            for (i = 1; i < NF; i++)
                if ($i ~ /\// && $(i+1) ~ /^\(sky130_fd_sc_hd__/) {
                    split($i, pin, "/"); cell = $(i+1); gsub(/[()]/, "", cell)
                    if (cell !~ /__(s|e)?df|__dl/ && !(pin[1] in seen)) {
                        seen[pin[1]] = 1; printf "%s%s(%s)", sep, pin[1], cell; sep = ", "
                    }
                }
        }' "$STA_LOG")

    # ---- 3. Interpretacion ----
    step 3/3 "Interpretacion"
    if [[ -z "$setup" || "$setup" == "none" ]]; then
        printf '  No se encontro camino registro -> registro (revisar el netlist).\n'
        overall_fail=1
        continue
    fi

    printf '  Camino FF1 -> FF2\n'
    printf '    Slack de setup : %s ns  -> tiempo de resolucion disponible t_r\n' "$setup"
    printf '    Slack de hold  : %s ns\n' "$hold"
    if [[ -n "$logic_cells" ]]; then
        printf '    Logica entre FF1 y FF2: %s\n' "$logic_cells"
        printf '      Esa logica consume parte del periodo y reduce t_r.\n'
    else
        printf '    Logica entre FF1 y FF2: ninguna (Q de FF1 va directo a D de FF2)\n'
    fi

    lost=$(awk -v p="$PERIOD_NS" -v s="$setup" 'BEGIN { printf "%.3f", p - s }')
    printf '\n  Comparacion con meta_model.v\n'
    printf '    El modelo supone que FF1 dispone del periodo completo: %s ns\n' "$PERIOD_NS"
    printf '    Segun el STA dispone de t_r = %s ns (%s ns se van en clk->Q, logica y setup)\n' "$setup" "$lost"
    printf '    P(FF1 metaestable no resuelve antes de FF2) = exp(-t_r/tau):\n'
    printf '      tau = %s ns (demo)   : %s\n' "$TAU_DEMO_NS" "$(p_fail "$setup" "$TAU_DEMO_NS")"
    printf '      tau = %s ns (sky130) : %s\n' "$TAU_REAL_NS" "$(p_fail "$setup" "$TAU_REAL_NS")"

    printf '\n  Peor slack de todo el diseno: setup %s ns | hold %s ns\n' "$worst_setup" "$worst_hold"
    status=PASS
    if awk -v a="$worst_setup" -v b="$worst_hold" 'BEGIN { exit !(a < 0 || b < 0) }'; then
        status=FAIL
        overall_fail=1
        printf '  RESULTADO: hay violaciones de timing (slack negativo).\n'
    else
        printf '  RESULTADO: todos los caminos cumplen timing.\n'
    fi

    area_short=$(awk -v a="${area:-}" 'BEGIN { if (a == "") print "n/d"; else printf "%.2f", a }')
    logic_short=${logic_cells//sky130_fd_sc_hd__/}
    SUMMARY_ROWS+=("$(printf '%-16s | %8s | %3s | %-16s | %8s | %9s | %s' \
        "$TOP" "$area_short" "$n_ff" "${logic_short:-ninguna}" "$setup" \
        "$(p_fail "$setup" "$TAU_REAL_NS")" "$status")")
done

# ---------------------------------------------------------- comparacion ---
printf '\n'
bar
printf 'Comparacion (P con tau = %s ns)\n' "$TAU_REAL_NS"
bar
printf '%-16s | %8s | %3s | %-16s | %8s | %9s | %s\n' \
    "Diseno" "Area um2" "FFs" "Logica FF1->FF2" "t_r (ns)" "P(fallo)" "Timing"
for row in "${SUMMARY_ROWS[@]}"; do
    printf '%s\n' "$row"
done
printf '\nArchivos generados en %s/ (netlists, logs de sintesis y reportes de STA).\n' "$OUTDIR"

exit "$overall_fail"
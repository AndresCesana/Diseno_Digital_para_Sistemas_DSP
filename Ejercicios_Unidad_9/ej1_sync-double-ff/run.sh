#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

for tool in iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'ERROR: no se encontro %s en PATH.\n' "$tool" >&2
        exit 127
    fi
done

printf '>>> Compilando dff_sync2.v y tb_dff_sync2.v...\n'
iverilog -g2012 -o sim dff_sync2.v tb_dff_sync2.v

printf '>>> Ejecutando simulacion...\n'
if simulation_output=$(vvp sim 2>&1); then
    simulation_status=0
else
    simulation_status=$?
fi
printf '%s\n' "$simulation_output"

summary_line=$(printf '%s\n' "$simulation_output" | awk '/^SUMMARY:/ { print; exit }')
if [[ -z "$summary_line" ]]; then
    printf 'ERROR: la simulacion no produjo la linea SUMMARY esperada.\n' >&2
    exit 1
fi

printf '\n>>> Comparacion esperado vs obtenido\n'
if ! printf '%s\n' "$summary_line" | awk -v sim_status="$simulation_status" '
function report(name, expected, actual, passed) {
    printf "  %-15s | %-18s | %-8s | %s\n", name, expected, actual, passed ? "PASS" : "FAIL"
    if (!passed) failures++
}

{
    if ($1 != "SUMMARY:" || NF != 7)
        malformed = 1

    for (i = 2; i <= NF; i++) {
        fields = split($i, pair, "=")
        if (fields != 2 ||
            pair[1] !~ /^(toggles|meta|FF1|FF2_demo|FF2_real|bad_X)$/ ||
            pair[2] !~ /^[0-9]+$/ ||
            pair[1] in observed) {
            malformed = 1
        } else {
            observed[pair[1]] = pair[2] + 0
        }
    }
}

END {
    if (malformed || !("toggles" in observed) || !("meta" in observed) ||
        !("FF1" in observed) || !("FF2_demo" in observed) ||
        !("FF2_real" in observed) || !("bad_X" in observed)) {
        print "ERROR: formato SUMMARY invalido o incompleto." > "/dev/stderr"
        exit 2
    }

    printf "  %-15s | %-18s | %-8s | %s\n", "Metrica", "Esperado", "Obtenido", "Estado"
    printf "  ----------------+--------------------+----------+--------\n"
    report("Toggles", "2000", observed["toggles"], observed["toggles"] == 2000)
    report("Eventos meta", "280 (150..450)", observed["meta"], observed["meta"] >= 150 && observed["meta"] <= 450)
    report("Fallos FF1", "~53 (20..100)", observed["FF1"], observed["FF1"] >= 20 && observed["FF1"] <= 100)
    report("Fallos FF2 demo", "~10 (0..30)", observed["FF2_demo"], observed["FF2_demo"] <= 30)
    report("Fallos FF2 real", "0", observed["FF2_real"], observed["FF2_real"] == 0)
    report("X en bad_cross", "= meta (" observed["meta"] ")", observed["bad_X"], observed["bad_X"] == observed["meta"])

    if (sim_status != 0) {
        printf "  Simulacion termino con codigo %d.\n", sim_status
        failures++
    }

    if (failures) {
        print "RESULTADO: FAIL"
        exit 1
    }
    print "RESULTADO: PASS"
}' ; then
    exit 1
fi

if command -v gtkwave >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    printf '\n>>> Abriendo tb_dff_sync2.vcd en GTKWave...\n'
    gtkwave tb_dff_sync2.vcd >/dev/null 2>&1 &
elif ! command -v gtkwave >/dev/null 2>&1; then
    printf '\nAVISO: GTKWave no esta instalado; se genero tb_dff_sync2.vcd.\n'
else
    printf '\nAVISO: no hay DISPLAY/WAYLAND_DISPLAY; no se abre GTKWave.\n'
    printf '       Se genero tb_dff_sync2.vcd para abrirlo manualmente.\n'
fi
#!/usr/bin/env python3
"""
Analisis de error del divisor 1/a por Newton-Raphson (entregable d).

Lee los CSV que emite el testbench (nr_error_N<n>.csv) y produce la tabla
de estadisticas y los graficos de error vs N.

Formato de CSV esperado:
    a_int,y_rtl,y_ref,err_lsb

Uso:
    python3 nr_plot.py                      # toma todos los nr_error_N*.csv
    python3 nr_plot.py nr_error_N3.csv nr_error_N4.csv
    python3 nr_plot.py --dir resultados/
"""

import csv
import glob
import os
import re
import sys

WIDTH    = 16
LUT_BITS = 3
A_MIN    = 1 << (WIDTH - 1)      # 0x8000
A_MAX    = (1 << WIDTH) - 1      # 0xFFFF


# ---------------------------------------------------------------------------
# Lectura
# ---------------------------------------------------------------------------
def leer_csv(ruta):
    """Devuelve (n_iter, lista de (a_int, y_rtl, y_ref, err))."""
    m = re.search(r"N(\d+)", os.path.basename(ruta))
    if not m:
        raise ValueError(f"No pude deducir N del nombre '{ruta}' "
                         "(se espera algo como nr_error_N4.csv)")
    n = int(m.group(1))

    datos = []
    with open(ruta, newline="") as fh:
        for fila in csv.DictReader(fh):
            datos.append((
                int(fila["a_int"]),
                int(fila["y_rtl"]),
                int(fila["y_ref"]),
                int(fila["err_lsb"]),
            ))
    if not datos:
        raise ValueError(f"'{ruta}' no tiene filas de datos")
    return n, datos


def estadisticas(n, datos):
    errs = [d[3] for d in datos]
    k = len(errs)
    peor = max(datos, key=lambda d: abs(d[3]))
    return {
        "n": n,
        "casos": k,
        "min": min(errs),
        "max": max(errs),
        "absmax": max(abs(e) for e in errs),
        "sesgo": sum(errs) / k,
        "rms": (sum(e * e for e in errs) / k) ** 0.5,
        "exactos": sum(1 for e in errs if e == 0) / k * 100.0,
        "a_peor": peor[0],
        "err_peor": peor[3],
    }


# ---------------------------------------------------------------------------
# Tabla
# ---------------------------------------------------------------------------
def imprimir_tabla(stats):
    print()
    print("=" * 82)
    print(" ERROR vs N ITERACIONES   (unidad: LSB de U(16,15), 1 LSB = 2^-15)")
    print("=" * 82)
    print(f"{'N':>2} {'casos':>7} {'err min':>8} {'err max':>8} {'|max|':>7} "
          f"{'sesgo':>9} {'RMS':>7} {'exactos':>9} {'peor a':>9}")
    print("-" * 82)
    for s in stats:
        print(f"{s['n']:>2} {s['casos']:>7} {s['min']:>8} {s['max']:>8} "
              f"{s['absmax']:>7} {s['sesgo']:>+9.4f} {s['rms']:>7.3f} "
              f"{s['exactos']:>8.1f}% {'0x%04X' % s['a_peor']:>9}")
    print("-" * 82)

    # deteccion automatica del plateau
    plateau = None
    for i in range(1, len(stats)):
        if stats[i]["absmax"] >= stats[i - 1]["absmax"]:
            plateau = stats[i - 1]["n"]
            break
    if plateau is not None:
        print(f"\n  El error deja de bajar a partir de N={plateau}: por encima de")
        print(f"  ese punto domina la cuantizacion, no la convergencia de NR.")
        print(f"  Piso medido: {stats[-1]['absmax']} LSB.")

    # aviso de sesgo
    s = stats[-1]
    if abs(s["sesgo"]) > 0.25:
        signo = "negativo" if s["sesgo"] < 0 else "positivo"
        print(f"\n  Sesgo {signo} de {s['sesgo']:+.3f} LSB: el error no esta")
        print(f"  centrado, indicio de truncamiento sin redondeo en el datapath.")
    print()


# ---------------------------------------------------------------------------
# Graficos
# ---------------------------------------------------------------------------
def graficar(stats, datos_por_n, archivo="error_vs_n.png"):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib no esta instalado: pip install matplotlib")
        return

    n_nom = max(s["n"] for s in stats)
    datos_nom = datos_por_n[n_nom]

    fig = plt.figure(figsize=(13, 8))
    gs = fig.add_gridspec(2, 2, hspace=0.32, wspace=0.24)

    # -- (1) error maximo vs N ------------------------------------------
    ax = fig.add_subplot(gs[0, 0])
    ns = [s["n"] for s in stats]
    ax.semilogy(ns, [max(s["absmax"], 0.4) for s in stats],
                "o-", color="tab:red", label="error maximo")
    ax.semilogy(ns, [max(s["rms"], 0.4) for s in stats],
                "s--", color="tab:orange", label="error RMS")
    ax.axhline(1.0, ls=":", color="k", lw=1)
    ax.text(ns[0], 1.08, "1 LSB", fontsize=8)
    ax.set_xlabel("N iteraciones")
    ax.set_ylabel("error [LSB]")
    ax.set_title("Convergencia: error vs N")
    ax.set_xticks(ns)
    ax.grid(True, which="both", alpha=0.3)
    ax.legend(fontsize=9)

    # -- (2) histograma del error en el N nominal ------------------------
    ax = fig.add_subplot(gs[0, 1])
    errs = [d[3] for d in datos_nom]
    lo, hi = min(errs), max(errs)
    bins = [b - 0.5 for b in range(lo, hi + 2)]
    ax.hist(errs, bins=bins, color="tab:blue", edgecolor="white")
    ax.axvline(0, color="k", lw=1, ls=":")
    med = sum(errs) / len(errs)
    ax.axvline(med, color="tab:red", lw=1.5,
               label=f"sesgo = {med:+.3f} LSB")
    ax.set_xlabel("error [LSB]")
    ax.set_ylabel("cantidad de valores de a")
    ax.set_title(f"Distribucion del error (N={n_nom})")
    ax.set_xticks(range(lo, hi + 1))
    ax.grid(True, axis="y", alpha=0.3)
    ax.legend(fontsize=9)

    # -- (3) error en funcion de a ---------------------------------------
    ax = fig.add_subplot(gs[1, :])
    paso = max(1, len(datos_nom) // 8000)      # submuestreo para el scatter
    xs = [d[0] / (1 << WIDTH) for d in datos_nom[::paso]]
    ys = [d[3] for d in datos_nom[::paso]]
    ax.plot(xs, ys, ".", ms=1.2, color="tab:blue", alpha=0.5)

    # limites de los tramos de la LUT
    n_lut = 1 << LUT_BITS
    for i in range(n_lut + 1):
        x = 0.5 + i * 0.5 / n_lut
        ax.axvline(x, color="tab:gray", lw=0.6, ls="--", alpha=0.7)
    for i in range(n_lut):
        ax.text(0.5 + (i + 0.5) * 0.5 / n_lut, hi + 0.35, str(i),
                ha="center", fontsize=7, color="tab:gray")

    ax.axhline(0, color="k", lw=0.8)
    ax.set_xlabel("a  (lineas punteadas = limites de los tramos de la LUT)")
    ax.set_ylabel("error [LSB]")
    ax.set_title(f"Error en funcion de a  (N={n_nom})")
    ax.set_xlim(0.5, 1.0)
    ax.set_ylim(lo - 0.6, hi + 0.9)
    ax.set_yticks(range(lo, hi + 1))
    ax.grid(True, axis="y", alpha=0.3)

    fig.savefig(archivo, dpi=140, bbox_inches="tight")
    print(f"Grafico guardado en {archivo}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    args = sys.argv[1:]
    carpeta = "."
    if args and args[0] == "--dir":
        carpeta = args[1]
        args = args[2:]

    rutas = args if args else sorted(
        glob.glob(os.path.join(carpeta, "nr_error_N*.csv")),
        key=lambda p: int(re.search(r"N(\d+)", os.path.basename(p)).group(1)),
    )

    if not rutas:
        print("No encontre ningun nr_error_N*.csv.")
        print("Genera los CSV corriendo el testbench para cada N:")
        print("  for n in 1 2 3 4; do")
        print("    iverilog -Ptb_newton_raphson.N_ITER=$n -o tb$n "
              "tb_newton_raphson.v newton_raphson.v lut.v")
        print("    vvp tb$n")
        print("  done")
        sys.exit(1)

    stats, datos_por_n = [], {}
    for r in rutas:
        n, datos = leer_csv(r)
        datos.sort(key=lambda d: d[0])
        datos_por_n[n] = datos
        stats.append(estadisticas(n, datos))
        print(f"leido {r}: N={n}, {len(datos)} casos")

    stats.sort(key=lambda s: s["n"])
    imprimir_tabla(stats)
    graficar(stats, datos_por_n)


if __name__ == "__main__":
    main()
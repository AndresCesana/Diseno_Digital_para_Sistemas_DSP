#!/usr/bin/env python3
"""
Grafica la comparativa de sumadores a partir de la salida del testbench.

Uso:
    ./sim_comp.out | python3 plot_adders.py
    python3 plot_adders.py sim.log

Lineas esperadas:
    CSV,<TYPE>,<N>,<gates>,<t_cin>,<t_data>,<pass>,<fail>
"""

import os
import sys

def parse(src):
    rows = []
    for line in src:
        if line.startswith("CSV,"):
            f = line.strip().split(",")
            rows.append({
                "type":   f[1],
                "N":      int(f[2]),
                "gates":  int(f[3]),
                "t_cin":  int(f[4]),
                "t_data": int(f[5]),
                "pass":   int(f[6]),
                "fail":   int(f[7]),
            })
    return rows


src = open(sys.argv[1]) if len(sys.argv) > 1 else sys.stdin
rows = parse(src)

if not rows:
    sys.exit("ERROR: no encontre lineas 'CSV,'.\n"
             "  Recorda que hay que pasarle la salida del SIMULADOR, no la del compilador:\n"
             "    ./sim_comp.out | python3 plot_adders.py")

rows.sort(key=lambda r: ["RCA", "CSLA", "CLA"].index(r["type"])
          if r["type"] in ("RCA", "CSLA", "CLA") else 99)

N = rows[0]["N"]
base = next((r for r in rows if r["type"] == "RCA"), rows[0])

# ---- Tabla -------------------------------------------------------------
print(f"\n--- Sumadores de {N} bits ---")
print(f"{'arq':>5} {'gates':>7} {'t_cin':>7} {'t_data':>7} {'Fmax':>9} "
      f"{'area*del':>9} {'speedup':>8} {'area':>6} {'fail':>5}")
print("-" * 72)
for r in rows:
    print(f"{r['type']:>5} {r['gates']:>7} {r['t_cin']:>7} {r['t_data']:>7} "
          f"{1000.0/r['t_data']:>8.1f}M {r['gates']*r['t_data']:>9} "
          f"{base['t_data']/r['t_data']:>7.2f}x {r['gates']/base['gates']:>5.1f}x "
          f"{r['fail']:>5}")
print(f"\n(speedup y area relativos a {base['type']})")

tot_fail = sum(r["fail"] for r in rows)
if tot_fail:
    print(f"\nATENCION: {tot_fail} fallas funcionales, los retardos no valen.\n")
else:
    print(f"\nTodos pasaron ({rows[0]['pass']} vectores por arquitectura).\n")

# ---- Grafico -----------------------------------------------------------
try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError as e:
    sys.exit(f"[aviso] sin grafico: falta {e.name}  ->  pip install matplotlib")

palette = {"RCA": "#c0392b", "CSLA": "#e67e22", "CLA": "#2980b9"}
names   = [r["type"] for r in rows]
colors  = [palette.get(t, "#7f8c8d") for t in names]

fig, axes = plt.subplots(1, 3, figsize=(13, 4.3))

paneles = [
    ("t_data", "retardo peor caso [ns]",  "Velocidad\n(menor es mejor)",      "{:.0f} ns"),
    ("gates",  "compuertas",              "Area\n(menor es mejor)",           "{:.0f}"),
    ("ad",     "compuertas x ns",         "Area x delay\n(menor es mejor)",   "{:.0f}"),
]

for ax, (clave, ylab, titulo, fmt) in zip(axes, paneles):
    vals = [r["gates"] * r["t_data"] if clave == "ad" else r[clave] for r in rows]
    barras = ax.bar(names, vals, color=colors, width=0.6)
    for barra, v in zip(barras, vals):
        ax.annotate(fmt.format(v),
                    (barra.get_x() + barra.get_width()/2, v),
                    textcoords="offset points", xytext=(0, 4),
                    ha="center", fontsize=10)
    ax.set_ylabel(ylab)
    ax.set_title(titulo, fontsize=10)
    ax.set_ylim(0, max(vals) * 1.18)
    ax.grid(axis="y", alpha=0.3)
    ax.set_axisbelow(True)

# anota Fmax sobre el panel de velocidad
for i, r in enumerate(rows):
    axes[0].annotate(f"{1000.0/r['t_data']:.1f} MHz", (i, r["t_data"]/2),
                     ha="center", fontsize=9, color="white", weight="bold")

fig.suptitle(f"Sumadores de {N} bits: RCA vs CSLA vs CLA   "
             f"(TXOR=3, TAND=2, TOR=2, TMUX=2)", fontsize=11)
plt.tight_layout(rect=[0, 0, 1, 0.93])

out = os.environ.get("DELAY_PNG", "adders_comparison.png")
plt.savefig(out, dpi=150)
print(f"-> {out}")
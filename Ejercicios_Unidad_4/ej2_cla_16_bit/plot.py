import os
import sys
from collections import defaultdict

# ---- Parseo (stdlib) --------------------------------------------------------
# Formato esperado por linea:
#   CSV,<TYPE>,<N>,<n_gates>,<delay_cin>,<delay_data>,<pass>,<fail>
# TYPE identifica la arquitectura (ej: "RCA", "CLA"), asi el mismo script
# sirve para comparar cualquier cantidad de arquitecturas, no solo dos.
def parse(src):
    rows = []
    for line in src:
        if line.startswith("CSV,"):
            f = line.strip().split(",")
            rows.append({
                "type":       f[1],
                "N":          int(f[2]),
                "n_gates":    int(f[3]),
                "delay_cin":  int(f[4]),
                "delay_data": int(f[5]),
                "pass":       int(f[6]),
                "fail":       int(f[7]),
            })
    return rows


src = open(sys.argv[1]) if len(sys.argv) > 1 else sys.stdin
rows = parse(src)

if not rows:
    sys.exit("ERROR: no encontre lineas 'CSV,' en la entrada. "
              "Corrio bien la simulacion?")

by_type = defaultdict(list)
for r in rows:
    by_type[r["type"]].append(r)
for t in by_type:
    by_type[t].sort(key=lambda r: r["N"])


# ---- Ajuste lineal por minimos cuadrados (solo si hay >=2 N distintos) -----
def linfit(xs, ys):
    n = len(xs)
    if n < 2 or len(set(xs)) < 2:
        return None
    mx, my = sum(xs) / n, sum(ys) / n
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    sxx = sum((x - mx) ** 2 for x in xs)
    m = sxy / sxx if sxx else 0.0
    b = my - m * mx
    ss_t = sum((y - my) ** 2 for y in ys)
    ss_r = sum((y - (m * x + b)) ** 2 for x, y in zip(xs, ys))
    r2 = 1 - ss_r / ss_t if ss_t else 1.0
    return m, b, r2


fits = {}
for t, rs in by_type.items():
    xs = [r["N"] for r in rs]
    ys = [r["delay_cin"] for r in rs]
    fit = linfit(xs, ys)
    if fit:
        fits[t] = fit
        m, b, r2 = fit
        print(f"[{t}]  t_pd = {m:.3f}*N + {b:.3f}   (R^2 = {r2:.6f})  -> escala ~O(N)")
    else:
        print(f"[{t}]  un solo punto (N={xs[0]}, delay={ys[0]} ua) -> no se ajusta recta")
print()

# ---- Tabla por arquitectura --------------------------------------------------
for t, rs in by_type.items():
    print(f"--- {t} ---")
    print(f"{'N':>4} {'gates':>7} {'t_cin':>7} {'t_data':>7} {'t/N':>6} {'fail':>5}")
    print("-" * 40)
    for r in rs:
        print(f"{r['N']:>4} {r['n_gates']:>7} "
              f"{r['delay_cin']:>7} {r['delay_data']:>7} "
              f"{r['delay_cin'] / r['N']:>6.1f} {r['fail']:>5}")
    print()

# ---- Comparacion directa para los N presentes en TODAS las arquitecturas ---
types = list(by_type.keys())
if len(types) >= 2:
    common_N = set.intersection(*[{r["N"] for r in by_type[t]} for t in types])
    if common_N:
        print("--- Comparacion (mismo N) ---")
        header = f"{'N':>4}" + "".join(f" {('t_cin_' + t):>10}" for t in types)
        if "RCA" in types and "CLA" in types:
            header += f" {'speedup':>9}"
        print(header)
        print("-" * len(header))
        for N in sorted(common_N):
            vals = {t: next(r for r in by_type[t] if r["N"] == N)["delay_cin"]
                     for t in types}
            line = f"{N:>4}" + "".join(f" {vals[t]:>10}" for t in types)
            if "RCA" in vals and "CLA" in vals and vals["CLA"]:
                speedup = vals["RCA"] / vals["CLA"]
                line += f" {speedup:>8.2f}x"
            print(line)
        print()

# ---- Grafico (opcional) -----------------------------------------------------
try:
    import numpy as np
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError as e:
    print(f"[aviso] sin grafico: falta {e.name}")
    print("        instalar con:  sudo apt install python3-matplotlib python3-numpy")
    sys.exit(0)

fig, ax = plt.subplots(figsize=(7.2, 4.8))

palette = {"RCA": "#c0392b", "CLA": "#2980b9"}
markers = {"RCA": "o", "CLA": "s"}
other_colors = ["#27ae60", "#8e44ad", "#f39c12"]

max_N = max(r["N"] for r in rows)
max_d = max(r["delay_cin"] for r in rows)

for idx, (t, rs) in enumerate(by_type.items()):
    xs = np.array([r["N"] for r in rs])
    ys = np.array([r["delay_cin"] for r in rs])
    color = palette.get(t, other_colors[idx % len(other_colors)])
    marker = markers.get(t, "^")

    if t in fits:
        m, b, r2 = fits[t]
        Nf = np.linspace(0, max_N * 1.15, 100)
        ax.plot(Nf, m * Nf + b, "--", color=color, lw=1.2, alpha=0.6,
                label=f"{t} ajuste: $t={m:.1f}N{b:+.0f}$ ($R^2$={r2:.3f})")
        ax.plot(xs, ys, marker + "-", color=color, lw=2, ms=8,
                label=f"{t} $c_{{in}}\\rightarrow c_{{out}}$")
        for x, y in zip(xs, ys):
            ax.annotate(f"{y}", (x, y), textcoords="offset points",
                        xytext=(0, 11), ha="center", fontsize=9, color=color)
    else:
        ax.plot(xs, ys, marker, color=color, ms=13, mfc="none", mew=2.2,
                label=f"{t} (N={xs[0]}, delay={ys[0]} ua)")
        ax.annotate(f"{ys[0]}", (xs[0], ys[0]), textcoords="offset points",
                    xytext=(10, 0), ha="left", fontsize=9, color=color)

ax.set_xlabel("N (bits)")
ax.set_ylabel("retardo de propagacion c_in->c_out [ua]")
ax.set_title("Comparacion de retardo worst-case vs N")
ax.grid(alpha=0.3)
ax.legend(fontsize=8, loc="upper left")
ax.set_xlim(0, max_N * 1.15)
ax.set_ylim(0, max_d * 1.25)

plt.tight_layout()
out = os.environ.get("DELAY_PNG", "delay_comparison.png")
plt.savefig(out, dpi=150)
print(f"-> {out}")
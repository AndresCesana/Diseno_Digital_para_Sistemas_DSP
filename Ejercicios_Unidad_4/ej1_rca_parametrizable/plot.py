import os
import sys

# ---- Parseo (stdlib) --------------------------------------------------------
src = open(sys.argv[1]) if len(sys.argv) > 1 else sys.stdin
rows = []
for line in src:
    if line.startswith("CSV,"):
        f = line.strip().split(",")
        rows.append({
            "N":          int(f[1]),
            "n_fa":       int(f[2]),
            "n_gates":    int(f[3]),
            "delay_cin":  int(f[4]),
            "delay_data": int(f[5]),
            "pass":       int(f[6]),
            "fail":       int(f[7]),
        })
rows.sort(key=lambda r: r["N"])

if not rows:
    sys.exit("ERROR: no encontre lineas 'CSV,' en la entrada. "
             "Corrio bien la simulacion?")

N     = [r["N"]         for r in rows]
d_cin = [r["delay_cin"] for r in rows]

# ---- Ajuste lineal por minimos cuadrados (stdlib) ---------------------------
n     = len(N)
mx    = sum(N) / n
my    = sum(d_cin) / n
sxy   = sum((x - mx) * (y - my) for x, y in zip(N, d_cin))
sxx   = sum((x - mx) ** 2 for x in N)
m     = sxy / sxx if sxx else 0.0
b     = my - m * mx
ss_t  = sum((y - my) ** 2 for y in d_cin)
ss_r  = sum((y - (m * x + b)) ** 2 for x, y in zip(N, d_cin))
r2    = 1 - ss_r / ss_t if ss_t else 1.0

# ---- Tabla ------------------------------------------------------------------
print(f"\nAjuste:  t_pd = {m:.3f}*N + {b:.3f}   (R^2 = {r2:.6f})\n")
print(f"{'N':>4} {'FAs':>5} {'gates':>7} {'t_cin':>7} {'t_data':>7} {'t/N':>6} {'fail':>5}")
print("-" * 46)
for r in rows:
    print(f"{r['N']:>4} {r['n_fa']:>5} {r['n_gates']:>7} "
          f"{r['delay_cin']:>7} {r['delay_data']:>7} "
          f"{r['delay_cin']/r['N']:>6.1f} {r['fail']:>5}")

# ---- Grafico (opcional) -----------------------------------------------------
try:
    import numpy as np
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError as e:
    print(f"\n[aviso] sin grafico: falta {e.name}")
    print("        instalar con:  sudo apt install python3-matplotlib python3-numpy")
    sys.exit(0)

Na     = np.array(N)
d_cina = np.array(d_cin)
d_data = np.array([r["delay_data"] for r in rows])

fig, ax = plt.subplots(figsize=(7.2, 4.8))

Nf = np.linspace(0, max(N) * 1.15, 100)
ax.plot(Nf, m * Nf + b, "--", color="#888", lw=1.2, zorder=1,
        label=f"ajuste: $t_{{pd}} = {m:.0f}N {b:+.0f}$   ($R^2$={r2:.4f})")
ax.plot(Na, d_cina, "o-", color="#c0392b", lw=2, ms=8, zorder=3,
        label=r"$c_{in} \rightarrow c_{out}$ (ripple completo)")
ax.plot(Na, d_data, "s", color="#2980b9", ms=13, mfc="none", mew=1.8, zorder=4,
        label=r"$a,b \rightarrow$ salidas (coincide)")
for x, y in zip(Na, d_cina):
    ax.annotate(f"{y}", (x, y), textcoords="offset points",
                xytext=(0, 11), ha="center", fontsize=9, color="#c0392b")

ax.set_xlabel("N (bits)")
ax.set_ylabel("retardo de propagacion [ua]")
ax.set_title("RCA: retardo worst-case vs N")
ax.grid(alpha=0.3)
ax.legend(fontsize=9, loc="upper left")
ax.set_xlim(0, max(N) * 1.15)
ax.set_ylim(0, max(d_cin) * 1.18)
ax.set_xticks(Na)

plt.tight_layout()
out = os.environ.get("RCA_PNG", "rca_delay.png")
plt.savefig(out, dpi=150)
print(f"\n-> {out}")
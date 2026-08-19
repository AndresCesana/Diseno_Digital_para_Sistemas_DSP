import os
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ---- Parseo ----------------------------------------------------------------
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

N      = np.array([r["N"]          for r in rows])
d_cin  = np.array([r["delay_cin"]  for r in rows])
d_data = np.array([r["delay_data"] for r in rows])
gates  = np.array([r["n_gates"]    for r in rows])

# ---- Ajuste lineal ---------------------------------------------------------
m, b = np.polyfit(N, d_cin, 1)
r2 = 1 - np.sum((d_cin - (m*N + b))**2) / np.sum((d_cin - d_cin.mean())**2)

print(f"\nAjuste:  t_pd = {m:.3f}*N + {b:.3f}   (R^2 = {r2:.6f})")
print(f"{'N':>4} {'FAs':>5} {'gates':>7} {'t_cin':>7} {'t_data':>7} {'t/N':>6}")
for r in rows:
    print(f"{r['N']:>4} {r['n_fa']:>5} {r['n_gates']:>7} "
          f"{r['delay_cin']:>7} {r['delay_data']:>7} {r['delay_cin']/r['N']:>6.1f}")

# ---- Grafico ---------------------------------------------------------------
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4.8))

# Izquierda: delay vs N, escala lineal
Nf = np.linspace(0, 36, 100)
ax1.plot(Nf, m*Nf + b, "--", color="#888", lw=1.2, zorder=1,
         label=f"ajuste: $t_{{pd}} = {m:.0f}N {b:+.0f}$   ($R^2$={r2:.4f})")
ax1.plot(N, d_cin,  "o-", color="#c0392b", lw=2, ms=8, zorder=3,
         label=r"$c_{in} \rightarrow c_{out}$ (ripple)")
ax1.plot(N, d_data, "s--", color="#2980b9", lw=1.6, ms=7, zorder=2,
         label=r"$a,b \rightarrow$ salidas")
for x, y in zip(N, d_cin):
    ax1.annotate(f"{y}", (x, y), textcoords="offset points",
                 xytext=(0, 11), ha="center", fontsize=9, color="#c0392b")
ax1.set_xlabel("N (bits)")
ax1.set_ylabel("delay de propagacion [ua]")
ax1.set_title("RCA: delay worst-case vs N  —  crecimiento $O(N)$")
ax1.grid(alpha=0.3)
ax1.legend(fontsize=9, loc="upper left")
ax1.set_xlim(0, 36)
ax1.set_ylim(0, max(d_cin)*1.18)

# Derecha: comparacion con CLA teorico O(log N) y area
t_cla = 4 * (np.log2(N) + 1)          # modelo grueso: profundidad log2(N)
ax2.plot(N, d_cin, "o-", color="#c0392b", lw=2, ms=8, label="RCA medido  $O(N)$")
ax2.plot(N, t_cla, "^:", color="#27ae60", lw=1.6, ms=8,
         label=r"CLA teorico  $O(\log N)$")
ax2b = ax2.twinx()
ax2b.bar(N, gates, width=N*0.25, alpha=0.18, color="#7f8c8d", zorder=0)
ax2b.set_ylabel("compuertas (area)", color="#7f8c8d")
ax2b.tick_params(axis="y", labelcolor="#7f8c8d")
ax2.set_xscale("log", base=2)
ax2.set_xticks(N)
ax2.set_xticklabels([str(n) for n in N])
ax2.set_xlabel("N (bits)")
ax2.set_ylabel("delay [ua]")
ax2.set_title("Costo del ripple: delay vs area")
ax2.grid(alpha=0.3)
ax2.legend(fontsize=9, loc="upper left")
ax2.set_zorder(ax2b.get_zorder() + 1)
ax2.patch.set_visible(False)

plt.tight_layout()
out = os.environ.get("RCA_PNG", "rca_delay.png")
plt.savefig(out, dpi=150)
print(f"\n-> {out}")
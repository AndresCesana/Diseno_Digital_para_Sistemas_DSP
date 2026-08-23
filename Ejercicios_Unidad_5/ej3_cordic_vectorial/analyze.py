#!/usr/bin/env python3
"""
analyze.py -- Entregables (c) precision  y  (d) error vs cuadrante

Uso:
    python3 analyze.py resultados.csv     # analiza la salida del testbench
    python3 analyze.py --selftest         # corre los modelos bit-exactos

Validacion en dos niveles:
    nivel 1  modelo bit-exacto  vs  RTL          -> tolerancia CERO (busca bugs)
    nivel 2  modelo bit-exacto  vs  numpy        -> error del algoritmo
"""
import sys
import math

import numpy as np

Q15 = 1 << 15
Q14 = 1 << 14

# =====================================================================
#  Modelos bit-exactos (nivel 1)
# =====================================================================

ATAN_LUT = [12868, 7596, 4014, 2037, 1023, 512, 256, 128,
            64, 32, 16, 8, 4, 2, 1, 0]


def _wrap(v, nb):
    """complemento a dos de nb bits"""
    m = 1 << nb
    v &= m - 1
    return v - m if v & (m >> 1) else v


def cordic_model(ix, iy, n_iter=16, nb_int=18):
    """Replica exacta de cordic_vectorial.v"""
    x = ix
    y = iy
    if ix < 0:                       # pre-rotacion de 180 grados
        x, y = -x, -y                # (despues de extender a nb_int bits)
    z = 0
    for i in range(n_iter):
        d = 0 if y < 0 else 1        # d = ~y[MSB]
        xs, ys = x >> i, y >> i      # >>> aritmetico
        if d:
            xn, yn, zn = x + ys, y - xs, z + ATAN_LUT[i]
        else:
            xn, yn, zn = x - ys, y + xs, z - ATAN_LUT[i]
        x, y = _wrap(xn, nb_int), _wrap(yn, nb_int)
        z = _wrap(zn, 16)
    # compensacion de 1/K por shifts
    xc = _wrap((x >> 1) + (x >> 3) - (x >> 6) - (x >> 9), nb_int)
    chk = (xc >> 15) & 0x7            # bits [17:15]
    ovf = (chk != 0) and (chk != 7)
    if ovf:
        r = -Q15 if xc < 0 else Q15 - 1
    else:
        r = _wrap(xc & 0xFFFF, 16)
    return r, z


def _build_roms():
    sq = [0] + [int(round(math.sqrt((a + 0.5) / 1024.0) * Q14)) for a in range(1, 4096)]
    rc = [int(round((1.0 / ((2**15 + a * 16 + 8) / 2**16)) * Q14)) for a in range(2048)]
    at = [int(round(math.atan(min((a + 0.5) / 2048.0, 1.0)) * Q14)) for a in range(4096)]
    return sq, rc, at


_SQ, _RC, _AT = _build_roms()
PI2_Q14 = 25736


def ref_model(ix, iy):
    """Replica exacta de mult_reference.v"""
    ax = 32768 if ix == -32768 else abs(ix)
    ay = 32768 if iy == -32768 else abs(iy)
    swp = ay > ax
    num, den = (ax, ay) if swp else (ay, ax)
    sgn = (ix < 0) ^ (iy < 0)

    r14 = _SQ[(ax * ax + ay * ay) >> 20]
    r = (Q15 - 1) if (r14 >> 14) else ((r14 & 0x7FFF) << 1)

    if den == 0:
        return r, 0
    sh = 16 - den.bit_length()
    den_n, num_n = den << sh, num << sh
    t = (num_n * _RC[(den_n >> 4) & 0x7FF]) >> 15
    av = _AT[(t >> 4) & 0xFFF]
    base = PI2_Q14 - av if swp else av
    return r, (-base if sgn else base)


# =====================================================================
#  Referencia numerica (nivel 2)
# =====================================================================

def golden(ix, iy):
    """hypot y atan(y/x), este ultimo envuelto a +-pi/2 como los DUTs"""
    xr, yr = ix / Q15, iy / Q15
    r = np.hypot(xr, yr)
    p = np.arctan2(yr, xr)
    p = np.where(p > np.pi / 2, p - np.pi, p)
    p = np.where(p < -np.pi / 2, p + np.pi, p)
    return r, p


# =====================================================================
#  Metricas
# =====================================================================

def stats(err_lsb, label):
    if len(err_lsb) == 0:
        return f"  {label:22s}  (sin muestras)"
    return ("  {:22s} max {:8.2f}   rms {:8.3f}   sesgo {:+8.3f}   n={}"
            .format(label, np.abs(err_lsb).max(), np.sqrt((err_lsb**2).mean()),
                    err_lsb.mean(), len(err_lsb)))


def report(ix, iy, cr, cp, rr, rp):
    gr, gp = golden(ix, iy)
    inside = gr < 1.0            # fuera del circulo unitario R satura

    e_cr = (cr / Q15 - gr)[inside] * Q15
    e_rr = (rr / Q15 - gr)[inside] * Q15
    e_cp = (cp / Q14 - gp) * Q14
    e_rp = (rp / Q14 - gp) * Q14

    print("\n=== (c) PRECISION GLOBAL  [error en LSB] ===")
    print(stats(e_cr, "modulo  CORDIC"))
    print(stats(e_rr, "modulo  referencia"))
    print(stats(e_cp, "fase    CORDIC"))
    print(stats(e_rp, "fase    referencia"))
    n_sat = int((~inside).sum())
    print(f"\n  puntos con R >= 1.0 (saturan en S(16,15)): "
          f"{n_sat} / {len(gr)}  ({100*n_sat/len(gr):.1f}%)")

    print("\n=== (d) ERROR POR CUADRANTE  [error en LSB] ===")
    quad = np.where(ix >= 0,
                    np.where(iy >= 0, 1, 4),
                    np.where(iy >= 0, 2, 3))
    print("      cuad |  mod CORDIC          |  mod REF             |"
          "  fase CORDIC         |  fase REF")
    print("      -----+----------------------+----------------------+"
          "----------------------+---------------------")
    for q in (1, 2, 3, 4):
        m = quad == q
        mi = m[inside]
        row = f"      {q:^4d} |"
        for e, sel in ((e_cr, mi), (e_rr, mi), (e_cp, m), (e_rp, m)):
            if sel.sum() == 0:
                row += "      ---           |"
            else:
                row += f" max{np.abs(e[sel]).max():7.1f} rms{np.sqrt((e[sel]**2).mean()):6.2f} |"
        print(row)


# =====================================================================
#  Entrada
# =====================================================================

def load_csv(path):
    d = np.genfromtxt(path, delimiter=",", skip_header=1, dtype=np.int64)
    return d[:, 0], d[:, 1], d[:, 2], d[:, 3], d[:, 4], d[:, 5], d[:, 6]


def selftest(n=20000):
    rng = np.random.default_rng(1)
    pts = [(16384, 16384), (-16384, 16384), (-16384, -16384), (16384, -16384),
           (32767, 0), (0, 32767), (-32768, 0), (-32768, 1000)]
    pts += list(zip(rng.integers(-32768, 32768, n).tolist(),
                    rng.integers(-32768, 32768, n).tolist()))
    pts = [p for p in pts if p != (0, 0)]
    cm = [cordic_model(a, b) for a, b in pts]
    rm = [ref_model(a, b) for a, b in pts]
    arr = lambda v: np.array(v, dtype=np.int64)
    return (arr([0] * len(pts)),
            arr([p[0] for p in pts]), arr([p[1] for p in pts]),
            arr([c[0] for c in cm]), arr([c[1] for c in cm]),
            arr([r[0] for r in rm]), arr([r[1] for r in rm]))


def plots(ix, iy, cp, rp, tag):
    """(d): error de fase vs angulo, sobre el barrido polar"""
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("\n[matplotlib no disponible: se omiten los graficos]")
        return
    m = tag == 1
    if m.sum() == 0:
        m = np.ones_like(tag, dtype=bool)
    ang = np.degrees(np.arctan2(iy[m] / Q15, ix[m] / Q15))
    _, gp = golden(ix[m], iy[m])
    o = np.argsort(ang)
    fig, ax = plt.subplots(2, 1, figsize=(11, 7), sharex=True)
    ax[0].plot(ang[o], ((cp[m] / Q14 - gp)[o]) * Q14, lw=.8)
    ax[0].set_ylabel("error fase CORDIC [LSB]")
    ax[0].grid(alpha=.3)
    ax[1].plot(ang[o], ((rp[m] / Q14 - gp)[o]) * Q14, lw=.8, color="tab:red")
    ax[1].set_ylabel("error fase referencia [LSB]")
    ax[1].set_xlabel("angulo de entrada [grados]")
    ax[1].grid(alpha=.3)
    for a in ax:
        for g in (-135, -90, -45, 0, 45, 90, 135):
            a.axvline(g, color="k", lw=.4, ls=":")
    fig.tight_layout()
    fig.savefig("error_vs_angulo.png", dpi=130)
    print("\n  grafico -> error_vs_angulo.png")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] != "--selftest":
        data = load_csv(sys.argv[1])
        print(f"cargado {sys.argv[1]}: {len(data[0])} vectores")
    else:
        data = selftest()
        print(f"selftest con modelos bit-exactos: {len(data[0])} vectores")
    tag, ix, iy, cr, cp, rr, rp = data
    report(ix, iy, cr, cp, rr, rp)
    plots(ix, iy, cp, rp, tag)
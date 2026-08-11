#!/usr/bin/env python3
"""Genera vectores de referencia para suma_punto_fijo usando fxpmath."""
import os, random
from fxpmath import Fxp

# ---------- formato (unica fuente de verdad) ----------
NB1, NBF1 = 6, 4
NB2, NBF2 = 8, 5

NBI1, NBI2 = NB1 - NBF1, NB2 - NBF2
NBFO = max(NBF1, NBF2)
NBIO = max(NBI1, NBI2) + 1
NBO  = NBIO + NBFO

FMT1 = dict(signed=True, n_word=NB1, n_frac=NBF1)
FMT2 = dict(signed=True, n_word=NB2, n_frac=NBF2)
FMTO = dict(signed=True, n_word=NBO, n_frac=NBFO)

N_VECTORS = int(os.environ.get("N_VECTORS", 1000))
ESPACIO   = (1 << NB1) * (1 << NB2)          # 64 * 256 = 16384

# ---------- helpers ----------
def rango_raw(nb):
    """enteros C2 representables en nb bits"""
    return range(-(1 << (nb-1)), 1 << (nb-1))

def hexa(raw, nb):
    return format(raw & ((1 << nb) - 1), '0{}x'.format((nb + 3) // 4))

def bordes(nb, nbf):
    lo, hi = -(1 << (nb-1)), (1 << (nb-1)) - 1
    return [lo, lo+1, -1, 0, 1, hi-1, hi]

# ---------- construccion de la lista ----------
if N_VECTORS >= ESPACIO or os.environ.get("EXHAUSTIVE"):
    pares = [(x, y) for x in rango_raw(NB1) for y in rango_raw(NB2)]
else:
    pares = [(x, y) for x in bordes(NB1, NBF1) for y in bordes(NB2, NBF2)]
    random.seed(0)                                   # reproducible
    while len(pares) < N_VECTORS:
        pares.append((random.choice(rango_raw(NB1)),
                      random.choice(rango_raw(NB2))))
    pares = pares[:max(N_VECTORS, len(bordes(NB1,NBF1))*len(bordes(NB2,NBF2)))]

# ---------- modelo de referencia ----------
fa, fb, fo = open("a.hex","w"), open("b.hex","w"), open("expected.hex","w")

for a_raw, b_raw in pares:
    A = Fxp(a_raw / 2.0**NBF1, **FMT1)
    B = Fxp(b_raw / 2.0**NBF2, **FMT2)
    O = Fxp(A.get_val() + B.get_val(), **FMTO)

    # el bit de guarda garantiza que no hay overflow: lo verificamos
    assert O.get_val() == A.get_val() + B.get_val(), \
        f"perdida de precision en {A.get_val()} + {B.get_val()}"

    fa.write(hexa(a_raw, NB1)  + "\n")
    fb.write(hexa(b_raw, NB2)  + "\n")
    fo.write(hexa(int(round(O.get_val() * 2**NBFO)), NBO) + "\n")

fa.close(); fb.close(); fo.close()

# ---------- parametros para Verilog ----------
with open("params.vh","w") as f:
    f.write("// generado por gen_vectors.py - NO EDITAR\n")
    f.write("`ifndef PARAMS_VH\n`define PARAMS_VH\n")
    for k, v in [("NB1",NB1),("NBF1",NBF1),("NB2",NB2),("NBF2",NBF2),
                 ("NVEC",len(pares))]:
        f.write(f"`define {k} {v}\n")
    f.write("`endif\n")

print(f"S({NB1},{NBF1}) + S({NB2},{NBF2}) -> S({NBO},{NBFO})")
print(f"{len(pares)} vectores generados"
      f"{' (exhaustivo)' if len(pares) == ESPACIO else ''}")
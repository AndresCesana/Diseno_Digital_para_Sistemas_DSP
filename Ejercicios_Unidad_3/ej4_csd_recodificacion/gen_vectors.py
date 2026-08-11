#!/usr/bin/env python3
#==============================================================
#  gen_vectors.py - Multiplicacion por la constante K = 23
#
#  Usa fxpmath como MODELO DE REFERENCIA en punto fijo y emite:
#
#     x.hex         vectores de entrada        (N bits, C2)
#     expected.hex  valores esperados          (W bits, C2)
#     params.vh     parametros para el testbench
#
#  Variables de entorno:
#     N_BITS     ancho de X            (default 8)
#     N_FRAC     bits fraccionales     (default 0 -> entero)
#     N_VECTORS  vectores random extra (default 1000)
#==============================================================
import os
import random
from fxpmath import Fxp

K = 23

N     = int(os.environ.get('N_BITS',    8))
NF    = int(os.environ.get('N_FRAC',    0))
NVEC  = int(os.environ.get('N_VECTORS', 1000))
SEED  = int(os.environ.get('SEED',      1))

W  = N + 5          # 23 < 2^5 -> el producto necesita 5 bits mas
WF = NF             # multiplicar por un entero no mueve la coma

MIN_RAW = -(2 ** (N - 1))
MAX_RAW = (2 ** (N - 1)) - 1

random.seed(SEED)


def to_hex(fxp):
    """Devuelve el hex crudo (C2, sin prefijo) listo para $readmemh."""
    return fxp.hex()[2:].lower()


#--------------------------------------------------------------
# 1) Construccion de la lista de vectores (en RAW, enteros)
#--------------------------------------------------------------
directed = [0, 1, -1, 7, -7, MAX_RAW, MIN_RAW, MIN_RAW + 1, MAX_RAW - 1]
directed = [v for v in directed if MIN_RAW <= v <= MAX_RAW]

if 2 ** N <= 4096:
    # el rango entra en memoria: barrido EXHAUSTIVO
    raws = list(range(MIN_RAW, MAX_RAW + 1))
    modo = "exhaustivo ({} casos)".format(2 ** N)
else:
    # rango grande: bordes dirigidos + random
    raws = directed + [random.randint(MIN_RAW, MAX_RAW) for _ in range(NVEC)]
    modo = "dirigido + random ({} casos)".format(len(raws))


#--------------------------------------------------------------
# 2) Modelo de referencia con fxpmath
#--------------------------------------------------------------
x_lines = []
y_lines = []
saturados = 0

for raw in raws:
    val = raw / (2.0 ** NF)

    # entrada en formato S(N, NF)
    x = Fxp(val, signed=True, n_word=N, n_frac=NF)

    # producto en formato S(W, WF).
    # overflow='saturate' para DETECTAR si el ancho elegido no alcanza:
    # si satura, el valor guardado difiere del exacto.
    y = Fxp(val * K, signed=True, n_word=W, n_frac=WF,
            overflow='saturate', rounding='around')

    if y.get_val() != val * K:
        saturados += 1

    x_lines.append(to_hex(x))
    y_lines.append(to_hex(y))

if saturados:
    raise SystemExit(
        "ERROR: {} vectores saturaron -> W={} bits es insuficiente".format(
            saturados, W))


#--------------------------------------------------------------
# 3) Escritura de archivos
#--------------------------------------------------------------
with open('x.hex', 'w') as f:
    f.write('\n'.join(x_lines) + '\n')

with open('expected.hex', 'w') as f:
    f.write('\n'.join(y_lines) + '\n')

with open('params.vh', 'w') as f:
    f.write("// Generado por gen_vectors.py - NO EDITAR A MANO\n")
    f.write("`define N_BITS  {}\n".format(N))
    f.write("`define N_FRAC  {}\n".format(NF))
    f.write("`define W_BITS  {}\n".format(W))
    f.write("`define N_VEC   {}\n".format(len(raws)))


#--------------------------------------------------------------
# 4) Resumen + tabla de comprobacion manual
#--------------------------------------------------------------
print("=" * 50)
print(" gen_vectors.py  -  K = {}".format(K))
print("=" * 50)
print("  Formato entrada : S({}, {})".format(N, NF))
print("  Formato salida  : S({}, {})".format(W, WF))
print("  Modo            : {}".format(modo))
print("  Sin saturacion  : W = N+5 es suficiente  OK")
print()
print("  {:>10}  {:>8}  {:>12}  {:>8}".format("x", "x.hex", "23*x", "exp.hex"))
print("  " + "-" * 44)
for raw in directed[:6]:
    val = raw / (2.0 ** NF)
    x = Fxp(val, signed=True, n_word=N, n_frac=NF)
    y = Fxp(val * K, signed=True, n_word=W, n_frac=WF)
    print("  {:>10}  {:>8}  {:>12}  {:>8}".format(
        x.get_val(), to_hex(x), y.get_val(), to_hex(y)))
print()
print("  -> x.hex, expected.hex, params.vh  ({} vectores)".format(len(raws)))
print("=" * 50)
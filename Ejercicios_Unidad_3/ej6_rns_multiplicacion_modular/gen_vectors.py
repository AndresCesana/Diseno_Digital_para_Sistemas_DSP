#!/usr/bin/env python3
#==============================================================
#  gen_vectors.py - Multiplicador RNS con base {m0, m1, m2}
#
#  Reimplementa en Python las MISMAS funciones de elaboracion que
#  el RTL (clog2, mod_inv) y deriva las mismas constantes. Si el
#  RTL y este script no coinciden, el testbench lo detecta.
#
#  Emite:
#     x.hex         operandos X                (XW bits)
#     y.hex         operandos Y                (XW bits)
#     expected.hex  (X*Y) % M                  (XW bits)
#     valid.hex     1 si X*Y < M (sin desborde) (1 bit)
#     params.vh     parametros para el testbench
#
#  Variables de entorno:
#     M0, M1, M2   base de modulos       (default 3 5 7)
#     N_VECTORS    vectores random extra (default 2000)
#     SEED         semilla               (default 1)
#==============================================================
import os
import random
from math import gcd
from fxpmath import Fxp

M0 = int(os.environ.get('M0', 3))
M1 = int(os.environ.get('M1', 5))
M2 = int(os.environ.get('M2', 7))

NVEC = int(os.environ.get('N_VECTORS', 2000))
SEED = int(os.environ.get('SEED',      1))

MODS = [M0, M1, M2]

random.seed(SEED)


#--------------------------------------------------------------
# 0) Funciones de elaboracion  (espejo exacto de las del RTL)
#--------------------------------------------------------------
def clog2(value):
    """Identico al clog2 del modulo rns_mult."""
    n = 0
    v = value - 1
    while v > 0:
        n += 1
        v >>= 1
    return n


def mod_inv(a, m):
    """Inverso de a modulo m por fuerza bruta. 0 si no existe."""
    for k in range(1, m):
        if (a * k) % m == 1:
            return k
    return 0


def to_hex(fxp, nbits):
    """Hex crudo sin prefijo, con ancho fijo, listo para $readmemh."""
    raw = int(fxp.raw()) & ((1 << nbits) - 1)
    return format(raw, '0{}x'.format((nbits + 3) // 4))


#--------------------------------------------------------------
# 1) Validacion de la base y derivacion de constantes
#--------------------------------------------------------------
for i in range(3):
    for j in range(i + 1, 3):
        if gcd(MODS[i], MODS[j]) != 1:
            raise SystemExit(
                "ERROR: m{}={} y m{}={} no son coprimos -> la "
                "representacion RNS no es unica".format(
                    i, MODS[i], j, MODS[j]))

M  = M0 * M1 * M2
XW = clog2(M)

W    = [clog2(m) for m in MODS]
WMAX = max(W)

MI = [M // m for m in MODS]
E  = [MI[i] * mod_inv(MI[i] % MODS[i], MODS[i]) for i in range(3)]

if 0 in E:
    raise SystemExit("ERROR: no existe inverso modular -> base invalida")

SMAX = sum(E[i] * (MODS[i] - 1) for i in range(3))
SW   = clog2(SMAX + 1)

# Verificacion de que los e_i son indicadores de canal:
#   e_i = 1 (mod m_i)   y   e_i = 0 (mod m_j) para j != i
for i in range(3):
    for j in range(3):
        esperado = 1 if i == j else 0
        if E[i] % MODS[j] != esperado:
            raise SystemExit(
                "ERROR: e{} = {} no cumple la condicion CRT mod {}".format(
                    i, E[i], MODS[j]))


#--------------------------------------------------------------
# 2) Construccion de la lista de pares (X, Y)
#--------------------------------------------------------------
directed = [
    (0, 0), (0, 1), (1, 1), (1, M - 1),
    (14, 6),                 # caso del enunciado -> 84
    (13, 7),                 # 91, sin desborde
    (13, 9),                 # 117 -> desborda, devuelve 12
    (M - 1, M - 1),          # producto maximo
]
directed = [(a, b) for (a, b) in directed if 0 <= a < M and 0 <= b < M]

if M * M <= 65536:
    # el espacio de pares entra en memoria: barrido EXHAUSTIVO
    pares = [(a, b) for a in range(M) for b in range(M)]
    modo = "exhaustivo ({} pares)".format(M * M)
else:
    # espacio grande: bordes dirigidos + random
    pares = directed + [(random.randrange(M), random.randrange(M))
                        for _ in range(NVEC)]
    modo = "dirigido + random ({} pares)".format(len(pares))


#--------------------------------------------------------------
# 3) Modelo de referencia
#
#  La aritmetica RNS es entera y sin signo: fxpmath se usa aqui
#  como CHEQUEO DE ANCHO. Con overflow='saturate', si XW no
#  alcanzara para representar un operando o el resultado, el valor
#  guardado diferiria del exacto y lo detectamos.
#--------------------------------------------------------------
x_lines, y_lines, e_lines, v_lines = [], [], [], []
saturados = 0
sin_desborde = 0

for (a, b) in pares:
    prod = a * b
    res  = prod % M

    xf = Fxp(a,   signed=False, n_word=XW, n_frac=0, overflow='saturate')
    yf = Fxp(b,   signed=False, n_word=XW, n_frac=0, overflow='saturate')
    ef = Fxp(res, signed=False, n_word=XW, n_frac=0, overflow='saturate')

    if xf.get_val() != a or yf.get_val() != b or ef.get_val() != res:
        saturados += 1

    valido = 1 if prod < M else 0
    sin_desborde += valido

    x_lines.append(to_hex(xf, XW))
    y_lines.append(to_hex(yf, XW))
    e_lines.append(to_hex(ef, XW))
    v_lines.append(str(valido))

if saturados:
    raise SystemExit(
        "ERROR: {} vectores saturaron -> XW={} bits es insuficiente".format(
            saturados, XW))


#--------------------------------------------------------------
# 4) Escritura de archivos
#--------------------------------------------------------------
for nombre, lineas in [('x.hex',        x_lines),
                       ('y.hex',        y_lines),
                       ('expected.hex', e_lines),
                       ('valid.hex',    v_lines)]:
    with open(nombre, 'w') as f:
        f.write('\n'.join(lineas) + '\n')

with open('params.vh', 'w') as f:
    f.write("// Generado por gen_vectors.py - NO EDITAR A MANO\n")
    f.write("`define M0      {}\n".format(M0))
    f.write("`define M1      {}\n".format(M1))
    f.write("`define M2      {}\n".format(M2))
    f.write("`define M_TOT   {}\n".format(M))
    f.write("`define XW_BITS {}\n".format(XW))
    f.write("`define WMAX    {}\n".format(WMAX))
    f.write("`define E0_REF  {}\n".format(E[0]))
    f.write("`define E1_REF  {}\n".format(E[1]))
    f.write("`define E2_REF  {}\n".format(E[2]))
    f.write("`define SMAX    {}\n".format(SMAX))
    f.write("`define SW_BITS {}\n".format(SW))
    f.write("`define N_VEC   {}\n".format(len(pares)))


#--------------------------------------------------------------
# 5) Resumen + tabla de comprobacion manual
#--------------------------------------------------------------
print("=" * 62)
print(" gen_vectors.py  -  base RNS {{{}, {}, {}}}".format(M0, M1, M2))
print("=" * 62)
print("  Rango dinamico  : M = {}".format(M))
print("  Ancho X, Y, O   : XW = {} bits".format(XW))
print("  Anchos residuo  : {}  -> WMAX = {}".format(W, WMAX))
print("  M_i = M/m_i     : {}".format(MI))
print("  e_i (CRT)       : {}".format(E))
print("  Suma CRT maxima : SMAX = {}  -> SW = {} bits".format(SMAX, SW))
print("  Modo            : {}".format(modo))
print("  Sin saturacion  : XW alcanza para todo el rango  OK")
print("  Condicion CRT   : e_i indicador de canal         OK")
print()
print("  {:>5} {:>5} {:>7} {:>7} {:>8} {:>10}".format(
    "x", "y", "x*y", "esperado", "hex", "desborde"))
print("  " + "-" * 48)
for (a, b) in directed:
    prod = a * b
    res  = prod % M
    ef   = Fxp(res, signed=False, n_word=XW, n_frac=0)
    print("  {:>5} {:>5} {:>7} {:>8} {:>8} {:>10}".format(
        a, b, prod, res, to_hex(ef, XW), "SI" if prod >= M else "no"))
print()
print("  Pares sin desborde: {} de {}  ({:.1f} %)".format(
    sin_desborde, len(pares), 100.0 * sin_desborde / len(pares)))
print("  -> x.hex, y.hex, expected.hex, valid.hex, params.vh")
print("=" * 62)
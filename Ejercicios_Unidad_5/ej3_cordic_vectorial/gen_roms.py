#!/usr/bin/env python3
"""
Genera los tres ROMs de mult_reference.v

    rom_sqrt.hex   4096 x 16   sqrt(sum),  sum en Q10,  salida Q2.14
    rom_recip.hex  2048 x 16   1/den_n,    den_n en [0.5,1), salida Q2.14
    rom_atan.hex   4096 x 16   atan(t),    t en Q11,    salida Q2.14

Uso:  python3 gen_roms.py
"""
import math

Q14 = 1 << 14


def write_hex(fname, values):
    with open(fname, "w") as f:
        for v in values:
            v = max(0, min(v, 0xFFFF))
            f.write("%04x\n" % v)
    print("%-16s %5d entradas  (%d bytes)" % (fname, len(values), 2 * len(values)))


# ---------------------------------------------------------------- sqrt
# addr = sum[31:20]  =>  sum ~ addr / 1024, con addr en [0, 2048]
# se usa el punto medio del intervalo para minimizar el error de truncado
sqrt_rom = []
for a in range(4096):
    if a == 0:
        sqrt_rom.append(0)           # entrada nula -> R = 0 exacto
    else:
        s = (a + 0.5) / 1024.0
        sqrt_rom.append(int(round(math.sqrt(s) * Q14)))
write_hex("rom_sqrt.hex", sqrt_rom)


# --------------------------------------------------------------- recip
# den_n tiene el MSB (bit 15) siempre en 1, se direcciona con [14:4]
# dn = (2^15 + a*16 + 8) / 2^16   en [0.5, 1)   =>   1/dn en (1, 2]
recip_rom = []
for a in range(2048):
    dn = (2**15 + a * 16 + 8) / 2**16
    recip_rom.append(int(round((1.0 / dn) * Q14)))
write_hex("rom_recip.hex", recip_rom)


# ---------------------------------------------------------------- atan
# addr = t[15:4]  =>  t ~ addr / 2048, con addr en [0, 2048]
atan_rom = []
for a in range(4096):
    t = min((a + 0.5) / 2048.0, 1.0)
    atan_rom.append(int(round(math.atan(t) * Q14)))
write_hex("rom_atan.hex", atan_rom)


# ------------------------------------------------------- comprobaciones
print()
print("chequeos:")
print("  sqrt(2)   ->", sqrt_rom[2048], " esperado", round(math.sqrt(2) * Q14))
print("  atan(1)   ->", atan_rom[2048], " esperado", round(math.atan(1) * Q14))
print("  pi/2      ->", round(math.pi / 2 * Q14), " (PI2_Q14 en el RTL)")
print("  1/0.5     ->", recip_rom[0], " esperado ~", 2 * Q14)
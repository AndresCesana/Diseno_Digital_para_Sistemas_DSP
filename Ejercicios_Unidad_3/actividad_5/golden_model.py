# ============================================================
# GOLDEN MODEL - BOOTH RADIX-2
#
# A = +6  -> 0110 (4 bits C2)
# B = -5  -> 1011 (4 bits C2)
# b_-1 = 0
#
# Resultado esperado:
# A * B = -30
# ============================================================


def booth_radix2(A, B, N=4):

    # --------------------------------------------------------
    # Conversión a representación C2 de N bits
    # --------------------------------------------------------

    mask = (1 << N) - 1

    A_bits = A & mask
    B_bits = B & mask

    # Extensión de signo de A a 2N bits
    if A_bits & (1 << (N - 1)):
        A_ext = A_bits | (~mask)
    else:
        A_ext = A_bits

    # Mantener A en 2N bits
    mask_2N = (1 << (2 * N)) - 1
    A_ext = A_ext & mask_2N

    # Complemento a 2 para obtener -A
    A_neg = (-A_ext) & mask_2N

    # Acumulador
    parcial = 0

    # b_-1
    b_prev = 0

    print("==========================================")
    print("        GOLDEN MODEL - BOOTH RADIX-2")
    print("==========================================")

    print("A =", A)
    print("A bits =", format(A_bits, f"0{N}b"))

    print("B =", B)
    print("B bits =", format(B_bits, f"0{N}b"))

    print("b_-1 = 0")

    print()
    print("==========================================")
    print("TABLA DE BOOTH")
    print("==========================================")
    print(" i | bi bi-1 | accion | producto parcial")
    print("------------------------------------------")

    for i in range(N):

        bi = (B_bits >> i) & 1

        par = (bi << 1) | b_prev

        if par == 0b01:

            # +A << i
            pp = A_ext << i
            accion = f"+A<<{i}"

        elif par == 0b10:

            # -A << i
            pp = A_neg << i
            accion = f"-A<<{i}"

        else:

            # 00 o 11
            pp = 0
            accion = "0"

        # Mantener 2N bits
        pp &= mask_2N

        # Acumulación
        parcial = (parcial + pp) & mask_2N

        # Convertir acumulado a signed
        acumulado_signed = parcial

        if parcial & (1 << (2 * N - 1)):
            acumulado_signed -= (1 << (2 * N))

        # Convertir producto parcial a signed
        pp_signed = pp

        if pp & (1 << (2 * N - 1)):
            pp_signed -= (1 << (2 * N))

        print(
            f" {i} |  {bi}   {b_prev}  | "
            f"{accion:6s} | "
            f"{pp_signed:4d}  "
            f"(acum = {acumulado_signed:4d})"
        )

        b_prev = bi

    # Convertir resultado final a signed
    resultado = parcial

    if parcial & (1 << (2 * N - 1)):
        resultado -= (1 << (2 * N))

    print("------------------------------------------")

    print("Suma de productos parciales =", resultado)

    print("Resultado binario =", format(parcial, f"0{2*N}b"))

    print("==========================================")

    return resultado


# ============================================================
# EJECUCIÓN
# ============================================================

A = 6
B = -5

resultado = booth_radix2(A, B)

print()
print("==========================================")
print("VERIFICACIÓN")
print("==========================================")

esperado = A * B

print("A * B =", esperado)
print("Booth =", resultado)

if resultado == esperado:
    print("[PASS] Resultado correcto.")
else:
    print("[FAIL] Resultado incorrecto.")

print("==========================================")
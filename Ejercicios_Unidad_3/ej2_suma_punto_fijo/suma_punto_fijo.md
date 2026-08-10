# Suma en punto fijo S(NB, NBF) — C2

## 1. Datos

| | bits | NB | NBF | NBI = NB−NBF | valor |
|---|---|---|---|---|---|
| A | `110010`   | 6 | 4 | 2 | −0,875  |
| B | `00011110` | 8 | 5 | 3 | +0,9375 |

> Decodificar: leer como entero C2 y dividir por 2^NBF.
> A: 110010₂ = 50 − 64 = −14 → −14/2⁴ = −0,875

## 2. Formato de salida

```
NBF_out = max(4, 5)     = 5
NBI_out = max(2, 3) + 1 = 4     ← el +1 es el bit de guarda
NB_out  = 4 + 5         = 9
```

**O = S(9, 5)** → rango [−8; 7,96875], paso 2⁻⁵ = 0,03125

## 3. Alineación

Izquierda: extender **signo** (NBI_out − NBI bits).
Derecha: rellenar **ceros** (NBF_out − NBF bits).

```
A: +2 signo, +1 cero  →  A_ext = 1-111.00100
B: +1 signo, +0 ceros →  B_ext = 0-000.11110
```

## 4. Suma

```
  1-111.00100
+ 0-000.11110
--------------
  0-000.00010
```

## 5. Verificación

```
Pesos:   0-000.00010 = 2⁻⁴ = 0,0625
Decimal: −0,875 + 0,9375 = 0,0625
```


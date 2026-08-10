## (a) K en binario estándar

K = 23 = 10111₂ = 16 + 4 + 2 + 1

| Posición | 4 | 3 | 2 | 1 | 0 |
|---|---|---|---|---|---|
| Dígito | 1 | 0 | 1 | 1 | 1 |
| Peso | 16 | — | 4 | 2 | 1 |

Dígitos no nulos: **4**

## (b) K en CSD canónico

Aplicando la regla `0111…1` → `100…0(-1)` sobre el tramo de unos:

```
10111  →  11000 - 1     (111 = 1000 - 1)
11000  →  10-1000       (11 = 100 - 10)
```

K_csd = `1 0 -1 0 0 -1` = 32 - 8 - 1 = 23

| Posición | 5 | 4 | 3 | 2 | 1 | 0 |
|---|---|---|---|---|---|---|
| Dígito | 1 | 0 | -1 | 0 | 0 | -1 |
| Peso | +32 | — | -8 | — | — | -1 |

Dígitos no nulos: **3** — sin no-ceros consecutivos ✓

## (c) Expresión de Y = X · 23

**Forma binaria**

```
Y = (X<<4) + (X<<2) + (X<<1) + X
  = 16X + 4X + 2X + X
```

**Forma CSD**

```
Y = (X<<5) - (X<<3) - X
  = 32X - 8X - X
```

## Comparación

| | Binario | CSD |
|---|---|---|
| Representación | `10111` | `1 0 -1 0 0 -1` |
| Dígitos no nulos | 4 | 3 |
| Términos a combinar | 4 | 3 |
| **Sumadores/restadores** | **3** | **2** |

El CSD ahorra **1 sumador** (33 % menos). Los shifts son cableado y no
consumen lógica; las restas se implementan en complemento a dos
(inversión + carry-in = 1).

**Verificación con X = 7:**
- Binario: 112 + 28 + 14 + 7 = 161 ✓
- CSD: 224 - 56 - 7 = 161 ✓
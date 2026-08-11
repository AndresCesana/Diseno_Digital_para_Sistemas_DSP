## Multiplicación en RNS

**Base de módulos:** ${m_1, m_2, m_3} = {3, 5, 7}$

**Rango dinámico:** $M = 3 \cdot 5 \cdot 7 = 105$

Como los módulos son coprimos dos a dos, el Teorema Chino del Resto garantiza que todo entero $X \in [0, 105)$ tiene una representación única en RNS, y que es reconstruible a partir de sus residuos.

---

### 1. Codificación

Cada número se representa por sus residuos respecto a la base:

$X = 14 \rightarrow X_{rns} = (14 \mod 3, 14 \mod 5, 14 \mod 7) = (2, 4, 0)$

$Y = 6  \rightarrow Y_{rns} = ( 6 \mod 3,  6 \mod 5,  6 \mod 7) = (0, 1, 6)$

| | mod 3 | mod 5 | mod 7 |
|-----|:-----:|:-----:|:-----:|
| X = 14 | 2 | 4 | 0 |
| Y = 6 | 0 | 1 | 6 |

---

### 2. Multiplicación residuo a residuo

La operación se aplica de forma independiente en cada canal:

$o_i = (x_i \cdot y_i) \mod m_i$

| canal | producto | mod m_i | o_i |
|-------|----------|---------|:---:|
| $m_1$ = 3 | 2 $\cdot$ 0 = 0 | 0 mod 3 | 0 |
| $m_2$ = 5 | 4 $\cdot$ 1 = 4 | 4 mod 5 | 4 |
| $m_3$ = 7 | 0 $\cdot$ 6 = 0 | 0 mod 7 | 0 |

$O_{rns} = (0, 4, 0)$

No existe propagación de acarreo entre canales: cada residuo es menor que su módulo (aquí, 3 bits como máximo), por lo que los tres productos pueden calcularse en paralelo y en tiempo constante. Esta es la ventaja principal de RNS frente a la aritmética posicional.

---

### 3. Constantes CRT (precálculo)

Se calculan una única vez para la base elegida y quedan fijas como constantes del sistema:

$M_i = M / m_i$

$e_i = M_i · (M_i^{-1} \mod m_i)$

| i | $m_i$ | $M_i = M/m_i$ | $M_i \mod m_i$ | inverso | $e_i$ |
|---|-----|-------------|-------------|---------|-----|
| 1 | 3 | 35 | 2 | 2 (pues $2\cdot2 \equiv 1 \mod 3$) | 70 |
| 2 | 5 | 21 | 1 | 1 | 21 |
| 3 | 7 | 15 | 1 | 1 | 15 |

El inverso es necesario para que cada e_i actúe como indicador de su canal: $e_i \equiv 1 (\mod m_i) y e_i \equiv 0 (\mod m_j) para j \neq i$. En los canales 2 y 3 el inverso vale 1 y no altera nada; en el canal 1 sí es
imprescindible, ya que $35 \equiv 2 (\mod 3)$ y no 1.

Verificación: $e_1 = 70 \rightarrow 70 \mod 3 = 1$, $70 \mod 5 = 0$, $70 \mod 7 = 0$

---

### 4. Decodificación (reconstrucción por CRT)

$O_dec = ( \Sigma e_i \cdot o_i ) \mod M$

$O_dec = (70\cdot 0 + 21\cdot 4 + 15\cdot 0) \mod 105 = 84 \mod 105 = 84$

---

### 5. Verificación y rango

$14 \cdot 6 = 84$

Comprobación cruzada de los residuos:
$84 \mod 3 = 0$, $84 \mod 5 = 4$, $84 \mod 7 = 0 \rightarrow$ coincide con $O_{rns}$ 

**Condición de validez:** el resultado debe cumplir $0 \leq O_{dec} < M$.

Aquí 84 < 105, por lo que no hay desbordamiento.

RNS no dispone de un mecanismo económico de detección de overflow: si el producto excede M, el sistema devuelve el resultado reducido módulo M sin emitir ninguna señal de error. Por ejemplo, $14 \cdot 9 = 126$ se codificaría
como (0, 1, 0) y se reconstruiría como 21, indistinguible de un resultado legítimo. Por eso la base debe  dimensionarse de modo que M supere el producto máximo esperado.
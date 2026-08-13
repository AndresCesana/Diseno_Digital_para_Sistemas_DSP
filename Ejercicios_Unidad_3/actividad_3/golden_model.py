from fxpmath import Fxp


# ============================================================
# PARTE A
#
# x = 5.5625
# S(11,6) -> S(7,3)
# ============================================================

x = Fxp(
    5.5625,
    signed=True,
    n_word=11,
    n_frac=6
)

trunc = Fxp(
    x,
    signed=True,
    n_word=7,
    n_frac=3,
    overflow='wrap',
    rounding='trunc'
)

round_value = Fxp(
    x.get_val() + 0.0625,
    signed=True,
    n_word=7,
    n_frac=3,
    overflow='wrap',
    rounding='trunc'
)

print("=================================")
print("PARTE A")
print("=================================")

print("x =", x.get_val())

print("Truncado   =", trunc.get_val())

print("Redondeado =", round_value.get_val())

y = Fxp(
    8.75,
    signed=True,
    n_word=11,
    n_frac=6
)

wrap = Fxp(
    y,
    signed=True,
    n_word=5,
    n_frac=3,
    overflow='wrap',
    rounding='trunc'
)

sat = Fxp(
    y,
    signed=True,
    n_word=5,
    n_frac=3,
    overflow='saturate',
    rounding='trunc'
)

print()
print("=================================")
print("PARTE B")
print("=================================")

print("y =", y.get_val())

print("Wrap-around =", wrap.get_val())

print("Saturación  =", sat.get_val())
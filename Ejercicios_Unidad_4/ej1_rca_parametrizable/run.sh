set -euo pipefail

iverilog -g2012 -o sim -s tb_top full_adder.v rca.v tb_rca.v
vvp sim | tee run.log
python3 plot.py run.log

grep -q '\[FAIL\]' run.log && { echo "HAY TESTS QUE FALLARON"; exit 1; } || exit 0
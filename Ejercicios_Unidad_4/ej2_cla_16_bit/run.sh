iverilog -g2012 -o sim.out cla_lookahead.v cla4.v cla16.v full_adder.v rca.v tb_rca.v tb_cla.v tb_compare_top.v
vvp sim.out | tee resultado.log
python3 plot.py resultado.log
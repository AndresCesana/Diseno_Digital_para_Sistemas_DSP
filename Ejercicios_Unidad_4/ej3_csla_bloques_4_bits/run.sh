iverilog -g2012 -o sim_comp.out rca.v csla16.v cla16.v tb_comp.v
./sim_comp.out | python3 plot.py
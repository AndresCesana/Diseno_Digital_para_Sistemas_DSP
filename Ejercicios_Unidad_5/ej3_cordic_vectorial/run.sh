python3 gen_roms.py
iverilog -o sim cordic_vectorial.v mult_reference.v tb_compare.v
./sim
python3 analyze.py resultados.csv
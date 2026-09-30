create_clock -name dst_clk -period 5.0 [get_ports dst_clk]

# rst es sincrono a dst_clk
set_input_delay 1.0 -clock dst_clk [get_ports rst]
set_output_delay 1.0 -clock dst_clk [get_ports synced]

# src_bit es asincrono: no tiene relacion temporal con dst_clk
set_false_path -from [get_ports src_bit]
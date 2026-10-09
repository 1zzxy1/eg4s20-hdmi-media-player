create_clock -name clk50 -period 20.000 [get_ports {clk}]
# Keep generated clock and inter-domain timing visible during initial timing closure.
create_generated_clock -name mem_clk -source [get_ports {clk}] -divide_by 1.25 [get_nets {mem_clk}]
create_generated_clock -name mem_shift -source [get_ports {clk}] -divide_by 1.25 -phase 172.8 [get_nets {mem_clk_shift}]
create_generated_clock -name pix_clk -source [get_ports {clk}] -divide_by 2 [get_nets {pix_clk}]
create_generated_clock -name serial_clk -source [get_ports {clk}] -multiply_by 2.5 [get_nets {serial_clk}]
set_false_path -from [get_ports {rst_n}]
# No blanket false path between clock domains: CDC and SDRAM timing remain review gates.

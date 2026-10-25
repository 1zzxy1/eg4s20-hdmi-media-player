create_clock -name clk50 -period 20.000 [get_ports {clk}]
create_generated_clock -name sd_clk -source [get_ports {clk}] -divide_by 1 [get_nets {sd_clk}]
create_generated_clock -name mem_clk -source [get_ports {clk}] -divide_by 1.25 [get_nets {mem_clk}]
create_generated_clock -name mem_clk_shift -source [get_ports {clk}] -divide_by 1.25 -phase 172.8 [get_nets {mem_clk_shift}]
create_generated_clock -name pix_clk -source [get_ports {clk}] -divide_by 2 [get_nets {pix_clk}]
create_generated_clock -name serial_clk -source [get_ports {clk}] -multiply_by 2.5 [get_nets {serial_clk}]
# Reset is generated from PLL lock; buttons are synchronized as ordinary inputs.
# No blanket false path between clock domains: CDC and SDRAM timing remain review gates.

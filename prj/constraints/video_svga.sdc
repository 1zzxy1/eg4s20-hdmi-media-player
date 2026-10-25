create_clock -name clk50 -period 20.000 [get_ports {clk}]
create_generated_clock -name feedback_clk -source [get_ports {clk}] -multiply_by 1 [get_nets {u_vid/feedback_clk}]
create_generated_clock -name pix_clk -source [get_ports {clk}] -divide_by 1.25 [get_nets {pix_clk}]
create_generated_clock -name serial_clk -source [get_ports {clk}] -multiply_by 4 [get_nets {serial_clk}]

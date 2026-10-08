# LSBD 100 MHz single-ended oscillator and active-low reset.
set_property PACKAGE_PIN AC19 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets sys_clk]
create_clock -period 10.000 -name sys_clk [get_ports sys_clk]

set_property PACKAGE_PIN Y3 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]

# LSBD USB-to-UART bridge.
set_property PACKAGE_PIN F23 [get_ports rs232_uart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports rs232_uart_rxd]
set_property PACKAGE_PIN H19 [get_ports rs232_uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports rs232_uart_txd]
set_property SLEW SLOW [get_ports rs232_uart_txd]

# DDR3 pins are constrained by the generated MIG constraints.

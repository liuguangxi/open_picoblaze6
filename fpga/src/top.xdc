create_clock -period 5.0 -name clk [get_ports clk]

set_property PACKAGE_PIN AD12 [get_ports clk]
set_property PACKAGE_PIN AA12 [get_ports reset]
set_property PACKAGE_PIN AB12 [get_ports sleep]
set_property PACKAGE_PIN AA8 [get_ports test_in]

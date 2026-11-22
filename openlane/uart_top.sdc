#------------------------------------------------------------------------------
# uart_top.sdc - timing constraints (100 MHz APB clock)
#------------------------------------------------------------------------------
set clk_period 10.0
create_clock -name pclk -period $clk_period [get_ports pclk]

set_clock_uncertainty 0.25 [get_clocks pclk]
set_clock_transition  0.15 [get_clocks pclk]

# APB inputs / outputs budgeted at 30% of the cycle
set in_ports  [lsearch -inline -all -not -exact [all_inputs] [get_ports pclk]]
set_input_delay  [expr 0.3 * $clk_period] -clock pclk $in_ports
set_output_delay [expr 0.3 * $clk_period] -clock pclk [all_outputs]

# asynchronous reset and serial input are not timed against pclk
set_false_path -from [get_ports presetn]
set_false_path -from [get_ports uart_rxd]

set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y $in_ports
set_load 0.033 [all_outputs]
set_max_fanout 10 [current_design]

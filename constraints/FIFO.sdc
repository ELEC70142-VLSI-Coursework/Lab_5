####################################################################
##
##  Timing constraints for FIFO. Read into every scenario.
##  Units are nanoseconds and picofarads.
##
##  Author:   Sne Samal
##  Version:  1.0
##  Date:     2026-09-01
##
####################################################################

create_clock -name clk -period 1.1 [get_ports clk]

# Jitter, and the skew a clock tree would have. 2 percent of the period,
set_clock_uncertainty 0.022 [get_clocks clk]

# Edge rate assumed until a clock tree exists.
set_clock_transition 0.05 [get_clocks clk]

# Without this, max_transition checking has no value to check against.
set_max_transition 0.2 [current_design]

set_input_delay  0.22 -clock clk \
    [get_ports {rst_n clk_en in_valid in_data[*] out_ready}]
set_output_delay 0.22 -clock clk [all_outputs]

set_load 0.01 [all_outputs]

# Drive strength is set in scripts/mcmm.tcl, since it names a library
# cell and cell names belong to the kit.

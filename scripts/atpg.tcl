####################################################################
##
##  Stuck-at pattern generation for the scan design, written as STIL
##  for stil2verilog to translate into a testbench.
##
##  Author:   Sne Samal
##  Version:  1.1
##  Date:     2026-09-04
##
##      tmax -shell -nostartup scripts/atpg.tcl
##
####################################################################

source scripts/setup.tcl

set_messages -log $LOG_DIR/tmax.log -replace

####################################################################
## Build the model
####################################################################

read_netlist $SIM_MODELS -library
read_netlist $DFT_V

run_build_model $DESIGN

run_drc $DFT_SPF

####################################################################
## Patterns
####################################################################

set_faults -model stuck
add_faults -all

run_atpg

report_summaries

write_faults $OUT_DIR/${DESIGN}_faults.rpt -all -replace

write_patterns $STIL_PATTERNS -format stil -serial -unified_stil_flow -replace

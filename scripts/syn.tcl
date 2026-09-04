####################################################################
##
##  Logical synthesis of the FIFO. The netlist, SDC and SVF it writes
##  are the whole handoff to scripts/dft.tcl and scripts/lec.tcl.
##
##  Author:   Sne Samal
##  Version:  1.1
##  Date:     2026-09-04
##
##      fc_shell -f scripts/syn.tcl
##
####################################################################

source scripts/setup.tcl

set_host_options -max_cores $MAX_CORES

# Recreated each run, so a stale block cannot be picked up.
if { [file exists $SYN_LIB] } { file delete -force $SYN_LIB }

create_lib $SYN_LIB -technology $TECH_FILE -ref_libs $REF_LIBS
report_ref_libs

# Must be set before the design is read. Nothing here is placed or
# routed, so nothing needs physical data.
set_non_physical_mode

# Opened before the RTL is read and closed before the netlist is
# written, so the file records every transformation in between. A
# truncated SVF makes the equivalence check fail for reasons that have
# nothing to do with the design.
set_svf $SYNTH_SVF

analyze -format sverilog $RTL_FILES
elaborate $DESIGN
set_top_module $DESIGN

# clk_en is declared in the RTL and never used, so expect an unloaded
# port here. That is in the original source and is left alone.
redirect -tee -file $RPT_DIR/synth_check.rpt \
    "check_design -checks netlist -log_file $RPT_DIR/synth_check_netlist.log"

source scripts/mcmm.tcl

report_clocks

####################################################################
## Clock gating
####################################################################
# Scan shifting needs every flip-flop in the chain to see an edge on
# every cycle. The FIFO's register enables are generated inside the
# design, so a gated clock cannot be made to toggle from a port and
# every gate would have to be forced open by a test signal wired to its
# test enable pin. Ungated, each flop takes its clock straight from the
# clk port and the chain shifts unconditionally.

set_clock_gating_options -minimum_bitwidth $CG_SUPPRESS_BITWIDTH

compile_logical

# scripts/dft.tcl stops if a gate slipped through anyway.
catch {redirect -file $RPT_DIR/synth_clock_gating.rpt {report_clock_gating}}

lab_reports synth

####################################################################
## Export
####################################################################

set_svf -off

write_verilog $SYNTH_V
write_sdc -output $SYNTH_SDC

save_block
save_lib

####################################################################
##
##  Logic equivalence check of the post-DFT netlist against the
##  original RTL, in Formality.
##
##  Author:   Sne Samal
##  Version:  1.1
##  Date:     2026-09-04
##
##      fm_shell -f scripts/lec.tcl
##
####################################################################

source scripts/setup.tcl

set_host_options -max_cores $MAX_CORES

if { ![file exists $DFT_V] } {
    error "No netlist at $DFT_V. Run scripts/dft.tcl first."
}

set_svf $SYNTH_SVF $DFT_SVF

####################################################################
## Verification settings
####################################################################

set_app_var verification_assume_reg_init none

set_app_var verification_inversion_push true

set_app_var verification_failing_point_limit 0

####################################################################
## Libraries
####################################################################

set lib_base [file tail [file dirname $STD_DB_DIR]]
set LIB_DB   $STD_DB_DIR/${lib_base}tc.db

if { ![file exists $LIB_DB] } {
    error "No library at $LIB_DB. Check STD_DB_DIR in the kit."
}

####################################################################
## Reference: the RTL
####################################################################

if { [read_db -r $LIB_DB] != 1 } {
    error "read_db -r failed for $LIB_DB."
}
if { [read_sverilog -r $RTL_FILES] != 1 } {
    error "read_sverilog -r failed for $RTL_FILES."
}
if { [set_top r:/WORK/$DESIGN] != 1 } {
    error "Could not link the RTL as r:/WORK/$DESIGN."
}

####################################################################
## Implementation: the post-DFT netlist
####################################################################

if { [read_db -i $LIB_DB] != 1 } {
    error "read_db -i failed for $LIB_DB."
}
if { [read_verilog -i $DFT_V] != 1 } {
    error "read_verilog -i failed for $DFT_V."
}
if { [set_top i:/WORK/$DESIGN] != 1 } {
    error "Could not link the netlist as i:/WORK/$DESIGN. Look for\
           FE-LINK-2 warnings above: they name the cells that could not\
           be resolved against $LIB_DB."
}

set_constant i:/WORK/$DESIGN/$SCAN_EN_PORT   0
set_constant i:/WORK/$DESIGN/$TEST_MODE_PORT 0

####################################################################
## Match and verify
####################################################################

set_reference_design      r:/WORK/$DESIGN
set_implementation_design i:/WORK/$DESIGN

set match_log $RPT_DIR/lec_match.log
redirect -tee -file $match_log { match }

set fh [open $match_log r]
set match_text [read $fh]
close $fh

set n_matched 0
regexp {([0-9]+) +Compare points matched by name} $match_text -> n_matched

if { $n_matched == 0 } {
    error "match paired up no compare points, so there is nothing to\
           verify and the result would be meaningless. Look for FE-LINK\
           warnings above: they mean the netlist did not resolve against\
           $LIB_DB."
}

redirect -file $RPT_DIR/lec_matched.rpt   {report_matched_points}
redirect -file $RPT_DIR/lec_unmatched.rpt {report_unmatched_points}

report_setup_status

verify

####################################################################
## Reports
####################################################################

redirect -file $RPT_DIR/lec_passing.rpt   {report_passing_points}
redirect -file $RPT_DIR/lec_failing.rpt   {report_failing_points}
redirect -file $RPT_DIR/lec_aborted.rpt   {report_aborted_points}
redirect -file $RPT_DIR/lec_constants.rpt {report_constants}
redirect -file $RPT_DIR/lec_guidance.rpt  {report_guidance -summary}

# analyze_points explains why a point failed rather than only that it
# did.
redirect -file $RPT_DIR/lec_analysis.rpt {analyze_points -all}

report_status

print_message_info

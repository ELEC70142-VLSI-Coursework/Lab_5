####################################################################
##
##  Kit, design parameters, directories and reporting.
##  Sourced first by every script in this flow.
##
##  Author:   Sne Samal
##  Version:  1.1
##  Date:     2026-09-04
##
####################################################################

if { ![info exists env(SYN_KIT_TCL)] } { error "SYN_KIT_TCL is not set. Load the PDK first." }

source $env(SYN_KIT_TCL)

####################################################################
## Design
####################################################################

set DESIGN   FIFO
set CLK_PORT clk

set RTL_FILES [list src/$DESIGN.sv]
set SDC_FILE  constraints/$DESIGN.sdc

####################################################################
## DFT
####################################################################

set SCAN_EN_PORT   scan_en
set TEST_MODE_PORT scan_testmode
set SCAN_IN_PORT   scan_di
set SCAN_OUT_PORT  scan_do

set CHAIN_COUNT 1

set TEST_MODE Internal_scan

set CG_SUPPRESS_BITWIDTH 4096

set SCAN_CLOCK_TIMING {45 55}

####################################################################
## Analysis
####################################################################

set DERATE_EARLY 0.95
set DERATE_LATE  1.05

# func_wc has dynamic power disabled, so power is reported from tc.
set POWER_SCENARIO func_tc

set MAX_CORES 8

####################################################################
## Directories and files
####################################################################

set WORK_DIR work
set OUT_DIR  outputs
set RPT_DIR  reports
set LOG_DIR  logs

foreach d [list $WORK_DIR $OUT_DIR $RPT_DIR $LOG_DIR] { file mkdir $d }

# Two libraries with the netlist as the handoff, so DFT is added to an
# already synthesised netlist rather than folded into synthesis.
set SYN_LIB $WORK_DIR/${DESIGN}_syn.dlib
set DFT_LIB $WORK_DIR/${DESIGN}_dft.dlib

set SYNTH_V   $OUT_DIR/${DESIGN}_synth.v
set SYNTH_SDC $OUT_DIR/${DESIGN}_synth.sdc
set SYNTH_SVF $OUT_DIR/${DESIGN}_synth.svf

set DFT_V     $OUT_DIR/${DESIGN}_dft.v
set DFT_SDC   $OUT_DIR/${DESIGN}_dft.sdc
set DFT_SVF   $OUT_DIR/${DESIGN}_dft.svf
set DFT_SPF   $OUT_DIR/${DESIGN}_dft.spf

set STIL_PATTERNS $OUT_DIR/${DESIGN}_patterns.stil

####################################################################
## Reports
####################################################################
# One call per stage, so a stage's effect is a diff against the one
# before it.

proc lab_reports {stage} {
    global RPT_DIR POWER_SCENARIO

    redirect -file $RPT_DIR/${stage}_timing_max.rpt \
        {report_timing -delay_type max -max_paths 10}
    redirect -file $RPT_DIR/${stage}_timing_min.rpt \
        {report_timing -delay_type min -max_paths 10}
    redirect -file $RPT_DIR/${stage}_area.rpt  {report_area -hierarchy}
    redirect -file $RPT_DIR/${stage}_qor.rpt   {report_qor}
    redirect -file $RPT_DIR/${stage}_power.rpt \
        "report_power -scenarios $POWER_SCENARIO"
}

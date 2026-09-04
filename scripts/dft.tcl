####################################################################
##
##  Muxed scan chain insertion into the synthesised netlist, and the
##  STIL protocol that scripts/atpg.tcl needs.
##
##  Author:   Sne Samal
##  Version:  1.1
##  Date:     2026-09-04
##
##      fc_shell -f scripts/dft.tcl
##
####################################################################

source scripts/setup.tcl

set_host_options -max_cores $MAX_CORES

if { ![file exists $SYNTH_V] } {
    error "No netlist at $SYNTH_V. Run scripts/syn.tcl first."
}

if { [file exists $DFT_LIB] } { file delete -force $DFT_LIB }

create_lib $DFT_LIB -technology $TECH_FILE -ref_libs $REF_LIBS

set_non_physical_mode

set_svf $DFT_SVF

read_verilog -top $DESIGN $SYNTH_V
link_block

source scripts/mcmm.tcl

####################################################################
## Test ports
####################################################################

create_port $SCAN_EN_PORT   -direction in
create_port $TEST_MODE_PORT -direction in
create_port $SCAN_IN_PORT   -direction in
create_port $SCAN_OUT_PORT  -direction out

####################################################################
## Scan configuration
####################################################################

set_dft_configuration -scan enable

set_scan_configuration -style multiplexed_flip_flop -chain_count $CHAIN_COUNT

set_dft_signal -view spec -type ScanEnable  -port $SCAN_EN_PORT   -active_state 1
set_dft_signal -view spec -type TestMode    -port $TEST_MODE_PORT -active_state 1
set_dft_signal -view spec -type ScanDataIn  -port $SCAN_IN_PORT
set_dft_signal -view spec -type ScanDataOut -port $SCAN_OUT_PORT

set_dft_signal -view existing_dft -type ScanClock \
    -port $CLK_PORT -timing $SCAN_CLOCK_TIMING

####################################################################
## Clock gates
####################################################################

set icg_refs {}
catch {
    foreach_in_collection lc [get_lib_cells -quiet */* \
            -filter "is_integrated_clock_gating_cell == true"] {
        lappend icg_refs [get_attribute $lc base_name]
    }
}

if { [llength $icg_refs] > 0 } {
    set icgs [get_cells -quiet -hierarchical * \
        -filter "ref_name == [join $icg_refs { || ref_name == }]"]
    if { [sizeof_collection $icgs] > 0 } {
        error "[sizeof_collection $icgs] clock gating cell(s) in $SYNTH_V.\
               Their registers cannot shift and dft_drc will fail. Raise\
               CG_SUPPRESS_BITWIDTH in scripts/setup.tcl and re-run syn.tcl."
    }
}

####################################################################
## Test protocol and rule check
####################################################################

create_test_protocol

redirect -tee -file $RPT_DIR/dft_drc_pre.rpt {dft_drc}

redirect -file $RPT_DIR/scan_registers_report.rep {report_scan_configuration}

####################################################################
## Preview and insert
####################################################################

redirect -tee -file $RPT_DIR/dft_preview.rpt {preview_dft}

insert_dft

####################################################################
## Constrain the new ports
####################################################################

foreach corner $CORNER_LABELS {
    current_scenario func_$corner

    set test_in [get_ports [list $SCAN_EN_PORT $TEST_MODE_PORT $SCAN_IN_PORT]]
    set_input_delay 0.22 -clock $CLK_PORT $test_in
    set_driving_cell -lib_cell $DRIVE_CELL $test_in

    set_output_delay 0.22 -clock $CLK_PORT [get_ports $SCAN_OUT_PORT]
    set_load 0.01 [get_ports $SCAN_OUT_PORT]
}
current_scenario func_wc

####################################################################
## Post insertion checks
####################################################################

redirect -tee -file $RPT_DIR/dft_drc_post.rpt {dft_drc}

# Wrapped, because a failed DRC leaves no traced chain to report on and
# the netlist below is worth having either way. report_scan_path takes
# no -view in Fusion Compiler, unlike report_dft_signal.
catch {redirect -file $RPT_DIR/${DESIGN}_scan_chains_report.rep {report_scan_path}}
catch {redirect -file $RPT_DIR/${DESIGN}_scan_setup_report.rep \
    {report_dft_signal -view existing_dft}}
catch {redirect -file $RPT_DIR/${DESIGN}_dft_summary.rep {report_dft}}

lab_reports dft

####################################################################
## Export
####################################################################

set_svf -off

write_verilog $DFT_V
write_sdc -output $DFT_SDC

write_test_protocol -test_mode $TEST_MODE -output $DFT_SPF


set fh [open $DFT_SPF r]
set spf_text [read $fh]
close $fh
if { ![string match {*ScanStructures*} $spf_text] } {
    error "$DFT_SPF has no ScanStructures block, so it describes no scan\
           chains. TestMAX will see every flip-flop as nonscan and report\
           near-zero coverage. Check that TEST_MODE ($TEST_MODE) is the mode\
           named in $RPT_DIR/dft_drc_post.rpt."
}

save_block
save_lib


#######################################################################################################
##  Design initialization for DFT Scan Chain
#######################################################################################################

set DESIGN FIFO 
set CLOCK_NAME clk

set MAP_OPT_EFF high

set _OUTPUTS_PATH OUTPUTS_DFT
set _REPORTS_PATH REPORTS_DFT


source ./OUTPUTS/DESIGN/${DESIGN}_synth.genus_setup.tcl

#######################################################################################################
## DFT Scan Chain Configuration
#######################################################################################################

# DFT Scan Chain Configuration for Genus
set_db dft_scan_style muxed_scan

# Define DFT signals and ports
define_dft shift_enable -active high -create_port scan_en
define_dft test_mode -active high -create_port scan_testmode

# Define the test clock
define_dft test_clock ${CLOCK_NAME}

# Exclude certain modules from scan chain
# set_db inst:<inst_name> .dft_dont_scan true
# Example:
# set_db [get_db insts:SYSTEM_TOP ram_ram_registers_reg*] .dft_dont_scan true


set_db dft_identify_test_signals false
set_db dft_identify_top_level_test_clocks false
set_compatible_test_clocks -all

#######################################################################################################
## Check DFT Rules and Fix Violations
#######################################################################################################


check_dft_rules

fix_dft_violations -test_control scan_testmode -async_set -async_reset -clock

report_scan_registers > ${_REPORTS_PATH}/scan_registers_report.rep


#######################################################################################################
## Connect scan chains and run incremental synthesis
#######################################################################################################

define_dft scan_chain -create_ports -sdi scan_di -sdo scan_do -shift_enable scan_en -domain clk -edge rise

# Replace non-scan flops with their scan-equivalent flip-flops if the design was previously mapped.
convert_to_scan 

# Connect scan chains
connect_scan_chains -auto_create_chains

set_db syn_opt_effort ${MAP_OPT_EFF}
syn_opt -incremental

report_scan_chains > ${_REPORTS_PATH}/${DESIGN}_scan_chains_report.rep
report_scan_setup > ${_REPORTS_PATH}/${DESIGN}_scan_setup_report.rep

#######################################################################################################
## Export Design Files
#######################################################################################################

write_snapshot -directory ${_REPORTS_PATH}/final -tag final
report_summary -directory ${_REPORTS_PATH}

write_hdl > ${_OUTPUTS_PATH}/${DESIGN}_synth.v
write_sdc > ${_OUTPUTS_PATH}/${DESIGN}_synth.sdc
write_sdf > ${_OUTPUTS_PATH}/${DESIGN}_synth.sdf
write_script > ${_OUTPUTS_PATH}/${DESIGN}_synth.script
    
write_design -base_name ${_OUTPUTS_PATH}/DESIGN/${DESIGN}_synth
write_db -all_root_attributes -script ${_OUTPUTS_PATH}/DESIGN/${DESIGN}_synth.tcl    


#######################################################################################################
## Write Reports
#######################################################################################################

report_qor > ${_REPORTS_PATH}/${DESIGN}_qor.rpt
report_area > ${_REPORTS_PATH}/${DESIGN}_area.rpt
report_dp > ${_REPORTS_PATH}/${DESIGN}_datapath_incr.rpt
report_messages > ${_REPORTS_PATH}/${DESIGN}_messages.rpt
report_gates > ${_REPORTS_PATH}/${DESIGN}_gates.rpt
report_timing > ${_REPORTS_PATH}/${DESIGN}_timing.rpt
report_power > ${_REPORTS_PATH}/${DESIGN}_power.rpt



#######################################################################################################
## ATPG Test Vector Generation
#######################################################################################################

# To generate the ATPG test vectors in fullscan mode :
# .... Invoke the script from OS command line as 'modus -file ./ATPG/runmodus.atpg.tcl'.
# To simulate the ATPG generated test vectors in FULLSCAN mode:
# .... Invoke the script from OS command line as './ATPG/run_fullscan_sim'.

write_dft_atpg  -directory ./ATPG \
                -library "/usr/local/cadence/kits/tsmc/beLibs/65nm/TSMCHOME/digital/Front_End/verilog/tcbn65lpbwp7t_141a/tcbn65lpbwp7t.v" \
                -build_testmode_options "-testmode FULLSCAN" \
                -atpg_options "-reportheartbeat 5 -maxelapsedtime 10" \



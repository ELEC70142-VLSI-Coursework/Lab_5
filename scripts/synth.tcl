####################################################################
##
##          GENUS SYNTHESYS FLOW SCRIPT
## 
####################################################################

####################################################################
## Variables Setup
####################################################################

# Design name should match the top-level module name in the HDL file.
#  JTAG.sv Programming_controller.sv GPIO.sv

# Variable setup
set _HDL_DIRECTORY ./SRC
set HDL_FILES [list FIFO.sv]           ;# list of sources
set DESIGN FIFO                        ;# top-level module name

# Clock name should match the clock signal name in HDL (i.e. clk, CLK, ...)
set CLOCK_NAME clk
set CLOCK_PERIOD_ps 1100

set GEN_EFF medium                      ;# synthesis effort
set MAP_OPT_EFF high                    ;# mapping and optimization effort

set _OUTPUTS_PATH OUTPUTS               ;# where to store output files
set _REPORTS_PATH REPORTS               ;# where to store synthesis reports

####################################################################
## Environment Settings and library setup
####################################################################

set_db init_hdl_search_path $_HDL_DIRECTORY;
set_db library "/usr/local/cadence/kits/tsmc/beLibs/65nm/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn65lpbwp7t_220a/tcbn65lpbwp7twc.lib /home/lr524/TestDigital/Lab3/ts1n65lpll32x32m4_220a/SYNOPSYS/ts1n65lpll32x32m4_220a_tt1p2v25c.lib";
set_db lef_library "/usr/local/cadence/kits/tsmc/beLibs/65nm/TSMCHOME/digital/Back_End/lef/tcbn65lpbwp7t_141a/lef/tcbn65lpbwp7t_9lmT2.lef /home/lr524/TestDigital/Lab3/ts1n65lpll32x32m4_220a/LEF/ts1n65lpll32x32m4_220a_5m.lef";
set_db cap_table_file "/usr/local/cadence/kits/tsmc/beLibs/65nm/TSMCHOME/digital/Back_End/lef/tcbn65lpbwp7t_141a/techfiles/captable/cln65lp_1p09m+alrdl_top2_rcworst.captable";
set_db information_level 4;       # Output verbosity level - 1 (default) to 11
set_db use_tiehilo_for_const duplicate;
set_db lp_insert_clock_gating false; 

####################################################################
## Load Design
####################################################################

# Read HDL files from the specified directory
# Use option -vhd for VHDL files, -verilog for Verilog files, or -sv for SystemVerilog files.

read_hdl -sv ${HDL_FILES}
elaborate ${DESIGN}
check_design -unresolved
check_design -unloaded

####################################################################
## Constraints Setup
####################################################################

# Set time units for SDC commands to be consistent with Genus commands
set_time_unit -picoseconds
set_load_unit -femtofarads

# Define the system clock constraints
create_clock -domain domain1 -name ${CLOCK_NAME} -period ${CLOCK_PERIOD_ps} [get_db ports ${CLOCK_NAME}]
set_db clock:${DESIGN}/${CLOCK_NAME} .setup_uncertainty [expr 0.02 * ${CLOCK_PERIOD_ps}]
set_clock_uncertainty -hold  [expr 0.02 * ${CLOCK_PERIOD_ps}] ${CLOCK_NAME} 
set_clock_uncertainty -setup [expr 0.02 * ${CLOCK_PERIOD_ps}] ${CLOCK_NAME} 
set_clock_transition -rise  50 ${CLOCK_NAME}
set_clock_transition -fall  50 ${CLOCK_NAME}

####################################################################################################
## Synthesizing to generic 
####################################################################################################

# First synthesize to generic gates
set_db syn_generic_effort $GEN_EFF
syn_generic

####################################################################################################
## Synthesizing to gates
####################################################################################################

set_db syn_map_effort $MAP_OPT_EFF
syn_map

write_snapshot -directory ${_REPORTS_PATH}/map -tag map
report_dp > ${_REPORTS_PATH}/map/${DESIGN}_datapath.rpt
report_summary -directory ${_REPORTS_PATH}

#######################################################################################################
## Optimize Netlist
#######################################################################################################

set_db syn_opt_effort $MAP_OPT_EFF
syn_opt
write_snapshot -directory ${_REPORTS_PATH}/opt -tag syn_opt
report_dp > ${_REPORTS_PATH}/opt/${DESIGN}_datapath.rpt
report_summary -directory ${_REPORTS_PATH}

#######################################################################################################
## Export Design Files
#######################################################################################################

write_snapshot -directory ${_REPORTS_PATH}/final -tag final
report_summary -directory ${_REPORTS_PATH}
write_hdl > ${_OUTPUTS_PATH}/${DESIGN}_synth.v
write_sdc > ${_OUTPUTS_PATH}/${DESIGN}_synth.sdc
write_sdf > ${_OUTPUTS_PATH}/${DESIGN}_synth.sdf
write_script > ${_OUTPUTS_PATH}/${DESIGN}.script
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
## Write LEC
#######################################################################################################

## Write LEC script comparing the synthesized design with the original RTL.
write_do_lec -revised_design ${_OUTPUTS_PATH}/${DESIGN}_synth.v -logfile ${_OUTPUTS_PATH}/rtl2final.lec.log > ${_OUTPUTS_PATH}/rtl2final.lec.do


#######################################################################################################
## END
#######################################################################################################
time_info FINAL
puts "============================"
puts "Synthesis Finished ........."
puts "============================"
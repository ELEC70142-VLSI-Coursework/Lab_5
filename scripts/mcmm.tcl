####################################################################
##
##  Modes, corners and scenarios, and the SDC read into them.
##  Sourced once the block exists.
##
##  Author:   Sne Samal
##  Version:  1.1
##  Date:     2026-09-04
##
####################################################################

catch {remove_scenarios -all}
catch {remove_corners   -all}
catch {remove_modes     -all}

####################################################################
## Mode and corners
####################################################################

create_mode func
current_mode func

foreach corner $CORNER_LABELS {
    create_corner $corner
    current_corner $corner

    set_process_label $corner
    set_temperature   $CORNER_TEMP($corner)
    set_voltage $CORNER_VOLTAGE($corner) -object_list $PWR_NET
    set_voltage 0.0                      -object_list $GND_NET

    create_scenario -name func_$corner -mode func -corner $corner
}

####################################################################
## Constraints
####################################################################

foreach corner $CORNER_LABELS {
    current_scenario func_$corner

    set sdc_log $RPT_DIR/read_sdc_$corner.log
    redirect -tee -file $sdc_log { read_sdc $SDC_FILE }

    set fh [open $sdc_log r]
    set sdc_out [read $fh]
    close $fh
    if { [string match {*Errors reading SDC file*} $sdc_out] } {
        error "read_sdc reported errors for scenario func_$corner.\
               The rest of $SDC_FILE was skipped. See $sdc_log."
    }

    set_driving_cell -lib_cell $DRIVE_CELL \
        [get_ports * -filter "direction == in && name != $CLK_PORT"]

    set_timing_derate -early $DERATE_EARLY -cell_delay -net_delay
    set_timing_derate -late  $DERATE_LATE  -cell_delay -net_delay
}

# Belt to the braces above: a scenario with no clock reports no
# violations at all.
foreach corner $CORNER_LABELS {
    current_scenario func_$corner
    if { [sizeof_collection [all_clocks]] == 0 } {
        error "No clock in scenario func_$corner after reading $SDC_FILE."
    }
}

####################################################################
## What each scenario is for
####################################################################
#   wc  slow, hot, low voltage    setup, transition, capacitance
#   bc  fast, cold, high voltage  hold
#   tc  nominal                   power

set_scenario_status func_wc -active true \
    -setup true  -hold false \
    -max_transition true  -max_capacitance true \
    -leakage_power true   -dynamic_power false

set_scenario_status func_bc -active true \
    -setup false -hold true \
    -max_transition false -max_capacitance false \
    -leakage_power false  -dynamic_power false

set_scenario_status func_tc -active true \
    -setup false -hold false \
    -max_transition false -max_capacitance false \
    -leakage_power true   -dynamic_power true

current_scenario func_wc

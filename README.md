##### Imperial College London, Department of Electrical & Electronic Engineering


#### ELEC70142 Digital VLSI Design

### Lab 5 – Scan Chain Insertion, Logic Equivalence Check, and Power Estimation

##### *Peter Cheung, v1.2 – 13 November 2025*

---

### Objectives

By the end of this lab, you will be able to:
- Implement Design for Testability (DFT)
- Perform Logic Equivalence Check (LEC)

---

### Task 1 – Scan Chain Insertion

As integrated circuits become more complex and costly to manufacture, it is crucial to incorporate testability features early in the design process. Design for Testability (DFT) techniques enhance fault coverage and reduce test time and cost by making internal signals easier to control and observe. One widely used DFT method is scan chain insertion, which links sequential elements into shift registers. This allows test vectors to be serially loaded, captured, and read back, enabling effective fault detection and diagnosis.

Cadence Genus offers built-in support for various DFT flows. In this lab, you will use Genus to insert scan chains into a synthesized design, create the necessary test ports and control signals, and analyze the resulting reports to assess the impact on area, timing, and power.

#### Step 1 – Synthesize the Design

For this lab you will synthesize a synchronous FIFO with read/valid interface. You can find the System Verilog code in the SRC folder. 

DFT can be applied during synthesis or added to a synthesized netlist. Begin by synthesizing the RTL design with Genus. After successful synthesis, save the design for future use:

```
write_design -base_name ${_OUTPUTS_PATH}/DESIGN/${DESIGN}_synth
```

Ensure that `${_OUTPUTS_PATH}` and `${DESIGN}` are set correctly before executing this command.

#### Step 2 – Insert Scan Chains

Start the DFT flow in the current Genus session or reload the synthesized design. To reload, set the design name and source the setup file:

```
set DESIGN FIFO
source ./OUTPUTS/DESIGN/${DESIGN}_synth.genus_setup.tcl
```

Define the required variables:

```
set CLOCK_NAME clk
set MAP_OPT_EFF high
set _OUTPUTS_PATH OUTPUTS_DFT
set _REPORTS_PATH REPORTS_DFT
```

Configure the DFT scan style and create two control ports:
- `scan_en`: Enables scan mode by selecting the scan input via the multiplexer.
- `scan_testmode`: Forces the design into test mode, disabling or overriding parts of the circuit for testing.

By default, the design clock (`${CLOCK_NAME}`) is used as the test clock, but you can specify a different test clock if needed.

```
# DFT Scan Chain Configuration for Genus
set_db dft_scan_style muxed_scan

# Define DFT signals and ports
define_dft shift_enable -active high -create_port scan_en
define_dft test_mode -active high -create_port scan_testmode

# Define the test clock
define_dft test_clock ${CLOCK_NAME}

set_db dft_identify_test_signals false
set_db dft_identify_top_level_test_clocks false
set_compatible_test_clocks -all
```

Automatically fix DFT violations (such as asynchronous set/reset pins and gated clocks) and insert any required fix-up logic controlled by the `scan_testmode` signal:

```
check_dft_rules

fix_dft_violations -clock -test_control scan_testmode -async_set -async_reset 

report_scan_registers > ${_REPORTS_PATH}/scan_registers_report.rep
```

Genus will add the necessary scan-related ports, replace standard flip-flops with scan-enabled versions (if available), connect all registers into scan chains, and re-synthesize the design to incorporate these changes:

```
define_dft scan_chain -create_ports -sdi scan_di -sdo scan_do -shift_enable scan_en -domain clk -edge rise

# Replace non-scan flops with scan-equivalent flip-flops if previously mapped
convert_to_scan 

# Connect scan chains
connect_scan_chains -auto_create_chains

set_db syn_opt_effort ${MAP_OPT_EFF}
syn_opt -incremental

report_scan_chains > ${_REPORTS_PATH}/${DESIGN}_scan_chains_report.rep
report_scan_setup > ${_REPORTS_PATH}/${DESIGN}_scan_setup_report.rep
```

The `convert_to_scan` command reports the percentage of registers available for DFT:

```
Scan mapping status report
==========================
    Scan mapping: converting flip-flops that pass TDRC.
      Scan connection mode: 'loopback'.
      Scan shift-enable connection mode: 'tie_off'.
    Scan mapping done: 22 flip-flops mapped to scan.
    Category                               Number    Percentage
    -----------------------------------------------------------
    Scan flip-flops mapped for DFT            22        100.00%
    Flip-flops not mapped for DFT
         flip-flops not scan replaceable       0          0.00%
         flip-flops not targeted for DFT       0          0.00%
    -----------------------------------------------------------
                                  Totals      22        100.00%
```

If the percentage of scan flip-flops mapped for DFT is lower than expected, review the unmapped registers and investigate the reasons for incomplete coverage. Addressing these issues will help maximize fault coverage and improve your test strategy.

Export the updated design using the following commands:

```
write_snapshot -directory ${_REPORTS_PATH}/final -tag final
report_summary -directory ${_REPORTS_PATH}

write_hdl > ${_OUTPUTS_PATH}/${DESIGN}_synth.v
write_sdc > ${_OUTPUTS_PATH}/${DESIGN}_synth.sdc
write_sdf > ${_OUTPUTS_PATH}/${DESIGN}_synth.sdf
write_script > ${_OUTPUTS_PATH}/${DESIGN}_synth.script
    
write_design -base_name ${_OUTPUTS_PATH}/DESIGN/${DESIGN}_synth
write_db -all_root_attributes -script ${_OUTPUTS_PATH}/DESIGN/${DESIGN}_synth.tcl    

report_qor > ${_REPORTS_PATH}/${DESIGN}_qor.rpt
report_area > ${_REPORTS_PATH}/${DESIGN}_area.rpt
report_dp > ${_REPORTS_PATH}/${DESIGN}_datapath_incr.rpt
report_messages > ${_REPORTS_PATH}/${DESIGN}_messages.rpt
report_gates > ${_REPORTS_PATH}/${DESIGN}_gates.rpt
report_timing > ${_REPORTS_PATH}/${DESIGN}_timing.rpt
report_power > ${_REPORTS_PATH}/${DESIGN}_power.rpt
```

#### Step 3 – Inspect and Compare Results

Review the generated reports and output files.  
Open the updated Verilog design and examine the module’s input and output ports.  
> Can you identify the new ports added by the DFT flow? During simulation, ensure these ports are defined in your DUT to avoid simulation errors.

Explore the reports in the `REPORTS_DFT` directory.

The `scan_registers_report.rep` file details which registers have passed or failed the DFT rules and provides a summary.  
Other reports, such as area, power, and timing, should be familiar.

> Compare the area, power, and timing metrics before and after scan chain insertion. What differences do you observe? Can you explain the reasons for these changes?

#### Step 4 – Write the ATPG

Genus can automatically generate an ATPG script for Modus to create test vectors for your design. This script configures the test environment, specifies the scan mode, and sets ATPG options. Once generated, you can run it in Modus to produce the necessary test patterns for verifying scan chain functionality.

```
write_dft_atpg  -directory ./ATPG \
                -library "/usr/local/cadence/kits/tsmc/beLibs/65nm/TSMCHOME/digital/Front_End/verilog/tcbn65lpbwp7t_141a/tcbn65lpbwp7t.v" \
                -build_testmode_options "-testmode FULLSCAN" \
                -atpg_options "-reportheartbeat 5 -maxelapsedtime 10" \
```

<!-- Exit Genus and run the generated script in Modus:

```
modus -file ./ATPG/runmodus.atpg.tcl
```

This process generates a Verilog testbench that can be used by Automatic Test Equipment (ATE) to control the DUT ports, shift in test vectors, and capture the serial output during scan testing.

To simulate scan chain operation, run the provided script at `./ATPG/run_fullscan_sim`. -->

---

### Task 2 – Logic Equivalence Check (LEC)

Logic Equivalence Check (LEC) is a vital verification step to ensure functional correctness after design transformations such as scan chain insertion or optimization. By comparing the original RTL with the modified netlist, LEC confirms that no unintended changes have been introduced, guaranteeing that the synthesized design remains functionally identical to the source.

This can be performed using Cadence Conformal as follows:

Start Genus and reload the post-DFT design:

```
source ./OUTPUTS_DFT/DESIGN/${DESIGN}_synth.genus_setup.tcl
```

Genus can automatically generate a script for Logic Equivalence Check (LEC):

```
write_do_lec -revised_design <path to the synthesized file> -logfile ${_OUTPUTS_PATH}/rtl2final.lec.log > ${_OUTPUTS_PATH}/rtl2final.lec.do
```

Close Genus and run the generated LEC script in Conformal:

```
lec -xl -nogui -dofile ./<path of do file>/<name of do file>.do
```

If the designs are functionally equivalent, the tool will report "PASS":

```
--------------------------------------------------------------------------------
6. Compare Results:                                                        PASS
     Number of EQ compare points:                              60
     Number of NON-EQ compare points:                          0
     Number of Aborted compare points:                         0
     Number of Uncompared compare points :                     0
================================================================================
```

> Now, introduce an error in the structural Verilog netlist and repeat the LEC. You will observe that the check does not pass.





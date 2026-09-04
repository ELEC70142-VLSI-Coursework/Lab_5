##### Imperial College London, Department of Electrical & Electronic Engineering


#### ELEC70142 Digital VLSI Design

### Lab 5 – Scan Chain Insertion, ATPG and Logic Equivalence Check

##### *Peter Cheung, v2.0 – 4 September 2026*

---

### Objectives

By the end of this lab, you will be able to:
- Implement Design for Testability (DFT)
- Generate test patterns with an ATPG tool
- Perform Logic Equivalence Check (LEC)

---


### Task 1 – Scan Chain Insertion

As integrated circuits become more complex and costly to manufacture, it is crucial to
incorporate testability features early in the design process. Design for Testability (DFT)
techniques enhance fault coverage and reduce test time and cost by making internal signals
easier to control and observe. One widely used DFT method is scan chain insertion, which
links sequential elements into shift registers. This allows test vectors to be serially
loaded, captured, and read back, enabling effective fault detection and diagnosis.

Fusion Compiler contains the TestMAX DFT engine, so scan insertion happens in the same
tool you used for synthesis in Lab 1. In this lab, you will insert scan chains into a synthesized design, create the necessary test ports and control signals.  

#### Step 1 – Synthesize the Design

For this lab you will synthesize a synchronous FIFO with a ready/valid interface. The
SystemVerilog is in `src/FIFO.sv`.

DFT can be applied during synthesis or added to a synthesized netlist. This lab does the
second, so start by synthesizing the RTL on its own:

```bash
fc_shell -f scripts/syn.tcl
```

#### Step 2 – Insert Scan Chains

Run the DFT flow. It reads the synthesised netlist back into a fresh library, so scan is
added to a finished netlist rather than folded into synthesis:

```bash
fc_shell -f scripts/dft.tcl
```

**The rest of this step is what that script does, in order.** Read it alongside
`scripts/dft.tcl`.

It configures the scan style and creates four test ports:
- `scan_en`: enables scan mode by selecting the scan input at every register.
- `scan_testmode`: forces the design into test mode. This design resets synchronously, has
  an ungated clock and no tristate logic, so there is nothing to hold and the port stays
  unconnected.
- `scan_di` and `scan_do`: serial input and output of the chain.

```tcl
set_dft_configuration -scan enable
set_scan_configuration -style multiplexed_flip_flop -chain_count 1

create_port scan_en       -direction in
create_port scan_testmode -direction in
create_port scan_di       -direction in
create_port scan_do       -direction out

set_dft_signal -view spec -type ScanEnable  -port scan_en       -active_state 1
set_dft_signal -view spec -type TestMode    -port scan_testmode -active_state 1
set_dft_signal -view spec -type ScanDataIn  -port scan_di
set_dft_signal -view spec -type ScanDataOut -port scan_do
```

By default the design clock is used as the test clock. `-view existing_dft` says the port
is already in the design rather than something to create:

```tcl
set_dft_signal -view existing_dft -type ScanClock -port clk -timing {45 55}
```

It then builds the shift and capture procedure, and checks every register can be reached
through it:

```tcl
create_test_protocol
dft_drc
```

The chain is previewed before it is committed to:

```tcl
preview_dft
insert_dft
```

`preview_dft` reports the chain without modifying the design:

```
Number of chains: 1

Scan chain '1' (scan_di --> scan_do) contains 525 cells:

  count_reg[0]              (clk, 45, rising)
  count_reg[1]
  ...
```

Finally the rule check is re-run now the chain exists, and the results exported:

```tcl
dft_drc

write_verilog outputs/FIFO_dft.v
write_sdc -output outputs/FIFO_dft.sdc
write_test_protocol -test_mode Internal_scan -output outputs/FIFO_dft.spf
```

When the script finishes, compare `reports/dft_drc_pre.rpt` with
`reports/dft_drc_post.rpt`, and read `reports/dft_preview.rpt`.


#### Step 3 – Inspect and Compare Results

Open `outputs/FIFO_dft.v` and look at the module's port list.

> Can you identify the new ports added by the DFT flow? During simulation, ensure these
> ports are driven in your testbench to avoid simulation errors.

Then compare the two report sets:

```bash
diff reports/synth_area.rpt reports/dft_area.rpt
diff reports/synth_qor.rpt  reports/dft_qor.rpt
```

#### Step 4 – Generate Test Patterns

`scripts/dft.tcl` wrote `outputs/FIFO_dft.spf`, a STIL protocol file describing how to
shift and capture:

```tcl
write_test_protocol -test_mode Internal_scan -output outputs/FIFO_dft.spf
```

TestMAX ATPG reads the protocol along with the netlist:

```bash
tmax -shell -nostartup scripts/atpg.tcl
```

The script builds the model, runs DRC against the protocol, adds a stuck-at fault list,
and generates patterns. It leaves you at a `TEST>` prompt with the fault list still
loaded, so you can explore:

```
report_summaries
```

#### Step 5 – Simulate the Patterns

Generating patterns is not the same as knowing they work. To check them you need a
testbench, and getting one takes an extra step.

`write_patterns` in TestMAX writes tester formats only - STIL, WGL, TDL and so on. The supported verilog route is the
*unified STIL flow*: write the patterns once as STIL, then translate them.

```bash
make patterns
```

which runs:

```bash
stil2verilog outputs/FIFO_patterns.stil outputs/FIFO_patterns \
    -v_file outputs/FIFO_dft.v \
    -v_lib $SYN_SIM_MODELS \
    -serial -sim_script vcs
```

Then simulate:

```bash
make sim-atpg
```

A passing run reports no mismatches.

---

### Task 2 – Logic Equivalence Check (LEC)

Logic Equivalence Check (LEC) is a vital verification step to ensure functional
correctness after design transformations such as scan chain insertion or optimization. By
comparing the original RTL with the modified netlist, LEC confirms that no unintended
changes have been introduced, guaranteeing that the synthesized design remains
functionally identical to the source.

The Synopsys tool for this is Formality:

```bash
fm_shell -f scripts/lec.tcl
```

The script compares `src/FIFO.sv` against `outputs/FIFO_dft.v` - the original RTL against
the netlist after both synthesis and scan insertion.

If the designs are equivalent, the tool reports:

```
********************************* Verification Results *********************************
Verification SUCCEEDED
----------------------
 Reference design: r:/WORK/FIFO
 Implementation design: i:/WORK/FIFO
 559 Passing compare points
----------------------------------------------------------------------------------------
Matched Compare Points     BBPin    Loop   BBNet     Cut    Port     DFF     LAT   TOTAL
----------------------------------------------------------------------------------------
Passing (equivalent)           0       0       0       0      34     525       0     559
Failing (not equivalent)       0       0       0       0       0       0       0       0
****************************************************************************************
```

>Now, introduce an error in the structural Verilog netlist and repeat the LEC. You will observe that the check does not pass.

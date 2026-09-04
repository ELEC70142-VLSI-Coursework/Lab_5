####################################################################
#
#  Pattern simulation and waveform viewing.
#  Synthesis, DFT, LEC and ATPG are run in the tools, not from here.
#
#  Author:   Sne Samal
#  Version:  1.1
#  Date:     2026-09-04
#
####################################################################

DESIGN := FIFO

OUT  := outputs
SIM  := sim
LOGS := logs

# -full64        the 32-bit binary is broken on this server
# -timescale=    the netlist declares none and VCS rejects a mix
# +neg_tchk      honour negative setup and hold from the library
# +error+30      the default of 10 hides whole categories of failure
# -kdb           lets Verdi show source and schematic, not just waves
VCS := vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb \
       +neg_tchk +error+30

NETLIST := $(OUT)/$(DESIGN)_dft.v
STIL    := $(OUT)/$(DESIGN)_patterns.stil

# stil2verilog takes a base name and appends its own suffixes:
# <base>.v the testbench, <base>.dat the test data it reads at runtime,
# <base>_vcs.sh a reference run script.
TB_BASE   := $(OUT)/$(DESIGN)_patterns
TESTBENCH := $(TB_BASE).v

.DEFAULT_GOAL := help
.PHONY: patterns sim-atpg waves waves-verdi clean help

## patterns: translate the ATPG STIL into a Verilog testbench
# tools/stil2verilog wraps the shipped binary, which needs a libstdc++
# this OS does not have.
#
# -serial shifts the chain a bit at a time, as the hardware does.
# Parallel load force-writes the scan cells and so proves nothing about
# whether the chain is stitched correctly.
#
# No -tb_format: the help lists v95, v01 and sv, but this build rejects
# anything but the v95 default with E-021. VCS reads it fine.
#
# W-006 "no scan chains found" in the log is expected. It means a
# parallel-load testbench cannot be built, and we asked for serial.
patterns: $(TESTBENCH)

$(TESTBENCH): $(STIL) $(NETLIST)
	mkdir -p $(LOGS)
	stil2verilog $(STIL) $(TB_BASE) \
	  -v_file $(NETLIST) \
	  -v_lib $$SYN_SIM_MODELS \
	  -serial -sim_script vcs \
	  -log $(LOGS)/stil2verilog.log -replace
	@test -f $(TESTBENCH) || \
	  { echo "stil2verilog exited cleanly but wrote no $(TESTBENCH)."; \
	    echo "See $(LOGS)/stil2verilog.log for the names it did write."; \
	    exit 1; }

## sim-atpg: simulate the ATPG patterns against the scan netlist
# A passing run reports no miscompares in $(LOGS)/sim_atpg.log.
sim-atpg: $(TESTBENCH)
	mkdir -p $(SIM) $(LOGS)
	$(VCS) $$SYN_SIM_MODELS $(NETLIST) $(TESTBENCH) \
	  -o $(SIM)/simv_atpg -Mdir=$(SIM)/csrc_atpg -l $(LOGS)/vcs_atpg.log
	./$(SIM)/simv_atpg -l $(LOGS)/sim_atpg.log

####################################################################
# Waveforms
####################################################################
# The TestMAX testbench does not dump by default. Add +vcs+dumpvars or
# a $$dumpfile call to it to watch the chain shift.

KIND ?= atpg

## waves: view waveforms in GTKWave
waves:
	gtkwave $(SIM)/$(KIND).vcd

# Verdi reads its own FSDB format, so the VCD is converted once.
$(SIM)/%.fsdb: $(SIM)/%.vcd
	vcd2fsdb $< -o $@

## waves-verdi: the same waveforms in Verdi, which also shows the design
# -dbdir is the database VCS wrote next to simv. Without it Verdi shows
# waveforms and nothing to relate them to.
waves-verdi: $(SIM)/$(KIND).fsdb
	verdi -nologo -ssf $(SIM)/$(KIND).fsdb \
	  $$(test -d $(SIM)/simv_$(KIND).daidir/kdb && echo "-dbdir $(SIM)/simv_$(KIND).daidir/kdb")

## clean: remove everything the flow and the simulator generated
clean:
	rm -rf work outputs reports logs sim
	rm -rf *.svf fc_command.log fc_output.txt HDL_LIBRARIES
	rm -rf fm_shell_command.log FM_WORK *_formal_equivalence formality.log
	rm -rf tmax_command.log
	rm -rf *.dat run_vcs* vcs.sim* maxtb* stil2verilog.log
	rm -rf csrc simv simv.daidir ucli.key *.vcd *.fsdb
	rm -rf verdiLog novas* .inter.vpd DVEfiles

## help: list the targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  make /' | \
	  awk -F': ' '{ printf "%-20s %s\n", $$1, $$2 }'
	@printf "%-20s %s\n" "    KIND" "waveform set to open, default $(KIND)"
	@echo ""
	@echo "  The flow itself runs in the tools, in this order:"
	@echo "    fc_shell -f scripts/syn.tcl"
	@echo "    fc_shell -f scripts/dft.tcl"
	@echo "    fm_shell -f scripts/lec.tcl"
	@echo "    tmax -shell -nostartup scripts/atpg.tcl"

# Build/simulation/coverage workflow for the computa UVM testbench. Run
# from uvm/tb. See the README's "UVM Verification Environment" section
# for full usage; this is just a quick reference.
#
#   make sim TEST=<name>              run one test (default addi_test)
#   make simvision                    run the current run.f test with SimVision attached
#   make coverage-report TEST=<name>  text coverage report for one test
#   make coverage-merge               merge tests listed in imc_merge.tcl
#   make coverage-gui [DB=<path>]     open a snapshot/merge in the IMC GUI
#   make install-spike                one-time: build Spike from source
#   make clean                        remove generated artifacts

XRUN        := xrun
# Path to this project's Cadence vmanager install; likely different on
# another machine. Override with e.g. `make coverage-report IMC=/path/to/imc`.
IMC         ?= /tools/software/cadence/vmanager/latest/tools.lnx86/vmgr/bin/imc
VALID_TESTS := base_test addi_test addi_extensive_test register_test non_shift_immediate_test shift_immediate_test store_test

TEST ?= store_test
DB   ?= ./cov_work/scope/$(TEST)

.PHONY: help
help:
	@echo "Targets: sim  simvision  coverage-report  coverage-merge  coverage-gui  install-spike  clean"
	@echo "Valid TEST names: $(VALID_TESTS)"
	@echo "See the comment header in this Makefile for full usage/examples."

.PHONY: check-test
check-test:
	@echo "$(VALID_TESTS)" | grep -qw "$(TEST)" || \
		{ echo "error: TEST=$(TEST) not recognized. Valid: $(VALID_TESTS)"; exit 1; }

.PHONY: sim
sim: check-test
	sed -i -E 's|^\+UVM_TESTNAME=|//+UVM_TESTNAME=|' run.f
	sed -i -E 's|^//\+UVM_TESTNAME=$(TEST)\r?$$|+UVM_TESTNAME=$(TEST)|' run.f
	sed -i -E 's|^-covtest .*|-covtest $(TEST)|' run.f
	$(XRUN) -uvm -uvmnocdnsextra -f run.f

.PHONY: simvision
simvision:
	$(XRUN) -f run.f -gui -access rwc

.PHONY: coverage-report
coverage-report: check-test
	sed -i -E 's|^set TEST ".*"|set TEST "$(TEST)"|' imc_report.tcl
	$(IMC) -exec imc_report.tcl
	@echo "Report: ./$(TEST)_report.txt"

.PHONY: coverage-merge
coverage-merge:
	$(IMC) -exec imc_merge.tcl
	@echo "Report: ./cov_work/cov_merged_report.txt"

.PHONY: coverage-gui
coverage-gui:
	$(IMC) -load $(DB) &

.PHONY: install-spike
install-spike:
	bash ../../scripts/install_spike.sh

.PHONY: clean
clean:
	rm -rf cov_work xcelium.d *.shm .simvision
	rm -f prog_gen.hex spike_trace.txt xrun.log xrun.history xrun.key imc.key
	rm -f *_report.txt

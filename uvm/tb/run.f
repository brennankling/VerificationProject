// To use: cd into the tb
// setenv UVMHOME `ncroot`/tools/methodology/UVM/CDNS-1.1d
// xrun -uvm -uvmnocdnsextra -f run.f

// To run simvision with xrun:
// xrun -f run.f -gui -access rwc

// If simvision quits unexpectedly:
// check runing processes
// ps aux | grep bklingenberg6 | grep -iE "xrun|simvision|xmsim"
// for each process:
// kill <pid>


// 64 bit option required for AWS labs
-64

-uvmhome $UVMHOME
-timescale 1ns/1ns
// include directories
-incdir ../sv

// options
+UVM_VERBOSITY=UVM_FULL 

// (un)comment lines to select test. Keep -covtest below in sync with
// whichever UVM_TESTNAME is active. Each distinct -covtest name gets
// its own coverage snapshot under cov_work/scope/<name>, so switching
// tests without updating it will silently mix that run's coverage into
// the previous test's snapshot instead of keeping them separate.
//+UVM_TESTNAME=base_test
//+UVM_TESTNAME=addi_test
//+UVM_TESTNAME=addi_extensive_test
//+UVM_TESTNAME=register_test
//+UVM_TESTNAME=non_shift_immediate_test
//+UVM_TESTNAME=shift_immediate_test
//+UVM_TESTNAME=store_test
//+UVM_TESTNAME=load_test
+UVM_TESTNAME=lui_test

//+SVSEED=random

// Code coverage (block/expr/toggle/fsm on the RTL) plus functional
// coverage (computa_coverage.sv's covergroups), scoped to this test by
// name. -covoverwrite resets this test's own snapshot each run instead
// of accumulating across reruns of the same test -- drop it if you want
// the opposite. See uvm/tb/imc_merge.tcl for merging multiple tests'
// coverage together once you've got more than one snapshot.

// /tools/software/cadence/vmanager/latest/tools.lnx86/vmgr/bin/imc -load ./cov_work/scope/<name of the covtest (doesnt have to match anything in run.f)> &
// to see merged test results run:
// /tools/software/cadence/vmanager/latest/tools.lnx86/vmgr/bin/imc -load ./cov_work/cov_merged &
-coverage all
-covtest lui_test
-covoverwrite

// compile files
../../rtl/pkg/brv32_pkg.sv
../../rtl/alu.sv
../../rtl/reg_file.sv
../../rtl/fetch_stage.sv
../../rtl/decode_stage.sv
../../rtl/execute_stage.sv
../../rtl/memory_stage.sv
../../rtl/writeback_stage.sv
../../rtl/chip_top.sv
../sv/computa_pkg.sv
../sv/computa_if.sv
tb_top.sv
clkgen.sv
hw_top.sv
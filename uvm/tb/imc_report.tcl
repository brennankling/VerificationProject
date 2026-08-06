# Batch (no GUI) coverage report for a single -covtest snapshot. Run from
# uvm/tb
#
#   /tools/software/cadence/vmanager/latest/tools.lnx86/vmgr/bin/imc -exec imc_report.tcl
#

# Edit TEST below to match whichever -covtest name you want a report for.

set TEST "shift_immediate_test"

if {[catch {
    load -run ./cov_work/scope/${TEST}
    # -both: without an explicit -covered/-uncovered/-both/-all, report
    # defaults to "uncovered only". A coverpoint sitting at 100% (all its
    # bins hit) gets omitted from the tree entirely instead of just not
    # flagged, which looks like a real coverage gap unless -both is set.
    report -detail -both -out ./${TEST}_report.txt
} err]} {
    puts "REPORT FAILED: $err"
    exit 1
}

puts "Report for $TEST -> ./${TEST}_report.txt"
exit

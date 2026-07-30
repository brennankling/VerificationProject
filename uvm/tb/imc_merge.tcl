# Merges per-test coverage snapshots (each produced by an xrun run with
# -covtest <name>, per run.f) into one merged model and writes a summary
# report. Run from uvm/tb: imc resolves paths relative to the shell's
# CWD, and running from the wrong directory produces confusing
# CNTRDDR/INVDM errors.
#
#   /tools/software/cadence/vmanager/latest/tools.lnx86/vmgr/bin/imc -exec imc_merge.tcl
#
# (NOT the xcelium/.../tools/bin/launch_rmi_imc.sh wrapper, that's an
# unrelated tool despite the name; imc actually lives under the separate
# vmanager install tree.)
#
# Edit TESTS below to match whatever -covtest names you've actually run.

set TESTS {addi_test register_test}

set snapshots {}
foreach t $TESTS {
    lappend snapshots ./cov_work/scope/$t
}

# No -initial_model: that flag expects an actual run name/path, not a
# strategy keyword. "union" (combining what every run hit) is merge's
# default behavior anyway, which is what we want here.
if {[catch {merge -out ./cov_merged -overwrite $snapshots} err]} {
    puts "MERGE FAILED: $err"
    exit 1
}

# report's -detail/-summary/-list are mutually exclusive (not
# combinable modifiers); -detail for the fuller per-coverpoint/per-bin
# breakdown. load as its own step first, matching imc_report.tcl.
if {[catch {
    load -run ./cov_work/cov_merged
    # -both: see imc_report.tcl. Without it, fully-covered coverpoints
    # get omitted from the tree entirely instead of just not flagged.
    report -detail -both -out ./cov_work/cov_merged_report.txt
} err]} {
    puts "REPORT FAILED: $err"
    exit 1
}

puts "Merged [llength $TESTS] test(s) -> ./cov_work/cov_merged, report -> ./cov_work/cov_merged_report.txt"
exit

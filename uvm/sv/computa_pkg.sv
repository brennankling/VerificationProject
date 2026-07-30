package computa_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import brv32_pkg::*;
    typedef uvm_config_db#(virtual computa_if) computa_vif_config; // convenience typedef

    `include "computa_instruction.sv"
    `include "computa_retire_txn.sv"
    `include "computa_monitor.sv"
    `include "computa_scoreboard.sv"
    `include "computa_coverage.sv"
    `include "computa_sequencer.sv"
    `include "computa_seqs.sv"
    `include "computa_driver.sv"
    `include "computa_agent.sv"
    `include "computa_env.sv"
    
endpackage
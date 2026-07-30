module tb_top;
  
  import uvm_pkg::*;

  `include "uvm_macros.svh"

  import computa_pkg::*;

  `include "cpu_tb.sv"
  `include "cpu_test_lib.sv"

  initial begin
    // Scoped at computa_env level so the scoreboard also picks up the vif.
    computa_vif_config::set(null, "uvm_test_top.tb.computa.*", "vif", hw_top.in0);
    run_test();
  end

endmodule : tb_top

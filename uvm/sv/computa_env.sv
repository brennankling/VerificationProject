class computa_env extends uvm_env;

  computa_agent      agent;
  computa_scoreboard scoreboard;
  computa_coverage   coverage;

  `uvm_component_utils(computa_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = computa_agent::type_id::create("agent", this);
    scoreboard = computa_scoreboard::type_id::create("scoreboard", this);
    coverage   = computa_coverage::type_id::create("coverage", this);
  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    agent.monitor.ap.connect(scoreboard.actual_export);
    agent.monitor.ap.connect(coverage.analysis_export);
  endfunction : connect_phase

  function void start_of_simulation_phase(uvm_phase phase);
    `uvm_info(get_type_name(), {"start of simulation for ", get_full_name()}, UVM_HIGH)
  endfunction : start_of_simulation_phase

endclass : computa_env
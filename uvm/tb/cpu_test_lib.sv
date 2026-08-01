class base_test extends uvm_test;

  `uvm_component_utils(base_test)

  cpu_tb tb;

  // Instructions the configured program is expected to retire, the
  // single source of truth for this test. Subclasses set this
  // from their sequence's own NUM_INSTRUCTIONS parameter before calling
  // super.build_phase(), which both sizes run_phase's drain time below
  // and pushes it into config_db here, driver/monitor/scoreboard all
  // picking it up automatically
  int unsigned program_size = 1;
  time clock_period = 10ns;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    uvm_config_int::set( this, "*", "recording_detail", 1);
    // Scoped at computa_env level (not just agent.*) so the scoreboard agrees with the
    // driver/monitor on how many instructions this test expects.
    uvm_config_db#(int unsigned)::set(this, "tb.computa.*", "program_size", program_size);
    tb = cpu_tb::type_id::create("tb", this);
  endfunction : build_phase
  
  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction : end_of_elaboration_phase

  function void start_of_simulation_phase(uvm_phase phase);
    `uvm_info(get_type_name(), {"start of simulation for ", get_full_name()}, UVM_HIGH);
  endfunction : start_of_simulation_phase

  function void check_phase(uvm_phase phase);
    // configuration checker
    check_config_usage();
  endfunction

  // The sequence's own pre_body/post_body objection spans only generation,
  // which finishes in zero simulated time; it does not cover loading
  // imem, releasing reset, or letting the DUT run. Draining for
  // (program_size + margin) clock periods keeps the phase open long
  // enough for the whole program to retire and be observed by the
  // monitor before the test ends, sized to this test's program instead
  // of a fixed guess. Margin covers hw_top's reset-assert/release delay
  // plus settling time for the monitor's last sample.
  task run_phase(uvm_phase phase);
    uvm_objection obj = phase.get_objection();
    obj.set_drain_time(this, (program_size + 5) * clock_period);
  endtask: run_phase
  
endclass : base_test

class addi_test extends base_test;

  `uvm_component_utils(addi_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  function void build_phase(uvm_phase phase);
    computa_instruction::type_id::set_type_override(non_shift_immediate_instruction::get_type());

    program_size = addi_seq::NUM_INSTRUCTIONS;
    super.build_phase(phase);
    uvm_config_wrapper::set(this, "tb.computa.agent.sequencer.run_phase",
                                   "default_sequence",
                                   addi_seq::get_type());
  endfunction: build_phase
endclass: addi_test

class addi_extensive_test extends base_test;

  `uvm_component_utils(addi_extensive_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  function void build_phase(uvm_phase phase);
    computa_instruction::type_id::set_type_override(non_shift_immediate_instruction::get_type());

    program_size = addi_extensive_seq::NUM_INSTRUCTIONS;
    super.build_phase(phase);
    uvm_config_wrapper::set(this, "tb.computa.agent.sequencer.run_phase",
                                   "default_sequence",
                                   addi_extensive_seq::get_type());
  endfunction: build_phase
endclass: addi_extensive_test

class register_test extends base_test;

  `uvm_component_utils(register_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  function void build_phase(uvm_phase phase);

    program_size = register_seq::NUM_INSTRUCTIONS;
    super.build_phase(phase);
    uvm_config_wrapper::set(this, "tb.computa.agent.sequencer.run_phase",
                                   "default_sequence",
                                   register_seq::get_type());
  endfunction: build_phase
endclass: register_test

class non_shift_immediate_test extends base_test;

  `uvm_component_utils(non_shift_immediate_test)

  function void new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  function void build_phase(uvm_phase phase);
    program_size = non_shift_immediate_seq::NUM_INSTRUCTIONS;
    super.build_phase(phase);
    uvm_config_wrapper::set(this, "tb.computa.agent.sequencer.run_phase",
                                    "default_sequence",
                                    non_shift_immediate_seq::get_type());
  endfunction: build_phase

endclass: non_shift_immediate_test
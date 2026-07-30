class cpu_tb extends uvm_env;

  `uvm_component_utils(cpu_tb)

  computa_env computa;

  function new (string name, uvm_component parent=null);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    `uvm_info("MSG","In the build phase",UVM_HIGH)
    super.build_phase(phase);
    computa = computa_env::type_id::create("computa", this);

  endfunction : build_phase

endclass : cpu_tb

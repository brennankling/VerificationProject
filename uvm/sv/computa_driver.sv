class computa_driver extends uvm_driver #(computa_instruction);

  virtual interface computa_if vif;

  // TEMPORARY: Use number of instructions to determine how long to drive for
  // Known bug: If there are loops or jumps to previous pc values, the simulation will finish early if
  // program_size is equal to just the number of instructions in imem 
  int unsigned program_size = 8;

  // Where to write the assembled image before loading it. Same
  // %h-per-line format as sim/prog.hex
  string imem_file = "prog_gen.hex";

  // Number of instructions assembled by driver
  int num_sent;

  `uvm_component_utils_begin(computa_driver)
    `uvm_field_int(num_sent, UVM_ALL_ON)
  `uvm_component_utils_end

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void start_of_simulation_phase(uvm_phase phase);
    `uvm_info(get_type_name(), {"start of simulation for ", get_full_name()}, UVM_HIGH)
  endfunction : start_of_simulation_phase

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(int unsigned)::get(this, "", "program_size", program_size));
    void'(uvm_config_db#(string)::get(this, "", "imem_file", imem_file));
  endfunction : build_phase

  // Assembles a program from the sequencer and loads it into the
  // DUT's instruction memory. 
  // chip_top fetches from its own imem every cycle on its own, so once
  // the image is loaded the driver's job is done.
  task run_phase(uvm_phase phase);
    bit [31:0] instrs [$];
    int fd;

    for (int i = 0; i < program_size; i++) begin
      seq_item_port.get_next_item(req);
      instrs.push_back(req.instruction);
      `uvm_info(get_type_name(), $sformatf("Assembled instr[%0d]: %h", i, req.instruction), UVM_HIGH)
      num_sent++;
      seq_item_port.item_done();
    end

    fd = $fopen(imem_file, "w");
    foreach (instrs[i]) $fwrite(fd, "%h\n", instrs[i]);
    $fclose(fd);

    // Reset is held for a few cycles by hw_top's reset generator; load
    // while it's still asserted so there's margin before release.
    @(posedge vif.reset);
    vif.load_imem(imem_file);
    `uvm_info(get_type_name(), $sformatf("Loaded %0d-instruction program from %s", instrs.size(), imem_file), UVM_MEDIUM)

    // Debug: confirm the imem actually landed in the DUT
    // instance, not just that the hex file was written.
    foreach (instrs[i])
      `uvm_info(get_type_name(), $sformatf("Readback imem[%0d] = %h (wrote %h)", i, vif.read_imem(i), instrs[i]), UVM_LOW)

    @(negedge vif.reset);
    `uvm_info(get_type_name(), "Reset dropped, DUT running", UVM_MEDIUM)
  endtask : run_phase

  function void connect_phase(uvm_phase phase);
    if (!(computa_vif_config::get(this, "", "vif", vif)))
      `uvm_error("NOVIF", "vif not set")
  endfunction: connect_phase

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(), $sformatf("Report: COMPUTA driver assembled %0d instructions", num_sent), UVM_LOW)
  endfunction : report_phase
endclass : computa_driver

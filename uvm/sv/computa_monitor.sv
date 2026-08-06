class computa_monitor extends uvm_monitor;

  virtual interface computa_if vif;

  uvm_analysis_port #(computa_retire_txn) ap;

  // See computa_driver.sv
  int unsigned program_size = 8;

  // Number of instructions collected by monitor
  int num_instr_col;

  // Regfile snapshot from the previously retired instruction, used to
  // compute computa_retire_txn::changed_regs
  bit [31:0] prev_regs [32];

  `uvm_component_utils_begin(computa_monitor)
    `uvm_field_int(num_instr_col, UVM_ALL_ON)
  `uvm_component_utils_end

  function new (string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction : new

  function void start_of_simulation_phase(uvm_phase phase);
    `uvm_info(get_type_name(), {"start of simulation for ", get_full_name()}, UVM_HIGH)
  endfunction : start_of_simulation_phase

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(int unsigned)::get(this, "", "program_size", program_size));
  endfunction: build_phase

  task run_phase(uvm_phase phase);
    computa_retire_txn txn;

    // Reset is asserted from simulation start; wait for the rising
    // edge hw_top drives a few cycles in, then the falling edge that
    // releases it. See hw_top.sv's reset generator
    @(posedge vif.reset);
    @(negedge vif.reset);
    `uvm_info(get_type_name(), "Detected Reset Done", UVM_MEDIUM)

    prev_regs = '{default: '0};

    repeat (program_size) begin
      // Sample pc right at the retiring edge, before the PC/regfile
      // flops' non-blocking updates land in the NBA region. This is
      // the PC of the instruction retiring this cycle, not the next one.
      @(posedge vif.clock);
      txn = computa_retire_txn::type_id::create("txn", this);
      txn.pc          = vif.pc;
      txn.instruction = vif.instruction;

      txn.mem_valid = vif.mem_read || vif.mem_write;
      if (txn.mem_valid) begin
        txn.mem_addr = vif.mem_addr;
        txn.mem_data = vif.mem_write ? vif.mem_wr_data : vif.mem_rd_data;
      end

      void'(begin_tr(txn, "computa_monitor_retire"));

      // Move past the edge so regs/mem reflect this instruction's
      // writeback, once the NBA updates have settled.
      @(negedge vif.clock);
      txn.regs = vif.regs;

      // Debug: dumps every register as plain text to the log
      begin
        string dbg;
        dbg = "";
        for (int i = 0; i < 32; i++)
          dbg = {dbg, $sformatf(" x%0d=%0h", i, txn.regs[i])};
        `uvm_info(get_type_name(), {"Full regfile: ", dbg}, UVM_LOW)
      end

      for (int i = 0; i < 32; i++) begin
        if (txn.regs[i] !== prev_regs[i]) txn.changed_regs.push_back(i);
      end
      prev_regs = txn.regs;

    // Looks like there was a bug where changes to mem at the following pc were being recorded
    /*
      txn.mem_valid = vif.mem_read || vif.mem_write;
      if (txn.mem_valid) begin
        txn.mem_addr = vif.mem_addr;
        txn.mem_data = vif.mem_write ? vif.mem_wr_data : vif.mem_rd_data;
      end
    */

      end_tr(txn);

      `uvm_info(get_type_name(), $sformatf("txn.sprint():\n%s", txn.sprint()), UVM_LOW)
      

      ap.write(txn);
      num_instr_col++;
      `uvm_info(get_type_name(), $sformatf("Retired: %s", txn.convert2string()), UVM_HIGH)
    end
  endtask : run_phase

  function void connect_phase(uvm_phase phase);
    if (!(computa_vif_config::get(this, "", "vif", vif)))
      `uvm_error("NOVIF", {"vif not set for: ", get_full_name(), ".vif"})
  endfunction: connect_phase

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(), $sformatf("Report: Computa Monitor Collected %0d Instructions", num_instr_col), UVM_LOW)
  endfunction : report_phase

endclass: computa_monitor

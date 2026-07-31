// Checks every computa_retire_txn the monitor publishes against Spike
// acting as the golden reference model, per the comparison
// computa_retire_txn.sv already documents as its purpose.
//
// Once the driver has loaded a program and reset drops, spike_ref.py is run once
// against that same program file, and its Spike commit
// log is parsed into expected_q. Actual transactions arriving from the
// monitor are then compared against expected_q in order as write() is
// called.
class computa_scoreboard extends uvm_scoreboard;

  virtual interface computa_if vif;

  uvm_analysis_imp #(computa_retire_txn, computa_scoreboard) actual_export;

  // See computa_sriver.sv
  int unsigned program_size = 8;
  string       imem_file    = "prog_gen.hex";

  // Both relative to the tb's CWD, same as imem_file (run.f/README expect
  // xrun to be invoked from uvm/tb).
  string spike_ref_script = "spike_ref.py";
  string trace_file       = "spike_trace.txt";

  computa_retire_txn expected_q[$];

  int unsigned num_checked;
  int unsigned num_pass;
  int unsigned num_fail;

  `uvm_component_utils_begin(computa_scoreboard)
    `uvm_field_int(num_checked, UVM_ALL_ON)
    `uvm_field_int(num_pass,    UVM_ALL_ON)
    `uvm_field_int(num_fail,    UVM_ALL_ON)
  `uvm_component_utils_end

  function new(string name, uvm_component parent);
    super.new(name, parent);
    actual_export = new("actual_export", this);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(int unsigned)::get(this, "", "program_size", program_size));
    void'(uvm_config_db#(string)::get(this, "", "imem_file", imem_file));
  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    if (!(computa_vif_config::get(this, "", "vif", vif)))
      `uvm_error("NOVIF", {"vif not set for: ", get_full_name(), ".vif"})
  endfunction: connect_phase

  // Waits for the same reset-drop edge the monitor syncs to, by which
  // point computa_driver.sv has already loaded the imem. Runs
  // Spike on that program and parses its commit log into expected_q,
  // drained by write() as actual retirements arrive.
  task run_phase(uvm_phase phase);
    int      fd;
    int      code;
    string   cmd;
    bit [31:0] pc, instr, rd_val, mem_addr, mem_data;
    int      has_rd, rd_idx, mem_valid;
    int      n;
    computa_retire_txn exp;

    @(posedge vif.reset);
    @(negedge vif.reset);

    // env -u LD_LIBRARY_PATH: Xcelium's launch environment points
    // LD_LIBRARY_PATH at Cadence's bundled shared libraries. Spike's
    //  libs are found via the rpath baked in at build time (scripts/install_spike.sh), not
    // LD_LIBRARY_PATH.
    cmd = $sformatf("env -u LD_LIBRARY_PATH python3 %s --hex %s --n %0d --out %s",
                     spike_ref_script, imem_file, program_size, trace_file);
    `uvm_info(get_type_name(), {"Running reference model: ", cmd}, UVM_MEDIUM)
    code = $system(cmd);
    if (code != 0)
      `uvm_error(get_type_name(), $sformatf("spike_ref.py exited with status %0d", code))

    fd = $fopen(trace_file, "r");
    if (fd == 0)
      `uvm_fatal(get_type_name(), {"Could not open reference trace: ", trace_file})

    forever begin
      n = $fscanf(fd, "%h %h %d %d %h %d %h %h\n",
                  pc, instr, has_rd, rd_idx, rd_val,
                  mem_valid, mem_addr, mem_data);
      if (n != 8) break;

      exp = computa_retire_txn::type_id::create("exp");
      exp.pc          = pc;
      exp.instruction = instr;
      exp.regs        = '{default: '0};
      if (has_rd) begin
        exp.changed_regs.push_back(rd_idx);
        exp.regs[rd_idx] = rd_val;
      end
      exp.mem_valid = (mem_valid != 0);
      exp.mem_addr  = mem_addr;
      exp.mem_data  = mem_data;

      expected_q.push_back(exp);
    end
    $fclose(fd);

    `uvm_info(get_type_name(),
      $sformatf("Loaded %0d expected transaction(s) from reference model", expected_q.size()),
      UVM_MEDIUM)
  endtask : run_phase

  // Called by the monitor's analysis port for every retired instruction.
  function void write(computa_retire_txn actual);
    computa_retire_txn exp;
    bit match;

    num_checked++;

    if (expected_q.size() == 0) begin
      `uvm_error(get_type_name(),
        $sformatf("DUT retired an instruction with no matching reference transaction left: %s",
                   actual.convert2string()))
      num_fail++;
      return;
    end

    exp = expected_q.pop_front();
    match = 1;

    if (exp.pc !== actual.pc) match = 0;
    if (exp.instruction !== actual.instruction) match = 0;

    if (exp.changed_regs.size() != actual.changed_regs.size()) begin
      match = 0;
    end else begin
      foreach (exp.changed_regs[i]) begin
        int idx = exp.changed_regs[i];
        if (actual.changed_regs[i] != idx || exp.regs[idx] !== actual.regs[idx])
          match = 0;
      end
    end

    if (exp.mem_valid != actual.mem_valid) begin
      match = 0;
    end else if (exp.mem_valid &&
                 (exp.mem_addr !== actual.mem_addr || exp.mem_data !== actual.mem_data)) begin
      match = 0;
    end

    if (match) begin
      num_pass++;
      `uvm_info(get_type_name(), $sformatf("MATCH: %s", actual.convert2string()), UVM_LOW)
    end else begin
      num_fail++;
      `uvm_error(get_type_name(),
        $sformatf("MISMATCH\n  expected: %s\n  actual:   %s",
                   exp.convert2string(), actual.convert2string()))
    end
  endfunction : write

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("Report: checked=%0d pass=%0d fail=%0d expected_remaining=%0d",
                 num_checked, num_pass, num_fail, expected_q.size()),
      UVM_LOW)
    if (num_fail != 0)
      `uvm_error(get_type_name(),
        $sformatf("%0d instruction(s) mismatched against the Spike reference model", num_fail))
    if (expected_q.size() != 0)
      `uvm_error(get_type_name(),
        $sformatf("%0d expected instruction(s) never retired on the DUT", expected_q.size()))
  endfunction : report_phase

endclass : computa_scoreboard

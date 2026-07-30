class computa_base_seq extends uvm_sequence #(computa_instruction);
  
  `uvm_object_utils(computa_base_seq)

  function new(string name="computa_base_seq");
    super.new(name);
  endfunction

  task pre_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      // in UVM1.2, get starting phase from method
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif
    if (phase != null) begin
      phase.raise_objection(this, get_type_name());
      `uvm_info(get_type_name(), "raise objection", UVM_MEDIUM)
    end
  endtask : pre_body

  task post_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      // in UVM1.2, get starting phase from method
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif
    if (phase != null) begin
      phase.drop_objection(this, get_type_name());
      `uvm_info(get_type_name(), "drop objection", UVM_MEDIUM)
    end
  endtask : post_body

endclass : computa_base_seq


// ADDI
// Fully Randomized
class addi_seq extends computa_base_seq;
  `uvm_object_utils(addi_seq)

  // How many computa_instruction items body() below generates. The test
  // class reads this (addi_seq::NUM_INSTRUCTIONS) instead of hardcoding
  // the count separately, so program_size can't drift out of sync with
  // what this sequence actually produces. Keep it equal to however many
  // finish_item() calls body() makes.
  parameter int unsigned NUM_INSTRUCTIONS = 1;

  function new (string name = "addi_seq");
    super.new(name);
  endfunction: new

  task body();
    non_shift_immediate_instruction item;
    item =
      non_shift_immediate_instruction::type_id::create("item");
    `uvm_info(get_type_name(), "Calling addi_seq", UVM_LOW)
    start_item(item);
    if (!item.randomize() with { alu_op == ALU_ADD; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);
  endtask: body
endclass: addi_seq

// ADDI
// program_size = 103 (3 directed corner cases + 100 randomized; keep
// NUM_INSTRUCTIONS equal to that total if body() below changes)
class addi_extensive_seq extends computa_base_seq;
  `uvm_object_utils(addi_extensive_seq)

  parameter int unsigned NUM_INSTRUCTIONS = 103;

  function new (string name = "addi_extensive_seq");
    super.new(name);
  endfunction: new

  task body();
    non_shift_immediate_instruction item;
    `uvm_info(get_type_name(), "Calling addi_extensive_seq", UVM_LOW)

    // Directed corner cases
    item = non_shift_immediate_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { alu_op == ALU_ADD; rd == 0; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    item = non_shift_immediate_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { alu_op == ALU_ADD; rs1 == 0; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    item = non_shift_immediate_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { alu_op == ALU_ADD; imm == 0; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    // Randomized stress
    repeat (100) begin
        item = non_shift_immediate_instruction::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { alu_op == ALU_ADD; })
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(item);
    end
  endtask: body
endclass: addi_extensive_seq

// R-type ALU ops: ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND
// program_size = 222 (30 register preload + 10 op-coverage + 70 operand
// corners [7 cases x 10 ops, each op gets its own pass since e.g. SUB
// with rs1==rs2 and XOR with rs1==rs2 both reduce to "should give 0" but
// exercise completely different logic] + 12 shift-amount setup/op pairs +
// 100 randomized; keep NUM_INSTRUCTIONS equal to that total if body()
// below changes)
class register_seq extends computa_base_seq;
  `uvm_object_utils(register_seq)

  parameter int unsigned NUM_INSTRUCTIONS = 222;

  // Scratch register used to stage a known value ahead of the
  // shift-amount corner cases below.
  localparam bit [4:0] SHAMT_SCRATCH = 5'd31;

  function new (string name = "register_seq");
    super.new(name);
  endfunction: new

  task body();
    register_instruction            item;
    non_shift_immediate_instruction setup;
    alu_op_t ops[10] = '{ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
                          ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND};
    alu_op_t shift_ops[3] = '{ALU_SLL, ALU_SRL, ALU_SRA};

    `uvm_info(get_type_name(), "Calling register_seq", UVM_LOW)

    // Preload x1..x30 with varied, non-zero signed values before anything
    // else runs. Straight out of reset every GPR is 0 (reg_file.sv), so
    // without this, most of the instructions below would just be
    // operating on 0/0, exercising decode/control, but not the ALU's
    // actual data path across real operand diversity (sign extension,
    // negatives, near-range values). x0 stays hardwired zero; x31 is
    // reserved as SHAMT_SCRATCH and gets (re)loaded down in the
    // shift-amount section instead of here.
    for (int r = 1; r <= 30; r++) begin
      setup = non_shift_immediate_instruction::type_id::create("setup");
      start_item(setup);
      if (!setup.randomize() with { alu_op == ALU_ADD; rs1 == 0; rd == r; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(setup);
    end

    // One directed instance of every R-type op, operands otherwise free.
    // Guarantees full opcode/funct3/funct7 coverage regardless of what
    // the randomized block at the bottom happens to hit.
    foreach (ops[i]) begin
      item = register_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);
    end

    // Operand corner cases: reg_file.sv special-cases x0, and a
    // single-cycle datapath reading rs1/rs2 combinationally the same
    // cycle it commits rd deserves explicit rd==rs1/rd==rs2 aliasing
    // checks too. Run all 7 corner cases against every op rather than
    // spreading one case per op: e.g. SUB with rs1==rs2 and XOR with
    // rs1==rs2 both reduce to "should give 0" architecturally, but
    // exercise completely different logic (a subtractor vs. an
    // XOR-cancel), so a bug specific to one wouldn't show up testing
    // only the other.
    foreach (ops[i]) begin
      item = register_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; rd == 0; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = register_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; rs1 == 0; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = register_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; rs2 == 0; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = register_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; rs1 == rs2; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = register_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; rd == rs1; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = register_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; rd == rs2; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = register_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; rd == rs1; rs1 == rs2; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);
    end

    // Shift-amount corner cases: rs2's *value*, not its index, selects
    // the shift amount, so a setup ADDI stages a known value (0, then
    // the max 31) into a scratch register before referencing it as rs2.
    foreach (shift_ops[i]) begin
      bit [11:0] shamt_vals[2] = '{12'd0, 12'd31};
      foreach (shamt_vals[j]) begin
        setup = non_shift_immediate_instruction::type_id::create("setup");
        start_item(setup);
        if (!setup.randomize() with {
              alu_op == ALU_ADD; rs1 == 0; rd == SHAMT_SCRATCH; imm == shamt_vals[j];
            })
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(setup);

        item = register_instruction::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { alu_op == shift_ops[i]; rs2 == SHAMT_SCRATCH; })
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(item);
      end
    end

    // Randomized stress
    repeat (100) begin
      item = register_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize())
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);
    end
  endtask: body
endclass: register_seq
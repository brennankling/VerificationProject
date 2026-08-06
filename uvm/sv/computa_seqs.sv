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
// program_size = 103 (3 directed corner cases + 100 randomized
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
// corners [7 cases x 10 ops] + 12 shift-amount setup/op pairs +
// 100 randomized
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
    // else runs. x0 stays hardwired zero; x31 is
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

    // Run all 7 corner cases against every op
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

    // Shift-amount corner cases: rs2's value selects
    // the shift amount, so a setup ADDI stages a known value (0 through
    // the max 31) into a scratch register to use as rs2.
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

// non-shift immediate instructions
// ADDI already verified in order to use this sequence
// 31 setup instructions, 6 directed, 6 * 10 corner cases, 100 randomized
class non_shift_immediate_seq extends computa_base_seq;
  `uvm_object_utils(non_shift_immediate_seq)

  parameter int unsigned NUM_INSTRUCTIONS = 197;

  function new (string name = "non_shift_immediate_seq");
    super.new(name);
  endfunction: new

  task body();

    non_shift_immediate_instruction item;
    non_shift_immediate_instruction setup;
    alu_op_t ops[6] = '{ALU_ADD, ALU_SLT, ALU_SLTU,
                          ALU_XOR,  ALU_OR, ALU_AND};


    `uvm_info(get_type_name(), "Calling non_shift_immediate_seq", UVM_LOW)

    // Preload x1..x30 with varied, non-zero signed values before anything
    // else runs. x0 stays hardwired zero
    for (int r = 1; r <= 31; r++) begin
      setup = non_shift_immediate_instruction::type_id::create("setup");
      start_item(setup);
      if (!setup.randomize() with { alu_op == ALU_ADD; rs1 == 0; rd == r; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(setup);
    end

    // One directed instance of every non-shift I-type op, operands otherwise free.

    foreach (ops[i]) begin
      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);
    end

    // Run all corner cases against every op
    foreach (ops[i]) begin
      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; rd == 0; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; rs1 == 0; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; rd == rs1; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; imm == 0; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; imm == 12'h800; }) // imm == -2048
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; imm == 12'h801; }) // imm == -2047
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; imm == 2047; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; imm == 2046; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);
      
      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; imm == 12'hFFF; }) // imm == -1
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);

      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { alu_op == ops[i]; imm == 1; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);
    end

    // Randomized stress
    repeat (100) begin
      item = non_shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize())
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);
    end
  endtask: body
endclass: non_shift_immediate_seq


// Shift Immediate Instructions
// 31 setup, 3 * 32 * 2 testing each amount of shift for each shift type, 100 random
class shift_immediate_seq extends computa_base_seq;
  `uvm_object_utils(shift_immediate_seq)

  parameter int unsigned NUM_INSTRUCTIONS = 323;
    // Scratch register used to stage a known value ahead of the


  function new (string name = "shift_immediate_seq");
    super.new(name);
  endfunction: new

  task body();

    shift_immediate_instruction item;
    non_shift_immediate_instruction setup;
    logic [4:0] temp_reg;
    alu_op_t ops[3] = '{ALU_SLL, ALU_SRL, ALU_SRA};


    `uvm_info(get_type_name(), "Calling shift_immediate_seq", UVM_LOW)

    // Preload x1..x30 with varied, non-zero signed values before anything
    // else runs. x0 stays hardwired zero
    for (int r = 1; r <= 31; r++) begin
      setup = non_shift_immediate_instruction::type_id::create("setup");
      start_item(setup);
      if (!setup.randomize() with { alu_op == ALU_ADD; rs1 == 0; rd == r; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(setup);
    end


    // Try every valid shift amount for each shift operation type
     foreach (ops[i]) begin
      for (int j = 0; j <= 31; j++) begin

        // Initialize a register with a random value
        setup = non_shift_immediate_instruction::type_id::create("setup");
        start_item(setup);
        if (!setup.randomize() with { alu_op == ALU_ADD; })
            `uvm_error(get_type_name(), "randomize failed")
        temp_reg = setup.rd;
        finish_item(setup);

        // Apply a shift on that value
        item = shift_immediate_instruction::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { alu_op == ops[i]; shamt == j; rs1 == temp_reg; })
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(item);

      end
    end

    // Randomized stress
    repeat (100) begin
      item = shift_immediate_instruction::type_id::create("item");
      start_item(item);
      if (!item.randomize())
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(item);
    end
  endtask: body
endclass: shift_immediate_seq


// 100 setup instructions + 100 store instructions * 3 store instruction types
class store_seq extends computa_base_seq;
  `uvm_object_utils(store_seq)

  parameter int unsigned NUM_INSTRUCTIONS = 900;

  function new(string name = "store_seq");
    super.new(name);
  endfunction: new

  task body();

    store_instruction item;
    non_shift_immediate_instruction setup;
    logic [4:0] temp_reg;
    logic [31:0] temp_mem_addr;
    store_funct3_t ops[3] = '{SB, SW, SW};

    `uvm_info(get_type_name(), "Calling store_seq", UVM_LOW)

    // Store word (all addresses are 4-byte word-aligned)
    repeat (100) begin
        
        setup = non_shift_immediate_instruction::type_id::create("setup");
        start_item(setup);
        if (!setup.randomize() with { alu_op == ALU_ADD; imm == 0; rs1 == 0; rd == 1; })
            `uvm_error(get_type_name(), "randomize failed")
        temp_reg = setup.rd;
        temp_mem_addr = setup.imm;
        finish_item(setup);
        
        setup = non_shift_immediate_instruction::type_id::create("setup");
        start_item(setup);
        if (!setup.randomize() with { alu_op == ALU_ADD; imm % 4 == 0; imm < 'h800; rs1 == 0; rd == 1; })
            `uvm_error(get_type_name(), "randomize failed")
        temp_reg = setup.rd;
        temp_mem_addr = setup.imm;
        finish_item(setup);

        item = store_instruction::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { funct3 == SW; imm % 4 == 0; rs1 == temp_reg; temp_mem_addr + imm < 'h800; })
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(item);
    end

    // SH
    repeat (100) begin

        setup = non_shift_immediate_instruction::type_id::create("setup");
        start_item(setup);
        if (!setup.randomize() with { alu_op == ALU_ADD; imm == 0; rs1 == 0; rd == 1; })
            `uvm_error(get_type_name(), "randomize failed")
        temp_reg = setup.rd;
        temp_mem_addr = setup.imm;
        finish_item(setup);

        setup = non_shift_immediate_instruction::type_id::create("setup");
        start_item(setup);
        if (!setup.randomize() with { alu_op == ALU_ADD; imm % 2 == 0; imm < 'h800; rs1 == 0; rd == 1;})
            `uvm_error(get_type_name(), "randomize failed")
        temp_reg = setup.rd;
        temp_mem_addr = setup.imm;
        finish_item(setup);

        item = store_instruction::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { funct3 == SH; imm % 2 == 0; rs1 == temp_reg; temp_mem_addr + imm < 'h800; })
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(item);
    end


    // SB
    repeat (100) begin

        setup = non_shift_immediate_instruction::type_id::create("setup");
        start_item(setup);
        if (!setup.randomize() with { alu_op == ALU_ADD; imm == 0; rs1 == 0; rd == 1; })
            `uvm_error(get_type_name(), "randomize failed")
        temp_reg = setup.rd;
        temp_mem_addr = setup.imm;
        finish_item(setup);

        setup = non_shift_immediate_instruction::type_id::create("setup");
        start_item(setup);
        if (!setup.randomize() with { alu_op == ALU_ADD; imm < 'h800; rs1 == 0; rd == 1;})
            `uvm_error(get_type_name(), "randomize failed")
        temp_reg = setup.rd;
        temp_mem_addr = setup.imm;
        finish_item(setup);

        item = store_instruction::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { funct3 == SB; rs1 == temp_reg; temp_mem_addr + imm < 'h800; })
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(item);

    end

  endtask: body

endclass: store_seq
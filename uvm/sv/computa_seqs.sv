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


// 2 one-time base-address setup instructions + 100 setup instructions +
// 100 store instructions * 3 store instruction types
//
// Store target addresses are DATA_BASE_REG (fixed at 0x1000) + a small
// offset, not just a small offset from x0. This program is 900+
// instructions (>0xE00 bytes of code) and Spike models a single unified
// memory for both instructions and data (unlike this DUT's separate
// imem/dmem), so addresses anywhere below the program's own length would
// let these stores silently overwrite not-yet-executed instructions in
// Spike's memory, corrupting its own reference trace. 0x1000 is safely
// past that footprint and still well inside the 16KiB memory window.
class store_seq extends computa_base_seq;
  `uvm_object_utils(store_seq)

  // 29 (preload) + 1 (one-time x31 = 0xFFFFFFFF setup) + 2 (DATA_BASE_REG
  // setup) + 3 x [2 (rs2==0 directed: setup+store) + 2 (rs2==31/
  // 0xFFFFFFFF directed: setup+store) + 300 (repeat(100) loop, 3
  // instructions/iter)] = 29+1+2+3*304 = 944.
  parameter int unsigned NUM_INSTRUCTIONS = 944;

  // Holds the fixed 0x1000 data-region base for the whole sequence; never
  // written again after the one-time setup below.
  localparam bit [4:0] DATA_BASE_REG = 5'd2; // x2 will store the memory base address (0x1000) after setup

  function new(string name = "store_seq");
    super.new(name);
  endfunction: new

  task body();

    store_instruction             item;
    non_shift_immediate_instruction setup;
    shift_immediate_instruction   base_shift;
    logic [4:0] temp_reg;
    logic [31:0] temp_mem_addr;
    store_funct3_t ops[3] = '{SB, SW, SW};

    `uvm_info(get_type_name(), "Calling store_seq", UVM_LOW)

    for (int i = 3; i < 32; i++) begin
        // Populate x3 - x31 with values. These will be 3 - 31 respectively, and will be the data being written to various memory addresses (rs2 values)
      setup = non_shift_immediate_instruction::type_id::create("setup");
      start_item(setup);
      if (!setup.randomize() with { alu_op == ALU_ADD; rd == i; rs1 == 0; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(setup);
    end;

    // One-time: x31 = sign_extend(0xFFF) = 0xFFFFFFFF, so store items
    // below can hit the storing-all-ones-data corner via rs2 == 31.
    // Overwrites x31's preload value (31). Any later
    // randomized iteration that happens to pick rs2==31 just stores
    // 0xFFFFFFFF instead of 31 from then on.
    setup = non_shift_immediate_instruction::type_id::create("setup");
    start_item(setup);
    if (!setup.randomize() with { alu_op == ALU_ADD; rs1 == 0; rd == 31; imm == 12'hFFF; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(setup);

    // One-time: DATA_BASE_REG = 0x400 << 2 = 0x1000
    setup = non_shift_immediate_instruction::type_id::create("setup");
    start_item(setup);
    if (!setup.randomize() with { alu_op == ALU_ADD; rs1 == 0; rd == DATA_BASE_REG; imm == 'h400; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(setup);

    base_shift = shift_immediate_instruction::type_id::create("base_shift");
    start_item(base_shift);
    if (!base_shift.randomize() with { alu_op == ALU_SLL; rs1 == DATA_BASE_REG; rd == DATA_BASE_REG; shamt == 2; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(base_shift);



    // Directed corners: storing 0 and storing 0xFFFFFFFF, each through
    // the same safe DATA_BASE_REG-relative addressing as the loop below.
    setup = non_shift_immediate_instruction::type_id::create("setup");
    start_item(setup);
    if (!setup.randomize() with { alu_op == ALU_ADD; imm % 4 == 0; imm < 'h800; rs1 == DATA_BASE_REG; rd == 1; })
        `uvm_error(get_type_name(), "randomize failed")
    temp_reg = setup.rd;
    temp_mem_addr = setup.imm + 32'h1000;
    finish_item(setup);

    item = store_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { funct3 == SW; imm % 4 == 0; imm < 'h800; rs1 == temp_reg; temp_mem_addr + imm < 'h4000; rs2 == 0; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    setup = non_shift_immediate_instruction::type_id::create("setup");
    start_item(setup);
    if (!setup.randomize() with { alu_op == ALU_ADD; imm % 4 == 0; imm < 'h800; rs1 == DATA_BASE_REG; rd == 1; })
        `uvm_error(get_type_name(), "randomize failed")
    temp_reg = setup.rd;
    temp_mem_addr = setup.imm + 32'h1000;
    finish_item(setup);

    item = store_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { funct3 == SW; imm % 4 == 0; imm < 'h800; rs1 == temp_reg; temp_mem_addr + imm < 'h4000; rs2 == 31; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    // Store word (all addresses are 4-byte word-aligned)
    repeat (100) begin

        // Reset x1 to 0
        setup = non_shift_immediate_instruction::type_id::create("setup");
        start_item(setup);
        if (!setup.randomize() with { alu_op == ALU_ADD; imm == 0; rs1 == 0; rd == 1; })
            `uvm_error(get_type_name(), "randomize failed")
        temp_reg = setup.rd; // should be x1
        temp_mem_addr = setup.imm; // should be 0
        finish_item(setup);

        // x1 = MEM_BASE + random offset : x1 will hold the base address used for the subsequent sw instruction
        setup = non_shift_immediate_instruction::type_id::create("setup");
        start_item(setup);
        if (!setup.randomize() with { alu_op == ALU_ADD; imm % 4 == 0; imm < 'h800; rs1 == DATA_BASE_REG; rd == 1; })
            `uvm_error(get_type_name(), "randomize failed")
        temp_reg = setup.rd; // should be x1
        temp_mem_addr = setup.imm + 32'h1000;
        finish_item(setup);

        item = store_instruction::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { funct3 == SW; imm % 4 == 0; imm < 'h800; rs1 == temp_reg; temp_mem_addr + imm < 'h4000; })
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(item);
    end


    // Directed corners: storing 0 and storing 0xFFFFFFFF.
    setup = non_shift_immediate_instruction::type_id::create("setup");
    start_item(setup);
    if (!setup.randomize() with { alu_op == ALU_ADD; imm % 2 == 0; imm < 'h800; rs1 == DATA_BASE_REG; rd == 1; })
        `uvm_error(get_type_name(), "randomize failed")
    temp_reg = setup.rd;
    temp_mem_addr = setup.imm + 32'h1000;
    finish_item(setup);

    item = store_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { funct3 == SH; imm % 2 == 0; imm < 'h800; rs1 == temp_reg; temp_mem_addr + imm < 'h4000; rs2 == 0; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    setup = non_shift_immediate_instruction::type_id::create("setup");
    start_item(setup);
    if (!setup.randomize() with { alu_op == ALU_ADD; imm % 2 == 0; imm < 'h800; rs1 == DATA_BASE_REG; rd == 1; })
        `uvm_error(get_type_name(), "randomize failed")
    temp_reg = setup.rd;
    temp_mem_addr = setup.imm + 32'h1000;
    finish_item(setup);

    item = store_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { funct3 == SH; imm % 2 == 0; imm < 'h800; rs1 == temp_reg; temp_mem_addr + imm < 'h4000; rs2 == 31; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

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
        if (!setup.randomize() with { alu_op == ALU_ADD; imm % 2 == 0; imm < 'h800; rs1 == DATA_BASE_REG; rd == 1;})
            `uvm_error(get_type_name(), "randomize failed")
        temp_reg = setup.rd;
        temp_mem_addr = setup.imm + 32'h1000;
        finish_item(setup);

        item = store_instruction::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { funct3 == SH; imm % 2 == 0; imm < 'h800; rs1 == temp_reg; temp_mem_addr + imm < 'h4000; })
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(item);
    end



    // Directed corners: storing 0 and storing 0xFFFFFFFF.
    setup = non_shift_immediate_instruction::type_id::create("setup");
    start_item(setup);
    if (!setup.randomize() with { alu_op == ALU_ADD; imm < 'h800; rs1 == DATA_BASE_REG; rd == 1; })
        `uvm_error(get_type_name(), "randomize failed")
    temp_reg = setup.rd;
    temp_mem_addr = setup.imm + 32'h1000;
    finish_item(setup);

    item = store_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { funct3 == SB; imm < 'h800; rs1 == temp_reg; temp_mem_addr + imm < 'h4000; rs2 == 0; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    setup = non_shift_immediate_instruction::type_id::create("setup");
    start_item(setup);
    if (!setup.randomize() with { alu_op == ALU_ADD; imm < 'h800; rs1 == DATA_BASE_REG; rd == 1; })
        `uvm_error(get_type_name(), "randomize failed")
    temp_reg = setup.rd;
    temp_mem_addr = setup.imm + 32'h1000;
    finish_item(setup);

    item = store_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { funct3 == SB; imm < 'h800; rs1 == temp_reg; temp_mem_addr + imm < 'h4000; rs2 == 31; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

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
        if (!setup.randomize() with { alu_op == ALU_ADD; imm < 'h800; rs1 == DATA_BASE_REG; rd == 1;})
            `uvm_error(get_type_name(), "randomize failed")
        temp_reg = setup.rd;
        temp_mem_addr = setup.imm + 32'h1000;
        finish_item(setup);

        item = store_instruction::type_id::create("item");
        start_item(item);
        if (!item.randomize() with { funct3 == SB; imm < 'h800; rs1 == temp_reg; temp_mem_addr + imm < 'h4000; })
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(item);

    end
  

  endtask: body

endclass: store_seq



// LW, LH, LB, LHU, LBU
//
// For every load width: build a known 32-bit value, store it as a word at
// a fresh word-aligned scratch address, then load it back with corner-case
// addressing/register choices. Every load reads from an address that was
// just written (never uninitialized or instruction memory), and
// DATA_BASE_REG (x2, fixed at Spike's 0x1000 memory base) never gets
// overwritten after its one-time setup. Every address generated here
// stays inside [0x1000, 0x1800) 
//
// program_size = 460:
//   1   DATA_BASE_REG (x2) one-time setup (build_word: single LUI, since
//       0x1000's low 12 bits are zero)
//   29  x3..x31 random preload
//   75  foreach of 5 ops: op-coverage(3) + rd==0(3) + rd==rs1(3)
//       + min-address(3) + max-address(3) = 15/op * 5 ops
//   39  sign-/zero-extension value corners: byte 0xFF/0x7F/0x80 (each a
//       1-instruction build_word), each loaded via LB+LBU (5 instr * 3 =
//       15); half 0x8000 (1-instr build, LUI only) loaded via LH+LHU (5);
//       half 0xFFFF/0x7FFF (each a 2-instr build_word: LUI+ADDI) loaded
//       via LH+LHU (6 instr * 2 = 12); all-zero word, no build needed (3);
//       all-ones word, 1-instr build_word (ADDI alone) (4)
//   16  byte-lane (4 offsets * LB/LBU = 10) + halfword-lane
//       (2 offsets * LH/LHU = 6) selection coverage
//   300 randomized stress, 100 iterations * 3 instructions/iteration
/*
class load_instruction_seq extends computa_base_seq;

  `uvm_object_utils(load_instruction_seq)

  parameter int unsigned NUM_INSTRUCTIONS = 460;

  // x2 holds the fixed 0x1000 data-region base, set up once and never
  // written again. x1 is scratch, rebuilt from DATA_BASE_REG before every
  // address use below.
  localparam bit [4:0] DATA_BASE_REG = 5'd2;
  localparam bit [4:0] ADDR_REG      = 5'd1;
  // Reused to stage 32-bit corner-case data patterns ahead of a store;
  // its x3..x31 preload value is overwritten the first time it's used.
  localparam bit [4:0] SCRATCH_REG   = 5'd31;

  function new (string name = "load_instruction_seq");
    super.new(name);
  endfunction: new

  // ADDR_REG = DATA_BASE_REG + offset. offset must keep ADDR_REG word
  // aligned since store_word() below always issues a word store at
  // ADDR_REG+0.
  task automatic setup_addr(bit [11:0] offset);
    non_shift_immediate_instruction setup;
    setup = non_shift_immediate_instruction::type_id::create("setup");
    start_item(setup);
    if (!setup.randomize() with { alu_op == ALU_ADD; rs1 == DATA_BASE_REG; rd == ADDR_REG; imm == offset; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(setup);
  endtask: setup_addr

  // Stages an arbitrary 32-bit value into dst_reg using the minimum of a
  // LUI and/or an ADDI, applying the standard sign-extension carry
  // adjustment so the pair reconstructs any value exactly (1 instruction
  // when value fits a sign-extended 12-bit immediate or is an exact
  // multiple of 0x1000, 2 otherwise).
  task automatic build_word(bit [4:0] dst_reg, bit [31:0] value);
    bit [11:0] lo;
    bit [19:0] hi;
    lui_instruction                 lui_item;
    non_shift_immediate_instruction addi_item;

    lo = value[11:0];
    hi = value[31:12] + (lo[11] ? 20'd1 : 20'd0);

    if (hi == 0) begin
      addi_item = non_shift_immediate_instruction::type_id::create("addi_item");
      start_item(addi_item);
      if (!addi_item.randomize() with { alu_op == ALU_ADD; rs1 == 0; rd == dst_reg; imm == lo; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(addi_item);
    end else begin
      lui_item = lui_instruction::type_id::create("lui_item");
      start_item(lui_item);
      if (!lui_item.randomize() with { rd == dst_reg; imm == hi; })
          `uvm_error(get_type_name(), "randomize failed")
      finish_item(lui_item);

      if (lo != 0) begin
        addi_item = non_shift_immediate_instruction::type_id::create("addi_item");
        start_item(addi_item);
        if (!addi_item.randomize() with { alu_op == ALU_ADD; rs1 == dst_reg; rd == dst_reg; imm == lo; })
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(addi_item);
      end
    end
  endtask: build_word

  task automatic preload_random(bit [4:0] dst_reg);
    non_shift_immediate_instruction setup;
    setup = non_shift_immediate_instruction::type_id::create("setup");
    start_item(setup);
    if (!setup.randomize() with { alu_op == ALU_ADD; rs1 == 0; rd == dst_reg; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(setup);
  endtask: preload_random

  // Word store of data_reg's value to ADDR_REG+0. Always a full word so
  // every byte in the word is initialized, regardless of what load width
  // reads it back afterwards.
  task automatic store_word(bit [4:0] data_reg);
    store_instruction store;
    store = store_instruction::type_id::create("store");
    start_item(store);
    if (!store.randomize() with { funct3 == SW; rs1 == ADDR_REG; rs2 == data_reg; imm == 0; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(store);
  endtask: store_word

  // Loads ADDR_REG+byte_off with the given width. rd_val < 0 (the default)
  // picks a random destination excluding ADDR_REG/DATA_BASE_REG so this
  // sequence's own scratch registers survive; pass a specific value to
  // direct rd (e.g. 0, or ADDR_REG for the rd==rs1 corner).
  task automatic do_load(load_funct3_t op, bit [11:0] byte_off, int rd_val = -1);
    load_instruction item;
    item = load_instruction::type_id::create("item");
    start_item(item);
    if (rd_val < 0) begin
      if (!item.randomize() with { funct3 == op; imm == byte_off; rs1 == ADDR_REG; !(rd inside {ADDR_REG, DATA_BASE_REG}); })
          `uvm_error(get_type_name(), "randomize failed")
    end else begin
      if (!item.randomize() with { funct3 == op; imm == byte_off; rs1 == ADDR_REG; rd == rd_val[4:0]; })
          `uvm_error(get_type_name(), "randomize failed")
    end
    finish_item(item);
  endtask: do_load

  task body();
    load_funct3_t ops[5] = '{LW, LH, LB, LBU, LHU};
    bit [11:0] rnd_off;
    bit [4:0]  rnd_data_reg;
    bit [11:0] max_byte_off;

    `uvm_info(get_type_name(), "Calling load_instruction_seq", UVM_LOW)

    // One-time: DATA_BASE_REG = 0x1000
    build_word(DATA_BASE_REG, 32'h00001000);

    // Preload x3..x31 with varied random values used as store data
    // throughout. x0 stays hardwired zero, x1/x2 are reserved above.
    for (int r = 3; r <= 31; r++) begin
      preload_random(r[4:0]);
    end

    // Per-op directed corners: op coverage, rd==0 (result discarded),
    // rd==rs1 (load overwrites its own address register), min address
    // (offset 0, i.e. exactly DATA_BASE_REG == 0x1000) and max address
    // reachable in this sequence's window (word base 0x17FC, so the
    // farthest byte touched is 0x17FF -- still well under the 0x4000
    // limit).
    foreach (ops[i]) begin
      rnd_off = $urandom_range(0, 511) << 2; // random word-aligned offset, 0..0x7FC
      rnd_data_reg = $urandom_range(3, 30);

      setup_addr(rnd_off);
      store_word(rnd_data_reg);
      do_load(ops[i], 0);

      setup_addr(rnd_off);
      store_word(rnd_data_reg);
      do_load(ops[i], 0, 0);

      setup_addr(rnd_off);
      store_word(rnd_data_reg);
      do_load(ops[i], 0, ADDR_REG);

      setup_addr(0);
      store_word(rnd_data_reg);
      do_load(ops[i], 0);

      case (ops[i])
        LW:      max_byte_off = 0;
        LH, LHU: max_byte_off = 2;
        default: max_byte_off = 3; // LB, LBU
      endcase
      setup_addr('h7FC);
      store_word(rnd_data_reg);
      do_load(ops[i], max_byte_off);
    end

    // Sign-/zero-extension corners: the same stored data is read back
    // through both the sign-extending and zero-extending op of a given
    // width so the two results can be compared directly.
    begin
      bit [31:0] byte_patterns[3] = '{32'h000000FF, 32'h0000007F, 32'h00000080};
      foreach (byte_patterns[i]) begin
        build_word(SCRATCH_REG, byte_patterns[i]);
        setup_addr(0);
        store_word(SCRATCH_REG);
        do_load(LB, 0);
        do_load(LBU, 0);
      end
    end

    // 0x00008000: sign bit only set
    build_word(SCRATCH_REG, 32'h00008000);
    setup_addr(0);
    store_word(SCRATCH_REG);
    do_load(LH, 0);
    do_load(LHU, 0);

    // 0x0000FFFF: all 16 bits set
    build_word(SCRATCH_REG, 32'h0000FFFF);
    setup_addr(0);
    store_word(SCRATCH_REG);
    do_load(LH, 0);
    do_load(LHU, 0);

    // 0x00007FFF: max positive halfword
    build_word(SCRATCH_REG, 32'h00007FFF);
    setup_addr(0);
    store_word(SCRATCH_REG);
    do_load(LH, 0);
    do_load(LHU, 0);

    // All-zero word (store x0 directly, no build needed)
    setup_addr(0);
    store_word(5'd0);
    do_load(LW, 0);

    // All-ones word
    build_word(SCRATCH_REG, 32'hFFFFFFFF);
    setup_addr(0);
    store_word(SCRATCH_REG);
    do_load(LW, 0);

    // Byte-lane selection: load every byte offset out of one freshly
    // stored word to exercise the load-path byte-select mux directly.
    rnd_off = $urandom_range(0, 511) << 2;
    rnd_data_reg = $urandom_range(3, 30);
    setup_addr(rnd_off);
    store_word(rnd_data_reg);
    for (int b = 0; b < 4; b++) begin
      do_load(LB, b[11:0]);
      do_load(LBU, b[11:0]);
    end

    // Halfword-lane selection: same idea, both halfwords of one word.
    rnd_off = $urandom_range(0, 511) << 2;
    rnd_data_reg = $urandom_range(3, 30);
    setup_addr(rnd_off);
    store_word(rnd_data_reg);
    do_load(LH, 0);
    do_load(LH, 2);
    do_load(LHU, 0);
    do_load(LHU, 2);

    // Randomized stress across all 5 load widths.
    repeat (100) begin
      rnd_off = $urandom_range(0, 511) << 2;
      rnd_data_reg = $urandom_range(3, 30);
      setup_addr(rnd_off);
      store_word(rnd_data_reg);
      do_load(ops[$urandom_range(0, 4)], 0);
    end
  endtask: body

endclass: load_instruction_seq
*/

// LUI
// program_size = 105 (5 directed corner cases + 100 randomized)
class lui_seq extends computa_base_seq;
  `uvm_object_utils(lui_seq)

  parameter int unsigned NUM_INSTRUCTIONS = 105;

  function new (string name = "lui_seq");
    super.new(name);
  endfunction: new

  task body();
    lui_instruction item;
    `uvm_info(get_type_name(), "Calling lui_seq", UVM_LOW)

    // Directed corner cases
    item = lui_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { rd == 0; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    item = lui_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { imm == 0; })
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    item = lui_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { imm == 20'h1; }) // smallest nonzero imm: 0x00001000
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    item = lui_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { imm == 20'hFFFFF; }) // 0xFFFFF000
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    item = lui_instruction::type_id::create("item");
    start_item(item);
    if (!item.randomize() with { imm == 20'h80000; }) // 0x80000000, result sign bit only
        `uvm_error(get_type_name(), "randomize failed")
    finish_item(item);

    // Randomized stress
    repeat (100) begin
        item = lui_instruction::type_id::create("item");
        start_item(item);
        if (!item.randomize())
            `uvm_error(get_type_name(), "randomize failed")
        finish_item(item);
    end
  endtask: body
endclass: lui_seq

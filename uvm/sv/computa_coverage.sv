import brv32_pkg::*;

// Functional coverage collector: samples ISA diversity as instructions
// retire, decoding each retiring instruction word the same way
// rtl/decode_stage.sv does. Separate from computa_scoreboard (which only
// checks correctness); subscribes to the same monitor.ap analysis port
// scoreboard does, so both run off the exact stream of instructions that
// actually executed on the DUT, not the randomized stimulus directly.
class computa_coverage extends uvm_component;

  uvm_analysis_imp #(computa_retire_txn, computa_coverage) analysis_export;

  // Decoded fields of the instruction currently being sampled, refreshed
  // by write() immediately before instr_cg.sample().
  opcode_t    opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [4:0] rd, rs1, rs2;

  // Branch outcome can't be read off a single retire txn: there's no
  // taken/not-taken field on computa_retire_txn, only pc/instruction/regs.
  // It only becomes knowable once the *next* instruction's pc is
  // observed, so a taken branch is sampled one retire late: write()
  // caches the previous instruction's opcode/pc, and if that was a
  // branch, derives taken = (this pc != prev_pc + 4) before sampling
  // branch_cg. A branch that is the very last instruction of a program
  // never gets its outcome sampled (no next txn ever arrives to reveal
  // it), a known, minor gap rather than a bug.
  bit        have_prev;
  bit [31:0] prev_pc;
  opcode_t   prev_opcode;
  bit        branch_taken;

  covergroup instr_cg;
    option.per_instance = 1;

    cp_opcode: coverpoint opcode {
      bins reg_reg = {OP_REG};
      bins reg_imm = {OP_IMM};
      bins load    = {OP_LOAD};
      bins store   = {OP_STORE};
      bins branch  = {OP_BRANCH};
      bins jal     = {OP_JAL};
      bins jalr    = {OP_JALR};
      bins lui     = {OP_LUI};
      bins auipc   = {OP_AUIPC};
      // Decode as no-ops in this core (see decode_stage.sv) and nothing
      // in computa_instruction.sv generates them. Kept as explicit bins
      // so an always-0% hit here reads as "not exercised by the
      // generator", not as a coverpoint that silently doesn't exist.
      bins fence   = {OP_FENCE};
      bins system  = {OP_SYSTEM};
    }

    // ALU op space: reg-reg and reg-imm share the same funct3 encoding.
    cp_alu_funct3: coverpoint funct3 iff (opcode inside {OP_REG, OP_IMM}) {
      bins add_or_sub = {3'b000};
      bins sll        = {3'b001};
      bins slt        = {3'b010};
      bins sltu       = {3'b011};
      bins xor_op     = {3'b100};
      bins srl_or_sra = {3'b101};
      bins or_op      = {3'b110};
      bins and_op     = {3'b111};
    }

    // funct7[5] only distinguishes ADD/SUB (OP_REG) and SRL/SRA (OP_REG
    // or OP_IMM shifts); everywhere else on OP_IMM those bits are just
    // part of the immediate, not a real variant selector, so this only
    // samples where funct7 is architecturally meaningful.
    cp_alu_variant: coverpoint funct7[5]
      iff (opcode == OP_REG || (opcode == OP_IMM && funct3 inside {3'b001, 3'b101})) {
      bins base = {1'b0}; // ADD / SRL(I)
      bins alt  = {1'b1}; // SUB / SRA(I)
    }

    cp_branch_funct3: coverpoint funct3 iff (opcode == OP_BRANCH) {
      bins beq  = {BEQ};
      bins bne  = {BNE};
      bins blt  = {BLT};
      bins bge  = {BGE};
      bins bltu = {BLTU};
      bins bgeu = {BGEU};
    }

    cp_load_funct3: coverpoint funct3 iff (opcode == OP_LOAD) {
      bins lb  = {LB};
      bins lh  = {LH};
      bins lw  = {LW};
      bins lbu = {LBU};
      bins lhu = {LHU};
    }

    cp_store_funct3: coverpoint funct3 iff (opcode == OP_STORE) {
      bins sb = {SB};
      bins sh = {SH};
      bins sw = {SW};
    }

    // reg_file.sv special-cases x0 (hardwired zero, writes silently
    // dropped), worth confirming the generator sometimes targets it,
    // since that's exactly the kind of edge real hardware bugs hide in.
    // Gated to opcodes that actually have that operand (e.g. LUI/AUIPC/
    // JAL read no registers at all).
    cp_rs1_x0: coverpoint (rs1 == 5'd0)
      iff (opcode inside {OP_REG, OP_IMM, OP_LOAD, OP_STORE, OP_BRANCH, OP_JALR});
    cp_rs2_x0: coverpoint (rs2 == 5'd0)
      iff (opcode inside {OP_REG, OP_STORE, OP_BRANCH});
    cp_rd_x0: coverpoint (rd == 5'd0)
      iff (opcode inside {OP_REG, OP_IMM, OP_LOAD, OP_JAL, OP_JALR, OP_LUI, OP_AUIPC});

    cross cp_opcode, cp_rd_x0;
  endgroup

  covergroup branch_cg;
    option.per_instance = 1;
    cp_taken: coverpoint branch_taken {
      bins taken     = {1};
      bins not_taken = {0};
    }
  endgroup

  `uvm_component_utils(computa_coverage)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
    instr_cg  = new();
    branch_cg = new();
  endfunction : new

  function void write(computa_retire_txn t);
    if (have_prev && prev_opcode == OP_BRANCH) begin
      branch_taken = (t.pc != prev_pc + 32'd4);
      branch_cg.sample();
    end

    opcode = opcode_t'(t.instruction[6:0]);
    funct3 = t.instruction[14:12];
    funct7 = t.instruction[31:25];
    rd     = t.instruction[11:7];
    rs1    = t.instruction[19:15];
    rs2    = t.instruction[24:20];
    instr_cg.sample();

    have_prev   = 1'b1;
    prev_pc     = t.pc;
    prev_opcode = opcode;
  endfunction : write

endclass : computa_coverage

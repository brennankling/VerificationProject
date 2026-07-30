import brv32_pkg::*;

class computa_instruction extends uvm_sequence_item;

    `uvm_object_utils(computa_instruction)

    bit [31:0] instruction;
    rand bit [6:0] opcode;

    constraint valid_opcode {
        opcode inside {7'b0110011, 7'b0010011, 7'b0000011,
                       7'b0100011, 7'b1100011, 7'b1101111,
                       7'b1100111, 7'b0110111, 7'b0010111,
                       7'b0001111, 7'b1110011};
    }

    function new(string name = "computa_instruction");
        super.new(name);
    endfunction: new

    // Packs this instruction's fields into `instruction`, overridden per
    // format subclass. Runs automatically via post_randomize(), but is
    // also safe to call directly for directed tests.
    virtual function void instruction_pack();
    endfunction: instruction_pack

    function void post_randomize();
        instruction_pack();
    endfunction: post_randomize
endclass: computa_instruction

class lui_instruction extends computa_instruction;

    `uvm_object_utils(lui_instruction)

    rand bit [19:0] imm;
    rand bit [4:0] rd;

    constraint lui_opcode { opcode == 7'b0110111;}

    function new(string name = "lui_instruction");
        super.new(name);
    endfunction: new

    function void instruction_pack();
        instruction = {imm, rd, opcode};
    endfunction: instruction_pack
endclass: lui_instruction

class auipc_instruction extends computa_instruction;
    `uvm_object_utils(auipc_instruction)

    rand bit [19:0] imm;
    rand bit [4:0] rd;

    constraint auipc_opcode { opcode == 7'b0010111;}

    function new(string name = "auipc_instruction");
        super.new(name);
    endfunction: new

    function void instruction_pack();
        instruction = {imm, rd, opcode};
    endfunction: instruction_pack
endclass: auipc_instruction

class jal_instruction extends computa_instruction;

    `uvm_object_utils(jal_instruction)

    rand bit [20:0] imm; // the last bit is discarded
    rand bit [4:0] rd;

    constraint jal_opcode { opcode == 7'b1101111;}

    function new(string name = "jal_instruction");
        super.new(name);
    endfunction: new

    function void instruction_pack();
        instruction = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
    endfunction: instruction_pack
endclass: jal_instruction

class jalr_instruction extends computa_instruction;

    `uvm_object_utils(jalr_instruction)

    rand bit [11:0] imm; // offset
    rand bit [4:0] rs1;
    // bit [2:0] funct3; hardcoded to 0 for jalr
    rand bit [4:0] rd;

    constraint jalr_opcode { opcode == 7'b1100111;}

    function new(string name = "jalr_instruction");
        super.new(name);
    endfunction: new

    function void instruction_pack();
        instruction = {imm, rs1, 3'b0, rd, opcode};
    endfunction: instruction_pack
endclass: jalr_instruction


// Comprised of BEQ, BNE, BLT, BGE, BLTU, BGEU
class branch_instruction extends computa_instruction;

    `uvm_object_utils(branch_instruction)

    rand bit [12:0] imm; // last bit discarded
    rand bit [4:0] rs2;
    rand bit [4:0] rs1;
    rand branch_funct3_t funct3;

    constraint branch_opcode { opcode == 7'b1100011;}
    constraint branch_imm { imm[1:0] == 2'b0; }


    function new(string name = "branch_instruction");
        super.new(name);
    endfunction: new

    function void instruction_pack();
        instruction = {imm[12], imm[10:5], rs2,
            rs1, funct3, imm[4:1], imm[11], opcode};
    endfunction: instruction_pack
endclass: branch_instruction

class load_instruction extends computa_instruction;

    `uvm_object_utils(load_instruction)

    rand bit [11:0] imm;
    rand bit [4:0] rs1;
    rand load_funct3_t funct3;
    rand bit [4:0] rd;

    constraint load_opcode { opcode == 7'b0000011;}


    function new(string name = "load_instruction");
        super.new(name);
    endfunction: new

    function void instruction_pack();
        instruction = {imm[11:0], rs1, funct3, rd, opcode};
    endfunction: instruction_pack
endclass: load_instruction

class store_instruction extends computa_instruction;
    `uvm_object_utils(store_instruction)

    rand bit [11:0] imm;
    rand bit [4:0] rs2;
    rand bit [4:0] rs1;
    rand store_funct3_t funct3;

    constraint store_opcode { opcode == 7'b0100011; }

    function new (string name = "store_instruction");
        super.new(name);
    endfunction: new

    function void instruction_pack();
        instruction = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
    endfunction: instruction_pack
endclass: store_instruction

class non_shift_immediate_instruction extends computa_instruction;
    `uvm_object_utils(non_shift_immediate_instruction)

    rand bit [11:0] imm;
    rand bit [4:0] rs1;
    rand alu_op_t alu_op; // 4 bits that translate into funct3 value
    bit [2:0] funct3;
    rand bit [4:0] rd;

    constraint non_shift_immediate_alu_op { alu_op inside {
                                            ALU_ADD,
                                            ALU_SLT,
                                            ALU_SLTU,
                                            ALU_XOR,
                                            ALU_OR,
                                            ALU_AND}; }
    constraint non_shift_immediate_opcode { opcode == 7'b0010011; }

    function new (string name = "non_shift_immediate_instruction");
        super.new(name);
    endfunction: new

    function void instruction_pack();
        case (alu_op)
            ALU_ADD: begin
                funct3 = 3'b0;
            end
            ALU_SLT: begin
                funct3 = 3'b010;
            end
            ALU_SLTU: begin
                funct3 = 3'b011;
            end
            ALU_XOR: begin
                funct3 = 3'b100;
            end
            ALU_OR: begin
                funct3 = 3'b110;
            end
            ALU_AND: begin
                funct3 = 3'b111;
            end
            default: begin
                funct3 = 3'b0;
            end
        endcase
        instruction = {imm, rs1, funct3, rd, opcode};
    endfunction: instruction_pack
endclass: non_shift_immediate_instruction

class shift_immediate_instruction extends computa_instruction;
        `uvm_object_utils(shift_immediate_instruction)

    bit [6:0] imm;
    rand bit [4:0] shamt; // shift amount
    rand bit [4:0] rs1;
    rand alu_op_t alu_op; // 4 bits that translate into funct3 value
    bit [2:0] funct3;
    rand bit [4:0] rd;


    constraint shift_immediate_opcode { opcode == 7'b0010011; }
    constraint shift_immediate_alu_op { alu_op inside {
                                            ALU_SLL,
                                            ALU_SRL,
                                            ALU_SRA}; }

    function new (string name = "shift_immediate_instruction");
        super.new(name);
    endfunction: new

    function void instruction_pack();
        case (alu_op)
            ALU_SLL: begin
                funct3 = 3'b001;
                imm = 7'b0;
            end
            ALU_SRL: begin
                funct3 = 3'b101;
                imm = 7'b0;
            end
            ALU_SRA: begin
                funct3 = 3'b101;
                imm = 7'b0100000;
            end
            default: begin
                funct3 = 3'b0;
                imm = 7'b0;
            end
        endcase
        instruction = {imm, shamt, rs1, funct3, rd, opcode};
    endfunction: instruction_pack
endclass: shift_immediate_instruction

class register_instruction extends computa_instruction;
    `uvm_object_utils(register_instruction)

    bit [6:0] funct7;
    rand bit [4:0] rs2;
    rand bit [4:0] rs1;
    rand alu_op_t alu_op;
    bit [2:0] funct3;
    rand bit [4:0] rd;

    constraint register_opcode { opcode == 7'b0110011; }
    constraint register_alu_op { alu_op != ALU_PASS; }

    function new (string name = "register_instruction");
        super.new(name);
    endfunction: new

    function void instruction_pack();
        case (alu_op)
            ALU_ADD: begin
                funct7 = 7'b0;
                funct3 = 3'b0;
            end
            ALU_SLT: begin
                funct7 = 7'b0;
                funct3 = 3'b010;
            end
            ALU_SLTU: begin
                funct7 = 7'b0;
                funct3 = 3'b011;
            end
            ALU_AND: begin
                funct7 = 7'b0;
                funct3 = 3'b111;
            end
            ALU_OR: begin
                funct7 = 7'b0;
                funct3 = 3'b110;
            end
            ALU_XOR: begin
                funct7 = 7'b0;
                funct3 = 3'b100;
            end
            ALU_SLL: begin
                funct7 = 7'b0;
                funct3 = 3'b001;
            end
            ALU_SRL: begin
                funct7 = 7'b0;
                funct3 = 3'b101;
            end
            ALU_SUB: begin
                funct7 = 7'b0100000;
                funct3 = 3'b0;
            end
            ALU_SRA: begin
                funct7 = 7'b0100000;
                funct3 = 3'b101;
            end
            default: begin
                funct7 = 7'b0;
                funct3 = 3'b0;
            end
        endcase
        instruction = {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction: instruction_pack
endclass: register_instruction

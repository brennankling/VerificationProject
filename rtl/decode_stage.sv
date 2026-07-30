module decode_stage
  import brv32_pkg::*;
#(
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [DATA_WIDTH-1:0] instruction,
    input  logic [DATA_WIDTH-1:0] wb_data,

    output logic [DATA_WIDTH-1:0] rs1_data,
    output logic [DATA_WIDTH-1:0] rs2_data,
    output logic [DATA_WIDTH-1:0] imm,
    output logic [4:0]            rd_addr,
    output logic [2:0]            funct3,
    output alu_op_t                alu_op,
    output logic                  alu_src,
    output logic                  mem_read,
    output logic                  mem_write,
    output logic                  reg_write,
    output logic                  mem_to_reg,
    output logic                  branch,
    output logic                  jal,
    output logic                  jalr,
    output logic                  illegal
);

    logic [6:0] opcode;
    logic [6:0] funct7;
    logic [4:0] rs1_addr;
    logic [4:0] rs2_addr;
    imm_type_t  imm_type;

    assign opcode   = instruction[6:0];
    assign rd_addr  = instruction[11:7];
    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign funct3   = instruction[14:12];
    assign funct7   = instruction[31:25];

    reg_file u_reg_file (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .rd_data  (wb_data),
        .reg_write(reg_write),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // Main control decode
    always_comb begin
        alu_src    = 1'b0;
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        branch     = 1'b0;
        jal        = 1'b0;
        jalr       = 1'b0;
        imm_type   = IMM_I;
        illegal    = 1'b0;

        case (opcode_t'(opcode))
            OP_REG: begin
                reg_write = 1'b1;
            end
            OP_IMM: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
            end
            OP_LOAD: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
            end
            OP_STORE: begin
                mem_write = 1'b1;
                alu_src   = 1'b1;
                imm_type  = IMM_S;
            end
            OP_BRANCH: begin
                branch   = 1'b1;
                imm_type = IMM_B;
            end
            OP_JAL: begin
                jal       = 1'b1;
                reg_write = 1'b1;
                imm_type  = IMM_J;
            end
            OP_JALR: begin
                jalr      = 1'b1;
                reg_write = 1'b1;
                alu_src   = 1'b1;
            end
            OP_LUI: begin
                imm_type  = IMM_U;
                reg_write = 1'b1;
                alu_src   = 1'b1;
            end
            OP_AUIPC: begin
                imm_type  = IMM_U;
                reg_write = 1'b1;
                alu_src   = 1'b1;
            end
            OP_FENCE: begin
                // no-op: single-hart in-order core has nothing to fence
            end
            OP_SYSTEM: begin
                // ECALL/EBREAK/CSR ops execute as no-ops: no trap or CSR
                // support in this base implementation
            end
            default: begin
                illegal = 1'b1;
            end
        endcase
    end

    // ALU operation decode
    always_comb begin
        alu_op = ALU_ADD;
        case (opcode_t'(opcode))
            OP_REG: begin
                case (funct3)
                    3'b000:  alu_op = alu_op_t'(funct7[5] ? ALU_SUB : ALU_ADD);
                    3'b001:  alu_op = ALU_SLL;
                    3'b010:  alu_op = ALU_SLT;
                    3'b011:  alu_op = ALU_SLTU;
                    3'b100:  alu_op = ALU_XOR;
                    3'b101:  alu_op = alu_op_t'(funct7[5] ? ALU_SRA : ALU_SRL);
                    3'b110:  alu_op = ALU_OR;
                    3'b111:  alu_op = ALU_AND;
                    default: alu_op = ALU_ADD;
                endcase
            end
            OP_IMM: begin
                case (funct3)
                    3'b000:  alu_op = ALU_ADD;  // ADDI 
                    3'b001:  alu_op = ALU_SLL;  // SLLI
                    3'b010:  alu_op = ALU_SLT;  // SLTI
                    3'b011:  alu_op = ALU_SLTU; // SLTIU
                    3'b100:  alu_op = ALU_XOR;  // XORI
                    3'b101:  alu_op = alu_op_t'(funct7[5] ? ALU_SRA : ALU_SRL); // SRAI/SRLI
                    3'b110:  alu_op = ALU_OR;   // ORI
                    3'b111:  alu_op = ALU_AND;  // ANDI
                    default: alu_op = ALU_ADD;
                endcase
            end
            OP_LUI: alu_op = ALU_PASS;
            default: alu_op = ALU_ADD; // LOAD/STORE/JALR/AUIPC address/base add
        endcase
    end

    // Immediate generation
    always_comb begin
        case (imm_type)
            IMM_I:   imm = {{20{instruction[31]}}, instruction[31:20]};
            IMM_S:   imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            IMM_B:   imm = {{19{instruction[31]}}, instruction[31], instruction[7],
                             instruction[30:25], instruction[11:8], 1'b0};
            IMM_U:   imm = {instruction[31:12], 12'b0};
            IMM_J:   imm = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                             instruction[20], instruction[30:21], 1'b0};
            default: imm = 32'b0;
        endcase
    end

endmodule

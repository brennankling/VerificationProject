module execute_stage
  import brv32_pkg::*;
#(
    parameter int DATA_WIDTH = 32
) (
    input  logic [DATA_WIDTH-1:0] rs1_data,
    input  logic [DATA_WIDTH-1:0] rs2_data,
    input  logic [DATA_WIDTH-1:0] imm,
    input  logic [DATA_WIDTH-1:0] pc,
    input  alu_op_t                alu_op,
    input  logic                  alu_src,
    input  logic [2:0]            funct3,
    input  logic                  branch,
    input  logic                  jal,
    input  logic                  jalr,

    output logic [DATA_WIDTH-1:0] alu_result,
    output logic [DATA_WIDTH-1:0] mem_addr,
    output logic [DATA_WIDTH-1:0] mem_wr_data,
    output logic [DATA_WIDTH-1:0] pc_target,
    output logic                  pc_src
);

    logic [DATA_WIDTH-1:0] operand2;
    logic                  branch_taken;

    assign operand2    = alu_src ? imm : rs2_data;
    assign mem_wr_data = rs2_data;
    assign mem_addr    = alu_result;

    alu u_alu (
        .operand1(rs1_data),
        .operand2(operand2),
        .alu_op  (alu_op),
        .result  (alu_result)
    );

    always_comb begin
        branch_taken = 1'b0;
        if (branch) begin
            case (funct3)
                BEQ:     branch_taken = (rs1_data == rs2_data);
                BNE:     branch_taken = (rs1_data != rs2_data);
                BLT:     branch_taken = ($signed(rs1_data) < $signed(rs2_data));
                BGE:     branch_taken = ($signed(rs1_data) >= $signed(rs2_data));
                BLTU:    branch_taken = (rs1_data < rs2_data);
                BGEU:    branch_taken = (rs1_data >= rs2_data);
                default: branch_taken = 1'b0;
            endcase
        end
    end

    // JALR targets rs1+imm with the LSB cleared; JAL and taken branches
    // target pc+imm.
    assign pc_target = jalr ? ((rs1_data + imm) & ~32'b1) : (pc + imm);
    assign pc_src     = jal || jalr || branch_taken;

endmodule

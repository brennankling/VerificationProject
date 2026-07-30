module alu
  import brv32_pkg::*;
#(
    parameter int DATA_WIDTH = 32
) (
    input  logic [DATA_WIDTH-1:0] operand1,
    input  logic [DATA_WIDTH-1:0] operand2,
    input  alu_op_t                alu_op,

    output logic [DATA_WIDTH-1:0] result
);

    always_comb begin
        case (alu_op)
            ALU_ADD:  result = operand1 + operand2;
            ALU_SUB:  result = operand1 - operand2;
            ALU_SLL:  result = operand1 << operand2[4:0];
            ALU_SLT:  result = {31'b0, $signed(operand1) < $signed(operand2)};
            ALU_SLTU: result = {31'b0, operand1 < operand2};
            ALU_XOR:  result = operand1 ^ operand2;
            ALU_SRL:  result = operand1 >> operand2[4:0];
            ALU_SRA:  result = $signed(operand1) >>> operand2[4:0];
            ALU_OR:   result = operand1 | operand2;
            ALU_AND:  result = operand1 & operand2;
            ALU_PASS: result = operand2;
            default:  result = '0;
        endcase
    end

endmodule

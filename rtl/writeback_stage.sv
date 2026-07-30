module writeback_stage #(
    parameter int DATA_WIDTH = 32
) (
    input  logic                  mem_to_reg,
    input  logic                  jump,       // jal || jalr
    input  logic [DATA_WIDTH-1:0] alu_result,
    input  logic [DATA_WIDTH-1:0] mem_rd_data,
    input  logic [DATA_WIDTH-1:0] pc_plus4,

    output logic [DATA_WIDTH-1:0] wb_data
);

    always_comb begin
        if (jump)             wb_data = pc_plus4;
        else if (mem_to_reg)  wb_data = mem_rd_data;
        else                  wb_data = alu_result;
    end

endmodule

module chip_top
  import brv32_pkg::*;
#(
    parameter int DATA_WIDTH = 32
) (
    input logic clk,
    input logic rst_n
);

    logic [DATA_WIDTH-1:0] pc;
    logic [DATA_WIDTH-1:0] pc_plus4;
    logic [DATA_WIDTH-1:0] instruction;
    logic                  pc_src;
    logic [DATA_WIDTH-1:0] pc_target;

    logic [DATA_WIDTH-1:0] rs1_data;
    logic [DATA_WIDTH-1:0] rs2_data;
    logic [DATA_WIDTH-1:0] imm;
    logic [4:0]            rd_addr;
    logic [2:0]            funct3;
    alu_op_t                alu_op;
    logic                  alu_src;
    logic                  mem_read;
    logic                  mem_write;
    logic                  reg_write;
    logic                  mem_to_reg;
    logic                  branch;
    logic                  jal;
    logic                  jalr;
    logic                  illegal;

    logic [DATA_WIDTH-1:0] alu_result;
    logic [DATA_WIDTH-1:0] mem_addr;
    logic [DATA_WIDTH-1:0] mem_wr_data;
    logic [DATA_WIDTH-1:0] mem_rd_data;
    logic [DATA_WIDTH-1:0] wb_data;

    fetch_stage #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_fetch (
        .clk        (clk),
        .rst_n      (rst_n),
        .pc_src     (pc_src),
        .pc_target  (pc_target),
        .pc         (pc),
        .pc_plus4   (pc_plus4),
        .instruction(instruction)
    );

    decode_stage #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_decode (
        .clk        (clk),
        .rst_n      (rst_n),
        .instruction(instruction),
        .wb_data    (wb_data),
        .rs1_data   (rs1_data),
        .rs2_data   (rs2_data),
        .imm        (imm),
        .rd_addr    (rd_addr),
        .funct3     (funct3),
        .alu_op     (alu_op),
        .alu_src    (alu_src),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .reg_write  (reg_write),
        .mem_to_reg (mem_to_reg),
        .branch     (branch),
        .jal        (jal),
        .jalr       (jalr),
        .illegal    (illegal)
    );

    execute_stage #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_execute (
        .rs1_data   (rs1_data),
        .rs2_data   (rs2_data),
        .imm        (imm),
        .pc         (pc),
        .alu_op     (alu_op),
        .alu_src    (alu_src),
        .funct3     (funct3),
        .branch     (branch),
        .jal        (jal),
        .jalr       (jalr),
        .alu_result (alu_result),
        .mem_addr   (mem_addr),
        .mem_wr_data(mem_wr_data),
        .pc_target  (pc_target),
        .pc_src     (pc_src)
    );

    memory_stage #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_memory (
        .clk      (clk),
        .addr     (mem_addr),
        .wr_data  (mem_wr_data),
        .funct3   (funct3),
        .mem_read (mem_read),
        .mem_write(mem_write),
        .rd_data  (mem_rd_data)
    );

    writeback_stage #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_writeback (
        .mem_to_reg (mem_to_reg),
        .jump       (jal || jalr),
        .alu_result (alu_result),
        .mem_rd_data(mem_rd_data),
        .pc_plus4   (pc_plus4),
        .wb_data    (wb_data)
    );

endmodule

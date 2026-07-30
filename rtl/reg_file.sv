// 32x32 register file
module reg_file #(
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [4:0]            rs1_addr,
    input  logic [4:0]            rs2_addr,
    input  logic [4:0]            rd_addr,
    input  logic [DATA_WIDTH-1:0] rd_data,
    input  logic                  reg_write,

    output logic [DATA_WIDTH-1:0] rs1_data,
    output logic [DATA_WIDTH-1:0] rs2_data
);

    logic [DATA_WIDTH-1:0] regs [32];

    assign rs1_data = (rs1_addr == 5'd0) ? '0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? '0 : regs[rs2_addr];

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            foreach (regs[i])
                regs[i] <= 32'b0;
        end else if (reg_write && rd_addr != 5'd0) begin
            regs[rd_addr] <= rd_data;
        end
    end

endmodule

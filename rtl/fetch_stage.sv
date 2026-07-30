module fetch_stage #(
    parameter int    DATA_WIDTH    = 32,
    parameter int    IMEM_DEPTH    = 2048,
    parameter string IMEM_INIT_FILE = ""
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  pc_src,     // 0: pc+4, 1: pc_target
    input  logic [DATA_WIDTH-1:0] pc_target,

    output logic [DATA_WIDTH-1:0] pc,
    output logic [DATA_WIDTH-1:0] pc_plus4,
    output logic [DATA_WIDTH-1:0] instruction
);

    logic [DATA_WIDTH-1:0] pc_q;
    logic [DATA_WIDTH-1:0] pc_next;

    assign pc        = pc_q;
    assign pc_plus4   = pc_q + 32'd4;
    assign pc_next    = pc_src ? pc_target : pc_plus4;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc_q <= '0;
        else        pc_q <= pc_next;
    end

    logic [DATA_WIDTH-1:0] imem [IMEM_DEPTH];

    initial begin
        if (IMEM_INIT_FILE != "") $readmemh(IMEM_INIT_FILE, imem);
    end

    assign instruction = imem[pc_q[$clog2(IMEM_DEPTH)+1:2]];

endmodule

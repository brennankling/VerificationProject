module memory_stage
  import brv32_pkg::*;
#(
    parameter int DATA_WIDTH = 32,
    parameter int MEM_DEPTH  = 4096
) (
    input  logic                  clk,
    input  logic [DATA_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic [2:0]            funct3,
    input  logic                  mem_read,
    input  logic                  mem_write,

    output logic [DATA_WIDTH-1:0] rd_data
);

    logic [DATA_WIDTH-1:0] mem [MEM_DEPTH];
    logic [DATA_WIDTH-1:0] raw_word;

    assign raw_word = mem[addr[$clog2(MEM_DEPTH)+1:2]];

    // synthesis translate_off
    always @(posedge clk) begin
        if (mem_read || mem_write) begin
            if (addr >= (MEM_DEPTH * 4)) begin
                $display("WARNING: out of bounds memory access at addr %h", addr);
            end
            if (funct3 == LW && addr[1:0] != 2'b00) begin
                $display("WARNING: misaligned word access at %h", addr);
            end
            if (funct3 == LH && addr[0] != 1'b0) begin
                $display("WARNING: misaligned halfword access at %h", addr);
            end
        end
    end
    // synthesis translate_on

    always_comb begin
        rd_data = raw_word;
        if (mem_read) begin
            case (funct3)
                LB: begin
                    case (addr[1:0])
                        2'b00: rd_data = {{24{raw_word[7]}},  raw_word[7:0]};
                        2'b01: rd_data = {{24{raw_word[15]}}, raw_word[15:8]};
                        2'b10: rd_data = {{24{raw_word[23]}}, raw_word[23:16]};
                        2'b11: rd_data = {{24{raw_word[31]}}, raw_word[31:24]};
                    endcase
                end
                LH: begin
                    rd_data = addr[1] ? {{16{raw_word[31]}}, raw_word[31:16]}
                                       : {{16{raw_word[15]}}, raw_word[15:0]};
                end
                LW: rd_data = raw_word;
                LBU: begin
                    case (addr[1:0])
                        2'b00: rd_data = {24'b0, raw_word[7:0]};
                        2'b01: rd_data = {24'b0, raw_word[15:8]};
                        2'b10: rd_data = {24'b0, raw_word[23:16]};
                        2'b11: rd_data = {24'b0, raw_word[31:24]};
                    endcase
                end
                LHU: begin
                    rd_data = addr[1] ? {16'b0, raw_word[31:16]} : {16'b0, raw_word[15:0]};
                end
                default: rd_data = raw_word;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (mem_write) begin
            case (funct3)
                SB: begin
                    case (addr[1:0])
                        2'b00: mem[addr[$clog2(MEM_DEPTH)+1:2]][7:0]   <= wr_data[7:0];
                        2'b01: mem[addr[$clog2(MEM_DEPTH)+1:2]][15:8]  <= wr_data[7:0];
                        2'b10: mem[addr[$clog2(MEM_DEPTH)+1:2]][23:16] <= wr_data[7:0];
                        2'b11: mem[addr[$clog2(MEM_DEPTH)+1:2]][31:24] <= wr_data[7:0];
                    endcase
                end
                SH: begin
                    case (addr[1])
                        1'b0: mem[addr[$clog2(MEM_DEPTH)+1:2]][15:0]  <= wr_data[15:0];
                        1'b1: mem[addr[$clog2(MEM_DEPTH)+1:2]][31:16] <= wr_data[15:0];
                    endcase
                end
                SW: mem[addr[$clog2(MEM_DEPTH)+1:2]] <= wr_data;
                default: ;
            endcase
        end
    end

endmodule

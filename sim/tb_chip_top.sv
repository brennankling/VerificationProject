// Self-checking smoke test for the single-cycle chip_top. Loads
// sim/prog.hex, runs to completion, and checks the register file.
// prog.hex is assembled from:
//
//   addi x1, x0, 5           # x1 = 5
//   addi x2, x0, 10          # x2 = 10
//   add  x3, x1, x2          # x3 = 15
//   sw   x3, 0(x0)           # mem[0] = 15
//   lw   x4, 0(x0)           # x4 = 15  (load-after-store)
//   beq  x0, x0, +8          # always taken, skips the next instruction
//   addi x5, x0, 999         # skipped, x5 must stay untouched
//   addi x6, x0, 42          # branch target, x6 = 42
//
// Run with sim/run_smoke_test.sh.
module tb_chip_top;

    logic clk = 0;
    logic rst_n = 0;

    chip_top #(.DATA_WIDTH(32)) dut (
        .clk  (clk),
        .rst_n(rst_n)
    );

    always #5 clk = ~clk;

    int errors = 0;

    task automatic check(string name, logic [31:0] actual, logic [31:0] expected);
        if (actual !== expected) begin
            $display("FAIL: %s = %0d, expected %0d", name, actual, expected);
            errors++;
        end else begin
            $display("PASS: %s = %0d", name, actual);
        end
    endtask

    initial begin
        $readmemh("prog.hex", dut.u_fetch.imem);

        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;

        // One instruction retires per cycle in a single-cycle datapath, so
        // 8 instructions means exactly 8 cycles before checking state.
        repeat (8) @(posedge clk);

        check("x1 (addi)",             dut.u_decode.u_reg_file.regs[1], 32'd5);
        check("x2 (addi)",             dut.u_decode.u_reg_file.regs[2], 32'd10);
        check("x3 (add)",              dut.u_decode.u_reg_file.regs[3], 32'd15);
        check("x4 (load-after-store)", dut.u_decode.u_reg_file.regs[4], 32'd15);
        check("x6 (branch target)",    dut.u_decode.u_reg_file.regs[6], 32'd42);
        check("pc (end of program)",   dut.pc,                          32'd36);

        if (dut.u_decode.u_reg_file.regs[5] !== 32'h0) begin
            $display("FAIL: x5 was written but the branch should have skipped it");
            errors++;
        end else begin
            $display("PASS: x5 untouched (branch correctly skipped over it)");
        end

        if (errors == 0) $display("ALL TESTS PASSED");
        else              $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule

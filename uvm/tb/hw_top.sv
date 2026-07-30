module hw_top;

  logic clk;
  logic rst_n;

  // clkgen module generates clock
  clkgen clkgen (
    .clock(clk),
    .run_clock(1'b1),
    .clock_period(32'd10)
  );

  chip_top dut (
    .clk  (clk),
    .rst_n(rst_n)
  );

  // computa_if expects an active-high reset; chip_top's rst_n is
  // active-low, so invert at the boundary. chip_top has no ports besides
  // clk/rst_n, so every other tap is wired here via the dut's internal nets
  computa_if in0 (
    .clock      (clk),
    .reset      (~rst_n),
    .pc         (dut.pc),
    .instruction(dut.instruction),
    .regs       (dut.u_decode.u_reg_file.regs),
    .mem_addr   (dut.mem_addr),
    .mem_wr_data(dut.mem_wr_data),
    .mem_rd_data(dut.mem_rd_data),
    .mem_read   (dut.mem_read),
    .mem_write  (dut.mem_write)
  );

  initial begin
    rst_n <= 1'b1;
    @(negedge clk)
      #1 rst_n <= 1'b0;
    @(negedge clk)
      #1 rst_n <= 1'b1;
  end

endmodule

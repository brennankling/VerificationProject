// chip_top exposes only clk/rst_n, so there is no instruction/data bus to
// drive or monitor. This interface carries architectural-state taps
// (pc, regfile, memory access) instead of a streaming protocol. Those taps
// are wired to dut's internal nets at the hw_top instantiation site, since
// hw_top is dut's parent and can legally reference them by hierarchical
// name without any RTL changes.
interface computa_if (
    input logic        clock,
    input logic        reset,        // active-high (chip_top's rst_n inverted at instantiation)

    input logic [31:0] pc,
    input logic [31:0] instruction,
    input logic [31:0] regs        [32],

    input logic [31:0] mem_addr,
    input logic [31:0] mem_wr_data,
    input logic [31:0] mem_rd_data,
    input logic        mem_read,
    input logic        mem_write
);
timeunit 1ns;
timeprecision 100ps;

    // Backdoor-load a program image into instruction memory. $readmemh
    // requires a statically-resolvable hierarchical name, which only a
    // module (not a UVM class) can reference, which is why this lives
    // here instead of in the driver. Path is hardcoded to this
    // testbench's top-level instance names (hw_top/dut); update it if the
    // tb hierarchy changes.
    task automatic load_imem(string hexfile);
        $readmemh(hexfile, hw_top.dut.u_fetch.imem);
    endtask : load_imem

    // Debug-only readback of a single imem word, to independently confirm
    // a backdoor load actually landed in the DUT instance the monitor
    // reads from 
    function automatic bit [31:0] read_imem(int idx);
        return hw_top.dut.u_fetch.imem[idx];
    endfunction : read_imem

endinterface : computa_if

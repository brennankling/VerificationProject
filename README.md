# computa_single_cycle

A single-cycle implementation of a subset of RV32I: the integer ALU ops,
loads/stores, branches, and jumps that make up the bulk of the base ISA,
with no CSR/privileged state, no traps or interrupts, and no
M-extension. Every instruction fetches, decodes, executes, accesses
memory, and writes back within one clock period; there are no pipeline
registers, and therefore no hazards to detect, no stalling, no
forwarding, and no flushing, exactly one instruction is ever in flight.

## Instruction set

Covers the RV32I base integer ISA's data-processing and control-flow
instructions:

- ALU reg-reg and reg-imm ops (`ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND`,
  and their `I`-suffixed immediate forms)
- `LUI`, `AUIPC`
- `JAL`, `JALR`
- Branches: `BEQ/BNE/BLT/BGE/BLTU/BGEU`
- Loads: `LB/LH/LW/LBU/LHU`
- Stores: `SB/SH/SW`
- `FENCE` and `SYSTEM` (`ECALL`/`EBREAK`/CSR ops) decode and execute as
  no-ops. There's no trap, interrupt, or CSR support in this core.

No M-extension (multiply/divide) and no privileged/CSR state.

## Architecture

`rtl/chip_top.sv` wires five combinational stages in series between two
state elements (the PC and the register file/data memory keep the only
flip-flops in the design):

![Datapath: Fetch, Decode, Execute, Memory, Writeback in series, with decode's control signals fanning out combinationally to Execute/Memory/Writeback, an Execute-to-Fetch feedback path for next-PC selection, and a Writeback-to-Decode feedback path for the register file write.](docs/architecture.png)

| File | Responsibility |
|---|---|
| `rtl/pkg/brv32_pkg.sv` | Opcode/funct3/ALU-op/immediate-type enums shared by every stage |
| `rtl/fetch_stage.sv` | PC register + async-read instruction memory. `pc_src`/`pc_target` select the next PC (branch/jump target vs. `pc+4`) |
| `rtl/decode_stage.sv` | Register file read, immediate generation, and control-signal decode for every RV32I opcode |
| `rtl/execute_stage.sv` | ALU, branch condition evaluation, and JAL/JALR/branch target computation |
| `rtl/memory_stage.sv` | Byte/half/word-addressable data memory (async read, sync write) |
| `rtl/writeback_stage.sv` | Selects what gets written back to the register file: ALU result, loaded data, or `pc+4` (for `JAL`/`JALR`) |
| `rtl/reg_file.sv` | 32x32 register file, x0 hardwired to zero |
| `rtl/alu.sv` | Combinational ALU |

Register writes and data-memory writes both commit on the clock edge;
everything else in the datapath is `always_comb`. Instruction and data
memory reads are asynchronous (address in, data out, same cycle), which is
what lets a whole instruction complete in one clock period.

## Testing

Two separate testbenches exist: a plain Icarus Verilog smoke test
(`sim/`, this section) and a full UVM environment with a Spike-based
golden reference model and coverage collection (`uvm/`, see
[UVM Verification Environment](#uvm-verification-environment) below).

The Icarus smoke test uses plain Icarus Verilog (`iverilog`/`vvp`), no
other toolchain is required.

### Run the smoke test

```sh
sim/run_smoke_test.sh
```

Expect `ALL TESTS PASSED`. (Icarus prints a handful of harmless `sorry:
constant selects in always_* processes are not currently supported`
notices during compilation, a known Icarus limitation with
constant-indexed bit selects inside `always_comb`/`always_ff`, not a
design error; the affected expressions still simulate correctly.)

`sim/tb_chip_top.sv` loads `sim/prog.hex` into instruction memory, runs it
to completion, and checks the register file and PC against expected
values. `sim/prog.hex` is the machine code for:

```asm
addi x1, x0, 5           # x1 = 5
addi x2, x0, 10          # x2 = 10
add  x3, x1, x2          # x3 = 15
sw   x3, 0(x0)           # mem[0] = 15
lw   x4, 0(x0)           # x4 = 15  (load-after-store)
beq  x0, x0, +8          # always taken, skips the next instruction
addi x5, x0, 999         # skipped, x5 must stay untouched
addi x6, x0, 42          # branch target, x6 = 42
```

This exercises reg-imm ALU ops, reg-reg ALU ops, store-then-load through
data memory, and a taken branch that redirects the PC and skips an
instruction.

### Writing a new test program

1. Assemble RV32I instructions to 32-bit hex words, one per line (an
   assembler like a RISC-V GCC/binutils toolchain with `objcopy -O
   verilog`, or a hand-rolled encoder, both work; there's no assembler
   in this repo).
2. Point `$readmemh` in a testbench at your hex file, e.g.
   `$readmemh("my_prog.hex", dut.u_fetch.imem);`.
3. Drive `clk`/`rst_n` as in `tb_chip_top.sv`, run for at least as many
   cycles as instructions you expect to retire (one instruction commits
   per cycle), then inspect state directly through hierarchical
   references:
   - Registers: `dut.u_decode.u_reg_file.regs[N]`
   - Data memory: `dut.u_memory.mem[word_addr]`
   - PC: `dut.pc`

### Waveform debugging

To dump a VCD for viewing in GTKWave, add to the testbench initial block:

```verilog
initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_chip_top);
end
```

## UVM Verification Environment

`uvm/` is a separate, full UVM testbench that constrained-randomly
generates programs, backdoor-loads them into the DUT, and checks every
retired instruction against [Spike](https://github.com/riscv-software-src/riscv-isa-sim)
(the reference RISC-V ISA simulator) acting as a golden model, plus
functional/code coverage collection. Unlike the Icarus smoke test above,
this requires Cadence Xcelium (`xrun`).

### Layout

| Path | Responsibility |
|---|---|
| `uvm/sv/computa_pkg.sv` | Package that `` `include``s everything below, in dependency order |
| `uvm/sv/computa_instruction.sv` | Randomizable per-format instruction classes (one per RV32I encoding) |
| `uvm/sv/computa_seqs.sv` | Sequences (`addi_seq`, `addi_extensive_seq`, `register_seq`, ...) that generate programs from those classes |
| `uvm/sv/computa_driver.sv` | Assembles a sequence's items into a hex program, backdoor-loads it into `imem` |
| `uvm/sv/computa_monitor.sv` | Samples the DUT after each retiring instruction (PC, instruction, register/memory changes) |
| `uvm/sv/computa_retire_txn.sv` | The architectural-state snapshot type the monitor publishes, shaped to compare directly against a Spike commit-log entry |
| `uvm/sv/computa_scoreboard.sv` | Runs Spike over the same program and diffs its commit log against the monitor's transactions, in order |
| `uvm/sv/computa_coverage.sv` | Functional coverage: opcode/ALU-op/branch/load/store diversity and operand corner cases (`x0`, aliasing) |
| `uvm/sv/computa_env.sv` / `computa_agent.sv` | Wires the above together |
| `uvm/tb/tb_top.sv`, `hw_top.sv`, `clkgen.sv` | Top-level module, DUT instantiation + reset generation, clock generation |
| `uvm/tb/cpu_test_lib.sv` | Test classes (`base_test`, `addi_test`, `addi_extensive_test`, `register_test`) |
| `uvm/tb/run.f` | `xrun` compile/elaborate/run file; test and coverage selection live here |
| `uvm/tb/Makefile` | Single-command wrapper around everything in this section |
| `uvm/tb/spike_ref.py` | Builds a minimal ELF around a hex program, runs Spike, emits a trace the scoreboard can parse |
| `uvm/tb/imc_report.tcl`, `imc_merge.tcl` | Batch (no-GUI) coverage report/merge scripts for IMC |

### One-time setup: Spike

The scoreboard needs a working Spike install; there's no package for it
on most systems, so it's built from source into `~/.local/spike`, patched to 
relocate Spike's hardcoded debug-module reservation off address `0x0` (this core
resets its PC to `0`, which Spike would otherwise refuse to place memory
at). No `sudo` is required. See `scripts/install_spike.sh` for exactly
what it does and why.

```sh
make -C uvm/tb install-spike
# or directly:
bash scripts/install_spike.sh
```

### Running a test

```sh
cd uvm/tb
make sim TEST=addi_test
```

| `TEST=` | Sequence | Instructions | What it exercises |
|---|---|---|---|
| `base_test` | none (no default sequence) | n/a | Elaboration/topology sanity check only |
| `addi_test` | `addi_seq` | 1 | A single randomized `ADDI` |
| `addi_extensive_test` | `addi_extensive_seq` | 103 | `ADDI` directed corner cases (`rd==0`, `rs1==0`, `imm==0`) + 100 randomized |
| `register_test` | `register_seq` | 222 | Every R-type ALU op directed once; all 7 operand corner cases (`x0`, aliasing) x all 10 ops; shift-by-0/shift-by-31 corners for `SLL`/`SRL`/`SRA`; a register preload phase so operands aren't all still `0` from reset; 100 randomized |

`make sim` rewrites `run.f`'s `+UVM_TESTNAME`/`-covtest` lines to match
`TEST` before invoking `xrun -uvm -uvmnocdnsextra -f run.f`. This is
exactly what used to be a manual two-line edit in `run.f` for every test
switch (`-covtest` has to track `UVM_TESTNAME`, or `-covoverwrite` will
silently clobber the wrong test's coverage snapshot). Editing `run.f` by
hand still works identically if you'd rather not use `make`.

Each run's coverage snapshot lands at `uvm/tb/cov_work/scope/<TEST>/`,
independent of every other test's snapshot.

### How correctness is checked

`computa_scoreboard.sv` waits for the driver to backdoor-load a program
and reset to drop, shells out to `spike_ref.py` to run that exact program
on Spike, and parses Spike's commit log into a queue of expected
transactions. As the monitor publishes each real retired instruction, the
scoreboard pops the next expected one and compares PC, instruction word,
register writes, and memory access, in order, one-to-one. See
`computa_retire_txn.sv`'s header comment and `computa_scoreboard.sv` for
the full mechanics.

### Coverage

```sh
make coverage-report TEST=register_test   # ./register_test_report.txt
make coverage-merge                       # ./cov_work/cov_merged_report.txt
make coverage-gui TEST=register_test      # opens that test's snapshot in the IMC GUI
make coverage-gui DB=./cov_work/cov_merged  # ...or the merged database
```

All three shell out to `imc` via the `Makefile`'s `IMC` variable, which defaults 
to this project's current server path. That path is installation-specific; if `imc` 
lives elsewhere on your machine, override it: `make coverage-report TEST=... IMC=/path/to/imc`.

`coverage-report` requires that test to have already been run (`make sim
TEST=...`). `coverage-merge` combines whichever tests are listed in
`uvm/tb/imc_merge.tcl`'s `TESTS` variable. Edit that list directly to
add more tests to the merge as you write them; it's a persistent, growing
list, unlike the single `TEST=` a `make sim`/`coverage-report` invocation
picks. `coverage-gui` needs X11 forwarding.

Report output shows one line per coverpoint bin with a hit count and
coverage percentage; a bin's absence from a plain `report -detail`
listing (without `-both`, which `imc_report.tcl`/`imc_merge.tcl` already
pass) means it's fully covered, not that it's missing. The report
defaults to listing only what still needs attention.

### Writing a new sequence/test

1. In `computa_seqs.sv`, give the sequence a
   `parameter int unsigned NUM_INSTRUCTIONS = <N>;` matching however many
   items its `body()` generates. This is the single source of truth
   `program_size` gets derived from everywhere else.
2. In `cpu_test_lib.sv`, add a test class mirroring `addi_test`: set
   `program_size = your_seq::NUM_INSTRUCTIONS;` *before* calling
   `super.build_phase()`, and point `default_sequence` at the new
   sequence type. `base_test::build_phase` automatically propagates
   `program_size` into `config_db` for the driver/monitor/scoreboard from
   there, no separate `uvm_config_db::set` needed.
3. Add a commented `+UVM_TESTNAME=your_test` line to `run.f`'s
   test-selector block, and the test name to `VALID_TESTS` in
   `uvm/tb/Makefile`.

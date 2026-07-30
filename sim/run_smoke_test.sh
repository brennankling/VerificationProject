#!/usr/bin/env bash
# Builds and runs the chip_top smoke test with Icarus Verilog.
set -euo pipefail
cd "$(dirname "$0")"

iverilog -g2012 -o sim.out -I ../rtl \
  ../rtl/pkg/brv32_pkg.sv ../rtl/alu.sv ../rtl/reg_file.sv \
  ../rtl/fetch_stage.sv ../rtl/decode_stage.sv ../rtl/execute_stage.sv \
  ../rtl/memory_stage.sv ../rtl/writeback_stage.sv ../rtl/chip_top.sv \
  tb_chip_top.sv

vvp sim.out

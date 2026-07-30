#!/usr/bin/env python3
"""Golden-reference trace generator for computa_scoreboard.sv.

Takes the same hex program computa_driver.sv backdoor-loads into the DUT
(one 32-bit instruction word per line), replays it on Spike, and re-emits
Spike's commit log as a small fixed-format trace that computa_scoreboard
can $fscanf without needing to understand Spike's native log syntax.

Usage: spike_ref.py --hex <program.hex> --n <instr_count> --out <trace_path>
                     [--spike <path to spike binary>]

Output format: one line per retired instruction,
    <pc_hex> <instr_hex> <has_rd> <rd_idx> <rd_val_hex> <mem_valid> <mem_addr_hex> <mem_data_hex>
All fields are always present (zeros where not applicable) so the line
shape is fixed regardless of instruction kind.
"""

import argparse
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

# scripts/install_spike.sh's default install prefix, checked here as a
# fallback so this script works out of the box even if the caller (e.g.
# Xcelium's $system(), invoked from computa_scoreboard.sv) doesn't have
# it on PATH.
DEFAULT_SPIKE_FALLBACK = os.path.expanduser("~/.local/spike/bin/spike")


def find_spike(explicit):
    if explicit:
        return explicit
    if shutil.which("spike"):
        return "spike"
    if os.path.exists(DEFAULT_SPIKE_FALLBACK):
        return DEFAULT_SPIKE_FALLBACK
    sys.exit(
        "spike_ref.py: can't find a spike binary on PATH or at "
        f"{DEFAULT_SPIKE_FALLBACK}. Run scripts/install_spike.sh first"
    )

# This core (rtl/fetch_stage.sv) resets pc to 0 and has no CSR/privileged
# state, but Spike unconditionally maps its debug module at physical
# address 0x0 (riscv/platform.h's DEBUG_START), a hardcoded constant,
# not a runtime flag. scripts/install_spike.sh builds Spike from a patched
# source tree that relocates DEBUG_START/DEFAULT_RSTVEC out of low memory
# so address 0 is free for our own program, matching the DUT's own
# zero-based addressing exactly (no PC-offset bookkeeping needed for
# AUIPC/JAL/JALR results).
MEM_BASE = 0x0
MEM_SIZE = 0x4000  # 16 KiB, comfortably covers fetch_stage's IMEM_DEPTH (2048 words = 8 KiB)

EHDR_SIZE = 52
PHDR_SIZE = 32
SHDR_SIZE = 40

COMMIT_RE = re.compile(
    r"^core\s+\d+:\s+\d+\s+0x([0-9a-fA-F]+)\s+\(0x([0-9a-fA-F]+)\)\s*(.*)$"
)
REG_RE = re.compile(r"\bx(\d+)\s+0x([0-9a-fA-F]+)")
MEM_RE = re.compile(r"\bmem\s+0x([0-9a-fA-F]+)(?:\s+0x([0-9a-fA-F]+))?")


def read_hex_words(hexfile):
    words = []
    with open(hexfile) as f:
        for line in f:
            line = line.strip()
            if line:
                words.append(int(line, 16))
    return words


def build_elf(words, elf_path):
    """Wraps raw instruction words in a minimal bare-metal RV32 ELF with
    entry point 0x0. No riscv*-elf toolchain is assumed to be available,
    so this hand-rolls just enough ELF (one PT_LOAD segment, plus the
    null/.shstrtab section pair Spike's loader asserts on) to satisfy
    fesvr's elfloader."""
    data = b"".join(struct.pack("<I", w) for w in words)

    phdr_off = EHDR_SIZE
    data_off = phdr_off + PHDR_SIZE
    shstrtab_data = b"\x00.shstrtab\x00"
    shstrtab_off = data_off + len(data)
    shdr_off = shstrtab_off + len(shstrtab_data)

    e_ident = b"\x7fELF" + bytes([1, 1, 1, 0]) + b"\x00" * 8
    ehdr = e_ident + struct.pack(
        "<HHIIIIIHHHHHH",
        2,          # e_type = ET_EXEC
        0xF3,       # e_machine = EM_RISCV
        1,          # e_version
        0x0,        # e_entry
        phdr_off,   # e_phoff
        shdr_off,   # e_shoff
        0,          # e_flags
        EHDR_SIZE,  # e_ehsize
        PHDR_SIZE,  # e_phentsize
        1,          # e_phnum
        SHDR_SIZE,  # e_shentsize
        2,          # e_shnum (null + .shstrtab)
        1,          # e_shstrndx
    )

    phdr = struct.pack(
        "<IIIIIIII",
        1,          # p_type = PT_LOAD
        data_off,   # p_offset
        0x0,        # p_vaddr
        0x0,        # p_paddr
        len(data),  # p_filesz
        len(data),  # p_memsz
        7,          # p_flags = RWX
        0x1000,     # p_align
    )

    shdr_null = b"\x00" * SHDR_SIZE
    shdr_shstrtab = struct.pack(
        "<IIIIIIIIII",
        1, 3, 0, 0, shstrtab_off, len(shstrtab_data), 0, 0, 1, 0,
    )

    with open(elf_path, "wb") as f:
        f.write(ehdr)
        f.write(phdr)
        f.write(data)
        f.write(shstrtab_data)
        f.write(shdr_null)
        f.write(shdr_shstrtab)


def run_spike(spike_bin, elf_path, n_instr):
    cmd = [
        spike_bin,
        "--isa=rv32i",
        "--priv=m",
        f"-m{MEM_BASE}:{hex(MEM_SIZE)}",
        "--pc=0",
        "--log-commits",
        f"--instructions={n_instr}",
        "--disable-dtb",
        str(elf_path),
    ]
    # capture_output=/text= (subprocess.run kwargs) need Python 3.7+; the
    # gatech server's system python3 is 3.6, so use the equivalent
    # stdout=/stderr=PIPE + universal_newlines= that's been there since 3.x.
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             universal_newlines=True)
    return result.stderr


def parse_commits(log_text, n_instr):
    entries = []
    # computa_monitor.sv has no reg_write/rd_addr tap, only the raw regs[]
    # value array (see computa_if.sv), so it infers changed_regs by
    # diffing consecutive register-file snapshots, not from "was this
    # register architecturally the destination." Spike's commit log always
    # logs the destination register on any rd!=0 instruction, even when
    # the computed value happens to equal what was already there (e.g.
    # "addi x5, x0, 0" when x5 is already 0). Those two definitions
    # disagree exactly in that case, so this shadow register file
    # replicates the monitor's value-diff semantics here: has_rd only
    # ends up true when the value actually changes, matching what the DUT
    # will really report. Starts at 0 to match reg_file.sv's reset value.
    shadow_regs = [0] * 32
    for line in log_text.splitlines():
        m = COMMIT_RE.match(line)
        if not m:
            continue
        pc = int(m.group(1), 16)
        instr = int(m.group(2), 16)
        tail = m.group(3)

        has_rd, rd_idx, rd_val = 0, 0, 0
        reg_m = REG_RE.search(tail)
        if reg_m:
            rd_idx = int(reg_m.group(1))
            rd_val = int(reg_m.group(2), 16)
            has_rd = 1 if rd_val != shadow_regs[rd_idx] else 0
            shadow_regs[rd_idx] = rd_val

        mem_valid, mem_addr, mem_data = 0, 0, 0
        mem_m = MEM_RE.search(tail)
        if mem_m:
            mem_valid = 1
            mem_addr = int(mem_m.group(1), 16)
            # Stores log their data inline ("mem <addr> <data>"); loads
            # only log the address since the loaded (already
            # sign/zero-extended) value is the register write above,
            # matches memory_stage.sv's rd_data, which is what
            # computa_monitor.sv records as mem_data for loads too.
            mem_data = int(mem_m.group(2), 16) if mem_m.group(2) else rd_val

        entries.append((pc, instr, has_rd, rd_idx, rd_val, mem_valid, mem_addr, mem_data))
        if len(entries) >= n_instr:
            break
    return entries


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hex", required=True)
    ap.add_argument("--n", type=int, required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--spike", default=None)
    args = ap.parse_args()

    spike_bin = find_spike(args.spike)
    words = read_hex_words(args.hex)

    with tempfile.TemporaryDirectory() as tmp:
        elf_path = Path(tmp) / "prog.elf"
        build_elf(words, elf_path)
        log_text = run_spike(spike_bin, elf_path, args.n)

    entries = parse_commits(log_text, args.n)

    if len(entries) < args.n:
        print(
            f"spike_ref.py: warning: only {len(entries)}/{args.n} instructions "
            "retired before Spike stopped (trap or program too short)",
            file=sys.stderr,
        )

    with open(args.out, "w") as f:
        for pc, instr, has_rd, rd_idx, rd_val, mem_valid, mem_addr, mem_data in entries:
            f.write(
                f"{pc:08x} {instr:08x} {has_rd} {rd_idx} {rd_val:08x} "
                f"{mem_valid} {mem_addr:08x} {mem_data:08x}\n"
            )


if __name__ == "__main__":
    main()

#!/usr/bin/env bash
# Builds and installs Spike (github.com/riscv-software-src/riscv-isa-sim)
# from source into a user-local prefix. No sudo required, only needs a
# C++ toolchain (gcc/g++/make), which is standard on any dev box.
#
# Usage: scripts/install_spike.sh [install_prefix]
# Default install_prefix: $HOME/.local/spike

set -euo pipefail

PREFIX="${1:-$HOME/.local/spike}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$PREFIX/bin"

# Spike's configure requires `dtc` (device-tree-compiler) on PATH at build
# time. If it's not already installed system-wide and there's no sudo
# available, grab just the binary out of the package. Downloading a
# package (without installing it) doesn't require root on either
# apt-based or dnf/yum-based systems, only actually installing it does.
if ! command -v dtc >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    echo "dtc not found on PATH; fetching it without sudo via apt-get download"
    ( cd "$WORKDIR" \
      && apt-get download device-tree-compiler \
      && dpkg-deb -x device-tree-compiler_*.deb extracted \
      && cp extracted/usr/bin/dtc "$PREFIX/bin/dtc" )
  elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
    echo "dtc not found on PATH; fetching it without sudo via dnf/yum download"
    (
      cd "$WORKDIR"
      if command -v dnf >/dev/null 2>&1 && dnf download dtc; then
        :
      elif command -v yumdownloader >/dev/null 2>&1 && yumdownloader dtc; then
        :
      else
        echo "error: both 'dnf download dtc' and 'yumdownloader dtc' failed, see output above for why (missing repo, no network, needs auth, etc.)" >&2
        exit 1
      fi
      rpm2cpio dtc-*.rpm | cpio -idm
      cp usr/bin/dtc "$PREFIX/bin/dtc"
    )
  else
    echo "error: no apt-get or dnf/yum found; can't fetch dtc without sudo." >&2
    echo "Either ask someone with root to install device-tree-compiler/dtc," >&2
    echo "or install it yourself if you do have sudo, then re-run this script." >&2
    exit 1
  fi
fi
export PATH="$PREFIX/bin:$PATH"

echo "Building Spike into $PREFIX"

git clone --depth 1 https://github.com/riscv-software-src/riscv-isa-sim.git "$WORKDIR/riscv-isa-sim"

# This core (rtl/fetch_stage.sv) resets pc to 0 and has no CSR/privileged
# state, but Spike unconditionally maps its debug module at physical
# address 0x0 (DEBUG_START in platform.h) regardless of any command-line
# flag, so a memory region could never be placed at address 0 without this
# patch. Relocate DEBUG_START (and DEFAULT_RSTVEC, the tiny boot-rom stub)
# out of low memory so address 0 is free, matching the DUT's own
# addressing exactly with no offset bookkeeping needed anywhere.
sed -i \
  -e 's/#define DEFAULT_RSTVEC     0x00001000/#define DEFAULT_RSTVEC     0x00101000/' \
  -e 's/#define DEBUG_START        0x0/#define DEBUG_START        0x00100000/' \
  "$WORKDIR/riscv-isa-sim/riscv/platform.h"

mkdir -p "$WORKDIR/riscv-isa-sim/build"
cd "$WORKDIR/riscv-isa-sim/build"

../configure --prefix="$PREFIX"
make -j"$(nproc)"
make install

echo
echo "Spike installed to $PREFIX/bin/spike"
echo "Add it to your PATH:"
echo "  export PATH=\"$PREFIX/bin:\$PATH\""

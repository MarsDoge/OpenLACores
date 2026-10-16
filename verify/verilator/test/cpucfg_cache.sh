#!/usr/bin/env bash
# SPDX-License-Identifier: MulanPSL-2.0
# CPUCFG cache parameter matrix test. Requires Icarus Verilog; override IVERILOG/VVP.
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
test_build=$(mktemp -d)
trap 'rm -rf "$test_build"' EXIT
cd "$root"
"${IVERILOG:-iverilog}" -g2012 -I design/sys/openla132/include \
    -s cpucfg_cache_tb -o "$test_build/test.vvp" \
    design/sys/openla132/csr/csr_cpucfg.v verify/verilator/test/cpucfg_cache_tb.v
"${VVP:-vvp}" "$test_build/test.vvp"

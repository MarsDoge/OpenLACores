#!/usr/bin/env bash
# SPDX-License-Identifier: MulanPSL-2.0
# Full-core boot ROM test. Requires Icarus Verilog; override IVERILOG/VVP.
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
test_build=$(mktemp -d)
trap 'rm -rf "$test_build"' EXIT
cd "$root"
"${IVERILOG:-iverilog}" -g2012 -DOPEN132_OUTPUT_WB_STATE \
    -DOPEN132_DATA_PATH_RESET -s cpucfg_boot_tb \
    -o "$test_build/test.vvp" -f design/filelist/openla132.f \
    verify/verilator/test/cpucfg_boot_tb.v
"${VVP:-vvp}" "$test_build/test.vvp"

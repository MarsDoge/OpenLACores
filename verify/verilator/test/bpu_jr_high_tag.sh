#!/usr/bin/env bash
# SPDX-License-Identifier: MulanPSL-2.0
# Run the standalone BPU regression; requires Icarus Verilog.
# Override tool paths with IVERILOG and VVP if needed.
set -euo pipefail

root=$(cd "$(dirname "$0")/../../.." && pwd)
test_build=$(mktemp -d)
trap 'rm -rf "$test_build"' EXIT
ifu="$root/design/sys/openla132/ifu"

"${IVERILOG:-iverilog}" -g2012 -s bpu_jr_high_tag_tb \
    -I "$root/design/sys/openla132/include" \
    -o "$test_build/test.vvp" \
    "$root/verify/verilator/test/bpu_jr_high_tag_tb.v" \
    "$ifu/ifu_bpu.v" "$ifu/ifu_first1_n.v" "$ifu/ifu_plru2.v" \
    "$ifu/ifu_dec4_16.v" "$ifu/ifu_enc_n_m.v"
"${VVP:-vvp}" "$test_build/test.vvp"

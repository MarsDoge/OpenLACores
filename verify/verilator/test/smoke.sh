#!/usr/bin/env bash
set -euo pipefail

emu=${1:?missing Verilator executable}
image=${2:?missing test image}
reference=${3:?missing reference model}
checkpoint=$(mktemp /tmp/openla132s-verilator-smoke.XXXXXX)
elf64=$(mktemp /tmp/openla132s-verilator-elf64.XXXXXX)
trap 'rm -f "${checkpoint}" "${elf64}"' EXIT

"${emu}" --help >/dev/null
"${emu}" --no-diff --image "${image}" --ref /reference/is/not/needed \
    --max-cycles 200000 --max-commits 16 --quiet-uart
"${ELF64_OBJCOPY:-loongarch64-linux-gnu-objcopy}" -O elf64-loongarch "${image}" "${elf64}"
"${emu}" --no-diff --image "${elf64}" --max-cycles 200000 \
    --max-commits 1 --quiet-uart
"${emu}" --diff --image "${image}" --ref "${reference}" \
    --max-cycles 500000 --max-commits 64 --quiet-uart
"${emu}" --diff --image "${image}" --ref "${reference}" \
    --max-cycles 500000 --max-commits 96 --quiet-uart \
    --checkpoint "${checkpoint}" --checkpoint-interval 1000000
"${emu}" --diff --restore "${checkpoint}" --ref "${reference}" \
    --max-cycles 500000 --max-commits 32 --quiet-uart

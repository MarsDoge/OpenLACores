# OpenLACores Verilator Simulation Environment

This directory provides a standalone Verilator simulator. It directly
instantiates `openla132_ip_top` and does not depend on the other simulation
top level, generated bus models, or C++ runtime framework.

## Components

- `vsrc/verilator_top.sv`: Preserves the CPU-native 32-bit AXI interface and
  exports stable writeback probes.
- `vsrc/soc_config.vh`: Defines the local instruction/data SRAM windows and
  the UART MMIO address.
- `vsrc/sram/openla132_spram_bytemask_init.v`: Byte-write SRAM model that can
  be initialized by the simulator.
- `src/axi.cpp`: A 32-bit AXI slave supporting multiple outstanding IDs and bursts.
- `src/ram.cpp`: A sparse, demand-paged memory model.
- `src/uart.cpp`: A minimal 16550 UART model at `0x1fe00000`.
- `src/elf_load.cpp`: ELF32/ELF64 LoongArch and raw-binary loader that
  automatically clears the BSS in `PT_LOAD` segments.
- `src/ref_proxy.cpp`: Calls the loong-emu DiffTest ABI through `dlopen`.
- `src/difftest.cpp`, `src/check.cpp`: Processor-independent commit
  execution and architectural-state comparison.
- `src/diff_micro.cpp`: ：OpenLA132 policy for multi-micro-operation instructions,
  implementation-specific CSRs, timers, and exception boundaries.
- `src/checkpoint.cpp`: Saves and restores RTL, AXI, RAM, UART, DiffTest, and
  reference-model state.
- `src/verilator_main.cpp`: Controls clocking, reset, waveform generation,
  exit markers, and statistics.

## Build

First prepare the reference model:

```bash
make -C verify/loong-emu DIFF=1
```

Build the Verilator simulator:

```bash
make -C verify/verilator
```

Build products encode both configuration values in their names, for example
`verify/verilator/build/emu-mmu1-sram0` for the default AXI configuration and
`verify/verilator/build/emu-mmu0-sram1` for the local-SRAM configuration. Each
combination has an independent Verilator object directory. 

```bash
make -C verify/verilator CONFIG_MMU=1
make -C verify/verilator CONFIG_MMU=0
make -C verify/verilator CONFIG_MMU=0 CONFIG_SRAM=1
```

## Run

DiffTest is enabled by default:

```bash
verify/verilator/build/emu-mmu1-sram0 \
  --diff \
  --image verify/apps/coremark/coremark.exe
```

Disable DiffTest to run only the RTL, AXI memory, and UART models:

```bash
verify/verilator/build/emu-mmu1-sram0 \
  --no-diff \
  --image verify/apps/coremark/coremark.exe
```

Makefile shortcut targets are also available:

```bash
make -C verify/verilator run
make -C verify/verilator run-nodiff
make -C verify/verilator run-coremark-sram
make -C verify/verilator run-rtthread-sram
make -C verify/verilator run-rtthread-axi
```

`run-coremark-sram` selects `CONFIG_MMU=0 CONFIG_SRAM=1`, routing instruction
and data accesses through `inst_sram_*`/`data_sram_*` instead of the system AXI
memory path.

Keep the RT-Thread Nano sources locally at `verify/kernel/RTThread_Nano`; 
`run-rtthread-sram` first builds that directory and then boots it
with the same `CONFIG_MMU=0 CONFIG_SRAM=1` configuration. The simulation top
loads the ELF instruction segment at `0x1c000000` and the data segment at
`0x15000000` into separate SRAM arrays. The system tick uses the CPU-local CSR
timer and does not drive `ext_int`. This target builds an independent
`obj/sram/RTThread_Nano.elf` with `HAS_CACHE=0`.

`run-rtthread-axi` also builds RT-Thread first, then selects
`CONFIG_MMU=1 CONFIG_SRAM=0` so memory and simulator peripherals are accessed
through the system AXI interface. It builds an independent
`obj/axi/RTThread_Nano.elf` with `HAS_CACHE=1`, so startup marks normal memory
as cached to match the enabled RTL ICache/DCache.

When the `IMAGE` basename is `coremark.exe`, `run` and `run-nodiff`
automatically raise the cycle limit to `2G` for the valid 3000-iteration
CoreMark run. Override it with `COREMARK_MAX_CYCLES=N`; an explicit
`--max-cycles` in `RUN_ARGS` takes precedence.

Common options:

- `--diff` / `--no-diff`: Enable or disable reference-model comparison.
  Enabled by default.
- `--ref FILE`: Specify the reference model. The default is
  `verify/loong-emu/build/la_emu_ref.so`.
- `--ref-arch NAME`: Reference CPU type. The default is `loongarch32s`.
- `--cpu-model NAME`: Select the microarchitecture Diff policy. The default
  is `la132`.
- `--ram-size SIZE`: RAM physical-address window. The default is `512M`.
- `--boot-pc ADDR`: Override the ELF entry address.
- `--load-address ADDR`: Raw-binary load address. The default is
  `0x1c000000`.
- `--load FILE@ADDR`: Preload an additional ELF or raw image. This option can
  be specified repeatedly.
- `--max-cycles N` / `--max-commits N`: Set execution limits.
- `--trace FILE`: Write a VCD waveform.
- `--commit-log`: Print every committed instruction and GPR writeback.
- `--quiet-uart`: Preserve UART output without printing it to the terminal.
- `--checkpoint FILE`: Periodically save a complete restorable simulation
  state, and save it once more on exit.
- `--checkpoint-interval N`: Checkpoint period. The default is 10 million
  clock cycles.
- `--restore FILE`: Restore from a checkpoint; an initial image is no longer
  required.

Numeric options accept decimal, hexadecimal with a `0x` prefix, and `K`,
`M`, or `G` suffixes. LoongArch DMW addresses in ELF64 are mapped into the
current LA132 physical address space by their low 32 bits. Segments beyond
4 GiB produce an error and are not silently truncated.

## Exit Conditions and Checking Scope

The simulator reads its exit markers from
`verify/apps/common/include/la_config.h`. With the current configuration it
reports `GOOD TRAP` when it commits `addi.w $r0, $r0, 52` (`0x0280d000`). The
application and simulator therefore stay synchronized when the marker changes.
Reaching the `--max-commits` limit is also treated as a controlled successful
exit for short regression tests.

The common Diff framework checks the committed PC, executes the reference
instruction, and compares the low 32 bits of all GPRs. The LA132-specific
handling for `rdcnt*` dual-micro-operation commits, `CPUCFG`, debug CSRs,
the real-time timer, and interrupt/exception boundaries is implemented by the
`DiffMicro` derived class rather than mixed into the common execution
framework. To add another CPU implementation, create a new `DiffMicro`
derived class and register it in `make_diff_micro()`.

Run the quick checks:

```bash
make -C verify/verilator test
```

Boot Linux with the same address layout as the FPGA (`loader` at
`0x1c000000`, kernel at `0x00200000`):

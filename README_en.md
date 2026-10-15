# OpenLACores

[中文 README](README.md)

OpenLACores is a LoongArch processor design and verification project centered on OpenLA132 and OpenLA264.

The project includes processor RTL source code, a bare-metal software environment, LoongArch functional-model simulation, Verilator differential verification, and Vivado FPGA implementation flows for the Loongson Laboratory Box and Xilinx VU13P FPGA boards.

It is intended to help users understand and practice chip-design flows including processor RTL design, functional validation, bare-metal program testing, and FPGA boot validation.

## OpenLA132

OpenLA132 is a 32-bit LoongArch core with 32-bit general-purpose registers and a 32-bit virtual/physical address space. Its microarchitecture uses a four-stage pipeline comprising instruction fetch/decode, execution, memory access, and retirement.

[Detailed documentation](docs/OpenLA132/README.md)

Running the CoreMark benchmark yields approximately 2.4 CoreMark/MHz; running the Dhrystone benchmark yields approximately 1.816 DMIPS/MHz.

## Repository Layout

~~~text
.
├── design/
│   ├── filelist/openla132.f      # OpenLA132 RTL file list
│   └── sys/openla132/
│       ├── ifu/ dsu/ exu/ rtu/   # Instruction fetch, decode, execution, and retirement RTL
│       ├── lsu/ mmu/ csr/ biu/   # Load/store, address translation, CSR, and bus RTL
│       ├── ram_arrays/           # Cache data/tag/LRU RAM wrappers
│       ├── libwrapper/           # SRAM, clock-gating, and technology wrappers
│       ├── ljtag/                # JTAG/cJTAG logic
│       ├── include/              # RTL parameters, macros, and bus-width definitions
│       └── top/                  # Core and IP top-level integration
├── docs/                         # IP integration documentation
├── impl/                         # Vivado project, board configuration, loader, and download scripts
├── toolchains/                   # LA32S cross-toolchain archives and instructions
└── verify/
    ├── apps/                     # Bare-metal applications, benchmarks, random tests, and shared software
    ├── kernel/                   # Linux kernel
    └── verilator/                # Standalone Verilator simulator
~~~

| Area | Contents |
| --- | --- |
| Processor RTL | OpenLA132 core; instruction fetch, decode, execution, and retirement; LSU, CSR, MMU, JTAG, AXI, cache, and RAM/standard-cell wrappers. |
| Software environment | LA32S reset entry, linker scripts, heap, console, timer, system-call stubs, and examples including hello, CoreMark, Dhrystone, RT-Thread Nano, and Linux. |
| RTL simulation | A standalone Verilator top directly instantiates `openla132_ip_top` and provides sparse AXI RAM, a 16550 UART, ELF/raw-BIN loading, commit logging, VCD, and checkpoints. |
| Differential verification | loong-emu can build a DiffTest reference shared library. Verilator compares PC and register state at commit boundaries and handles OpenLA132 specific micro-operations and exception boundaries. |
| FPGA | `impl/` supports VU13P and LSBD, including Block Design, DDR, UART, loader, JTAG download, ILA, and Linux boot scripts. |

## Quick Start

Verilator simulation is supported on Loongson 3A5000 Deepin systems and x86_64 Ubuntu 22.04/24.04 systems. FPGA programming and execution are currently supported only on x86_64 Ubuntu 22.04/24.04.

1. Common prerequisites:

   See the [development environment setup guide](docs/environment_setup.md) for complete installation and verification steps. Include:

   - GNU Make, a host C/C++ toolchain, and Python 3
   - The [LA32S cross-compilation toolchain](toolchains/README.md)
   - Verilator; GTKWave is optional for viewing VCD waveforms
   - Vivado for FPGA builds; see `impl/README.md` for verified versions and board-specific limitations
   - Linux kernel build dependencies, only when building Linux

2. Set environment variables:

   ```shell
   export TOOLCHAIN="$HOME/gcc/loongarch32s-unknown-linux-gnusf-gcc-16.2.0-ubuntu22.04"
   export CROSS_COMPILE="$TOOLCHAIN/bin/loongarch32s-unknown-linux-gnusf-"
   ```

3. **Build bare-metal applications**

   The shared software build rules use `LA_PROFILE` to select the target ISA. Use `LA_PROFILE=la32s` explicitly for the current OpenLA132 core.

   ```shell
   make -C verify/apps/hello LA_PROFILE=la32s CROSS_COMPILE="$CROSS_COMPILE"
   make -C verify/apps/coremark LA_PROFILE=la32s CROSS_COMPILE="$CROSS_COMPILE"
   make -C verify/apps/dhrystone LA_PROFILE=la32s CROSS_COMPILE="$CROSS_COMPILE"
   ```

   The generated files and their uses are as follows:

   | File suffix | Purpose |
   | --- | --- |
   | `.exe` (ELF) | Recommended for simulators; retains the entry address and multiple loadable segments. |
   | `.bin` | Suitable for fixed-address raw-binary loading or FPGA initialization flows. |
   | `.S` / `.s`, `.map` | Used to locate symbol, disassembly, and link-layout issues. |

   The required C library, link address, and startup method can differ between applications. Do not mix the link rules for a Linux user-space toolchain with those for bare-metal applications.

4. **Run Verilator simulation**

   See [verify/verilator/README.md](verify/verilator/README.md). Build the loong-emu reference model first:

   ```shell
   # Download
   git clone https://github.com/Open-ChipHub/loong-emu.git ./verify/loong-emu/
   # Build
   make -C verify/loong-emu DIFF=1
   ```

   Then build the Verilator simulator:

   ```shell
   make -C verify/verilator
   ```

   Run a simulation:

   ```bash
   # Run only the RTL, AXI RAM, and UART models
   make run-nodiff IMAGE=../apps/coremark/coremark.exe

   # Run with DiffTest enabled
   make run IMAGE=../apps/coremark/coremark.exe
   ```

   True output for Coremark test:
   ``` bash
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 12292063
Total time (secs): 0.122921
Iterations/Sec   : 244.059927
Iterations       : 30
Compiler version : GCC16.2.0
Compiler flags   : -O2
Memory location  : STACK
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xf8b3
Correct operation validated. See readme.txt for run and reporting rules.

[sim] GOOD TRAP at pc=0x1c0049d0
[sim] cycles=12334473 commits=8864282
   ```

5. **Common debugging methods**

   ```bash
   # Record commits and limit simulation cycles
   make -C verify/verilator run-nodiff IMAGE=../apps/coremark/coremark.exe RUN_ARGS="--max-cycles 200000 --commit-log --quiet-uart"

   # Generate a VCD waveform
   make -C verify/verilator run-nodiff IMAGE=../apps/coremark/coremark.exe RUN_ARGS="--max-cycles 200000 --trace coremark.vcd --quiet-uart"

   gtkwave verify/verilator/coremark.vcd
   ```

   The project also supports checkpoints, resumed execution, Linux multi-image loading, and other features. See the Verilator documentation for run-time options and debugging configuration.

6. **Random instruction tests**

   `verify/apps/random/` stores only the test-suite documentation. Download random-test images separately according to that documentation, then place them under `verify/apps/random/` in the repository.

   Replace `IMAGE` with the path to the actual `.bin` before running. A single image can be run directly:

   ```bash
   make -C verify/verilator run IMAGE=/path/to/<test>.bin RUN_ARGS="--max-cycles 100000000 --quiet-uart"
   ```

   Random instructions are constrained to the ISA subset implemented by OpenLA132. Unsupported instructions can cause an exception loop and prevent the program from reaching a GOOD TRAP.

7. **Linux kernel**

   The [Linux build guide](verify/kernel/README.md) provides `la32s.config`, `labcore.dts`, and instructions for generating the LA32S patch, `vmlinux`, `vmlinux.bin`, and DTB.

8. **FPGA bitstream and board bring-up**

   Supported FPGA boards:

   | Item | Loongson Laboratory Box (default) | VU13P |
   | --- | --- | --- |
   | Selection | `BOARD=lsbd` | `BOARD=vu13p` |
   | FPGA device | `xc7a200t-fbg676-2` | `xcvu13p-fhgb2104-2-i` |
   | Default CPU clock | 50 MHz, configurable through `CPU_FREQ_HZ` | 100 MHz |
   | External memory | One 16-bit DDR3 device, 128 MiB | DDR4 |
   | JTAG AXI | 32-bit address/data | 32-bit address/data |
   | Project working directory | `xlnx-work-lsbd` | `xlnx-work-vu13p` |

   `impl/` uses LSBD as the default board and also supports VU13P. Select the target through `BOARD` and specify the Vivado executable through `VIVADO`:

   ```bash
   make -C impl BOARD=lsbd config
   make -C impl VIVADO=/opt/Xilinx/Vivado/2022.2/bin/vivado BOARD=lsbd bitstream
   make -C impl VIVADO=/opt/Xilinx/Vivado/2022.2/bin/vivado BOARD=lsbd upload
   ```

   In addition to the bitstream, `upload` involves the loader, kernel image, JTAG hardware selection, and board-specific parameters. Override the Linux kernel directory and cross-toolchain prefix through `KERNEL_DIR` and `CROSS_COMPILE`; see [impl/README.md](impl/README.md).

## Documentation

| Context | Document |
| --- | --- |
| OpenLA132 overview | [OpenLA132 processor IP features and usage](docs/OpenLA132/README.md) |
| Verilator, waveforms, checkpoints, and DiffTest | [verify/verilator/README.md](verify/verilator/README.md) |
| Shared bare-metal runtime | [verify/common/README.md](verify/apps/common/README.md) |
| CoreMark | [verify/apps/coremark/README.md](verify/apps/coremark/README.md) |
| Dhrystone | [verify/apps/dhrystone/README.md](verify/apps/dhrystone/README.md) |
| Random test suite | [verify/apps/random/README.md](verify/apps/random/README.md) |
| Linux | [verify/kernel/linux/README_en.md](verify/kernel/linux/README_en.md) |
| FPGA build, address map, and board bring-up | [impl/README.md](impl/README.md) |
| FPGA Block Design IP management | [impl/ip/README.md](impl/ip/README.md) |
| Cross-toolchain | [toolchains/README.md](toolchains/README.md) |

## Contact

For project questions or to join the project, contact us at:

- loongsonlab@loongson.cn

## Contribution and Collaboration Guidelines

For contribution workflows, issue reporting, commit requirements, and review expectations, see the [Contribution and Collaboration Guidelines](docs/contributing_en.md).

## Acknowledgments

Thanks to Loongson Technology Corporation Limited for its support.

## License

This project is licensed under the [Mulan Permissive Software License, Version 2 (Mulan PSL v2)](LICENSE).

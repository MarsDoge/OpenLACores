# OpenLACores Unified FPGA Implementation Flow

`impl` provides a unified Vivado FPGA flow for the VU13P and LSBD boards. Select a board with `BOARD=vu13p` or `BOARD=lsbd`.

LSBD is the primary target and remains the default, so existing commands such as `make -C impl bitstream` retain their behavior.

## Board Selection

The currently supported boards are:

| Setting | LSBD (default) | VU13P |
| --- | --- | --- |
| Command | `BOARD=lsbd` | `BOARD=vu13p` |
| FPGA part | `xc7a200t-fbg676-2` | `xcvu13p-fhgb2104-2-i` |
| Project | `openla132s_lsbd_bd` | `openla132s_xlnx_bd` |
| Work root | `xlnx-work-lsbd` | `xlnx-work-vu13p` |
| CPU clock | 50 MHz default, configurable | 100 MHz default |
| Block Design clock | 100 MHz | 100 MHz |
| CPU AXI | 32-bit address/data, 4-bit ID | 32-bit address/data, 4-bit ID |
| Internal AXI data width | 64-bit | 64-bit |
| Memory AXI | 128 MiB DDR3, 32-bit AXI address/64-bit AXI data | DDR4, 64-bit data |
| JTAG AXI | 32-bit address/data | 32-bit address/data |
| Vivado strategy | Performance optimized | Performance optimized |

Board defaults are stored in `boards/vu13p.mk` and `boards/lsbd.mk`. Most settings can still be overridden on the command line, but JTAG widths must match the programmed Block Design.

```sh
make -C impl config
make -C impl BOARD=lsbd config
make -C impl BOARD=vu13p bitstream
make -C impl BOARD=lsbd bitstream
```

Run `reproject` after changing the selected board, CPU file list, Block Design Tcl, MIG project, FPGA part, constraint file, or top-level integration.

To adapt the project for another board, see the [new FPGA board configuration guide](boards/README.md).

## Common Architecture

Both boards instantiate the same LA132 source list, FPGA standard-cell replacement implementation, 32-bit CPU AXI adapter, loader, project scripts, synthesis flow, and upload-payload generator. Board-specific files are limited to:

- board defaults in `boards/`;
- VU13P DDR4 and LSBD DDR3 Block Design Tcl files in `bd/`;
- AXVU13P and LSBD constraints in `constraints/`;
- structural board shells in `soc/`;
- the version-controlled LSBD MIG configuration in `ip/xlnx_mig_axi/config/`.

VU13P retains its 100 MHz default. On LSBD, a Clocking Wizard derives the selected CPU clock plus fixed 100/200 MHz MIG inputs from the board's single-ended 100 MHz oscillator. Only the CPU and the S_AXI side of an explicit AXI Clock Converter use the selected frequency. Its M_AXI side and the complete Block Design fabric—including the 64-bit interconnect, MIG UI, JTAG AXI, VIO, UART, and loader RAM—remain at 100 MHz.

Set the LSBD CPU request in integer Hz and recreate the project whenever it changes. Clocking Wizard uses the nearest legal PLL ratio and propagates the realized frequency to the CPU AXI interface and debug hub:

```sh
make -C impl BOARD=lsbd CPU_FREQ_HZ=20000000 rebuild
```

## Address Maps

### VU13P

Only the lower 4 GiB of DDR4 is mapped, preserving the existing peripheral hole.

| Target | CPU/JTAG aperture |
| --- | --- |
| DDR4 | `0x00000000 <= addr < 0x1f000000` |
| AXI UART 16550 | `0x1fe00000 <= addr < 0x1fe01000` |
| DDR4 | `0x20000000 <= addr < 0x100000000` |

### LSBD

The LSBD board contains one 16-bit `MT41J64M16XX-125` DDR3 device. Its 13 row, 10 column, and 3 bank address bits provide exactly 128 MiB, which the Block Design maps only once.

| Target | Block Design aperture |
| --- | --- |
| DDR3 | `0x00000000 <= addr < 0x08000000` |
| 4 KiB loader AXI RAM | `0x1c000000 <= addr < 0x1c001000` |
| AXI UART 16550 | `0x1fe00000 <= addr < 0x1fe01000` |

CPU and JTAG AXI use the same three Block Design address segments. CPU AXI addresses enter the Block Design unchanged: DDR is mapped once; the reset and loader window is backed by AMD `axi_bram_ctrl` and `blk_mem_gen`; and the UART keeps its architectural address. Unmapped addresses return an AXI decode error instead of wrapping into the low 128 MiB DDR window.

## Loader and Programming

`loader/` builds an ELF32 `la32rv1.0` image linked at `0x1c000000`. Both VU13P and LSBD program it at that address; on LSBD it executes from the dedicated 4 KiB AXI RAM. The final 64 bytes of this RAM, starting at `0x1c000fc0`, are reserved for loader status, and the build rejects loaders larger than 4,032 bytes. The LSBD loader stack is located at `0x07f00000` in DDR. The Linux raw image is loaded at physical address `0x00200000`. When converting DMW addresses to physical programming addresses, the loader and `scripts/download_bit_ddr_and_run.tcl` clear LA32 DMW segment bits `[31:29]`.

The kernel requires `a1/fw_arg1` to point to a physical command-line buffer. The loader copies a board-specific string to `0x00100000` and passes that address instead of zero. VU13P uses a valid empty string and preserves the boot arguments built into the device tree. LSBD adds `mem=128M` to prevent the kernel from accessing addresses above the physical DDR limit while the device tree declares a 256 MiB region.

The current LSBD Systemd rootfs requires a compressed built-in initramfs. In the external kernel tree, enable `CONFIG_INITRAMFS_COMPRESSION_GZIP` and disable `CONFIG_INITRAMFS_COMPRESSION_NONE`; the original 38 MiB uncompressed archive exceeds the 128 MiB boot-time memory budget while being unpacked.

The programming file uses 1,024-byte records on both boards. The common download Tcl derives the hardware transfer format from the selected board:

- VU13P sends 128 64-bit JTAG AXI data words per record;
- LSBD sends 256 32-bit JTAG AXI data words per record.

The script selects hardware by FPGA device name instead of blindly using the first cable. Defaults are `xcvu13p_0` and `xc7a200t_0`. If multiple matching devices exist, explicitly select the matching device index:

```sh
make -C impl BOARD=vu13p upload
make -C impl BOARD=lsbd upload
make -C impl BOARD=lsbd FPGA_HW_TARGET_INDEX=1 upload
```

`upload`, `jtag-read`, `jtag-write`, `cpu-hold`, `cpu-release`, and `cpu-reset` all use the same board-specific Hardware Manager settings. LSBD also provides `capture-lsbd-status-ila` to export the 26-probe clock/reset/JTAG/MIG status ILA core included in the normal bitstream.

## Validation Status

Both `BOARD=vu13p reproject` and `BOARD=lsbd reproject` have completed with Vivado 2023.2. The generated LSBD Block Design passes `validate_bd_design` with no errors or critical warnings, and checks:

- 32-bit CPU address/data widths and 4-bit CPU ID width;
- an asynchronous AXI Clock Converter from the selected CPU clock domain to the 100 MHz Block Design clock domain;
- 64-bit internal interconnect and MIG AXI data widths;
- 32-bit LSBD JTAG AXI address/data widths;
- identical CPU/JTAG mappings for 128 MiB DDR, 4 KiB loader RAM, and UART;
- a 4 KiB, 64-bit AMD AXI BRAM controller and block-RAM implementation;
- a VIO CPU reset signal asserted at power-up.

The 2026-08-31 address-map update completed an independent LSBD `reproject` at the non-default `CPU_FREQ_HZ=20000000`; both the requested and realized CPU clocks reported 20.000000 MHz. BD validation, wrapper generation, and managed-IP generation passed. Full synthesis, implementation, bitstream generation, and hardware programming still need to be rerun for this new layout.

The previous alias-based layout completed bitstream generation with WNS `+0.123 ns` and WHS `+0.006 ns`, and three gzip-initramfs uploads reached `SYSTEM_RUNNING`. These historical results do not validate the new dedicated loader-RAM layout.

Generated Vivado projects, IP products, checkpoints, reports, and bitstreams are stored below the selected ignored `WORK_ROOT` directory.

## Running Example

To boot the Linux kernel on the Loongson Laboratory Box, first refer to the [Linux kernel build guide](../verify/kernel/linux/README.md).

Then run:

```shell
make -C impl/ BOARD=lsbd VIVADO=/path/to/vivado CROSS_COMPILE="$CROSS_COMPILE" CONFIG_MMU=1 bitstream
make -C impl/ BOARD=lsbd VIVADO=/path/to/vivado CROSS_COMPILE="$CROSS_COMPILE" KERNEL_DIR=./verify/kernel/ CONFIG_MMU=1 upload
```

Finally, connect the Loongson Laboratory Box UART cable to the host and open a serial terminal such as `minicom`. The Linux kernel boot log will appear on the serial console, which can then be used interactively.

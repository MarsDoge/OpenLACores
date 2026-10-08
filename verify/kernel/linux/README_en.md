# Linux 7.2.3 Build Guide

This directory provides the Linux kernel configuration and device tree for the
LA132S FPGA platform:

| File | Purpose |
| --- | --- |
| `la32s.config` | A complete Linux 7.2.3 `.config` verified for LA32S. The configuration was generated using `loongarch32s-unknown-linux-gnusf-gcc 16.2.0`. |
| `labcore.dts` | Device tree for the single-core LA132S platform: 128 MiB DDR, a 100 MHz clock, and a 16550 UART at `0x1fe00000`. |
| `rootfs.cpio.base` | Optional built-in initramfs CPIO root-filesystem archive. It is linked into `vmlinux` and does not need a separate loader-stage download. |

This document uses Linux **7.2.3** as an example. The kernel source tree must
include LA32S support. If the downloaded upstream source does not support
32-bit LoongArch or lacks the platform changes required by LA132S, copying
only the config and DTS from this directory is not sufficient: apply the
corresponding LA32S kernel patches first.

## Prerequisites

- A Linux host with kernel build dependencies such as `git`, `make`, `gcc`,
  `bc`, `bison`, `flex`, `openssl`, `libelf`, and `pahole`;
- An LA32S cross-compilation toolchain. See
  [`toolchains/README.md`](../../../../toolchains/README.md) for the toolchain
  provided by this repository and installation instructions.

The following commands assume they are run from the OpenLA132S repository root:

```bash
export ROOT="$PWD"
export TOOLCHAIN="$HOME/opt/loongarch32s-unknown-linux-gnusf-gcc-16.2.0-ubuntu22.04"
export CROSS_COMPILE="$TOOLCHAIN/bin/loongarch32s-unknown-linux-gnusf-"

"${CROSS_COMPILE}gcc" -dumpmachine
```

The final command should print:

```text
loongarch32s-unknown-linux-gnusf
```

## Download Linux 7.2.3 Source Code

The matching version can be obtained from the Linux stable source repository:

```bash
cd "${ROOT}/.."
git clone --depth 1 --branch v7.2.3 \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git \
  linux-7.2.3
cd linux-7.2.3
```

If you already have a Linux 7.2.3 source tree containing the LA32S patches,
use that tree directly. Do not overwrite it with an unpatched source tree.

## Install the Configuration and Device Tree

Copy the verified complete configuration to the kernel `.config`:

```bash
cp "${ROOT}/verify/apps/kernel/Linux/la32s.config" .config
make ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
```

Copy the device tree into the LoongArch DTS directory:

```bash
cp "${ROOT}/verify/apps/kernel/Linux/labcore.dts" \
  arch/loongarch/boot/dts/labcore.dts
```

Then edit `arch/loongarch/boot/dts/Makefile` and add `labcore.dtb` to the
`dtb-y` list. For example, if the original file contains:

```make
dtb-y = loongson-2k0500-ref.dtb loongson-2k1000-ref.dtb loongson-2k2000-ref.dtb labcore-sim.dtb
```

change it to:

```make
dtb-y = loongson-2k0500-ref.dtb loongson-2k1000-ref.dtb loongson-2k2000-ref.dtb labcore-sim.dtb labcore.dtb
```

Unless `labcore.dtb` is added to this list, `make dtbs` does not generate
the device-tree binary for this platform.

## Configure a Built-in Root Filesystem

`rootfs.cpio.base` is available, it can be linked into the kernel as the
built-in initramfs. The archive must use the CPIO format accepted by the Linux
initramfs builder. It is packaged while building `vmlinux`; it is not a
separate image that the loader must place in DDR.

`la32s.config` already contains the relevant settings:

```text
CONFIG_BLK_DEV_INITRD=y
CONFIG_INITRAMFS_SOURCE="rootfs.cpio.base"
CONFIG_INITRAMFS_ROOT_UID=0
CONFIG_INITRAMFS_ROOT_GID=0
CONFIG_RD_GZIP=y
CONFIG_INITRAMFS_COMPRESSION_GZIP=y
```

`CONFIG_INITRAMFS_SOURCE` is relative to the Linux source-tree root. After
copying `.config`, copy the supplied archive to that root and verify that it
exists:

```bash
ROOTFS="${ROOT}/verify/apps/kernel/Linux/rootfs.cpio.base"
test -f "${ROOTFS}"
cp "${ROOTFS}" ./rootfs.cpio.base

make ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
```

Alternatively, keep the archive outside the kernel tree and set
`CONFIG_INITRAMFS_SOURCE` to its absolute path. The path must not contain
spaces. The kernel-supplied helper can update the setting:

```bash
scripts/config --file .config --set-str INITRAMFS_SOURCE "${ROOTFS}"
make ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
```

Choose one method only. An absolute path must remain accessible for every
build; copying the file to the source-tree root usually makes builds easier to
reproduce. Do not add the same rootfs twice to `CONFIG_INITRAMFS_SOURCE`, or
its contents will be packaged twice.

The current configuration uses gzip compression for the built-in initramfs to
reduce image size and boot-time memory pressure. If another compression method
is selected, enable the corresponding decompression support and run
`olddefconfig` again.

## Build

Build the kernel and device trees:

```bash
make -j"$(nproc)" ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" \
  vmlinux dtbs

"${CROSS_COMPILE}objcopy" -O binary vmlinux \
  arch/loongarch/boot/vmlinux.bin
```

On success, the primary outputs are:

| File | Description |
| --- | --- |
| `vmlinux` | Uncompressed ELF kernel image. This is the file used by the default `impl/loader` workflow. |
| `arch/loongarch/boot/vmlinux.bin` | Raw binary kernel image, for flows that load a binary image directly. |
| `arch/loongarch/boot/dts/labcore.dtb` | Device-tree binary for the LA132S platform. |

The built-in `rootfs.cpio.base` is included in both `vmlinux` and the exported
`vmlinux.bin`; no additional rootfs file is required for FPGA download or
Verilator boot.

You can check the output formats with:

```bash
file vmlinux arch/loongarch/boot/vmlinux.bin arch/loongarch/boot/dts/labcore.dtb
"${CROSS_COMPILE}readelf" -h vmlinux | sed -n '1,20p'
```

## Rebuild

After changing only the DTS, regenerate the device tree with:

```bash
make ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" dtbs
```

After changing only the kernel configuration, first run:

```bash
make ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
```

Then rerun the full kernel build command. After the build is complete and FPGA
boot verification succeeds, copy the final `.config` back to this directory
and review the differences, so that `la32s.config` always matches the
verified version.

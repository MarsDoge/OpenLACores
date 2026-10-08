#   Linux 7.2.3 构建说明

本目录提供 OpenLA132 FPGA 平台使用的 Linux 内核配置与设备树：

| 文件 | 用途 |
| --- | --- |
| `la32s.config` | 已验证可用于 LA32S 的 Linux 7.2.3 完整 `.config`。配置使用 `loongarch32s-unknown-linux-gnusf-gcc 16.2.0` 生成。 |
| `labcore.dts` | LA132S 单核平台设备树：128 MiB DDR、100 MHz 时钟，以及位于 `0x1fe00000` 的 16550 UART。 |
| `rootfs.cpio.base` | 可选的内置 initramfs CPIO 根文件系统归档。构建时将其链接进 `vmlinux`，无需由 loader 单独加载。 |

本文以 Linux **7.2.3** 为例。内核源码必须包含 LA32S 支持；若所下载的上游源码不支持 32 位 LoongArch 或 LA132S 所需的平台改动，仅复制本目录的 config 与 DTS 不足以完成构建，须先应用对应的 LA32S 内核补丁。

## 前置条件

- Linux 主机，具有 `git`、`make`、`gcc`、`bc`、`bison`、`flex`、`openssl`、`libelf` 和 `pahole` 等内核构建依赖；
- LA32S 交叉编译工具链。仓库内提供的工具链及安装方法见 [`toolchains/README.md`](../../../../toolchains/README.md)。

以下命令假定在 OpenLA132S 仓库根目录执行：

```bash
export ROOT="$PWD"
export TOOLCHAIN="$HOME/opt/loongarch32s-unknown-linux-gnusf-gcc-16.2.0-ubuntu22.04"
export CROSS_COMPILE="$TOOLCHAIN/bin/loongarch32s-unknown-linux-gnusf-"

"${CROSS_COMPILE}gcc" -dumpmachine
```

最后一条命令应输出：

```text
loongarch32s-unknown-linux-gnusf
```

## 下载 Linux 7.2.3 源码

可从 Linux stable 源码仓库获取对应版本：

```bash
cd "${ROOT}/.."
git clone --depth 1 --branch v7.2.3 \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git \
  linux-7.2.3
cd linux-7.2.3
```

若已有包含 OpenLA132 补丁的 Linux 7.2.3 源码树，应直接使用该源码树，不要用未打补丁的源码覆盖它。

## 安装配置与设备树

将已验证的完整配置复制为内核 `.config`：

```bash
cp "${ROOT}/verify/kernel/la32s.config" .config
make ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
```

将设备树复制到 LoongArch DTS 目录：

```bash
cp "${ROOT}/verify/kernel/labcore.dts" \
  arch/loongarch/boot/dts/labcore.dts
```

然后编辑 `arch/loongarch/boot/dts/Makefile`，在 `dtb-y` 列表中加入 `labcore.dtb`。例如原文件为：

```make
dtb-y = loongson-2k0500-ref.dtb loongson-2k1000-ref.dtb loongson-2k2000-ref.dtb labcore-sim.dtb
```

修改为：

```make
dtb-y = loongson-2k0500-ref.dtb loongson-2k1000-ref.dtb loongson-2k2000-ref.dtb labcore-sim.dtb labcore.dtb
```

不将 `labcore.dtb` 加入该列表时，`make dtbs` 不会生成本平台的设备树二进制文件。

## 配置内置根文件系统

工程已提供 `rootfs.cpio.base`，可将其作为内置 initramfs 链接进内核。该归档应为
Linux initramfs 所使用的 CPIO 格式，并由内核在构建 `vmlinux` 时打包；它不是需要在
loader 阶段额外写入 DDR 的独立镜像。

`la32s.config` 已包含以下相关配置：

```text
CONFIG_BLK_DEV_INITRD=y
CONFIG_INITRAMFS_SOURCE="rootfs.cpio.base"
CONFIG_INITRAMFS_ROOT_UID=0
CONFIG_INITRAMFS_ROOT_GID=0
CONFIG_RD_GZIP=y
CONFIG_INITRAMFS_COMPRESSION_GZIP=y
```

其中 `CONFIG_INITRAMFS_SOURCE` 使用相对于 Linux 源码根目录的路径。完成 `.config`
复制后，将提供的根文件系统复制到内核源码根目录，并确认文件存在：

```bash
ROOTFS="${ROOT}/verify/kernel/rootfs.cpio.base"
test -f "${ROOTFS}"
cp "${ROOTFS}" ./rootfs.cpio.base

make ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
```

如果不希望复制文件，也可将 `.config` 中的 `CONFIG_INITRAMFS_SOURCE` 改为该文件的绝对
路径；路径中不应包含空格。可使用内核自带脚本设置：

```bash
scripts/config --file .config --set-str INITRAMFS_SOURCE "${ROOTFS}"
make ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
```

二选一即可。使用绝对路径时，构建环境必须始终能访问该路径；使用相对路径并复制到源码
根目录通常更便于复现构建。不要同时在 `CONFIG_INITRAMFS_SOURCE` 中加入两份相同的
rootfs，否则其内容会被重复打包。

当前配置选择 gzip 压缩内置 initramfs，以减小镜像和启动时内存占用。若切换压缩算法，
还应确认内核已启用对应的解压支持，并重新执行 `olddefconfig`。

## 编译

执行内核和设备树构建：

```bash
make -j"$(nproc)" ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" \
  vmlinux dtbs

"${CROSS_COMPILE}objcopy" -O binary vmlinux \
  arch/loongarch/boot/vmlinux.bin
```

成功后，主要产物为：

| 文件 | 说明 |
| --- | --- |
| `vmlinux` | 未压缩 ELF 内核镜像；`impl/loader` 的默认工作流使用该文件。 |
| `arch/loongarch/boot/vmlinux.bin` | 裸二进制内核镜像，可用于需要直接加载二进制镜像的流程。 |
| `arch/loongarch/boot/dts/labcore.dtb` | LA132S 平台设备树二进制文件。 |

内置 `rootfs.cpio.base` 已包含在 `vmlinux` 和由其导出的 `vmlinux.bin` 中，不需要为 FPGA
烧录或 Verilator 启动另外指定 rootfs 文件。

可检查产物格式：

```bash
file vmlinux arch/loongarch/boot/vmlinux.bin arch/loongarch/boot/dts/labcore.dtb
"${CROSS_COMPILE}readelf" -h vmlinux | sed -n '1,20p'
```

## 重新构建

仅修改 DTS 后，可重新生成设备树：

```bash
make ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" dtbs
```

仅修改内核配置后，应先执行：

```bash
make ARCH=loongarch CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
```

再重新执行完整内核构建命令。构建完成且 FPGA 启动验证通过后，建议将最终 `.config` 复制回本目录并审查差异，确保 `la32s.config` 始终对应已验证版本。

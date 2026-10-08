# OpenLACores 开发环境安装指南

本文说明 OpenLACores 仿真与上板所需运行环境的安装与检查方法。

指南以 Loongson 3A5000 Deepin 系统，与 x86_64 Ubuntu 22.04/24.04 系统为准。

其他 Linux 发行版请安装名称相同或功能等价的软件包。

除 FPGA 构建和 Linux 内核构建外，完成前四项即可编译裸机程序并运行 Verilator 仿真。

## 1. 宿主机构建环境

在 Loongson 3A5000 Deepin 系统，与 x86_64 Ubuntu 22.04/24.04 系统上，使用以下命令，可安装 GNU Make、宿主 C/C++ 编译器、Python 和常用构建工具：

```bash
sudo apt update
sudo apt install -y build-essential make gcc g++ python3 python3-venv \
  python3-pip git file xz-utils
```

确认工具可用：

```bash
make --version
gcc --version
g++ --version
python3 --version
```

其中宿主 C/C++ 编译器用于构建 Verilator 生成的仿真程序、辅助工具和部分主机端脚本，它不能替代 LoongArch 交叉编译器。

## 2. LA32S 交叉编译工具链

本仓库的 `toolchains/` 目录说明并保存（或随发行包提供）LA32S GNU soft-float 工具链。

工具链压缩包从 Release 处下载，其中，Loongson 3A5000 Deepin 系统用户，请下载和使用文件 loongarch32s-unknown-linux-gnusf-gcc-16.2.0-native.tgz ，x86_64 Ubuntu 22.04/24.04 系统用户，请下载和使用文件 loongarch32s-unknown-linux-gnusf-gcc-16.2.0.tar.xz。

下载后需解压。假定压缩包位于 `toolchains/`，可安装到用户目录：

```bash
export ROOT="$(git rev-parse --show-toplevel)"
mkdir -p "$HOME/gcc"
tar -xJf "$ROOT/toolchains/loongarch32s-unknown-linux-gnusf-gcc-16.2.0.tar.xz" \
  -C "$HOME/gcc"

export TOOLCHAIN="$HOME/gcc/loongarch32s-unknown-linux-gnusf-gcc-16.2.0-ubuntu22.04"
export CROSS_COMPILE="$TOOLCHAIN/bin/loongarch32s-unknown-linux-gnusf-"
export PATH="$TOOLCHAIN/bin:$PATH"

"${CROSS_COMPILE}gcc" --version
"${CROSS_COMPILE}gcc" -dumpmachine
```

当前工具链应报告 GCC 16.2.0；其可执行文件名前缀为
`loongarch32s-unknown-linux-gnusf-`，但 `-dumpmachine` 可能报告
`loongarch32-unknown-linux-gnusf`，这是工具链配置的正常表现。

该工具链默认使用 LA32 v1.0、`ilp32s` ABI 和 soft-float。编译本仓库裸机应用时，
应显式选择 LA32S：

```bash
make -C "$ROOT/verify/apps/hello" \
  LA_PROFILE=la32s CROSS_COMPILE="$CROSS_COMPILE"
```

如需长期使用，可将 `TOOLCHAIN`、`CROSS_COMPILE` 和 `PATH` 的导出语句加入
`~/.bashrc`。更多压缩包、sysroot 和使用说明见
[toolchains/README.md](../toolchains/README.md)。

## 3. Verilator 与 GTKWave

Verilator 将 RTL 转换并编译为主机 C++ 仿真程序；GTKWave 仅用于查看 VCD 波形，不是运行仿真的必需项。

在 Loongson 3A5000 Deepin 系统，与 x86_64 Ubuntu 22.04/24.04 系统上，安装方式均相同。

其中，GTKWave 均可使用发行版软件包

```bash
sudo apt install -y gtkwave

gtkwave --version
```

发行版提供的 Verilator 版本通常可能落后于上游。请按 [Verilator 官方安装说明](https://verilator.org/guide/latest/install.html)
从源码构建；其典型构建依赖如下：

```bash
sudo apt install -y autoconf flex bison help2man perl libfl-dev \
  zlib1g-dev liblz4-dev
```

完成后可构建本工程仿真器：

```bash
make -C "$ROOT/verify/verilator"
```

GTKWave 只在使用 `RUN_ARGS="--trace <file>.vcd"` 生成波形时使用：

```bash
gtkwave "$ROOT/verify/verilator/example.vcd"
```

## 4. Vivado

Vivado 仅用于 `impl/` 下的 FPGA 工程创建、综合、实现、bitstream 生成和 JTAG 上板；
运行 Verilator 或构建普通裸机程序不需要安装它。

目前，下面安装步骤仅限于 x86_64 Ubuntu 22.04/24.04 系统用户。

1. 从 [AMD Vivado 下载页面](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)
   获取与主机兼容的 Linux 安装包。安装、授权和版本限制请以 AMD 的
   [Vivado 安装文档](https://docs.amd.com/r/2022.2-English/ug973-vivado-release-notes-install-license/Run-the-Installation-File)
   为准。
2. 解压安装包并运行其中的安装程序，选择 Vivado Design Suite；默认安装路径通常为
   `/opt/Xilinx/Vivado/<版本>`。
3. 初始化当前 shell 环境并确认版本：

   ```bash
   source /opt/Xilinx/Vivado/2022.2/settings64.sh
   vivado -version
   ```

4. 构建本工程时建议显式传入可执行文件的绝对路径，而不是依赖 `PATH`：

   ```bash
   make -C "$ROOT/impl" \
     VIVADO=/opt/Xilinx/Vivado/2022.2/bin/vivado \
     BOARD=lsbd config
   ```

若需要 JTAG 上板，还需按 AMD 安装包中的说明安装 cable driver，并确保当前用户具有
访问 USB/JTAG 设备的权限。项目已验证的 Vivado 版本和板卡限制以
[impl/README.md](../impl/README.md) 为准。

## 5. Linux 内核构建依赖

仅在构建 `verify/apps/kernel/Linux/` 所说明的 Linux 内核、DTB 或内置 initramfs 时
需要此组依赖：

```bash
sudo apt install -y bc bison flex libssl-dev libelf-dev dwarves pahole \
  libncurses-dev cpio gzip rsync device-tree-compiler
```

各软件包的用途如下：

| 软件包 | 用途 |
| --- | --- |
| `bc`、`bison`、`flex` | 内核配置和构建阶段生成代码。 |
| `libssl-dev` | 内核证书、签名及部分构建工具依赖。 |
| `libelf-dev`、`dwarves`、`pahole` | BTF、ELF 和调试信息处理。 |
| `libncurses-dev` | `menuconfig` 等交互式配置界面。 |
| `cpio`、`gzip` | 生成或处理内置 initramfs。 |
| `rsync` | 部分内核构建与安装辅助流程。 |
| `device-tree-compiler` | DTS/DTB 检查与设备树相关调试。 |

随后使用第 2 节设置的 `CROSS_COMPILE`，并按
[Linux 构建说明](../verify/apps/kernel/Linux/README.md) 执行配置和构建。

## 安装后检查

可使用以下命令快速确认各环境。没有安装 Vivado 或 GTKWave 时，对应命令可跳过：

```bash
make --version
python3 --version
"${CROSS_COMPILE}gcc" -dumpmachine
verilator --version
gtkwave --version
vivado -version
```

最小功能验证是成功构建并运行 hello：

```bash
make -C "$ROOT/verify/apps/hello" \
  LA_PROFILE=la32s CROSS_COMPILE="$CROSS_COMPILE"
make -C "$ROOT/verify/verilator" run-nodiff \
  IMAGE="$ROOT/verify/apps/hello/hello_world.exe"
```

若其他应用的构建产物路径不同，请使用其输出的 ELF 路径替换 `IMAGE`。Verilator、Linux
和 FPGA 的详细运行方法分别见其目录下的 README。

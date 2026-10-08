# LoongArch32S 交叉编译工具链

本目录保存 OpenLA132S 裸机程序和 FPGA loader 所需的 LoongArch LA32S 交叉编译工具链压缩包。

请从仓库 Release 处下载压缩包。

## 文件说明

| 文件 | 说明 |
| --- | --- |
| `loongarch32s-unknown-linux-gnusf-gcc-16.2.0.tar.xz` | GCC 16.2.0 的 LA32S GNU soft-float 交叉工具链，解压后的顶层目录为 `loongarch32s-unknown-linux-gnusf-gcc-16.2.0-ubuntu22.04/`，适用于 x86 架构 Ubuntu 22.04/24/04 系统平台。 |
| `loongarch32s-unknown-linux-gnusf-gcc-16.2.0-native.tgz` | GCC 16.2.0 的 LA32S GNU soft-float 交叉工具链，解压后的顶层目录为 `loongarch32s-unknown-linux-gnusf-gcc-16.2.0-native`，适用于 Loongson 3A5000 架构 deepin 系统平台。|

请根据实验平台，自行选择对应压缩包，进行下载。下载后，配置和运行操作流程相同。

该压缩包包含以下常用工具，统一前缀为：

```text
loongarch32s-unknown-linux-gnusf-
```

例如 `gcc`、`g++`、`ld`、`objcopy`、`objdump`、`readelf` 和 `size`。

## 安装

以下示例将工具链解压到用户目录的 `~/opt`，不会污染仓库：

```bash
mkdir -p ~/opt
tar -xJf toolchains/loongarch32s-unknown-linux-gnusf-gcc-16.2.0.tar.xz -C ~/opt

export TOOLCHAIN="$HOME/opt/loongarch32s-unknown-linux-gnusf-gcc-16.2.0-ubuntu22.04"
export CROSS_COMPILE="$TOOLCHAIN/bin/loongarch32s-unknown-linux-gnusf-"
```

`CROSS_COMPILE` 是**命令前缀**，必须保留末尾的连字符；构建系统会在其后拼接 `gcc`、`ld`、`objcopy` 等命令名。

也可以将工具链加入 `PATH`：

```bash
export PATH="$TOOLCHAIN/bin:$PATH"
export CROSS_COMPILE=loongarch32s-unknown-linux-gnusf-
```

若希望每次登录后自动生效，可将上述 `export` 命令加入 shell 的启动文件，例如 `~/.bashrc`。

## 验证安装

```bash
"${CROSS_COMPILE}gcc" --version
"${CROSS_COMPILE}gcc" -dumpmachine
"${CROSS_COMPILE}objcopy" --version
```

第二条命令应输出：

```text
loongarch32s-unknown-linux-gnusf
```

## 在本工程中使用

当前 `LA32S` 应用构建的默认前缀与本压缩包不同，因此请显式传入 `CROSS_COMPILE`。从仓库根目录执行：

```bash
make -C verify/apps/coremark CROSS_COMPILE="$CROSS_COMPILE" -j"$(nproc)"
make -C verify/apps/dhrystone CROSS_COMPILE="$CROSS_COMPILE" -j"$(nproc)"
```

构建 FPGA loader 时也使用相同前缀：

```bash
make -C impl/loader CROSS_COMPILE="$CROSS_COMPILE"
```

## 构建 Picolibc

RT-Thread Nano 使用 Picolibc。先在仓库根目录克隆源码：

```bash
git clone https://github.com/picolibc/picolibc.git toolchains/picolibc
```

将 LA32S 工具链加入 `PATH`，然后使用仓库提供的 Meson cross file 配置、编译并安装：

```bash
export PATH=/path/to/loongarch32s-toolchain/bin:$PATH

meson setup toolchains/picolibc/build-la32s toolchains/picolibc \
  --cross-file toolchains/picolibc-la32s.ini \
  --prefix="$PWD/toolchains/picolibc/build-la32s/install" \
  --includedir=include \
  --libdir=lib \
  -Dspecsdir=none \
  -Dmultilib=false \
  -Dtests=false \
  -Dthread-local-storage=false \
  -Datomic-ungetc=false \
  -Dbuildtype=release

ninja -C toolchains/picolibc/build-la32s -j"$(nproc)"
ninja -C toolchains/picolibc/build-la32s install
```

头文件和静态库分别安装到 `toolchains/picolibc/build-la32s/install/include` 和 `lib`。RT-Thread Nano 默认使用该路径，不需要额外指定 `PICOLIBC_DIR`。

也可不预先导出变量，直接传入绝对前缀：

```bash
make -C verify/apps/coremark \
  CROSS_COMPILE="$HOME/opt/loongarch32s-unknown-linux-gnusf-gcc-16.2.0-ubuntu22.04/bin/loongarch32s-unknown-linux-gnusf-"
```

## 常见问题

- **`...-gcc: No such file or directory`**：检查 `TOOLCHAIN` 路径、`PATH`，以及 `CROSS_COMPILE` 是否以连字符结尾。
- **误用了系统默认工具链**：运行 `"${CROSS_COMPILE}gcc" -dumpmachine`，确认输出为 `loongarch32s-unknown-linux-gnusf`。
- **在非 Ubuntu 22.04 主机上不能启动**：该二进制工具链可能依赖发行版提供的动态库。请在兼容环境使用，或改用与主机兼容的 LA32S 工具链；不要将主机上的库文件复制进本仓库。

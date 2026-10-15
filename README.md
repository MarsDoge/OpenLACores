# OpenLACores

[English README](README_en.md)

OpenLACores 是一个以 OpenLA132、OpenLA264 为核心的 LoongArch 架构处理器设计和验证工程。

工程包含处理器 RTL 设计源码，和裸机软件运行环境、LoongArch 功能模型仿真、Verilator 差分验证，以及面向龙芯实验箱板卡和 Xilinx VU13P FPGA 的 Vivado FPGA 实现流程。

工程旨在提供处理器 RTL 设计、实现功能校验、裸机程序测试和 FPGA 启动验证等芯片设计流程的理解和帮助。

##  OpenLA132

OpenLA132 是 32 位 LoongArch 核，具有 32 位通用寄存器，以及 32 位虚拟地址/物理地址访问空间。微结构设计上，实现为包含取指译码、执行、访存和退休阶段的四级流水线。

运行 CoreMark 测试程序，其结果约为 2.4 CoreMark/MHz；运行 Dhrystone 测试程序，其结果约为 1.816 DMIPS/MHz。

[查看详细文档](docs/OpenLA132/README.md)

## 仓库结构

~~~text
.
├── design/
│   ├── filelist/openla132.f      # OpenLA132 RTL 文件列表
│   └── sys/openla132/
│       ├── ifu/ dsu/ exu/ rtu/   # 取指、译码、执行和退休 RTL
│       ├── lsu/ mmu/ csr/ biu/   # 访存、地址转换、CSR 和总线 RTL
│       ├── ram_arrays/           # Cache data/tag/LRU RAM 封装
│       ├── libwrapper/           # SRAM、时钟门控和工艺封装
│       ├── ljtag/                # JTAG/cJTAG 逻辑
│       ├── include/              # RTL 参数、宏和总线宽度定义
│       └── top/                  # 核心与 IP 顶层集成
├── docs/                         # IP 集成应用手册
├── impl/                         # Vivado 工程、板卡配置、loader 与下载脚本
├── toolchains/                   # LA32S 交叉工具链压缩包和使用说明
└── verify/
    ├── apps/                     # 裸机程序、基准和随机测试、公共软件
    ├── kernel/                   # Linux Kernel
    └── verilator/                # 独立 Verilator 仿真程序
~~~

| 范围 | 内容 |
| --- | --- |
| 处理器 RTL | OpenLA132 核心、取指/译码/执行/退休、LSU、CSR、MMU、JTAG、AXI、缓存与 RAM/标准单元封装。 |
| 软件环境 | 面向 OpenLA132 的复位入口、链接脚本、堆、控制台、计时器、系统调用桩，以及 hello、CoreMark、Dhrystone、RT-Thread Nano 和 Linux 示例。 |
| RTL 仿真 | 独立 Verilator 顶层直接例化 openla132_ip_top，提供稀疏 AXI RAM、16550 UART、ELF/raw BIN 加载、提交日志、VCD 和 checkpoint。 |
| 差分验证 | loong-emu 可构建 DiffTest reference 动态库；Verilator 在提交边界比较 PC 与寄存器状态，并处理 OpenLA132 特有的微操作和异常边界。 |
| FPGA | impl/ 支持 VU13P 与 LSBD，包含 Block Design、DDR、UART、loader、JTAG 下载、ILA 和 Linux 启动脚本。 |

##  快速启动

在 Loongson 3A5000 Deepin 系统，与 x86_64 Ubuntu 22.04/24.04 系统上，均支持 Verilator 仿真。目前，只在 x86_64 Ubuntu 22.04/24.04 系统上支持 FPGA 烧录运行。

1. 使用环境：

完整安装与检查步骤见 [开发环境安装指南](docs/environment_setup.md)，包括：

- GNU Make、宿主机 C/C++ 编译环境和 Python 3
- [LA32S 交叉编译工具链](toolchains/README.md)
- Verilator；GTKWave 为查看 VCD 波形的可选工具；
- Vivado，用于 FPGA 构建；已验证版本及板卡相关限制以 impl/README.md 的记录为准；
- Linux 内核构建依赖，仅在构建 Linux 时需要。

2. 环境变量设置：

``` shell
export TOOLCHAIN="$HOME/gcc/loongarch32s-unknown-linux-gnusf-gcc-16.2.0-ubuntu22.04"
export CROSS_COMPILE="$TOOLCHAIN/bin/loongarch32s-unknown-linux-gnusf-"
```

3. **构建裸机应用**

公共软件构建规则使用 LA_PROFILE 选择目标 ISA。当前 OpenLA132 应显式使用 LA_PROFILE=la32s。

``` shell
make -C verify/apps/hello LA_PROFILE=la32s CROSS_COMPILE="$CROSS_COMPILE"
make -C verify/apps/coremark LA_PROFILE=la32s CROSS_COMPILE="$CROSS_COMPILE"
make -C verify/apps/dhrystone LA_PROFILE=la32s CROSS_COMPILE="$CROSS_COMPILE"
```
其编译结果与用途如下：

| 文件后缀 | 用途 |
| --- | --- |
| .exe（ELF） | 推荐用于仿真器；保留入口地址和多个加载段。 |
| .bin | 适用于固定地址的裸二进制加载或 FPGA 初始化流程。 |
| .S / .s、.map | 用于定位符号、反汇编和链接布局问题。 |

另外，不同应用所需的 C 库、链接地址和启动方式可能不同；不要将 Linux 用户态工具链与裸机应用的链接规则混用。

4.  **Verilator 仿真**

可参考文档[verify/verilator/README.md](verify/verilator/README.md)。

需要先构建 loong-emu 参考模型：
``` shell
#   Download
git clone https://github.com/Open-ChipHub/loong-emu.git ./verify/loong-emu/
#   build
make -C verify/loong-emu DIFF=1
```
再构建 Verilator 仿真器。

``` shell
make -C verify/verilator
```

仿真运行：

``` bash
# 仅运行 RTL、AXI RAM 和 UART 模型
make run-nodiff IMAGE=../apps/coremark/coremark.exe

# 同时运行 DiffTest
make run IMAGE=../apps/coremark/coremark.exe
```

实际运行 Coremark 结果：
``` shell
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

5.  **常用调试方式**：

``` bash
# 记录提交，并限制仿真周期
make -C verify/verilator run-nodiff IMAGE=../apps/coremark/coremark.exe RUN_ARGS="--max-cycles 200000 --commit-log --quiet-uart"

# 生成 VCD 波形
make -C verify/verilator run-nodiff IMAGE=../apps/coremark/coremark.exe RUN_ARGS="--max-cycles 200000 --trace coremark.vcd --quiet-uart"

gtkwave verify/verilator/coremark.vcd
```

工程支持 checkpoint、恢复运行、Linux 多镜像加载等多种功能，运行参数与调试配置，请参考文档。

6.  **随机指令测试**：

verify/apps/random/ 只保存测试集说明。随机测试镜像请根据说明文档，单独下载后，放置仓库目录 verify/apps/random/ 下。

运行前请将 IMAGE 替换为实际 .bin 的路径。单个镜像可直接运行：

``` bash
make -C verify/verilator run IMAGE=/path/to/<test>.bin RUN_ARGS="--max-cycles 100000000 --quiet-uart"
``` 

随机指令已经限制在 OpenLA132 已实现的 ISA 子集内。

未实现指令可能造成异常循环，表现为无法到达 GOOD TRAP。

7.  **Linux Kernel**

[Linux 构建说明](verify/kernel/README.md)：提供 la32s.config、labcore.dts，并说明 LA32S 补丁、vmlinux、vmlinux.bin 和 DTB 的生成。

8.  **FPGA bitstream 与上板**

工程支持 FPGA 板卡清单如下：

| 项目 | 龙芯实验箱（默认） | VU13P |
| --- | --- | --- |
| 选择方式 | BOARD=lsbd | BOARD=vu13p |
| FPGA 型号 | xc7a200t-fbg676-2 | xcvu13p-fhgb2104-2-i |
| 默认 CPU 时钟 | 50 MHz，可通过 CPU_FREQ_HZ 配置 | 100 MHz |
| 外部内存 | 单颗 16 位 DDR3，128 MiB | DDR4 |
| JTAG AXI | 32 位地址/数据 | 32 位地址/数据 |
| 工程工作目录 | xlnx-work-lsbd | xlnx-work-vu13p |

impl/ 以 LSBD 为默认板卡，也支持 VU13P。通过 BOARD 选择目标，通过 VIVADO 指定 Vivado 可执行文件：

``` bash
make -C impl BOARD=lsbd config
make -C impl VIVADO=/opt/Xilinx/Vivado/2022.2/bin/vivado BOARD=lsbd bitstream
make -C impl VIVADO=/opt/Xilinx/Vivado/2022.2/bin/vivado BOARD=lsbd upload
```

upload 除 bitstream 外还涉及 loader、内核镜像、JTAG 硬件选择和板卡特定参数。Linux 内核目录和交叉工具链可通过 KERNEL_DIR、CROSS_COMPILE 覆盖。请参考
[impl/README.md](impl/README.md)。

## 文档导航

| 内容 | 文档 |
| --- | --- |
| OpenLA132 说明 | [OpenLA132 处理器 IP 特性与使用](docs/OpenLA132/README.md) |
| Verilator、波形、checkpoint、DiffTest | [verify/verilator/README.md](verify/verilator/README.md) |
| 公共裸机 runtime（小型libc） | [verify/common/README.md](verify/apps/common/README.md) |
| CoreMark | [verify/apps/coremark/README.md](verify/apps/coremark/README.md) |
| Dhrystone | [verify/apps/dhrystone/README.md](verify/apps/dhrystone/README.md) |
| 随机测试集 | [verify/apps/random/README.md](verify/apps/random/README.md) |
| Linux | [verify/kernel/linux/README.md](verify/kernel/linux/README.md) |
| FPGA 构建、地址映射、上板 | [impl/README.md](impl/README.md) |
| FPGA Block Design 管理 IP | [impl/ip/README.md](impl/ip/README.md) |
| 交叉工具链 | [toolchains/README.md](toolchains/README.md) |

## 联系我们

如果想加入我们，或对工程部分有疑问，可通过以下方式联系我们：

邮箱：

-   loongsonlab@loongson.cn

## 贡献与协作说明

贡献流程、问题反馈、提交和评审要求请见[贡献与协作说明](docs/contributing.md)。

##  致谢

感谢龙芯中科技术股份有限公司的支持。

##  许可证

工程采用 [木兰宽松许可证，第 2 版（Mulan PSL v2）](LICENSE)。

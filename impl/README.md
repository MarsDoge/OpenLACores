# OpenLACores 统一 FPGA 实现流程

`impl` 是面向 VU13P 和 LSBD 板卡的统一 Vivado FPGA 流程。使用
`BOARD=vu13p` 或 `BOARD=lsbd` 选择板卡。

lsbd 是主要目标且仍为默认值，因此现有命令（例如 `make -C impl bitstream`）保持原有行为。

## 板卡选择

当前工程支持的板卡如下：

| 设置 | LSBD（默认） | VU13P |
| --- | --- | --- |
| 命令 | `BOARD=lsbd` | `BOARD=vu13p` |
| FPGA 型号 | `xc7a200t-fbg676-2` | `xcvu13p-fhgb2104-2-i` |
| 工程 | `openla132s_lsbd_bd` | `openla132s_xlnx_bd` |
| 工作根目录 | `xlnx-work-lsbd` | `xlnx-work-vu13p` |
| CPU 时钟 | 默认 50 MHz，可配置 | 默认 100 MHz |
| Block Design 时钟 | 100 MHz | 100 MHz |
| CPU AXI | 32 位地址/数据，4 位 ID | 32 位地址/数据，4 位 ID |
| 内部 AXI 数据宽度 | 64 位 | 64 位 |
| 内存 AXI | 128 MiB DDR3，32 位 AXI 地址/64 位 AXI 数据 | DDR4，64 位数据 |
| JTAG AXI | 32 位地址/数据 | 32 位地址/数据 |
| Vivado 策略 | 面向性能优化 | 面向性能优化 |

板卡默认设置位于 `boards/vu13p.mk` 和 `boards/lsbd.mk`。通常仍可在命令行覆盖
这些设置，但 JTAG 位宽必须与已烧录的 Block Design 相匹配。

```sh
make -C impl config
make -C impl BOARD=lsbd config
make -C impl BOARD=vu13p bitstream
make -C impl BOARD=lsbd bitstream
```

修改所选板卡、CPU 文件列表、Block Design Tcl、MIG 工程、FPGA 型号、约束文件或
顶层集成后，应执行 `reproject`。

如果想为工程适配其他板卡，请参考[新增 FPGA 开发板配置指南](boards/README.md)。

## 通用架构

两块板卡均实例化相同的 LA132 源文件列表、FPGA 标准单元替代实现、32 位 CPU AXI
适配器、loader、工程脚本、综合流程和烧录载荷生成器。板卡专有文件仅包括：

- `boards/` 下的板卡默认设置；
- `bd/` 下的 VU13P DDR4 和 LSBD DDR3 Block Design Tcl 文件；
- `constraints/` 下的 AXVU13P 和 LSBD 约束文件；
- `soc/` 下的结构化板级外壳；
- `ip/xlnx_mig_axi/config/` 下纳入版本管理的 LSBD MIG 配置。

VU13P 保持 100 MHz 默认频率。对于 LSBD，Clocking Wizard 从板载单端 100 MHz
振荡器生成所选 CPU 时钟，以及固定的 MIG 100/200 MHz 输入。仅 CPU 和显式 AXI
Clock Converter 的 S_AXI 侧使用所选频率。其 M_AXI 侧以及完整 Block Design
逻辑（包括 64 位互连、MIG UI、JTAG AXI、VIO、UART 和 loader RAM）均保持在
100 MHz。

以整数 Hz 设置 LSBD 的 CPU 请求频率；频率改变后必须重建工程。Clocking Wizard
会使用最接近的合法 PLL 比率，并将实际实现的频率传递给 CPU AXI 接口和调试 hub：

```sh
make -C impl BOARD=lsbd CPU_FREQ_HZ=20000000 rebuild
```

## 地址映射

### VU13P

仅映射 DDR4 的低 4 GiB，并保留原有的外设空洞。

| 目标 | CPU/JTAG 地址窗口 |
| --- | --- |
| DDR4 | `0x00000000 <= addr < 0x1f000000` |
| AXI UART 16550 | `0x1fe00000 <= addr < 0x1fe01000` |
| DDR4 | `0x20000000 <= addr < 0x100000000` |

### LSBD

LSBD 板卡配备一颗 16 位 `MT41J64M16XX-125` DDR3。其 13 位行地址、10 位列地址和
3 位 bank 地址位恰好提供 128 MiB 容量，Block Design 对该容量只映射一次。

| 目标 | Block Design 地址窗口 |
| --- | --- |
| DDR3 | `0x00000000 <= addr < 0x08000000` |
| 4 KiB loader AXI RAM | `0x1c000000 <= addr < 0x1c001000` |
| AXI UART 16550 | `0x1fe00000 <= addr < 0x1fe01000` |

CPU 与 JTAG AXI 使用相同的三个 Block Design 地址段。CPU AXI 地址以原值进入
Block Design：DDR 仅映射一次；复位和 loader 窗口由 AMD `axi_bram_ctrl` 与
`blk_mem_gen` 提供；UART 保持其架构地址。未映射地址会返回 AXI decode error，
而不会回绕到低 128 MiB DDR 窗口。

## Loader 与烧录

`loader/` 构建一个链接到 `0x1c000000` 的 ELF32 `la32rv1.0` 镜像。VU13P 与 LSBD
均将其烧录到该地址；在 LSBD 上，它从专用的 4 KiB AXI RAM 执行。RAM 最后 64 字节
（从 `0x1c000fc0` 开始）保留给 loader 状态，构建流程会拒绝大于 4,032 字节的
loader。LSBD 的 loader 栈位于 DDR 中的 `0x07f00000`。Linux 原始镜像加载到物理
地址 `0x00200000`。在将 DMW 地址转换为物理烧录地址时，loader 和
`scripts/download_bit_ddr_and_run.tcl` 会清除 LA32 DMW 段位 `[31:29]`。

内核要求 `a1/fw_arg1` 指向物理命令行缓冲区。loader 会复制一条板卡专用字符串到
`0x00100000` 并传递该地址，而不是传递零。VU13P 使用有效的空字符串，并保留设备树
内置的 bootargs。LSBD 会添加 `mem=128M`，以防内核访问物理 DDR 上限之外、设备树中
所声明的 256 MiB 区域。

当前 LSBD Systemd rootfs 需要压缩的内置 initramfs。在外部内核树中，启用
`CONFIG_INITRAMFS_COMPRESSION_GZIP`，并禁用 `CONFIG_INITRAMFS_COMPRESSION_NONE`；
原始的 38 MiB 未压缩归档在解包期间会超过 128 MiB 的启动时内存预算。

两块板卡的同一烧录文件均为每条记录 1024 字节。通用下载 Tcl 会根据所选板卡生成
硬件传输格式：

- VU13P 每条记录发送 128 个 64 位 JTAG AXI 数据字；
- LSBD 每条记录发送 256 个 32 位 JTAG AXI 数据字。

该脚本还会按 FPGA 器件名称选择硬件，而不是盲目使用第一根下载线。默认器件为
`xcvu13p_0` 和 `xc7a200t_0`。若存在多个匹配器件，请显式选择匹配器件的索引：

```sh
make -C impl BOARD=vu13p upload
make -C impl BOARD=lsbd upload
make -C impl BOARD=lsbd FPGA_HW_TARGET_INDEX=1 upload
```

`upload`、`jtag-read`、`jtag-write`、`cpu-hold`、`cpu-release` 和 `cpu-reset`
均使用相同的板卡专用 Hardware Manager 设置。LSBD 还提供
`capture-lsbd-status-ila`，用于导出常规 bitstream 中已包含的 26 探针
时钟/复位/JTAG/MIG 状态 ILA 核。

## 验证情况

`BOARD=vu13p reproject` 与 `BOARD=lsbd reproject` 均已在 Vivado 2023.2 下完成。
生成的 LSBD Block Design 可通过 `validate_bd_design`，没有错误或严重警告，并检查：

- 32 位 CPU 地址/数据宽度与 4 位 CPU ID 宽度；
- 从所选 CPU 时钟域到 100 MHz Block Design 时钟域的异步 AXI Clock Converter；
- 64 位内部互连与 MIG AXI 数据宽度；
- 32 位 LSBD JTAG AXI 地址/数据宽度；
- CPU/JTAG 对 128 MiB DDR、4 KiB loader RAM 和 UART 的相同映射；
- 4 KiB、64 位 AMD AXI BRAM 控制器与块 RAM 实现；
- 上电时保持断言的 VIO CPU 复位信号。

2026-08-31 的地址映射更新已在非默认 `CPU_FREQ_HZ=20000000` 下完成独立 LSBD
`reproject`；请求与实际实现的 CPU 时钟均报告为 20.000000 MHz。BD 验证、wrapper
生成和受管理 IP 生成均已通过。该新布局仍需重新执行完整综合、实现、bitstream 生成
和硬件烧录。

此前基于别名的布局完成过 bitstream 生成，WNS 为 `+0.123 ns`、WHS 为
`+0.006 ns`，且三次 gzip-initramfs 烧录均到达 `SYSTEM_RUNNING`。这些历史结果不验证
新的专用 loader-RAM 布局。

生成的 Vivado 工程、IP 产物、检查点、报告和 bitstream 均保存在所选的、已忽略的
`WORK_ROOT` 目录下。

##	运行样例

在龙芯实验箱上启动 Linux kernel。

首先，请参考[Linux kernel构建说明](../verify/kernel/linux/README.md)。

然后，在终端运行：
``` shell
make -C impl/ BOARD=lsbd VIVADO=/path/to/vivado CROSS_COMPILE="$CROSS_COMPILE" CONFIG_MMU=1 bitstream
make -C impl/ BOARD=lsbd VIVADO=/path/to/vivado CROSS_COMPILE="$CROSS_COMPILE" KERNEL_DIR=./verify/kernel/ CONFIG_MMU=1 upload
```

最后，请将龙芯实验箱连接串口线到调试机上，并在调试机上打开串口软件，如 minicom 等，即可在串口接受到 Linux kernel 启动打印信息，并进行交互。

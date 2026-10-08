# 新增 FPGA 开发板配置指南

`impl/boards/` 中的每个 `.mk` 文件描述一款 FPGA 开发板的默认工程参数。顶层
`impl/Makefile` 根据 `BOARD=<名称>` 选择对应文件：

```text
BOARD=<board_id>
        ↓
impl/boards/<board_id>.mk
        ↓
Vivado 工程、Block Design、约束、JTAG 下载与 loader 参数
```

`.mk` 文件不包含板级 RTL、XDC 或 Block Design 本身；它仅将这些文件和硬件参数统一
传递给 `impl/scripts/` 下的 Vivado Tcl 流程。新增板卡时，必须同时准备与该参数一致的
顶层、约束和 Block Design。

## 1. 新板卡接入前的准备

先明确以下硬件信息：

- FPGA 完整料号，例如 `xc7a200t-fbg676-2`；
- 板载输入时钟频率、计划使用的 CPU 时钟频率，以及 DDR/MIG 所需时钟；
- DDR 类型、容量、数据位宽和其在 CPU AXI 地址空间中的窗口；
- UART、loader RAM、JTAG AXI、VIO/ILA 等 IP 的地址及位宽；
- JTAG 硬件 target、器件名称和允许的 JTAG 时钟频率；
- 新板卡对应的 XDC、SoC 顶层 Verilog 和 Block Design Tcl 文件。

建议从硬件结构最接近的现有文件复制：`vu13p.mk` 适合作为高端 DDR4/VU 系列板卡的
起点，`lsbd.mk` 适合作为 Artix-7、DDR3 和 32 位 JTAG AXI 板卡的起点。

## 2. 创建 `.mk` 文件

以下示例创建名为 `myboard` 的配置。所有路径均相对于 `impl/` 目录；使用 `?=` 而非
`:=`，以便用户可在命令行覆盖默认值。

```make
# impl/boards/myboard.mk

PROJECT_NAME ?= openla132s_myboard_bd
WORK_ROOT ?= xlnx-work-myboard
PROJECT_DIR ?= $(WORK_ROOT)/$(PROJECT_NAME)

# Vivado 器件和 CPU 时钟
FPGA_PART ?= <vivado-fpga-part>
CPU_FREQ_HZ ?= <cpu-clock-hz>

# 板级集成文件
CONSTRAINT_FILE ?= constraints/myboard.xdc
TOP_FILE ?= soc/xlnx_soc_myboard_bd.v
TOP_MODULE ?= $(basename $(notdir $(TOP_FILE)))
BD_NAME ?= xlnx_myboard_peripherals_bd
BD_TCL ?= bd/xlnx_soc_myboard_peripherals_bd.tcl
VERILOG_DEFINES ?=
FPGA_FILELIST ?= openla132.f
FPGA_SYNTH_STRATEGY ?= Flow_PerfOptimized_high

# Vivado Hardware Manager 与 JTAG AXI 参数
FPGA_HW_TARGET_PATTERN ?= */xilinx_tcf/Digilent/*
FPGA_HW_TARGET_INDEX ?= 0
FPGA_HW_FREQUENCY_HZ ?= 15000000
FPGA_HW_DEVICE_PATTERN ?= <vivado-device-name>
FPGA_HW_AXI_NAME ?= hw_axi_1
JTAG_AXI_ADDR_WIDTH ?= <32-or-64>
JTAG_AXI_DATA_WIDTH ?= <32-or-64>
JTAG_AXI_SANITY_ADDRESS ?= <mapped-readable-address>
UPLOAD_TRANSACTION_BYTES ?= 1024

# 可选：仅在 loader RAM 布局不同于通用默认值时覆盖。
# BIOS_OFFSET ?= 0x1c000000
# KERNEL_OFFSET ?= 0x00200000
# LOADER_STATUS_OFFSET ?= <status-address>
# LOADER_MAX_BYTES ?= <loader-ram-bytes-minus-status-area>
# LOADER_STACK_ADDR ?= <ddr-stack-address>
# LOADER_BOOTARGS ?= <kernel-command-line>
# JTAG_ADDR ?= $(LOADER_STATUS_OFFSET)
```

将尖括号中的占位符替换为实际数值。`BOARD` 标识建议仅使用小写字母、数字和下划线，
并使文件名严格为 `<board_id>.mk`；例如 `BOARD=myboard` 对应 `boards/myboard.mk`。

## 3. 参数说明

### 3.1 工程与综合参数

| 变量 | 必需 | 含义 |
| --- | --- | --- |
| `PROJECT_NAME` | 是 | Vivado 工程名。不同板卡必须不同，避免工程目录冲突。 |
| `WORK_ROOT` | 是 | 可再生 Vivado 工作目录。建议使用板卡专属名称。 |
| `PROJECT_DIR` | 是 | 通常设为 `$(WORK_ROOT)/$(PROJECT_NAME)`。 |
| `FPGA_PART` | 是 | Vivado 识别的完整 FPGA part 名称，必须包含封装和速度等级。 |
| `CPU_FREQ_HZ` | 是 | 请求的 CPU 时钟频率，单位 Hz；顶层和 BD Tcl 必须实际使用该参数。 |
| `CONSTRAINT_FILE` | 是 | XDC 文件，包含时钟定义、管脚、电气与时序约束。 |
| `TOP_FILE` / `TOP_MODULE` | 是 | 板级 SoC 顶层文件及模块名。默认模块名从文件名推导。 |
| `BD_NAME` / `BD_TCL` | 是 | Block Design 名称及创建/连接该 BD 的 Tcl 脚本。 |
| `FPGA_FILELIST` | 是 | CPU RTL 文件列表。当前通用设置为 `openla132.f`。 |
| `VERILOG_DEFINES` | 否 | 板级 RTL 所需的宏定义，以空格分隔；必须与顶层/BD 使用的宏一致。 |
| `FPGA_SYNTH_STRATEGY` | 否 | Vivado 综合策略，默认可使用 `Flow_PerfOptimized_high`。 |

`CPU_FREQ_HZ` 不能只在 `.mk` 中修改：若 Block Design 内有 Clocking Wizard、AXI Clock
Converter 或 MIG 时钟约束，相关 Tcl 和 XDC 也必须同步调整。否则配置命令显示的频率
与实际硬件频率会不一致。

### 3.2 Hardware Manager 与 JTAG AXI 参数

| 变量 | 必需 | 含义 |
| --- | --- | --- |
| `FPGA_HW_TARGET_PATTERN` | 是 | Hardware Manager target 的匹配模式。 |
| `FPGA_HW_TARGET_INDEX` | 是 | 同一模式匹配多个 target 时选择的索引，从 0 开始。 |
| `FPGA_HW_FREQUENCY_HZ` | 是 | JTAG 时钟频率，不是 CPU 时钟。 |
| `FPGA_HW_DEVICE_PATTERN` | 是 | Hardware Manager 中 FPGA 器件实例名，例如 `xc7a200t_0`。 |
| `FPGA_HW_AXI_NAME` | 是 | Vivado Hardware Manager 中 JTAG-to-AXI IP 的对象名。 |
| `JTAG_AXI_ADDR_WIDTH` | 是 | JTAG AXI 地址宽度，必须与 BD 中 JTAG AXI Master 配置一致。 |
| `JTAG_AXI_DATA_WIDTH` | 是 | JTAG AXI 数据宽度，必须与 BD 中 JTAG AXI Master 配置一致。 |
| `JTAG_AXI_SANITY_ADDRESS` | 是 | `jtag-read`/`jtag-write` 用于连通性检查的已映射地址。 |
| `UPLOAD_TRANSACTION_BYTES` | 是 | 下载脚本单条写事务的字节数；必须能被 JTAG AXI 数据位宽整除。 |

`JTAG_AXI_*` 与 Block Design 不一致时，工程可能仍能综合，但 `upload`、`jtag-read` 或
`jtag-write` 会因传输宽度、地址格式或对象名称不匹配而失败。

### 3.3 Loader 与 Linux 载荷参数

顶层 Makefile 默认将 loader 放在 `BIOS_OFFSET=0x1c000000`，将 Linux raw image 放在
`KERNEL_OFFSET=0x00200000`。若新板卡沿用该布局，通常无需在 `.mk` 中重复定义。

如果板级 BRAM 或 DDR 地址布局不同，可覆盖以下变量：

| 变量 | 用途 |
| --- | --- |
| `BIOS_OFFSET` | loader 的 CPU/JTAG 物理地址。 |
| `KERNEL_OFFSET` | `vmlinux.bin` 的物理加载地址。 |
| `LOADER_STATUS_OFFSET` | loader 状态字地址，也可用于下载后的启动诊断。 |
| `LOADER_MAX_BYTES` | loader RAM 可用容量上限；设置后构建时会检查 loader 大小。 |
| `LOADER_STACK_ADDR` | loader 使用的 DDR 栈地址，必须位于有效 DDR 范围。 |
| `LOADER_BOOTARGS` | loader 传给 Linux 的内核命令行。 |
| `JTAG_ADDR` | 未显式传入时，`jtag-read`/`jtag-write` 使用的默认地址。 |

这些地址必须同时与 BD Address Editor、SoC 顶层地址解码、内核 DTS 的 memory 节点及
loader 链接/启动逻辑一致。只修改 `.mk` 不会自动创建新的地址映射。

## 4. 在顶层 Makefile 注册板卡

创建 `boards/myboard.mk` 后，编辑 `impl/Makefile`，将板卡 ID 加入
`SUPPORTED_BOARDS`：

```make
SUPPORTED_BOARDS := vu13p lsbd myboard
```

否则执行 `make -C impl BOARD=myboard ...` 会报 `Unsupported BOARD`。如果希望在
`make help` 中展示新板卡，还应在 help 文本中添加相应示例；不修改默认 `BOARD ?= vu13p`
即可保持现有默认板卡不变。

## 5. 接入与检查流程

新增板卡至少需要以下文件同步完成：

```text
impl/boards/myboard.mk                 参数入口
impl/constraints/myboard.xdc           板级时钟与引脚约束
impl/soc/xlnx_soc_myboard_bd.v         板级 SoC 顶层
impl/bd/xlnx_soc_myboard_peripherals_bd.tcl
                                       Block Design 创建与互连
```

如 DDR、Clocking Wizard、MIG 或 JTAG AXI 的 IP 参数与现有板卡不同，还需要在 `ip/`
中加入其可复现的配置来源，并在 BD Tcl 中完成实例化和地址分配。

建议按以下顺序检查：

```bash
# 1. 仅解析 Makefile 参数，不启动 Vivado。
make -C impl BOARD=myboard config

# 2. 创建/重建 Vivado 工程，并让 Tcl 验证 Block Design。
make -C impl BOARD=myboard \
  VIVADO=/opt/Xilinx/Vivado/2022.2/bin/vivado reproject

# 3. 先综合，再实现和生成 bitstream。
make -C impl BOARD=myboard \
  VIVADO=/opt/Xilinx/Vivado/2022.2/bin/vivado syn
make -C impl BOARD=myboard \
  VIVADO=/opt/Xilinx/Vivado/2022.2/bin/vivado bitstream
```

在确认器件、JTAG target、AXI 位宽和地址映射正确前，不要执行 `upload` 或 `jtag-write`。
上板前还应确认 loader、Linux DTS 和 `LOADER_BOOTARGS` 所声明的内存容量不超过实际 DDR
容量。

## 6. 最小检查清单

- [ ] `BOARD=<board_id>` 已加入 `SUPPORTED_BOARDS`。
- [ ] `FPGA_PART` 与器件丝印、Vivado part 名称完全一致。
- [ ] XDC 覆盖输入时钟、复位、DDR、UART、JTAG 所需约束。
- [ ] 顶层模块名、`TOP_FILE`、`TOP_MODULE` 和 BD wrapper 名称一致。
- [ ] CPU/JTAG AXI 位宽、地址窗口和时钟域转换与 BD 一致。
- [ ] `JTAG_AXI_SANITY_ADDRESS` 是实际可读写的映射地址。
- [ ] loader、内核、DTS 与 DDR 容量的地址布局一致。
- [ ] `make -C impl BOARD=<board_id> config` 输出符合预期。
- [ ] `reproject`、`syn`、`bitstream` 完成后再进行硬件下载验证。

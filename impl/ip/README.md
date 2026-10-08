# 由 Block Design 管理的 IP

`impl/ip` 目录不保存独立的外设 XCI 文件。 VU13P的
[`bd/xlnx_soc_peripherals_bd.tcl`](../bd/xlnx_soc_peripherals_bd.tcl) 与 LSBD
[`bd/xlnx_soc_lsbd_peripherals_bd.tcl`](../bd/xlnx_soc_lsbd_peripherals_bd.tcl)
脚本，会在所选 Vivado Block Design 中创建并配置 AMD 外设 IP。

本目录主要是为龙芯实验箱（LSBD）提供DDR3的IP参数等：
[`xlnx_mig_axi/config/lsbd_axi64.prj`](xlnx_mig_axi/config/lsbd_axi64.prj)

该文件是 LSBD 板卡 `MT41J64M16XX-125` DDR3 的唯一配置依据，
其中包含引脚、时序、16 位物理数据总线、128 MiB 容量、32 位 AXI 地址宽度和
64 位 AXI 数据宽度。

另外，LSBD Block Design 还会创建一组 AMD `axi_bram_ctrl` 与 `blk_mem_gen` IP，
作为位于 `0x1c000000` 的 4 KiB loader RAM。这些受管理的 IP 实例由纳入版本管理的
Tcl 脚本生成，而非保存为独立的 XCI 文件。

生成的 XCI、输出产物、检查点和 wrapper 均保存在所选的 `WORK_ROOT` 目录下。

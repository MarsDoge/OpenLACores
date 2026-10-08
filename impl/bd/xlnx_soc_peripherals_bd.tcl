#
# Copyright (c) 2026 Loongson Technology Corporation Limited. 
#
# OpenLACores is licensed under Mulan PSL v2.
#
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# 
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
#
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
#
# See the Mulan PSL v2 for more details.
#

if {![info exists bd_name] || [string trim $bd_name] eq ""} {
    error "bd_name must be set before sourcing the peripheral BD script"
}
if {![info exists cpu_frequency_hz] ||
    ![string is integer -strict $cpu_frequency_hz] ||
    $cpu_frequency_hz < 1} {
    error "cpu_frequency_hz must be a positive integer"
}
set cpu_frequency_mhz [expr {$cpu_frequency_hz / 1000000.0}]
set cpu_axi_addr_width 32
set cpu_axi_data_width 32
set cpu_axi_id_width 4
set fabric_axi_data_width 64

create_bd_design $bd_name
current_bd_design $bd_name

# ---------------------------------------------------------------------------
# External board, CPU, and status ports
# ---------------------------------------------------------------------------

set sys_rst_n [create_bd_port -dir I -type rst sys_rst_n]
set_property CONFIG.POLARITY ACTIVE_LOW $sys_rst_n

set uart_rx [create_bd_port -dir I uart_rx]
set uart_tx [create_bd_port -dir O uart_tx]
set cpu_clk [create_bd_port -dir O -type clk cpu_clk]
set_property CONFIG.FREQ_HZ $cpu_frequency_hz $cpu_clk
set cpu_rst_b [create_bd_port -dir O -type rst cpu_rst_b]
set_property CONFIG.POLARITY ACTIVE_LOW $cpu_rst_b
set bd_cpu_ext_interrupt \
    [create_bd_port -dir O -from 7 -to 0 -type intr bd_cpu_ext_interrupt]
set led [create_bd_port -dir O -from 3 -to 0 led]

set cpu_bd_axi [create_bd_intf_port \
    -mode Slave \
    -vlnv xilinx.com:interface:aximm_rtl:1.0 \
    cpu_bd_axi]
set_property -dict [list \
    CONFIG.PROTOCOL {AXI4} \
    CONFIG.ADDR_WIDTH $cpu_axi_addr_width \
    CONFIG.DATA_WIDTH $cpu_axi_data_width \
    CONFIG.ID_WIDTH $cpu_axi_id_width \
    CONFIG.FREQ_HZ $cpu_frequency_hz \
    CONFIG.HAS_BURST {1} \
    CONFIG.HAS_LOCK {1} \
    CONFIG.HAS_CACHE {1} \
    CONFIG.HAS_PROT {1} \
    CONFIG.HAS_QOS {1} \
    CONFIG.HAS_REGION {0} \
    CONFIG.NUM_READ_OUTSTANDING {16} \
    CONFIG.NUM_WRITE_OUTSTANDING {16} \
] $cpu_bd_axi
set_property -dict [list \
    CONFIG.ASSOCIATED_BUSIF {cpu_bd_axi} \
    CONFIG.ASSOCIATED_RESET {cpu_rst_b} \
] $cpu_clk

# ---------------------------------------------------------------------------
# Peripheral and infrastructure IP
# ---------------------------------------------------------------------------

set ddr4_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:ddr4:2.2 \
    ddr4_0]
set_property -dict [list \
    CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
    CONFIG.C0.DDR4_AxiAddressWidth {34} \
    CONFIG.C0.DDR4_AxiDataWidth $fabric_axi_data_width \
    CONFIG.C0.DDR4_AxiIDWidth {9} \
    CONFIG.C0.DDR4_AxiNarrowBurst {false} \
    CONFIG.C0.DDR4_AxiSelection {true} \
    CONFIG.C0.DDR4_InputClockPeriod {5003} \
    CONFIG.C0.DDR4_MemoryPart {MTA16ATF2G64HZ-2G3} \
    CONFIG.C0.DDR4_MemoryType {SODIMMs} \
    CONFIG.C0.DDR4_TimePeriod {938} \
] $ddr4_0

make_bd_intf_pins_external [get_bd_intf_pins ddr4_0/C0_DDR4]
set c0_ddr4 [get_bd_intf_ports C0_DDR4_0]
set_property name c0_ddr4 $c0_ddr4
make_bd_intf_pins_external [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
set c0_sys_clk [get_bd_intf_ports C0_SYS_CLK_0]
set_property name c0_sys_clk $c0_sys_clk
set_property CONFIG.FREQ_HZ {199880000} $c0_sys_clk

set clk_wiz_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:clk_wiz:6.0 \
    clk_wiz_0]
set_property -dict [list \
    CONFIG.PRIM_SOURCE {Global_buffer} \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $cpu_frequency_mhz \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {false} \
] $clk_wiz_0

set axi_interconnect_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:axi_interconnect:2.1 \
    axi_interconnect_0]
set_property -dict [list \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {2} \
    CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
    CONFIG.XBAR_DATA_WIDTH $fabric_axi_data_width \
    CONFIG.S00_HAS_REGSLICE {3} \
    CONFIG.S01_HAS_REGSLICE {3} \
    CONFIG.M00_HAS_REGSLICE {3} \
    CONFIG.M01_HAS_REGSLICE {3} \
] $axi_interconnect_0

set cpu_axi_clock_converter [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:axi_clock_converter:2.1 \
    cpu_axi_clock_converter]
set_property -dict [list \
    CONFIG.PROTOCOL {AXI4} \
    CONFIG.ADDR_WIDTH $cpu_axi_addr_width \
    CONFIG.DATA_WIDTH $cpu_axi_data_width \
    CONFIG.ID_WIDTH $cpu_axi_id_width \
    CONFIG.ACLK_ASYNC {1} \
    CONFIG.SYNCHRONIZATION_STAGES {3} \
] $cpu_axi_clock_converter

set jtag_axi_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:jtag_axi:1.2 \
    jtag_axi_0]
set_property -dict [list \
    CONFIG.M_AXI_ADDR_WIDTH {64} \
    CONFIG.M_AXI_DATA_WIDTH {64} \
    CONFIG.M_AXI_ID_WIDTH {4} \
    CONFIG.M_HAS_BURST {0} \
    CONFIG.RD_TXN_QUEUE_LENGTH {8} \
    CONFIG.WR_TXN_QUEUE_LENGTH {8} \
] $jtag_axi_0

# probe_out0 drives the manual CPU reset and powers up asserted.  This keeps
# the CPU from fetching partially uploaded DDR contents immediately after FPGA
# configuration.  The upload flow releases it only after write/readback passes.
# probe_out1 and probe_out2 remain reserved for future reset scopes.
set xlnx_vio [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:vio:3.0 \
    xlnx_vio]
set_property -dict [list \
    CONFIG.C_PROBE_OUT2_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT1_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x1} \
    CONFIG.C_NUM_PROBE_OUT {3} \
    CONFIG.C_EN_PROBE_IN_ACTIVITY {0} \
    CONFIG.C_NUM_PROBE_IN {0} \
] $xlnx_vio

set axi_uart16550_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:axi_uart16550:2.0 \
    axi_uart16550_0]
set_property -dict [list \
    CONFIG.C_HAS_EXTERNAL_RCLK {0} \
    CONFIG.C_HAS_EXTERNAL_XIN {0} \
    CONFIG.C_S_AXI_ACLK_FREQ_HZ {100000000} \
    CONFIG.C_USE_MODEM_PORTS {0} \
    CONFIG.C_USE_USER_PORTS {0} \
    CONFIG.USE_BOARD_FLOW {false} \
    CONFIG.UART_BOARD_INTERFACE {Custom} \
] $axi_uart16550_0

set fabric_reset_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:proc_sys_reset:5.0 \
    fabric_reset_0]
set_property -dict [list \
    CONFIG.C_AUX_RESET_HIGH {0} \
] $fabric_reset_0

set cpu_reset_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:proc_sys_reset:5.0 \
    cpu_reset_0]
set_property -dict [list \
    CONFIG.C_AUX_RESET_HIGH {0} \
] $cpu_reset_0

set ddr_ui_reset_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:proc_sys_reset:5.0 \
    ddr_ui_reset_0]
set_property -dict [list \
    CONFIG.C_AUX_RESET_HIGH {1} \
] $ddr_ui_reset_0

set board_reset_not [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:util_vector_logic:2.0 \
    board_reset_not]
set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
] $board_reset_not

set cpu_reset_request_or [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:util_vector_logic:2.0 \
    cpu_reset_request_or]
set_property -dict [list \
    CONFIG.C_OPERATION {or} \
    CONFIG.C_SIZE {1} \
] $cpu_reset_request_or

set constant_zero [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:xlconstant:1.1 \
    constant_zero]
set_property -dict [list \
    CONFIG.CONST_WIDTH {1} \
    CONFIG.CONST_VAL {0} \
] $constant_zero

set constant_one [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:xlconstant:1.1 \
    constant_one]
set_property -dict [list \
    CONFIG.CONST_WIDTH {1} \
    CONFIG.CONST_VAL {1} \
] $constant_one

set interrupt_zero [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:xlconstant:1.1 \
    interrupt_zero]
set_property -dict [list \
    CONFIG.CONST_WIDTH {7} \
    CONFIG.CONST_VAL {0} \
] $interrupt_zero

set interrupt_concat [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:xlconcat:2.1 \
    interrupt_concat]
set_property -dict [list \
    CONFIG.NUM_PORTS {2} \
    CONFIG.IN0_WIDTH {1} \
    CONFIG.IN1_WIDTH {7} \
] $interrupt_concat

set status_concat [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:xlconcat:2.1 \
    status_concat]
set_property CONFIG.NUM_PORTS {4} $status_concat

# ---------------------------------------------------------------------------
# Clock and reset ownership
# ---------------------------------------------------------------------------

connect_bd_net [get_bd_pins ddr4_0/addn_ui_clkout1] \
    [get_bd_pins clk_wiz_0/clk_in1] \
    [get_bd_pins fabric_reset_0/slowest_sync_clk] \
    [get_bd_pins axi_interconnect_0/ACLK] \
    [get_bd_pins axi_interconnect_0/S00_ACLK] \
    [get_bd_pins axi_interconnect_0/S01_ACLK] \
    [get_bd_pins axi_interconnect_0/M01_ACLK] \
    [get_bd_pins cpu_axi_clock_converter/m_axi_aclk] \
    [get_bd_pins jtag_axi_0/aclk] \
    [get_bd_pins xlnx_vio/clk] \
    [get_bd_pins axi_uart16550_0/s_axi_aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] \
    [get_bd_ports cpu_clk] \
    [get_bd_pins cpu_reset_0/slowest_sync_clk] \
    [get_bd_pins cpu_axi_clock_converter/s_axi_aclk]

connect_bd_net [get_bd_ports sys_rst_n] \
    [get_bd_pins board_reset_not/Op1] \
    [get_bd_pins status_concat/In3]
connect_bd_net [get_bd_pins board_reset_not/Res] \
    [get_bd_pins ddr4_0/sys_rst] \
    [get_bd_pins fabric_reset_0/ext_reset_in] \
    [get_bd_pins cpu_reset_request_or/Op1] \
    [get_bd_pins ddr_ui_reset_0/aux_reset_in]
set vio_cpu_reset [create_bd_net vio_cpu_reset]
connect_bd_net -net $vio_cpu_reset \
    [get_bd_pins xlnx_vio/probe_out0] \
    [get_bd_pins cpu_reset_request_or/Op2]
connect_bd_net [get_bd_pins cpu_reset_request_or/Res] \
    [get_bd_pins cpu_reset_0/ext_reset_in]

connect_bd_net [get_bd_pins ddr4_0/c0_ddr4_ui_clk] \
    [get_bd_pins ddr_ui_reset_0/slowest_sync_clk] \
    [get_bd_pins axi_interconnect_0/M00_ACLK]
connect_bd_net [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] \
    [get_bd_pins ddr_ui_reset_0/ext_reset_in] \
    [get_bd_pins fabric_reset_0/mb_debug_sys_rst] \
    [get_bd_pins cpu_reset_0/mb_debug_sys_rst]

connect_bd_net [get_bd_pins clk_wiz_0/locked] \
    [get_bd_pins fabric_reset_0/dcm_locked] \
    [get_bd_pins cpu_reset_0/dcm_locked] \
    [get_bd_pins status_concat/In1]
connect_bd_net [get_bd_pins ddr4_0/c0_init_calib_complete] \
    [get_bd_pins fabric_reset_0/aux_reset_in] \
    [get_bd_pins cpu_reset_0/aux_reset_in] \
    [get_bd_pins status_concat/In0]

connect_bd_net [get_bd_pins constant_zero/dout] \
    [get_bd_pins ddr_ui_reset_0/mb_debug_sys_rst]
connect_bd_net [get_bd_pins constant_one/dout] \
    [get_bd_pins ddr_ui_reset_0/dcm_locked]

connect_bd_net [get_bd_pins fabric_reset_0/peripheral_aresetn] \
    [get_bd_pins axi_interconnect_0/ARESETN] \
    [get_bd_pins axi_interconnect_0/S00_ARESETN] \
    [get_bd_pins axi_interconnect_0/S01_ARESETN] \
    [get_bd_pins axi_interconnect_0/M01_ARESETN] \
    [get_bd_pins cpu_axi_clock_converter/m_axi_aresetn] \
    [get_bd_pins jtag_axi_0/aresetn] \
    [get_bd_pins axi_uart16550_0/s_axi_aresetn]
connect_bd_net [get_bd_pins cpu_reset_0/peripheral_aresetn] \
    [get_bd_ports cpu_rst_b] \
    [get_bd_pins status_concat/In2] \
    [get_bd_pins cpu_axi_clock_converter/s_axi_aresetn]
connect_bd_net [get_bd_pins ddr_ui_reset_0/peripheral_aresetn] \
    [get_bd_pins axi_interconnect_0/M00_ARESETN] \
    [get_bd_pins ddr4_0/c0_ddr4_aresetn]

# ---------------------------------------------------------------------------
# AXI fabric and peripheral connectivity
# ---------------------------------------------------------------------------

connect_bd_intf_net [get_bd_intf_ports cpu_bd_axi] \
    [get_bd_intf_pins cpu_axi_clock_converter/S_AXI]
connect_bd_intf_net [get_bd_intf_pins cpu_axi_clock_converter/M_AXI] \
    [get_bd_intf_pins axi_interconnect_0/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins jtag_axi_0/M_AXI] \
    [get_bd_intf_pins axi_interconnect_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] \
    [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M01_AXI] \
    [get_bd_intf_pins axi_uart16550_0/S_AXI]

connect_bd_net [get_bd_ports uart_rx] \
    [get_bd_pins axi_uart16550_0/sin]
connect_bd_net [get_bd_pins axi_uart16550_0/sout] \
    [get_bd_ports uart_tx]

connect_bd_net [get_bd_pins axi_uart16550_0/ip2intc_irpt] \
    [get_bd_pins interrupt_concat/In0]
connect_bd_net [get_bd_pins interrupt_zero/dout] \
    [get_bd_pins interrupt_concat/In1]
connect_bd_net [get_bd_pins interrupt_concat/dout] \
    [get_bd_ports bd_cpu_ext_interrupt]
connect_bd_net [get_bd_pins status_concat/dout] \
    [get_bd_ports led]

# ---------------------------------------------------------------------------
# Address map
# ---------------------------------------------------------------------------

set cpu_addr_space [get_bd_addr_spaces cpu_bd_axi]
set jtag_addr_space [get_bd_addr_spaces jtag_axi_0/Data]
set ddr_addr_segment \
    [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK]
set uart_addr_segment [get_bd_addr_segs axi_uart16550_0/S_AXI/Reg]

create_bd_addr_seg -range 0x10000000 -offset 0x00000000 \
    $cpu_addr_space $ddr_addr_segment SEG_cpu_ddr_low_256m
# Cover 0x10000000-0x1effffff exactly with aligned power-of-two windows.
# Leave 0x1f000000-0x1fffffff out of the DDR alias so the existing UART
# mapping at 0x1fe00000 remains unchanged.
create_bd_addr_seg -range 0x08000000 -offset 0x10000000 \
    $cpu_addr_space $ddr_addr_segment SEG_cpu_ddr_10000000_17ffffff
create_bd_addr_seg -range 0x04000000 -offset 0x18000000 \
    $cpu_addr_space $ddr_addr_segment SEG_cpu_ddr_18000000_1bffffff
create_bd_addr_seg -range 0x02000000 -offset 0x1c000000 \
    $cpu_addr_space $ddr_addr_segment SEG_cpu_ddr_1c000000_1dffffff
create_bd_addr_seg -range 0x01000000 -offset 0x1e000000 \
    $cpu_addr_space $ddr_addr_segment SEG_cpu_ddr_1e000000_1effffff
# Map only the lower 4 GiB of the physical DDR4. Keep the
# 0x1f000000-0x1fffffff peripheral hole, including the UART at 0x1fe00000,
# outside the DDR aperture and ignore all physical memory above 4 GiB.
create_bd_addr_seg -range 0x10000000 -offset 0x20000000 \
    $cpu_addr_space $ddr_addr_segment SEG_cpu_ddr_20000000_2fffffff
create_bd_addr_seg -range 0x10000000 -offset 0x30000000 \
    $cpu_addr_space $ddr_addr_segment SEG_cpu_ddr_30000000_3fffffff
create_bd_addr_seg -range 0x40000000 -offset 0x40000000 \
    $cpu_addr_space $ddr_addr_segment SEG_cpu_ddr_40000000_7fffffff
create_bd_addr_seg -range 0x80000000 -offset 0x80000000 \
    $cpu_addr_space $ddr_addr_segment SEG_cpu_ddr_80000000_ffffffff
create_bd_addr_seg -range 0x1000 -offset 0x1fe00000 \
    $cpu_addr_space $uart_addr_segment SEG_cpu_uart

create_bd_addr_seg -range 0x10000000 -offset 0x00000000 \
    $jtag_addr_space $ddr_addr_segment SEG_jtag_ddr_low_256m
# Give JTAG AXI the same low DDR aperture as the CPU so upload payloads can
# populate the BIOS at 0x1c000000.  Keep 0x1f000000-0x1fffffff outside the
# DDR alias because the JTAG UART window remains at 0x1fe00000.
create_bd_addr_seg -range 0x08000000 -offset 0x10000000 \
    $jtag_addr_space $ddr_addr_segment SEG_jtag_ddr_10000000_17ffffff
create_bd_addr_seg -range 0x04000000 -offset 0x18000000 \
    $jtag_addr_space $ddr_addr_segment SEG_jtag_ddr_18000000_1bffffff
create_bd_addr_seg -range 0x02000000 -offset 0x1c000000 \
    $jtag_addr_space $ddr_addr_segment SEG_jtag_ddr_1c000000_1dffffff
create_bd_addr_seg -range 0x01000000 -offset 0x1e000000 \
    $jtag_addr_space $ddr_addr_segment SEG_jtag_ddr_1e000000_1effffff
create_bd_addr_seg -range 0x10000000 -offset 0x20000000 \
    $jtag_addr_space $ddr_addr_segment SEG_jtag_ddr_20000000_2fffffff
create_bd_addr_seg -range 0x10000000 -offset 0x30000000 \
    $jtag_addr_space $ddr_addr_segment SEG_jtag_ddr_30000000_3fffffff
create_bd_addr_seg -range 0x40000000 -offset 0x40000000 \
    $jtag_addr_space $ddr_addr_segment SEG_jtag_ddr_40000000_7fffffff
create_bd_addr_seg -range 0x80000000 -offset 0x80000000 \
    $jtag_addr_space $ddr_addr_segment SEG_jtag_ddr_80000000_ffffffff
create_bd_addr_seg -range 0x1000 -offset 0x1fe00000 \
    $jtag_addr_space $uart_addr_segment SEG_jtag_uart

validate_bd_design

# Fail project generation if the safety-critical build parameters were not
# accepted by the IP.  These checks catch stale/unsupported property names
# before a long synthesis and implementation run starts.
set actual_cpu_frequency \
    [get_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $clk_wiz_0]
if {abs(double($actual_cpu_frequency) - $cpu_frequency_mhz) > 0.0005} {
    error "clk_wiz CPU frequency mismatch: requested $cpu_frequency_mhz MHz, got $actual_cpu_frequency MHz"
}
set actual_vio_reset_init \
    [string tolower [get_property CONFIG.C_PROBE_OUT0_INIT_VAL $xlnx_vio]]
if {$actual_vio_reset_init ni {0x1 1}} {
    error "VIO CPU reset must power up asserted, got $actual_vio_reset_init"
}
foreach {property expected} [list \
    CONFIG.ADDR_WIDTH $cpu_axi_addr_width \
    CONFIG.DATA_WIDTH $cpu_axi_data_width \
    CONFIG.ID_WIDTH $cpu_axi_id_width] {
    set actual [get_property $property $cpu_bd_axi]
    if {$actual != $expected} {
        error "cpu_bd_axi $property mismatch: expected $expected, got $actual"
    }
    set actual [get_property $property $cpu_axi_clock_converter]
    if {$actual != $expected} {
        error "cpu_axi_clock_converter $property mismatch: expected $expected, got $actual"
    }
}
set actual_xbar_data_width \
    [get_property CONFIG.XBAR_DATA_WIDTH $axi_interconnect_0]
if {$actual_xbar_data_width != $fabric_axi_data_width} {
    error "AXI interconnect data width mismatch: expected $fabric_axi_data_width, got $actual_xbar_data_width"
}
set actual_ddr_data_width \
    [get_property CONFIG.C0.DDR4_AxiDataWidth $ddr4_0]
if {$actual_ddr_data_width != $fabric_axi_data_width} {
    error "DDR4 AXI data width mismatch: expected $fabric_axi_data_width, got $actual_ddr_data_width"
}
save_bd_design

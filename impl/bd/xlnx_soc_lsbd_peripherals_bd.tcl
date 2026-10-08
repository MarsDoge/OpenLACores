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
if {![info exists impl_dir] || [string trim $impl_dir] eq ""} {
    error "impl_dir must be set before sourcing the peripheral BD script"
}
if {![info exists cpu_frequency_hz] ||
    ![string is integer -strict $cpu_frequency_hz] ||
    $cpu_frequency_hz < 1 ||
    $cpu_frequency_hz > 0xffffffff} {
    error "cpu_frequency_hz must be a positive 32-bit clock frequency"
}

set mig_project_file [file normalize \
    [file join $impl_dir ip xlnx_mig_axi config lsbd_axi64.prj]]
if {![file isfile $mig_project_file]} {
    error "LSBD MIG project file does not exist: $mig_project_file"
}

set cpu_axi_addr_width 32
set cpu_axi_data_width 32
set cpu_axi_id_width 4
set fabric_frequency_hz 100000000
set fabric_axi_data_width 64
set mig_axi_addr_width 32
set mig_axi_data_width 64
set jtag_axi_addr_width 32
set jtag_axi_data_width 32
set loader_ram_data_width 64
set loader_ram_depth_words 512
set loader_ram_size_bytes 4096
set cpu_frequency_mhz [expr {$cpu_frequency_hz / 1000000.0}]

create_bd_design $bd_name
current_bd_design $bd_name

# ---------------------------------------------------------------------------
# External board and CPU ports
# ---------------------------------------------------------------------------

set sys_clk [create_bd_port -dir I -type clk sys_clk]
set_property CONFIG.FREQ_HZ $fabric_frequency_hz $sys_clk
set sys_rst_n [create_bd_port -dir I -type rst sys_rst_n]
set_property CONFIG.POLARITY ACTIVE_LOW $sys_rst_n

set rs232_uart_rxd [create_bd_port -dir I rs232_uart_rxd]
set rs232_uart_txd [create_bd_port -dir O rs232_uart_txd]
set cpu_clk [create_bd_port -dir O -type clk cpu_clk]
set_property CONFIG.FREQ_HZ $cpu_frequency_hz $cpu_clk
set cpu_rst_b [create_bd_port -dir O -type rst cpu_rst_b]
set_property CONFIG.POLARITY ACTIVE_LOW $cpu_rst_b
set bd_cpu_ext_interrupt \
    [create_bd_port -dir O -from 7 -to 0 -type intr bd_cpu_ext_interrupt]

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

# ---------------------------------------------------------------------------
# LSBD DDR3 and peripheral IP
# ---------------------------------------------------------------------------

set mig_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:mig_7series:4.2 \
    mig_0]
set_property -dict [list \
    CONFIG.XML_INPUT_FILE $mig_project_file \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.MIG_DONT_TOUCH_PARAM {Custom} \
    CONFIG.BOARD_MIG_PARAM {Custom} \
] $mig_0

make_bd_intf_pins_external [get_bd_intf_pins mig_0/DDR3]
set ddr3 [get_bd_intf_ports DDR3_0]
set_property name ddr3 $ddr3

set clk_wiz_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:clk_wiz:6.0 \
    clk_wiz_0]
set_property -dict [list \
    CONFIG.PRIMITIVE {PLL} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $cpu_frequency_mhz \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {false} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {false} \
] $clk_wiz_0

# Clocking Wizard may quantize an arbitrary integer-Hz request to the nearest
# legal PLL ratio. Propagate the realized frequency to every CPU-domain
# interface so the Clock Converter sees one consistent timing contract.
set realized_cpu_frequency_hz \
    [get_property CONFIG.FREQ_HZ [get_bd_pins clk_wiz_0/clk_out1]]
if {![string is integer -strict $realized_cpu_frequency_hz] ||
    $realized_cpu_frequency_hz < 1} {
    error "clk_wiz produced an invalid CPU frequency: $realized_cpu_frequency_hz"
}
set_property CONFIG.FREQ_HZ $realized_cpu_frequency_hz $cpu_clk
set_property CONFIG.FREQ_HZ $realized_cpu_frequency_hz $cpu_bd_axi
set_property -dict [list \
    CONFIG.ASSOCIATED_BUSIF {cpu_bd_axi} \
    CONFIG.ASSOCIATED_RESET {cpu_rst_b} \
] $cpu_clk

set axi_interconnect_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:axi_interconnect:2.1 \
    axi_interconnect_0]
set_property -dict [list \
    CONFIG.NUM_MI {3} \
    CONFIG.NUM_SI {2} \
    CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
    CONFIG.XBAR_DATA_WIDTH $fabric_axi_data_width \
    CONFIG.S00_HAS_REGSLICE {3} \
    CONFIG.S01_HAS_REGSLICE {3} \
    CONFIG.M00_HAS_REGSLICE {3} \
    CONFIG.M01_HAS_REGSLICE {3} \
    CONFIG.M02_HAS_REGSLICE {3} \
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
    CONFIG.M_AXI_ADDR_WIDTH $jtag_axi_addr_width \
    CONFIG.M_AXI_DATA_WIDTH $jtag_axi_data_width \
    CONFIG.M_AXI_ID_WIDTH {4} \
    CONFIG.M_HAS_BURST {0} \
    CONFIG.RD_TXN_QUEUE_LENGTH {8} \
    CONFIG.WR_TXN_QUEUE_LENGTH {8} \
] $jtag_axi_0

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
    CONFIG.C_S_AXI_ACLK_FREQ_HZ $fabric_frequency_hz \
    CONFIG.C_USE_MODEM_PORTS {0} \
    CONFIG.C_USE_USER_PORTS {0} \
    CONFIG.USE_BOARD_FLOW {false} \
    CONFIG.UART_BOARD_INTERFACE {Custom} \
] $axi_uart16550_0

set loader_bram_ctrl_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 \
    loader_bram_ctrl_0]
set_property -dict [list \
    CONFIG.DATA_WIDTH $loader_ram_data_width \
    CONFIG.SINGLE_PORT_BRAM {1} \
] $loader_bram_ctrl_0

set loader_bram_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:blk_mem_gen:8.4 \
    loader_bram_0]
set_property -dict [list \
    CONFIG.Memory_Type {Single_Port_RAM} \
    CONFIG.Write_Width_A $loader_ram_data_width \
    CONFIG.Read_Width_A $loader_ram_data_width \
    CONFIG.Write_Depth_A $loader_ram_depth_words \
    CONFIG.use_bram_block {BRAM_Controller} \
    CONFIG.EN_SAFETY_CKT {false} \
] $loader_bram_0

set fabric_reset_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:proc_sys_reset:5.0 \
    fabric_reset_0]
set_property CONFIG.C_AUX_RESET_HIGH {0} $fabric_reset_0

set cpu_reset_0 [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:proc_sys_reset:5.0 \
    cpu_reset_0]
set_property CONFIG.C_AUX_RESET_HIGH {0} $cpu_reset_0

set board_reset_not [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:util_vector_logic:2.0 \
    board_reset_not]
set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
] $board_reset_not

set clock_locked_and [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:util_vector_logic:2.0 \
    clock_locked_and]
set_property -dict [list \
    CONFIG.C_OPERATION {and} \
    CONFIG.C_SIZE {1} \
] $clock_locked_and

set cpu_reset_request_or [create_bd_cell \
    -type ip \
    -vlnv xilinx.com:ip:util_vector_logic:2.0 \
    cpu_reset_request_or]
set_property -dict [list \
    CONFIG.C_OPERATION {or} \
    CONFIG.C_SIZE {1} \
] $cpu_reset_request_or

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

# ---------------------------------------------------------------------------
# Clock and reset ownership
# ---------------------------------------------------------------------------

# The MIG 100 MHz UI clock owns the complete Block Design fabric. Only the
# CPU-facing side of the explicit AXI Clock Converter uses the selected CPU
# frequency.
connect_bd_net [get_bd_ports sys_clk] \
    [get_bd_pins clk_wiz_0/clk_in1]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out2] \
    [get_bd_pins mig_0/clk_ref_i]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out3] \
    [get_bd_pins mig_0/sys_clk_i]
connect_bd_net [get_bd_pins mig_0/ui_clk] \
    [get_bd_pins fabric_reset_0/slowest_sync_clk] \
    [get_bd_pins axi_interconnect_0/ACLK] \
    [get_bd_pins axi_interconnect_0/S00_ACLK] \
    [get_bd_pins axi_interconnect_0/S01_ACLK] \
    [get_bd_pins axi_interconnect_0/M00_ACLK] \
    [get_bd_pins axi_interconnect_0/M01_ACLK] \
    [get_bd_pins axi_interconnect_0/M02_ACLK] \
    [get_bd_pins cpu_axi_clock_converter/m_axi_aclk] \
    [get_bd_pins jtag_axi_0/aclk] \
    [get_bd_pins xlnx_vio/clk] \
    [get_bd_pins axi_uart16550_0/s_axi_aclk] \
    [get_bd_pins loader_bram_ctrl_0/s_axi_aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] \
    [get_bd_ports cpu_clk] \
    [get_bd_pins cpu_reset_0/slowest_sync_clk] \
    [get_bd_pins cpu_axi_clock_converter/s_axi_aclk]

connect_bd_net [get_bd_ports sys_rst_n] \
    [get_bd_pins mig_0/sys_rst] \
    [get_bd_pins board_reset_not/Op1]
connect_bd_net [get_bd_pins board_reset_not/Res] \
    [get_bd_pins fabric_reset_0/ext_reset_in] \
    [get_bd_pins cpu_reset_request_or/Op1]
set vio_cpu_reset [create_bd_net vio_cpu_reset]
connect_bd_net -net $vio_cpu_reset \
    [get_bd_pins xlnx_vio/probe_out0] \
    [get_bd_pins cpu_reset_request_or/Op2]
connect_bd_net [get_bd_pins cpu_reset_request_or/Res] \
    [get_bd_pins cpu_reset_0/ext_reset_in]

connect_bd_net [get_bd_pins mig_0/ui_clk_sync_rst] \
    [get_bd_pins fabric_reset_0/mb_debug_sys_rst] \
    [get_bd_pins cpu_reset_0/mb_debug_sys_rst]
connect_bd_net [get_bd_pins mig_0/mmcm_locked] \
    [get_bd_pins clock_locked_and/Op1]
connect_bd_net [get_bd_pins clk_wiz_0/locked] \
    [get_bd_pins clock_locked_and/Op2]
connect_bd_net [get_bd_pins clock_locked_and/Res] \
    [get_bd_pins fabric_reset_0/dcm_locked] \
    [get_bd_pins cpu_reset_0/dcm_locked]
connect_bd_net [get_bd_pins mig_0/init_calib_complete] \
    [get_bd_pins fabric_reset_0/aux_reset_in] \
    [get_bd_pins cpu_reset_0/aux_reset_in]

connect_bd_net [get_bd_pins fabric_reset_0/peripheral_aresetn] \
    [get_bd_pins mig_0/aresetn] \
    [get_bd_pins axi_interconnect_0/ARESETN] \
    [get_bd_pins axi_interconnect_0/S00_ARESETN] \
    [get_bd_pins axi_interconnect_0/S01_ARESETN] \
    [get_bd_pins axi_interconnect_0/M00_ARESETN] \
    [get_bd_pins axi_interconnect_0/M01_ARESETN] \
    [get_bd_pins axi_interconnect_0/M02_ARESETN] \
    [get_bd_pins cpu_axi_clock_converter/m_axi_aresetn] \
    [get_bd_pins jtag_axi_0/aresetn] \
    [get_bd_pins axi_uart16550_0/s_axi_aresetn] \
    [get_bd_pins loader_bram_ctrl_0/s_axi_aresetn]
connect_bd_net [get_bd_pins cpu_reset_0/peripheral_aresetn] \
    [get_bd_ports cpu_rst_b] \
    [get_bd_pins cpu_axi_clock_converter/s_axi_aresetn]

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
    [get_bd_intf_pins mig_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M01_AXI] \
    [get_bd_intf_pins axi_uart16550_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M02_AXI] \
    [get_bd_intf_pins loader_bram_ctrl_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins loader_bram_ctrl_0/BRAM_PORTA] \
    [get_bd_intf_pins loader_bram_0/BRAM_PORTA]

connect_bd_net [get_bd_ports rs232_uart_rxd] \
    [get_bd_pins axi_uart16550_0/sin]
connect_bd_net [get_bd_pins axi_uart16550_0/sout] \
    [get_bd_ports rs232_uart_txd]

connect_bd_net [get_bd_pins axi_uart16550_0/ip2intc_irpt] \
    [get_bd_pins interrupt_concat/In0]
connect_bd_net [get_bd_pins interrupt_zero/dout] \
    [get_bd_pins interrupt_concat/In1]
connect_bd_net [get_bd_pins interrupt_concat/dout] \
    [get_bd_ports bd_cpu_ext_interrupt]

# ---------------------------------------------------------------------------
# Address map
# ---------------------------------------------------------------------------

set cpu_addr_space [get_bd_addr_spaces cpu_bd_axi]
set jtag_addr_space [get_bd_addr_spaces jtag_axi_0/Data]
set ddr_addr_segment [get_bd_addr_segs mig_0/memmap/memaddr]
set uart_addr_segment [get_bd_addr_segs axi_uart16550_0/S_AXI/Reg]
set loader_ram_addr_segment \
    [get_bd_addr_segs loader_bram_ctrl_0/S_AXI/Mem0]

# CPU and JTAG share one architectural address view: 128 MiB DDR begins at
# zero, the private 4 KiB loader RAM owns the reset window, and the UART keeps
# its architectural address. No modulo-DDR aliasing is permitted.
proc lsbd_map_addr_space {
    address_space owner_name ddr_addr_segment loader_ram_addr_segment \
        uart_addr_segment
} {
    set ddr_mapping [create_bd_addr_seg \
        -range 0x08000000 -offset 0x00000000 \
        $address_space $ddr_addr_segment \
        [format "SEG_%s_ddr_128m" $owner_name]]
    set loader_ram_mapping [create_bd_addr_seg \
        -range 0x00001000 -offset 0x1c000000 \
        $address_space $loader_ram_addr_segment \
        [format "SEG_%s_loader_ram_4k" $owner_name]]
    set uart_mapping [create_bd_addr_seg \
        -range 0x00001000 -offset 0x1fe00000 \
        $address_space $uart_addr_segment \
        [format "SEG_%s_uart" $owner_name]]
    return [list $ddr_mapping $loader_ram_mapping $uart_mapping]
}

set cpu_addr_segments [lsbd_map_addr_space \
    $cpu_addr_space cpu $ddr_addr_segment $loader_ram_addr_segment \
    $uart_addr_segment]
set jtag_addr_segments [lsbd_map_addr_space \
    $jtag_addr_space jtag $ddr_addr_segment $loader_ram_addr_segment \
    $uart_addr_segment]

validate_bd_design

# Verify that CPU and JTAG received the same architectural address layout.
foreach address_segments [list $cpu_addr_segments $jtag_addr_segments] {
    foreach address_segment $address_segments expected_offset \
            [list 0x00000000 0x1c000000 0x1fe00000] expected_range \
            [list 0x08000000 0x00001000 0x00001000] {
        set actual_offset [get_property OFFSET $address_segment]
        set actual_range [get_property RANGE $address_segment]
        if {$actual_offset != $expected_offset || $actual_range != $expected_range} {
            error "LSBD address segment mismatch: expected offset [format 0x%08x $expected_offset] range [format 0x%08x $expected_range], got offset $actual_offset range $actual_range"
        }
    }
}

# Fail immediately if a checked board boundary was not accepted by the IP.
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
set actual_loader_ram_data_width \
    [get_property CONFIG.DATA_WIDTH $loader_bram_ctrl_0]
if {$actual_loader_ram_data_width != $loader_ram_data_width} {
    error "loader AXI RAM data width mismatch: expected $loader_ram_data_width, got $actual_loader_ram_data_width"
}
set actual_loader_ram_depth \
    [get_property CONFIG.Write_Depth_A $loader_bram_0]
if {$actual_loader_ram_depth != $loader_ram_depth_words} {
    error "loader AXI RAM depth mismatch: expected $loader_ram_depth_words, got $actual_loader_ram_depth"
}
set actual_loader_ram_size_bytes \
    [expr {$actual_loader_ram_depth * ($actual_loader_ram_data_width / 8)}]
if {$actual_loader_ram_size_bytes != $loader_ram_size_bytes} {
    error "loader AXI RAM size mismatch: expected $loader_ram_size_bytes bytes, got $actual_loader_ram_size_bytes bytes"
}
foreach {property expected} [list \
    CONFIG.ADDR_WIDTH $mig_axi_addr_width \
    CONFIG.DATA_WIDTH $mig_axi_data_width] {
    set actual [get_property $property [get_bd_intf_pins mig_0/S_AXI]]
    if {$actual != $expected} {
        error "MIG AXI $property mismatch: expected $expected, got $actual"
    }
}
foreach {property expected} [list \
    CONFIG.M_AXI_ADDR_WIDTH $jtag_axi_addr_width \
    CONFIG.M_AXI_DATA_WIDTH $jtag_axi_data_width] {
    set actual [get_property $property $jtag_axi_0]
    if {$actual != $expected} {
        error "JTAG AXI $property mismatch: expected $expected, got $actual"
    }
}
set actual_vio_reset_init \
    [string tolower [get_property CONFIG.C_PROBE_OUT0_INIT_VAL $xlnx_vio]]
if {$actual_vio_reset_init ni {0x1 1}} {
    error "VIO CPU reset must power up asserted, got $actual_vio_reset_init"
}
puts [format \
    "INFO: LSBD CPU clock requested at %.6f MHz and realized at %.6f MHz" \
    [expr {double($cpu_frequency_hz) / 1000000.0}] \
    [expr {double($realized_cpu_frequency_hz) / 1000000.0}]]
puts [format \
    "INFO: LSBD address map: DDR=0x00000000/128MiB loader-RAM=0x1c000000/%dB UART=0x1fe00000/4KiB" \
    $actual_loader_ram_size_bytes]
save_bd_design

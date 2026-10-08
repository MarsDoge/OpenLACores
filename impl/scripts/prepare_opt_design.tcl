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

set hook_dir [file dirname [file normalize [info script]]]
source [file join $hook_dir set_vivado_threads.tcl]

if {[info exists ::env(FPGA_BOARD)] && $::env(FPGA_BOARD) eq "lsbd"} {
    if {![info exists ::env(FPGA_CPU_FREQ_HZ)] ||
        ![string is integer -strict $::env(FPGA_CPU_FREQ_HZ)] ||
        $::env(FPGA_CPU_FREQ_HZ) < 1 ||
        $::env(FPGA_CPU_FREQ_HZ) > 0xffffffff} {
        error "FPGA_CPU_FREQ_HZ must be a positive 32-bit clock frequency for LSBD debug insertion"
    }
    set requested_cpu_frequency_hz $::env(FPGA_CPU_FREQ_HZ)

    set debug_hubs [get_debug_cores -quiet dbg_hub]
    if {[llength $debug_hubs] != 1} {
        error "expected one LSBD debug hub, got [llength $debug_hubs]: $debug_hubs"
    }
    set cpu_clock_nets [get_nets -quiet -hierarchical \
        -filter {NAME == cpu_clk}]
    if {[llength $cpu_clock_nets] != 1} {
        error "expected one LSBD CPU clock net, got [llength $cpu_clock_nets]: $cpu_clock_nets"
    }
    set debug_hub [lindex $debug_hubs 0]
    set cpu_clock_net [lindex $cpu_clock_nets 0]
    set cpu_clocks [get_clocks -quiet -of_objects $cpu_clock_net]
    if {[llength $cpu_clocks] != 1} {
        error "expected one generated LSBD CPU clock, got [llength $cpu_clocks]: $cpu_clocks"
    }
    set cpu_clock_period_ns [get_property PERIOD [lindex $cpu_clocks 0]]
    if {![string is double -strict $cpu_clock_period_ns] ||
        $cpu_clock_period_ns <= 0.0} {
        error "invalid LSBD CPU clock period: $cpu_clock_period_ns ns"
    }
    set realized_cpu_frequency_hz \
        [expr {wide(round(1.0e9 / double($cpu_clock_period_ns)))}]
    set cpu_frequency_tolerance_hz \
        [expr {max(1.0, double($requested_cpu_frequency_hz) * 0.005)}]
    if {abs(double($realized_cpu_frequency_hz) -
            double($requested_cpu_frequency_hz)) >
        $cpu_frequency_tolerance_hz} {
        error [format \
            {LSBD CPU clock is stale or cannot match the request (implemented %.6f MHz, requested %.6f MHz). Run make -C impl BOARD=lsbd CPU_FREQ_HZ=%d reproject before rebuilding.} \
            [expr {double($realized_cpu_frequency_hz) / 1.0e6}] \
            [expr {double($requested_cpu_frequency_hz) / 1.0e6}] \
            $requested_cpu_frequency_hz]
    }
    connect_debug_port $debug_hub/clk $cpu_clock_net
    set_property C_CLK_INPUT_FREQ_HZ $realized_cpu_frequency_hz $debug_hub
    puts [format \
        "INFO: LSBD debug hub clocked from the independent %.6f MHz CPU output" \
        [expr {double($realized_cpu_frequency_hz) / 1.0e6}]]

    proc fpga_lsbd_require_net {label suffix} {
        set nets [get_nets -quiet -hierarchical -filter "NAME =~ *$suffix"]
        if {[llength $nets] != 1} {
            error "expected one LSBD $label net, got [llength $nets]: $nets"
        }
        return [lindex $nets 0]
    }

    set status_ila [create_debug_core u_ila_lsbd_status ila]
    set_property C_DATA_DEPTH 2048 $status_ila
    set_property C_INPUT_PIPE_STAGES 1 $status_ila
    set_property C_ADV_TRIGGER false $status_ila
    set_property C_EN_STRG_QUAL false $status_ila
    set_property C_TRIGIN_EN false $status_ila
    set_property C_TRIGOUT_EN false $status_ila
    connect_debug_port $status_ila/clk $cpu_clock_net

    set status_probe_specs [list \
        clk_wiz_locked /xlnx_lsbd_peripherals_bd_i/clk_wiz_0_locked \
        mig_mmcm_locked /xlnx_lsbd_peripherals_bd_i/mig_0_mmcm_locked \
        init_calib_complete /xlnx_lsbd_peripherals_bd_i/mig_0_init_calib_complete \
        ui_clk_sync_rst /xlnx_lsbd_peripherals_bd_i/mig_0_ui_clk_sync_rst \
        fabric_aresetn /xlnx_lsbd_peripherals_bd_i/fabric_reset_0_peripheral_aresetn \
        vio_cpu_reset /xlnx_lsbd_peripherals_bd_i/vio_cpu_reset \
        jtag_awvalid /xlnx_lsbd_peripherals_bd_i/jtag_axi_0_M_AXI_AWVALID \
        jtag_awready /xlnx_lsbd_peripherals_bd_i/jtag_axi_0_M_AXI_AWREADY \
        jtag_wvalid /xlnx_lsbd_peripherals_bd_i/jtag_axi_0_M_AXI_WVALID \
        jtag_wready /xlnx_lsbd_peripherals_bd_i/jtag_axi_0_M_AXI_WREADY \
        jtag_bvalid /xlnx_lsbd_peripherals_bd_i/jtag_axi_0_M_AXI_BVALID \
        jtag_bready /xlnx_lsbd_peripherals_bd_i/jtag_axi_0_M_AXI_BREADY \
        jtag_arvalid /xlnx_lsbd_peripherals_bd_i/jtag_axi_0_M_AXI_ARVALID \
        jtag_arready /xlnx_lsbd_peripherals_bd_i/jtag_axi_0_M_AXI_ARREADY \
        jtag_rvalid /xlnx_lsbd_peripherals_bd_i/jtag_axi_0_M_AXI_RVALID \
        jtag_rready /xlnx_lsbd_peripherals_bd_i/jtag_axi_0_M_AXI_RREADY \
        mig_awvalid /xlnx_lsbd_peripherals_bd_i/axi_interconnect_0_M00_AXI_AWVALID \
        mig_awready /xlnx_lsbd_peripherals_bd_i/axi_interconnect_0_M00_AXI_AWREADY \
        mig_wvalid /xlnx_lsbd_peripherals_bd_i/axi_interconnect_0_M00_AXI_WVALID \
        mig_wready /xlnx_lsbd_peripherals_bd_i/axi_interconnect_0_M00_AXI_WREADY \
        mig_bvalid /xlnx_lsbd_peripherals_bd_i/axi_interconnect_0_M00_AXI_BVALID \
        mig_bready /xlnx_lsbd_peripherals_bd_i/axi_interconnect_0_M00_AXI_BREADY \
        mig_arvalid /xlnx_lsbd_peripherals_bd_i/axi_interconnect_0_M00_AXI_ARVALID \
        mig_arready /xlnx_lsbd_peripherals_bd_i/axi_interconnect_0_M00_AXI_ARREADY \
        mig_rvalid /xlnx_lsbd_peripherals_bd_i/axi_interconnect_0_M00_AXI_RVALID \
        mig_rready /xlnx_lsbd_peripherals_bd_i/axi_interconnect_0_M00_AXI_RREADY]

    set probe_index 0
    foreach {probe_label net_suffix} $status_probe_specs {
        set probe_net [fpga_lsbd_require_net $probe_label $net_suffix]
        set_property MARK_DEBUG true $probe_net
        if {$probe_index == 0} {
            set probe_port [get_debug_ports $status_ila/probe0]
        } else {
            set probe_port [create_debug_port $status_ila probe]
        }
        set_property PORT_WIDTH 1 $probe_port
        set_property PROBE_TYPE DATA_AND_TRIGGER $probe_port
        connect_debug_port $probe_port $probe_net
        incr probe_index
    }
    puts "INFO: LSBD status ILA inserted with $probe_index clock, reset, and AXI probes"
}

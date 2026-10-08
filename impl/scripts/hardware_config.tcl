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

proc fpga_hw_env_or_default {environment_name default_value} {
    if {[info exists ::env($environment_name)] &&
        [string trim $::env($environment_name)] ne ""} {
        return $::env($environment_name)
    }
    return $default_value
}

proc fpga_hw_positive_integer {name value} {
    if {![string is integer -strict $value] || $value < 1} {
        error "$name must be a positive integer"
    }
    return $value
}

proc fpga_hardware_config {} {
    set board_name [string tolower [fpga_hw_env_or_default FPGA_BOARD vu13p]]
    switch -- $board_name {
        vu13p {
            set default_device_pattern xcvu13p_0
            set default_jtag_addr_width 64
            set default_jtag_data_width 64
            set default_project_name openla132s_xlnx_bd
            set default_top_module xlnx_soc_vu13p_bd
        }
        lsbd {
            set default_device_pattern xc7a200t_0
            set default_jtag_addr_width 32
            set default_jtag_data_width 32
            set default_project_name openla132s_lsbd_bd
            set default_top_module xlnx_soc_lsbd_bd
        }
        default {
            error "Unsupported FPGA_BOARD '$board_name'; expected vu13p or lsbd"
        }
    }
    set target_pattern [fpga_hw_env_or_default \
        FPGA_HW_TARGET_PATTERN */xilinx_tcf/Digilent/*]
    set target_index [fpga_hw_env_or_default FPGA_HW_TARGET_INDEX 0]
    if {![string is integer -strict $target_index] || $target_index < 0} {
        error "FPGA_HW_TARGET_INDEX must be a non-negative integer"
    }
    set target_frequency_hz [fpga_hw_positive_integer \
        FPGA_HW_FREQUENCY_HZ \
        [fpga_hw_env_or_default FPGA_HW_FREQUENCY_HZ 15000000]]
    set device_pattern [fpga_hw_env_or_default \
        FPGA_HW_DEVICE_PATTERN $default_device_pattern]
    set axi_name [fpga_hw_env_or_default FPGA_HW_AXI_NAME hw_axi_1]
    set jtag_addr_width [fpga_hw_positive_integer \
        FPGA_JTAG_AXI_ADDR_WIDTH \
        [fpga_hw_env_or_default \
            FPGA_JTAG_AXI_ADDR_WIDTH $default_jtag_addr_width]]
    set jtag_data_width [fpga_hw_positive_integer \
        FPGA_JTAG_AXI_DATA_WIDTH \
        [fpga_hw_env_or_default \
            FPGA_JTAG_AXI_DATA_WIDTH $default_jtag_data_width]]
    if {$jtag_data_width ni {32 64}} {
        error "FPGA_JTAG_AXI_DATA_WIDTH must be 32 or 64"
    }
    if {$jtag_addr_width ni {32 64}} {
        error "FPGA_JTAG_AXI_ADDR_WIDTH must be 32 or 64"
    }
    set upload_transaction_bytes [fpga_hw_positive_integer \
        FPGA_UPLOAD_TRANSACTION_BYTES \
        [fpga_hw_env_or_default FPGA_UPLOAD_TRANSACTION_BYTES 1024]]
    set jtag_word_bytes [expr {$jtag_data_width / 8}]
    if {$upload_transaction_bytes % $jtag_word_bytes != 0} {
        error "FPGA_UPLOAD_TRANSACTION_BYTES must be divisible by the JTAG AXI word size"
    }
    set upload_transaction_words \
        [expr {$upload_transaction_bytes / $jtag_word_bytes}]
    if {$upload_transaction_words > 256} {
        error "JTAG AXI upload transactions cannot exceed 256 words"
    }
    set sanity_address [fpga_hw_env_or_default \
        FPGA_JTAG_AXI_SANITY_ADDRESS 0x1efff000]

    return [dict create \
        board_name $board_name \
        default_project_name $default_project_name \
        default_top_module $default_top_module \
        target_pattern $target_pattern \
        target_index $target_index \
        target_frequency_hz $target_frequency_hz \
        device_pattern $device_pattern \
        axi_name $axi_name \
        jtag_addr_width $jtag_addr_width \
        jtag_data_width $jtag_data_width \
        jtag_word_bytes $jtag_word_bytes \
        jtag_word_hex_digits [expr {$jtag_data_width / 4}] \
        upload_transaction_bytes $upload_transaction_bytes \
        upload_transaction_words $upload_transaction_words \
        sanity_address $sanity_address]
}

proc fpga_connect_hw_device {hardware_config} {
    dict with hardware_config {}

    open_hw_manager
    catch {disconnect_hw_server localhost:3121}
    connect_hw_server -url localhost:3121
    set hw_targets [get_hw_targets -quiet $target_pattern]
    if {[llength $hw_targets] == 0} {
        error "no hardware target matched '$target_pattern'"
    }

    set matching_device_index 0
    foreach hw_target $hw_targets {
        current_hw_target $hw_target
        set_property PARAM.FREQUENCY $target_frequency_hz $hw_target
        open_hw_target
        set hw_devices [get_hw_devices -quiet $device_pattern]
        foreach hw_device $hw_devices {
            if {$matching_device_index == $target_index} {
                current_hw_device $hw_device
                puts "INFO: Selected $board_name device $hw_device on $hw_target"
                return $hw_device
            }
            incr matching_device_index
        }
        catch {close_hw_target}
    }
    error "no matching device index $target_index for '$device_pattern'"
}

proc fpga_get_hw_axi {axi_name} {
    set hw_axis [get_hw_axis -quiet $axi_name]
    if {[llength $hw_axis] != 1} {
        error "expected one JTAG AXI endpoint named $axi_name, got [llength $hw_axis]"
    }
    return [lindex $hw_axis 0]
}

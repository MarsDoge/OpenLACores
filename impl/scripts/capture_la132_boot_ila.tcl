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

if {$argc < 1 || $argc > 3} {
    error "usage: capture_la132_boot_ila.tcl <work-path> ?output-prefix? ?timeout-minutes?"
}

set script_dir [file dirname [file normalize [info script]]]
set impl_dir [file dirname $script_dir]
source [file join $script_dir project_config.tcl]
set project_config [fpga_project_config $impl_dir]
dict with project_config {}

set requested_work_path [file normalize [lindex $argv 0]]
if {$requested_work_path ne $work_root} {
    error "work path $requested_work_path does not match configured work root $work_root"
}
set output_prefix [file join $work_root la132_boot]
if {$argc >= 2 && [lindex $argv 1] ne ""} {
    set output_prefix [file normalize [lindex $argv 1]]
}
set timeout_minutes 1
if {$argc >= 3} {
    set timeout_minutes [lindex $argv 2]
}
if {![string is double -strict $timeout_minutes] || $timeout_minutes <= 0} {
    error "timeout-minutes must be positive"
}

proc la132_capture_env_hex {environment_name default_value} {
    set value $default_value
    if {[info exists ::env($environment_name)] && \
        $::env($environment_name) ne ""} {
        set value [string tolower [string trim $::env($environment_name)]]
    }
    if {[string first 0x $value] == 0} {
        set value [string range $value 2 end]
    }
    if {![regexp {^[0-9a-f]{1,8}$} $value]} {
        error "$environment_name must be a 32-bit hexadecimal address"
    }
    return "[string repeat 0 [expr {8 - [string length $value]}]]$value"
}

proc la132_capture_env_uint {environment_name default_value} {
    set value $default_value
    if {[info exists ::env($environment_name)] && \
        $::env($environment_name) ne ""} {
        set value $::env($environment_name)
    }
    if {![string is integer -strict $value] || $value < 0} {
        error "$environment_name must be a non-negative integer"
    }
    return $value
}

proc la132_capture_env_bit {environment_name default_value} {
    set value $default_value
    if {[info exists ::env($environment_name)] && \
        $::env($environment_name) ne ""} {
        set value $::env($environment_name)
    }
    if {$value ni {0 1}} {
        error "$environment_name must be 0 or 1"
    }
    return $value
}

proc la132_capture_probes_for_port {hw_ila port_index expected_width} {
    set matches [list]
    foreach probe [get_hw_probes -quiet -of_objects $hw_ila] {
        set matched 0
        set properties [list_property $probe]
        foreach property_name {PROBE_PORT PORT_INDEX} {
            if {[lsearch -exact $properties $property_name] >= 0} {
                set value [get_property $property_name $probe]
                if {$value eq $port_index || $value eq "probe$port_index"} {
                    set matched 1
                }
            }
        }
        if {!$matched && [string match "*probe${port_index}*" \
                [get_property NAME $probe]]} {
            set matched 1
        }
        if {$matched} {
            lappend matches $probe
        }
    }
    if {[llength $matches] == 1} {
        set probe [lindex $matches 0]
        if {[get_property WIDTH $probe] != $expected_width} {
            error "probe$port_index width is [get_property WIDTH $probe], expected $expected_width"
        }
        return $matches
    }
    if {[llength $matches] != $expected_width} {
        error "probe$port_index has [llength $matches] logical bits, expected $expected_width"
    }
    set probes_by_bit [dict create]
    foreach probe $matches {
        set bit_index [get_property PROBE_PORT_BITS $probe]
        if {![string is integer -strict $bit_index] || $bit_index < 0 || \
            $bit_index >= $expected_width} {
            error "invalid probe$port_index bit index $bit_index"
        }
        dict set probes_by_bit $bit_index $probe
    }
    set ordered_probes [list]
    for {set bit_index 0} {$bit_index < $expected_width} {incr bit_index} {
        if {![dict exists $probes_by_bit $bit_index]} {
            error "probe$port_index is missing bit $bit_index"
        }
        lappend ordered_probes [dict get $probes_by_bit $bit_index]
    }
    return $ordered_probes
}

proc la132_capture_set_pattern {probes digits} {
    if {[llength $probes] == 1} {
        set_property TRIGGER_COMPARE_VALUE "eq32'h$digits" [lindex $probes 0]
        return
    }
    if {[llength $probes] != 32} {
        error "cannot apply a 32-bit trigger to [llength $probes] probes"
    }
    for {set bit_index 0} {$bit_index < 32} {incr bit_index} {
        set digit_index [expr {7 - ($bit_index / 4)}]
        scan [string index $digits $digit_index] %x nibble_value
        set bit_value [expr {($nibble_value >> ($bit_index % 4)) & 1}]
        set_property TRIGGER_COMPARE_VALUE "eq1'b$bit_value" \
            [lindex $probes $bit_index]
    }
}

proc la132_capture_arm {hw_ila address_digits trigger_valid trigger_divisor trigger_position window_count} {
    current_hw_ila $hw_ila
    reset_hw_ila $hw_ila
    set capture_depth [get_property STATIC.MAX_DATA_DEPTH $hw_ila]
    if {$capture_depth % $window_count != 0} {
        error "ILA depth $capture_depth is not divisible by $window_count windows"
    }
    set window_depth [expr {$capture_depth / $window_count}]
    set_property CONTROL.DATA_DEPTH $window_depth $hw_ila
    set_property CONTROL.WINDOW_COUNT $window_count $hw_ila
    if {$trigger_position eq ""} {
        set selected_trigger_position [expr {$window_depth / $trigger_divisor}]
    } else {
        set selected_trigger_position \
            [expr {min($trigger_position, $window_depth - 1)}]
    }
    set_property CONTROL.TRIGGER_POSITION $selected_trigger_position $hw_ila
    set_property CONTROL.TRIGGER_CONDITION AND $hw_ila
    set pc_probes [la132_capture_probes_for_port $hw_ila 0 32]
    set valid_probes [la132_capture_probes_for_port $hw_ila 1 1]
    la132_capture_set_pattern $pc_probes $address_digits
    set_property TRIGGER_COMPARE_VALUE "eq1'b$trigger_valid" \
        [lindex $valid_probes 0]
    run_hw_ila $hw_ila
}

proc la132_capture_set_cpu_reset {reset_probe value} {
    set_property OUTPUT_VALUE $value $reset_probe
    commit_hw_vio $reset_probe
}

set cpu_trigger [la132_capture_env_hex ILA_CPU_TRIGGER_ADDRESS 1c000058]
set pipe_trigger [la132_capture_env_hex ILA_PIPE_TRIGGER_ADDRESS $cpu_trigger]
set mmu_trigger [la132_capture_env_hex ILA_MMU_TRIGGER_ADDRESS a0c5b084]
set axi_trigger [la132_capture_env_hex ILA_AXI_TRIGGER_ADDRESS a0c5b090]
set dcache_trigger [la132_capture_env_hex ILA_DCACHE_TRIGGER_ADDRESS a0c210a4]
set force_trigger_delay_ms \
    [la132_capture_env_uint ILA_FORCE_TRIGGER_DELAY_MS 5000]
set trigger_valid [la132_capture_env_bit ILA_TRIGGER_VALID 1]
set window_count [la132_capture_env_uint ILA_WINDOW_COUNT 1]
set keep_cpu_running [la132_capture_env_bit ILA_KEEP_CPU_RUNNING 0]
if {$window_count < 1 || ($window_count & ($window_count - 1)) != 0} {
    error "ILA_WINDOW_COUNT must be a positive power of two"
}
set trigger_position ""
if {[info exists ::env(ILA_TRIGGER_POSITION)] && \
    $::env(ILA_TRIGGER_POSITION) ne ""} {
    set trigger_position \
        [la132_capture_env_uint ILA_TRIGGER_POSITION 0]
}

set run_path [file join $project_dir ${project_name}.runs impl_1]
set ltx_path [file join $run_path ${top_module}.ltx]
if {![file isfile $ltx_path]} {
    error "required debug probes file does not exist: $ltx_path"
}
file mkdir [file dirname $output_prefix]

set_param xicom.use_bitstream_version_check false
set_param messaging.defaultLimit 100000
open_hw_manager
catch {disconnect_hw_server localhost:3121}
connect_hw_server -url localhost:3121

set hw_targets [get_hw_targets -quiet */xilinx_tcf/Digilent/*]
if {[llength $hw_targets] == 0} {
    error "no Digilent hardware target was found"
}
set hw_target [lindex $hw_targets 0]
current_hw_target $hw_target
set_property PARAM.FREQUENCY 15000000 $hw_target
open_hw_target

set hw_devices [get_hw_devices -quiet xcvu13p_0]
if {[llength $hw_devices] != 1} {
    error "expected one xcvu13p_0 device, got [llength $hw_devices]"
}
set hw_device [lindex $hw_devices 0]
current_hw_device $hw_device
set_property PROBES.FILE $ltx_path $hw_device
set_property FULL_PROBES.FILE $ltx_path $hw_device
refresh_hw_device $hw_device

set hw_vios [get_hw_vios -quiet -of_objects $hw_device \
    -filter {CELL_NAME =~ "*xlnx_vio"}]
if {[llength $hw_vios] == 0} {
    error "the programmed design does not expose xlnx_vio"
}
set reset_probe [get_hw_probes -quiet {*vio_cpu_reset*} \
    -of_objects [lindex $hw_vios 0]]
if {[llength $reset_probe] != 1} {
    error "expected one vio_cpu_reset probe, got [llength $reset_probe]"
}

set ila_cores [dict create]
foreach {label cell_name} {
    cpu u_ila_la132_cpu
    pipe u_ila_la132_pipe
    mmu u_ila_la132_mmu
    axi u_ila_la132_axi
    dcache u_ila_la132_dcache
} {
    set matches [get_hw_ilas -quiet -of_objects $hw_device \
        -filter [format {CELL_NAME =~ "*%s"} $cell_name]]
    if {[llength $matches] != 1} {
        error "expected one $cell_name hardware core, got [llength $matches]"
    }
    dict set ila_cores $label [lindex $matches 0]
}

if {!$keep_cpu_running} {
    la132_capture_set_cpu_reset $reset_probe 1
    after 100
    puts "INFO: CPU held in VIO reset while arming all LA132 boot ILAs"
} else {
    puts "INFO: CPU left running while arming all LA132 boot ILAs"
}

la132_capture_arm [dict get $ila_cores cpu] $cpu_trigger $trigger_valid 16 $trigger_position $window_count
la132_capture_arm [dict get $ila_cores pipe] $pipe_trigger $trigger_valid 8 $trigger_position $window_count
la132_capture_arm [dict get $ila_cores mmu] $mmu_trigger $trigger_valid 8 $trigger_position $window_count
la132_capture_arm [dict get $ila_cores axi] $axi_trigger $trigger_valid 8 $trigger_position $window_count
la132_capture_arm [dict get $ila_cores dcache] $dcache_trigger $trigger_valid 8 $trigger_position $window_count
puts "INFO: CPU trigger=0x$cpu_trigger Pipeline trigger=0x$pipe_trigger MMU trigger=0x$mmu_trigger AXI trigger=0x$axi_trigger DCache trigger=0x$dcache_trigger"

if {!$keep_cpu_running} {
    la132_capture_set_cpu_reset $reset_probe 0
    puts "INFO: CPU VIO reset released"
}

set trigger_deadline_ms [expr {[clock milliseconds] + $force_trigger_delay_ms}]
set all_captured 0
while {!$all_captured && [clock milliseconds] < $trigger_deadline_ms} {
    set all_captured 1
    foreach label {cpu pipe mmu axi dcache} {
        set hw_ila [dict get $ila_cores $label]
        wait_on_hw_ila -timeout 0.001 $hw_ila
        if {[get_property STATUS.CORE_STATUS $hw_ila] ne "FULL"} {
            set all_captured 0
        }
    }
    if {!$all_captured} {
        after 100
    }
}

foreach label {cpu pipe mmu axi dcache} {
    set hw_ila [dict get $ila_cores $label]
    wait_on_hw_ila -timeout 0.001 $hw_ila
    if {[get_property STATUS.CORE_STATUS $hw_ila] eq "FULL"} {
        puts "INFO: $label ILA captured its configured trigger"
    } else {
        run_hw_ila -trigger_now $hw_ila
        puts "INFO: forced $label ILA after $force_trigger_delay_ms ms"
    }
}

foreach label {cpu pipe mmu axi dcache} {
    set hw_ila [dict get $ila_cores $label]
    if {[catch {wait_on_hw_ila -timeout $timeout_minutes $hw_ila} wait_error]} {
        puts "WARNING: wait for $label ILA returned: $wait_error"
    }
    set ila_data [upload_hw_ila_data $hw_ila]
    set ila_path ${output_prefix}_${label}.ila
    set csv_path ${output_prefix}_${label}.csv
    write_hw_ila_data -force $ila_path $ila_data
    write_hw_ila_data -force -csv_file $csv_path $ila_data
    puts "INFO: $label ILA binary: $ila_path"
    puts "INFO: $label ILA CSV: $csv_path"
}

close_hw_target
disconnect_hw_server
close_hw_manager

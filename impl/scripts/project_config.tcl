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

set fpga_config_script_dir [file dirname [file normalize [info script]]]
source [file join $fpga_config_script_dir resolve_work_root.tcl]

proc fpga_required_env {environment_name} {
    if {![info exists ::env($environment_name)] ||
        [string trim $::env($environment_name)] eq ""} {
        error "Required environment variable is not set: $environment_name"
    }
    return $::env($environment_name)
}

proc fpga_env_or_default {environment_name default_value} {
    if {[info exists ::env($environment_name)] &&
        $::env($environment_name) ne ""} {
        return $::env($environment_name)
    }
    return $default_value
}

proc fpga_normalize_from {base_dir path} {
    if {[file pathtype $path] eq "absolute"} {
        return [file normalize $path]
    }
    return [file normalize [file join $base_dir $path]]
}

proc fpga_project_config {impl_dir} {
    set impl_dir [file normalize $impl_dir]
    set repo_root [file dirname $impl_dir]
    set work_root [fpga_resolve_work_root $impl_dir]

    set board_name [fpga_env_or_default FPGA_BOARD vu13p]
    if {$board_name ni {vu13p lsbd}} {
        error "Unsupported FPGA_BOARD '$board_name'; expected vu13p or lsbd"
    }

    set project_name [fpga_required_env FPGA_PROJECT_NAME]
    if {![regexp {^[A-Za-z0-9_.-]+$} $project_name]} {
        error "FPGA_PROJECT_NAME contains unsupported characters: $project_name"
    }

    set project_dir_value [fpga_env_or_default \
        FPGA_PROJECT_DIR [file join $work_root $project_name]]
    set project_dir [fpga_normalize_from $impl_dir $project_dir_value]

    set part_name [fpga_required_env FPGA_PART]
    set cpu_frequency_hz [fpga_required_env FPGA_CPU_FREQ_HZ]
    if {![string is integer -strict $cpu_frequency_hz] ||
        $cpu_frequency_hz < 1} {
        error "FPGA_CPU_FREQ_HZ must be a positive integer"
    }
    set project_filelist [fpga_required_env FPGA_FILELIST]
    set constraint_file [fpga_normalize_from $impl_dir \
        [fpga_required_env FPGA_CONSTRAINT_FILE]]
    set top_file [fpga_normalize_from $impl_dir \
        [fpga_required_env FPGA_TOP_FILE]]
    set top_module [fpga_required_env FPGA_TOP_MODULE]
    if {![regexp {^[A-Za-z_][A-Za-z0-9_$]*$} $top_module]} {
        error "FPGA_TOP_MODULE is not a valid Verilog identifier: $top_module"
    }
    set verilog_defines [fpga_env_or_default FPGA_VERILOG_DEFINES ""]
    if {[catch {llength $verilog_defines}]} {
        error "FPGA_VERILOG_DEFINES must be a valid Tcl list"
    }
    set synth_strategy [fpga_env_or_default \
        FPGA_SYNTH_STRATEGY Flow_PerfOptimized_high]

    set bd_name [fpga_required_env FPGA_BD_NAME]
    if {![regexp {^[A-Za-z_][A-Za-z0-9_$]*$} $bd_name]} {
        error "FPGA_BD_NAME is not a valid Verilog identifier: $bd_name"
    }
    set bd_tcl [fpga_normalize_from $impl_dir \
        [fpga_required_env FPGA_BD_TCL]]

    return [dict create \
        board_name $board_name \
        impl_dir $impl_dir \
        repo_root $repo_root \
        ip_root [file join $impl_dir ip] \
        work_root $work_root \
        project_name $project_name \
        project_dir $project_dir \
        filelist_name $project_filelist \
        project_file [file join $project_dir ${project_name}.xpr] \
        part_name $part_name \
        cpu_frequency_hz $cpu_frequency_hz \
        constraint_file $constraint_file \
        top_file $top_file \
        top_module $top_module \
        bd_name $bd_name \
        bd_tcl $bd_tcl \
        verilog_defines $verilog_defines \
        synth_strategy $synth_strategy]
}

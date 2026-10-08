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
    error "usage: vio_cpu_reset.tcl <work-path> ?pulse|assert|release? ?assert-time-ms?"
}
set work_path [file normalize [lindex $argv 0]]
set reset_action pulse
set assert_time_ms 100
if {$argc >= 2} {
    set reset_action [string tolower [lindex $argv 1]]
}
if {$argc == 3} {
    set assert_time_ms [lindex $argv 2]
}
if {$reset_action ni {pulse assert release}} {
    error "reset action must be pulse, assert, or release"
}
if {![string is integer -strict $assert_time_ms] || $assert_time_ms < 1} {
    error "assert-time-ms must be a positive integer"
}
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir hardware_config.tcl]
set hardware_config [fpga_hardware_config]
dict with hardware_config {}

set project_name $default_project_name
if {[info exists ::env(FPGA_PROJECT_NAME)] &&
    [string trim $::env(FPGA_PROJECT_NAME)] ne ""} {
    set project_name $::env(FPGA_PROJECT_NAME)
}
set top_module $default_top_module
if {[info exists ::env(FPGA_TOP_MODULE)] &&
    [string trim $::env(FPGA_TOP_MODULE)] ne ""} {
    set top_module $::env(FPGA_TOP_MODULE)
}
set ltx_path [file join $work_path $project_name \
    ${project_name}.runs impl_1 ${top_module}.ltx]
if {![file isfile $ltx_path]} {
    error "debug probes file does not exist: $ltx_path"
}

set_param xicom.use_bitstream_version_check false
set hw_device [fpga_connect_hw_device $hardware_config]
set_property PROBES.FILE $ltx_path $hw_device
set_property FULL_PROBES.FILE $ltx_path $hw_device
refresh_hw_device $hw_device

set hw_vios [get_hw_vios -quiet -of_objects $hw_device \
    -filter {CELL_NAME =~ "*xlnx_vio"}]
if {[llength $hw_vios] == 0} {
    error "the programmed $board_name design does not expose xlnx_vio"
}
set reset_probe [get_hw_probes -quiet {*vio_cpu_reset*} \
    -of_objects [lindex $hw_vios 0]]
if {[llength $reset_probe] != 1} {
    error "expected one vio_cpu_reset probe, got [llength $reset_probe]"
}

if {$reset_action eq "pulse"} {
    set_property OUTPUT_VALUE 1 $reset_probe
    commit_hw_vio $reset_probe
    after $assert_time_ms
    set_property OUTPUT_VALUE 0 $reset_probe
    commit_hw_vio $reset_probe
    puts "INFO: Pulsed OpenLA132S CPU reset for $assert_time_ms ms"
} elseif {$reset_action eq "assert"} {
    set_property OUTPUT_VALUE 1 $reset_probe
    commit_hw_vio $reset_probe
    puts "INFO: Held OpenLA132S CPU in reset"
} else {
    set_property OUTPUT_VALUE 0 $reset_probe
    commit_hw_vio $reset_probe
    puts "INFO: Released OpenLA132S CPU reset"
}

close_hw_target
disconnect_hw_server
close_hw_manager

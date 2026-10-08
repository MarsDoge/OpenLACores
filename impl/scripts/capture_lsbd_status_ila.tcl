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

if {$argc < 1 || $argc > 2} {
    error "usage: capture_lsbd_status_ila.tcl <work-path> ?output-prefix?"
}

set work_path [file normalize [lindex $argv 0]]
set output_prefix [file join $work_path lsbd_status]
if {$argc == 2 && [string trim [lindex $argv 1]] ne ""} {
    set output_prefix [file normalize [lindex $argv 1]]
}

set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir hardware_config.tcl]
set hardware_config [fpga_hardware_config]
dict with hardware_config {}
if {$board_name ne "lsbd"} {
    error "the LSBD status ILA can only be captured with FPGA_BOARD=lsbd"
}

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
file mkdir [file dirname $output_prefix]

set_param xicom.use_bitstream_version_check false
set hw_device [fpga_connect_hw_device $hardware_config]
set_property PROBES.FILE $ltx_path $hw_device
set_property FULL_PROBES.FILE $ltx_path $hw_device
refresh_hw_device $hw_device

set status_ilas [get_hw_ilas -quiet -of_objects $hw_device \
    -filter {CELL_NAME =~ "*u_ila_lsbd_status"}]
if {[llength $status_ilas] != 1} {
    error "expected one u_ila_lsbd_status hardware core, got [llength $status_ilas]"
}
set status_ila [lindex $status_ilas 0]
current_hw_ila $status_ila
reset_hw_ila $status_ila

set capture_depth [get_property STATIC.MAX_DATA_DEPTH $status_ila]
set_property CONTROL.DATA_DEPTH $capture_depth $status_ila
set_property CONTROL.WINDOW_COUNT 1 $status_ila
set_property CONTROL.TRIGGER_POSITION [expr {$capture_depth - 1}] $status_ila
run_hw_ila $status_ila
after 20
run_hw_ila -trigger_now $status_ila
wait_on_hw_ila -timeout 1 $status_ila

set ila_data [upload_hw_ila_data $status_ila]
set ila_path ${output_prefix}.ila
set csv_path ${output_prefix}.csv
write_hw_ila_data -force $ila_path $ila_data
write_hw_ila_data -force -csv_file $csv_path $ila_data
puts "INFO: LSBD status ILA binary: $ila_path"
puts "INFO: LSBD status ILA CSV: $csv_path"

close_hw_target
disconnect_hw_server
close_hw_manager

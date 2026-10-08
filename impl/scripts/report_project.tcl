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

if {$argc != 1} {
    error "usage: report_project.tcl <status|synth|impl>"
}

set report_action [lindex $argv 0]
if {$report_action ni {status synth impl}} {
    error "unsupported report action: $report_action"
}

set script_dir [file dirname [file normalize [info script]]]
set impl_dir [file dirname $script_dir]
source [file join $script_dir project_config.tcl]
set project_config [fpga_project_config $impl_dir]
dict with project_config {}
source [file join $script_dir flow_helpers.tcl]
source [file join $script_dir report_design.tcl]

if {![file exists $project_file]} {
    error "Vivado project does not exist: $project_file"
}

open_project $project_file

if {$report_action eq "status"} {
    foreach run_name {synth_1 impl_1} {
        set run [get_runs $run_name]
        puts [format "INFO: %-8s status=%s progress=%s needs_refresh=%s" \
            $run_name \
            [get_property STATUS $run] \
            [get_property PROGRESS $run] \
            [fpga_run_needs_refresh $run_name]]
    }
    close_project
    return
}

if {$report_action eq "synth"} {
    if {![fpga_synthesis_complete]} {
        error "synth_1 is incomplete or stale: [fpga_run_status synth_1]; run make syn first"
    }
    open_run synth_1
    fpga_write_synthesis_reports $work_root
} else {
    if {![fpga_implementation_step_complete route_design]} {
        set impl_status [fpga_run_status impl_1]
        error "impl_1 is not current and routed: $impl_status; \
            run make -C impl impl first"
    }
    open_run impl_1
    fpga_write_implementation_reports $work_root
}

close_design
close_project

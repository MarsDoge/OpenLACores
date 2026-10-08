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

set script_dir [file dirname [file normalize [info script]]]
set impl_dir [file dirname $script_dir]
source [file join $script_dir project_config.tcl]
set project_config [fpga_project_config $impl_dir]
dict with project_config {}
source [file join $script_dir configure_parallelism.tcl]
source [file join $script_dir flow_helpers.tcl]
source [file join $script_dir report_design.tcl]

if {![file exists $project_file]} {
    error "Vivado project does not exist: $project_file"
}

open_project $project_file
fpga_apply_parallel_hooks $script_dir
fpga_run_implementation route_design $::vivado_run_jobs

open_run impl_1
fpga_write_implementation_reports $work_root
close_design
close_project

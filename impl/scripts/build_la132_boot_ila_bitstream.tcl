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

set protected_work_root [file normalize [file join $impl_dir xlnx-work]]
if {$work_root eq $protected_work_root} {
    error "Refusing to insert LA132 boot ILAs into the normal project: $work_root"
}
if {![file exists $project_file]} {
    error "Vivado project does not exist: $project_file"
}

open_project $project_file
fpga_apply_parallel_hooks $script_dir

set source_defines [get_property verilog_define [get_filesets sources_1]]
foreach required_define {GODSON_DEBUG FPGA_LA132_BOOT_ILA} {
    if {[lsearch -exact $source_defines $required_define] < 0} {
        error "LA132 boot ILA project is missing define $required_define"
    }
}

set impl_runs [get_runs -quiet impl_1]
if {[llength $impl_runs] != 1} {
    error "Expected one impl_1 run, found [llength $impl_runs]"
}
set impl_run [lindex $impl_runs 0]
set ila_hook [file normalize \
    [file join $script_dir insert_la132_boot_ila_hook.tcl]]
set_property STEPS.OPT_DESIGN.TCL.PRE $ila_hook $impl_run

fpga_run_synthesis $::vivado_run_jobs 0
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $::vivado_run_jobs
wait_on_run impl_1
if {[fpga_run_status impl_1] ne "write_bitstream Complete!"} {
    error "LA132 boot ILA implementation failed: [fpga_run_status impl_1]"
}

open_run impl_1
foreach core_name {
    u_ila_la132_cpu u_ila_la132_pipe u_ila_la132_mmu
    u_ila_la132_axi u_ila_la132_dcache
} {
    set debug_cores [get_debug_cores -quiet $core_name]
    if {[llength $debug_cores] != 1} {
        error "Expected routed $core_name, found [llength $debug_cores]"
    }
}

set run_dir [get_property DIRECTORY $impl_run]
set ltx_file [file join $run_dir ${top_module}.ltx]
write_debug_probes -force $ltx_file
report_debug_core -file [file join $work_root la132_boot_ila_debug_core.rpt]
fpga_write_implementation_reports $work_root

set worst_paths [get_timing_paths -quiet -delay_type max -max_paths 1]
if {[llength $worst_paths] == 0} {
    set worst_slack ""
} else {
    set worst_slack [get_property SLACK [lindex $worst_paths 0]]
}

close_design
close_project

puts "INFO: LA132 boot ILA probes: $ltx_file"
if {$worst_slack ne "" && $worst_slack < 0.0} {
    error "ILA bitstream was generated but routed setup timing failed: WNS=$worst_slack ns"
}

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

foreach {file_role required_file} [list \
    "top-level RTL" $top_file \
    "constraint" $constraint_file \
    "Block Design Tcl" $bd_tcl] {
    if {![file isfile $required_file]} {
        error "Configured $file_role file does not exist: $required_file"
    }
}

puts "INFO: FPGA board: $board_name"
puts "INFO: Project name: $project_name"
puts "INFO: Project directory: $project_dir"
puts "INFO: Project FileList: $filelist_name"
puts "INFO: FPGA part: $part_name"
puts "INFO: Constraint file: $constraint_file"
puts "INFO: Top-level RTL/module: $top_file / $top_module"
puts "INFO: Block Design: $bd_name from $bd_tcl"
puts "INFO: Synthesis strategy: $synth_strategy"

file mkdir $project_dir
create_project $project_name $project_dir -force -part $part_name
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property source_mgmt_mode None [current_project]
set_property strategy $synth_strategy [get_runs synth_1]
fpga_apply_parallel_hooks $script_dir

# Parse the checked repo-root-relative CPU file list without replacing or
# overlaying entries.
set cpu_filelist [file join $repo_root design filelist $filelist_name]
if {![file isfile $cpu_filelist]} {
    error "CPU RTL file list not found: $cpu_filelist"
}
set file_handle [open $cpu_filelist r]
set filelist_text [read $file_handle]
close $file_handle

set cpu_rtl [list]
set include_dirs [list]
foreach raw_line [split $filelist_text "\n"] {
    set line [string trim [lindex [split $raw_line "#"] 0]]
    if {$line eq ""} {
        continue
    }
    if {[string match "+incdir+*" $line]} {
        set relative_dir [string range $line 8 end]
        set include_dir [file normalize \
            [file join $repo_root $relative_dir]]
        if {![file isdirectory $include_dir]} {
            error "CPU include directory not found: $include_dir"
        }
        lappend include_dirs $include_dir
    } else {
        set rtl_file [file normalize \
            [file join $repo_root $line]]
        if {![file isfile $rtl_file]} {
            error "CPU RTL file not found: $rtl_file"
        }
        lappend cpu_rtl $rtl_file
    }
}

set soc_rtl [list \
    [file join $impl_dir soc xlnx_cpu_axi_bd_adapt.v] \
    $top_file \
]
foreach rtl_file $soc_rtl {
    if {![file isfile $rtl_file]} {
        error "SoC RTL file not found: $rtl_file"
    }
}

add_files -fileset sources_1 -norecurse \
    [concat $cpu_rtl $soc_rtl]
set_property include_dirs $include_dirs [get_filesets sources_1]
set_property verilog_define $verilog_defines [get_filesets sources_1]

# The checked Tcl is the sole source of truth for all peripheral IP.
source $bd_tcl
set bd_file [get_files -quiet */${bd_name}.bd]
if {[llength $bd_file] != 1} {
    error "Expected one generated Block Design file for $bd_name, got: $bd_file"
}

set wrapper_file [file join \
    $project_dir \
    ${project_name}.gen \
    sources_1 \
    bd \
    $bd_name \
    hdl \
    ${bd_name}_wrapper.v]
make_wrapper -files $bd_file -top
if {![file isfile $wrapper_file]} {
    error "Generated Block Design wrapper not found: $wrapper_file"
}
add_files -fileset sources_1 -norecurse $wrapper_file

generate_target all $bd_file
export_ip_user_files \
    -of_objects $bd_file \
    -no_script \
    -sync \
    -force \
    -quiet
create_ip_run $bd_file

add_files -fileset constrs_1 -norecurse $constraint_file
set_property top $top_module [get_filesets sources_1]
set_property top $top_module [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
close_bd_design [get_bd_designs $bd_name]
close_project

puts "Created [file join $project_dir ${project_name}.xpr]"

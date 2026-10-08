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

proc fpga_parallel_value {environment_name default_value maximum_value} {
    if {![info exists ::env($environment_name)] ||
        $::env($environment_name) eq ""} {
        return $default_value
    }

    set value $::env($environment_name)
    if {![string is integer -strict $value] ||
        $value < 1 || $value > $maximum_value} {
        error "$environment_name must be an integer from 1 through $maximum_value"
    }
    return $value
}

set ::vivado_run_jobs [fpga_parallel_value VIVADO_JOBS 8 64]
set ::vivado_max_threads [fpga_parallel_value VIVADO_THREADS 8 20]
set_param general.maxThreads $::vivado_max_threads

proc fpga_apply_parallel_hooks {script_dir} {
    set thread_hook [file normalize \
        [file join $script_dir set_vivado_threads.tcl]]
    set opt_design_hook [file normalize \
        [file join $script_dir prepare_opt_design.tcl]]

    set synth_run [get_runs -quiet synth_1]
    if {[llength $synth_run] == 1} {
        set_property STEPS.SYNTH_DESIGN.TCL.PRE $thread_hook $synth_run
    }

    set impl_run [get_runs -quiet impl_1]
    if {[llength $impl_run] == 1} {
        foreach step {
            INIT_DESIGN OPT_DESIGN POWER_OPT_DESIGN PLACE_DESIGN
            POST_PLACE_POWER_OPT_DESIGN PHYS_OPT_DESIGN ROUTE_DESIGN
            POST_ROUTE_PHYS_OPT_DESIGN WRITE_BITSTREAM
        } {
            set property_name STEPS.${step}.TCL.PRE
            if {[lsearch -exact [list_property $impl_run] $property_name] >= 0} {
                set step_hook $thread_hook
                if {$step eq "OPT_DESIGN"} {
                    set step_hook $opt_design_hook
                }
                set_property $property_name $step_hook $impl_run
            }
        }
    }

    puts "INFO: Vivado parallelism: jobs=$::vivado_run_jobs, threads=$::vivado_max_threads"
}

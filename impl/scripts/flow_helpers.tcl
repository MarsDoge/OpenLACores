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

proc fpga_run_status {run_name} {
    return [get_property STATUS [get_runs $run_name]]
}

proc fpga_run_needs_refresh {run_name} {
    set run [get_runs $run_name]
    if {[lsearch -exact [list_property $run] NEEDS_REFRESH] < 0} {
        return 0
    }
    return [expr {[get_property NEEDS_REFRESH $run] ? 1 : 0}]
}

proc fpga_stop_active_runs {} {
    set active_runs [list]
    foreach run [get_runs -quiet] {
        set run_status [get_property STATUS $run]
        if {[string match "*Running*" $run_status] ||
            [string match "*Queued*" $run_status]} {
            lappend active_runs $run
        }
    }
    if {[llength $active_runs] != 0} {
        catch {stop_runs $active_runs}
    }
    return $active_runs
}

proc fpga_synthesis_complete {} {
    return [expr {
        [fpga_run_status synth_1] eq "synth_design Complete!" &&
        ![fpga_run_needs_refresh synth_1]
    }]
}

proc fpga_run_synthesis {jobs force_run} {
    if {!$force_run && [fpga_synthesis_complete]} {
        puts "INFO: Reusing completed synth_1 run"
        return
    }

    set interrupted_runs [fpga_stop_active_runs]
    reset_run synth_1
    foreach run $interrupted_runs {
        set run_name [get_property NAME $run]
        if {$run_name ne "synth_1" &&
            [string match "*_synth_1" $run_name]} {
            reset_run $run
        }
    }
    launch_runs synth_1 -jobs $jobs
    if {[catch {wait_on_run synth_1} wait_error]} {
        fpga_stop_active_runs
        error $wait_error
    }

    set synth_status [fpga_run_status synth_1]
    if {$synth_status ne "synth_design Complete!"} {
        error "Synthesis failed: $synth_status"
    }
}

proc fpga_implementation_step_complete {target_step} {
    set impl_status [fpga_run_status impl_1]
    if {[fpga_run_needs_refresh impl_1]} {
        return 0
    }
    if {$target_step eq "route_design"} {
        return [expr {
            $impl_status eq "route_design Complete!" ||
            $impl_status eq "write_bitstream Complete!"
        }]
    }
    if {$target_step eq "write_bitstream"} {
        return [expr {$impl_status eq "write_bitstream Complete!"}]
    }
    error "Unsupported implementation target step: $target_step"
}

proc fpga_run_implementation {target_step jobs} {
    fpga_run_synthesis $jobs 0

    if {[fpga_implementation_step_complete $target_step]} {
        puts "INFO: Reusing impl_1 at [fpga_run_status impl_1]"
        return
    }

    set impl_status [fpga_run_status impl_1]
    if {$target_step eq "write_bitstream" &&
        $impl_status eq "route_design Complete!"} {
        puts "INFO: Continuing routed impl_1 through write_bitstream"
    } else {
        reset_run impl_1
    }

    launch_runs impl_1 -to_step $target_step -jobs $jobs
    if {[catch {wait_on_run impl_1} wait_error]} {
        fpga_stop_active_runs
        error $wait_error
    }

    if {![fpga_implementation_step_complete $target_step]} {
        error "Implementation failed: [fpga_run_status impl_1]"
    }
}

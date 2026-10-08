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

proc fpga_report_worst_setup {} {
    set worst_paths [get_timing_paths -quiet -delay_type max -max_paths 1]
    if {[llength $worst_paths] == 0} {
        puts "WARNING: No constrained setup timing path was found"
        return
    }

    set worst_path [lindex $worst_paths 0]
    puts "INFO: Worst setup slack: [get_property SLACK $worst_path] ns"
    puts "INFO: Worst setup startpoint: [get_property STARTPOINT_PIN $worst_path]"
    puts "INFO: Worst setup endpoint: [get_property ENDPOINT_PIN $worst_path]"
}

proc fpga_report_cpu_utilization {report_file stage_name} {
    set cpu_cells [get_cells -quiet -hierarchical -filter \
        {REF_NAME =~ openla132_ip_top*}]
    if {[llength $cpu_cells] == 1} {
        report_utilization -cells $cpu_cells -file $report_file
    } else {
        puts "WARNING: expected one $stage_name openla132_ip_top, found [llength $cpu_cells]"
    }
}

proc fpga_write_synthesis_reports {report_root} {
    file mkdir $report_root
    report_utilization -file \
        [file join $report_root synth_utilization.rpt]
    report_utilization -hierarchical -hierarchical_depth 8 -file \
        [file join $report_root synth_utilization_hierarchical.rpt]
    report_timing_summary -delay_type min_max -report_unconstrained -file \
        [file join $report_root synth_timing_summary.rpt]
    report_timing -delay_type max -max_paths 200 -nworst 1 -unique_pins \
        -path_type full -file \
        [file join $report_root synth_timing_top200_unique.rpt]
    report_high_fanout_nets -max_nets 200 -timing -file \
        [file join $report_root synth_high_fanout_timing.rpt]
    fpga_report_cpu_utilization \
        [file join $report_root synth_cpu_utilization.rpt] synthesized
    fpga_report_worst_setup
    puts "INFO: Synthesis reports: $report_root"
}

proc fpga_write_implementation_reports {report_root} {
    file mkdir $report_root
    report_timing_summary -delay_type min_max -report_unconstrained -file \
        [file join $report_root timing_summary.rpt]
    report_timing -delay_type max -max_paths 200 -nworst 1 -unique_pins \
        -path_type full_clock_expanded -file \
        [file join $report_root timing_top200_unique.rpt]
    report_high_fanout_nets -max_nets 200 -timing -file \
        [file join $report_root high_fanout_timing.rpt]
    report_design_analysis -congestion -file \
        [file join $report_root congestion.rpt]
    report_route_status -file \
        [file join $report_root route_status.rpt]
    report_utilization -file \
        [file join $report_root utilization.rpt]
    report_utilization -slr -file \
        [file join $report_root utilization_slr.rpt]
    report_utilization -hierarchical -hierarchical_depth 8 -file \
        [file join $report_root utilization_hierarchical.rpt]
    fpga_report_cpu_utilization \
        [file join $report_root cpu_utilization.rpt] implemented
    fpga_report_worst_setup
    puts "INFO: Implementation reports: $report_root"
}

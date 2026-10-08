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

foreach core_name {
    u_ila_la132_cpu u_ila_la132_pipe u_ila_la132_mmu
    u_ila_la132_axi u_ila_la132_dcache
} {
    if {[llength [get_debug_cores -quiet $core_name]] != 0} {
        error "$core_name already exists in the current design"
    }
}

proc la132_ila_require_one {description objects} {
    if {[llength $objects] != 1} {
        error "expected one $description, got [llength $objects]: $objects"
    }
    return [lindex $objects 0]
}

proc la132_ila_require_scope {reference_name instance_name} {
    set matches [get_cells -quiet -hierarchical -filter \
        [format {NAME == "%s"} $instance_name]]
    foreach nested_match [get_cells -quiet -hierarchical -filter \
            [format {NAME =~ "*/%s"} $instance_name]] {
        lappend matches $nested_match
    }
    set matches [lsort -unique $matches]
    return [la132_ila_require_one \
        "$reference_name instance $instance_name" $matches]
}

proc la132_ila_net {scope signal_name} {
    set full_name [format {%s/%s} $scope $signal_name]
    set matches [get_nets -quiet -hierarchical -filter \
        [format {NAME == "%s"} $full_name]]
    return [list [la132_ila_require_one "debug net $full_name" $matches]]
}

proc la132_ila_bus {scope signal_name width} {
    set nets [list]
    for {set bit 0} {$bit < $width} {incr bit} {
        set full_name [format {%s/%s[%d]} $scope $signal_name $bit]
        set matches [get_nets -quiet -hierarchical -filter \
            [format {NAME == "%s"} $full_name]]
        lappend nets [la132_ila_require_one "debug net $full_name" $matches]
    }
    return $nets
}

proc la132_ila_signal {scope signal_name width} {
    if {$width == 1} {
        return [la132_ila_net $scope $signal_name]
    }
    return [la132_ila_bus $scope $signal_name $width]
}

proc la132_ila_depth {environment_name default_depth} {
    set depth $default_depth
    if {[info exists ::env($environment_name)] && \
        $::env($environment_name) ne ""} {
        set depth $::env($environment_name)
    }
    if {![string is integer -strict $depth] || $depth < 1024 || \
        ($depth & ($depth - 1)) != 0} {
        error "$environment_name must be a power of two of at least 1024"
    }
    return $depth
}

proc la132_ila_create {core_name depth clock_net} {
    set core [create_debug_core $core_name ila]
    set_property C_DATA_DEPTH $depth $core
    set_property C_INPUT_PIPE_STAGES 2 $core
    set_property C_ADV_TRIGGER false $core
    set_property C_EN_STRG_QUAL false $core
    set_property C_TRIGIN_EN false $core
    set_property C_TRIGOUT_EN false $core
    connect_debug_port $core/clk $clock_net
    return $core
}

array set la132_ila_probe_index {}
proc la132_ila_add_probe {core label objects probe_type} {
    global la132_ila_probe_index
    if {![info exists la132_ila_probe_index($core)]} {
        set la132_ila_probe_index($core) 0
    }
    set probe_index $la132_ila_probe_index($core)
    if {$probe_index == 0} {
        set port [la132_ila_require_one "$core probe0" \
            [get_debug_ports -quiet $core/probe0]]
    } else {
        set port [create_debug_port $core probe]
    }
    set_property PORT_WIDTH [llength $objects] $port
    set_property PROBE_TYPE $probe_type $port
    connect_debug_port $port $objects
    puts "INFO: $core probe$probe_index $label width=[llength $objects] type=$probe_type"
    incr la132_ila_probe_index($core)
}

proc la132_ila_add_named_signals {core scope signal_specs label_prefix {trigger_signals {}}} {
    foreach {signal_name width} $signal_specs {
        set probe_type DATA
        if {[lsearch -exact $trigger_signals $signal_name] >= 0} {
            set probe_type DATA_AND_TRIGGER
        }
        la132_ila_add_probe $core ${label_prefix}${signal_name} \
            [la132_ila_signal $scope $signal_name $width] $probe_type
    }
}

set adapter_scope [la132_ila_require_scope \
    xlnx_cpu_axi_bd_adapt x_xlnx_cpu_axi_bd_adapt]
set ifu_stage_scope [la132_ila_require_scope ifu_stage x_ifu_stage]
set dsu_stage_scope [la132_ila_require_scope dsu_stage x_dsu_stage]
set mmu_scope [la132_ila_require_scope mmu_core x_mmu_core]
set lsu_stage_scope [la132_ila_require_scope lsu_stage x_lsu_stage]
set rtu_stage_scope [la132_ila_require_scope rtu_stage x_rtu_stage]
set biu_sysbus_scope [la132_ila_require_scope \
    biu_axi_sysbus x_biu_axi_sysbus]
set ifu_port_scope [la132_ila_require_scope mmu_port x_mmu_port_ifu]
set lsu_port_scope [la132_ila_require_scope mmu_port x_mmu_port_lsu]
set ptw_scope [la132_ila_require_scope mmu_ptw x_mmu_ptw]
set dcache_arb_scope [la132_ila_require_scope \
    mmu_dcache_arb x_mmu_dcache_arb]
set dcache_tag_scope [la132_ila_require_scope \
    lsu_tagcmp x_lsu_cache_0/x_lsu_tagcmp]
set dcache_mq_scope [la132_ila_require_scope \
    lsu_mq x_lsu_cache_0/x_lsu_mq]
set cpu_clock [la132_ila_require_one "CPU clock net" \
    [get_nets -quiet cpu_clk]]

set commit_pc [la132_ila_bus $adapter_scope la132_ila_commit_pc 32]
set commit_valid [la132_ila_net $adapter_scope la132_ila_commit_valid]

set cpu_depth [la132_ila_depth FPGA_LA132_CPU_ILA_DEPTH 16384]
set pipe_depth [la132_ila_depth FPGA_LA132_PIPE_ILA_DEPTH 8192]
set mmu_depth [la132_ila_depth FPGA_LA132_MMU_ILA_DEPTH 8192]
set axi_depth [la132_ila_depth FPGA_LA132_AXI_ILA_DEPTH 8192]
set dcache_depth [la132_ila_depth FPGA_LA132_DCACHE_ILA_DEPTH 4096]

set cpu_core [la132_ila_create u_ila_la132_cpu $cpu_depth $cpu_clock]
la132_ila_add_probe $cpu_core commit_pc $commit_pc DATA_AND_TRIGGER
la132_ila_add_probe $cpu_core commit_valid $commit_valid DATA_AND_TRIGGER
la132_ila_add_named_signals $cpu_core $adapter_scope {
    la132_ila_cpu_reset     1
    la132_ila_commit_inst  32
    la132_ila_gr_we         1
    la132_ila_gr_waddr      5
    la132_ila_gr_wdata     32
    la132_ila_csr0         32
    la132_ila_csr1         32
    la132_ila_csr4         32
    la132_ila_csr5         32
    la132_ila_csr6         32
    la132_ila_csr7         32
} {} {
    la132_ila_csr1
    la132_ila_csr5
    la132_ila_csr6
    la132_ila_csr7
}

set pipe_core [la132_ila_create u_ila_la132_pipe $pipe_depth $cpu_clock]
la132_ila_add_probe $pipe_core commit_pc $commit_pc DATA_AND_TRIGGER
la132_ila_add_probe $pipe_core commit_valid $commit_valid DATA_AND_TRIGGER
la132_ila_add_named_signals $pipe_core $ifu_stage_scope {
    la132_ila_ifu_reset                 1
    la132_ila_ifu_pc                   32
    la132_ila_ifu_state                 2
    la132_ila_ifu_next_state            2
    la132_ila_ifu_pc_allowin            1
    la132_ila_ifu_idu_allowin           1
    la132_ila_ifu_fetch_req             1
    la132_ila_ifu_fetch_vaddr          32
    la132_ila_ifu_fetchreq_ready        1
    la132_ila_ifu_fetchdata_ready       1
    la132_ila_ifu_fetchdata_err         1
    la132_ila_ifu_fetch_mmu_expt_vld    1
    la132_ila_ifu_fetch_mmu_expt_code   6
    la132_ila_ifu_fetch_resp_vld        1
    la132_ila_ifu_fetch_validout        1
    la132_ila_ifu_fetch_pc             32
    la132_ila_ifu_fetch_inst           32
    la132_ila_ifu_stall_inst_valid      1
    la132_ila_ifu_stall2_inst_valid     1
    la132_ila_ifu_ex_valid              1
    la132_ila_ifu_ex_pc                32
    la132_ila_ifu_user_mode             1
    la132_ila_ifu_cancel_nextpc         1
    la132_ila_ifu_ft_send_pc            1
    la132_ila_ifu_ft_send_npc           1
    la132_ila_ifu_ft_no_send            1
} ifu_
la132_ila_add_named_signals $pipe_core $dsu_stage_scope {
    la132_ila_idu_reset            1
    la132_ila_idu_valid            1
    la132_ila_idu_pc              32
    la132_ila_idu_inst            32
    la132_ila_idu_ifu_inst_valid   1
    la132_ila_idu_de_allowin       1
    la132_ila_idu_nxt_validout     1
    la132_ila_idu_ex_cancel        1
    la132_ila_idu_exu_allowin      1
    la132_ila_idu_lsu_allowin      1
    la132_ila_idu_lsu_inst_valid   1
    la132_ila_idu_ls_cps_valid     1
    la132_ila_idu_ls               2
    la132_ila_idu_store_valid      1
    la132_ila_idu_mald_go          1
    la132_ila_idu_ex               1
    la132_ila_idu_excode           6
    la132_ila_idu_store_stall      1
    la132_ila_idu_sync_stall       1
    la132_ila_idu_other_stall      1
    la132_ila_idu_mm_stall_main    1
    la132_ila_idu_mem_valid        1
    la132_ila_idu_wb_valid         1
    la132_ila_idu_wb_stall         1
    la132_ila_idu_jbr_taken_valid  1
    la132_ila_idu_order_flag       1
    la132_ila_idu_split_2nd        1
} idu_
la132_ila_add_named_signals $pipe_core $lsu_stage_scope {
    la132_ila_lsu_reset                 1
    la132_ila_lsu_ex_cancel             1
    la132_ila_lsu_valid                 1
    la132_ila_lsu_pc                   32
    la132_ila_lsu_rtu_allowin           1
    la132_ila_lsu_valid_go_wb           1
    la132_ila_lsu_mem_valid_go          1
    la132_ila_lsu_mem_is_ld             1
    la132_ila_lsu_mem_is_st             1
    la132_ila_lsu_mem_ex                1
    la132_ila_lsu_mem_statcode          6
    la132_ila_lsu_mem_ex_pesudoint      1
    la132_ila_lsu_mmu_expt_vld          1
    la132_ila_lsu_mmu_expt_hold         1
    la132_ila_lsu_mmu_expt_write        1
    la132_ila_lsu_mmu_page_mode         1
    la132_ila_lsu_mem_st_retire_ready   1
    la132_ila_lsu_mem_st_cansend        1
    la132_ila_lsu_memld_req             1
    la132_ila_lsu_mem_ldsc_wait         1
    la132_ila_lsu_dals_wait             1
    la132_ila_lsu_llbit                 1
    la132_ila_lsu_mem_is_sc_valid       1
    la132_ila_lsu_mem_sc_ok             1
    la132_ila_lsu_sc_fail               1
    la132_ila_lsu_sc_data_result        1
    la132_ila_lsu_ifc_last_exok         1
    la132_ila_lsu_mark_int              1
    la132_ila_lsu_mem_nmi_ccerr         1
    la132_ila_lsu_userdef_supexc        1
    la132_ila_lsu_mem_load_wait_back    1
    la132_ila_lsu_de_load_wait          1
    la132_ila_lsu_lddata_ready          1
    la132_ila_lsu_lddata_err            1
    la132_ila_lsu_load_data_ok          1
    la132_ila_lsu_mem_load_ok           1
    la132_ila_lsu_ifc_ls_cmplt          1
    la132_ila_lsu_storeq_valid          1
    la132_ila_lsu_storeq_flush          1
    la132_ila_lsu_mem_st_go_sq          1
    la132_ila_lsu_st_req                1
    la132_ila_lsu_st_req_addr_rcv       1
    la132_ila_lsu_st_req_3byte          1
    la132_ila_lsu_storeq_vaddr         32
    la132_ila_lsu_storeq_size           2
    la132_ila_lsu_memld_st_req          1
    la132_ila_lsu_memld_st_req_ready    1
    la132_ila_lsu_memld_st_write        1
    la132_ila_lsu_memld_st_vaddr       32
} lsu_ {
    la132_ila_lsu_mem_is_ld
    la132_ila_lsu_mem_is_st
    la132_ila_lsu_mem_ex
    la132_ila_lsu_mmu_expt_vld
    la132_ila_lsu_mem_st_retire_ready
    la132_ila_lsu_mem_ldsc_wait
    la132_ila_lsu_dals_wait
    la132_ila_lsu_mark_int
    la132_ila_lsu_mem_nmi_ccerr
    la132_ila_lsu_mem_load_ok
    la132_ila_lsu_memld_st_req
    la132_ila_lsu_memld_st_req_ready
}
la132_ila_add_named_signals $pipe_core $rtu_stage_scope {
    la132_ila_rtu_reset         1
    la132_ila_rtu_valid         1
    la132_ila_rtu_pc           32
    la132_ila_rtu_mem_validout  1
    la132_ila_rtu_lsu_allowin   1
    la132_ila_rtu_ex_cancel     1
    la132_ila_rtu_ex_pc        32
    la132_ila_rtu_ex_valid      1
    la132_ila_rtu_wb_stall      1
    la132_ila_rtu_wb_validout   1
    la132_ila_rtu_mdu           1
    la132_ila_rtu_roll          1
    la132_ila_rtu_dest          5
    la132_ila_rtu_result       32
    la132_ila_rtu_commit        1
} rtu_ {
    la132_ila_rtu_ex_cancel
    la132_ila_rtu_ex_valid
}

set mmu_core [la132_ila_create u_ila_la132_mmu $mmu_depth $cpu_clock]
la132_ila_add_probe $mmu_core commit_pc $commit_pc DATA_AND_TRIGGER
la132_ila_add_probe $mmu_core commit_valid $commit_valid DATA_AND_TRIGGER
la132_ila_add_named_signals $mmu_core $mmu_scope {
    la132_ila_mmu_reset                  1
    la132_ila_mmu_csr_plv                2
    la132_ila_mmu_csr_da                 1
    la132_ila_mmu_csr_pg                 1
    la132_ila_mmu_csr_datf               2
    la132_ila_mmu_csr_datm               2
    la132_ila_mmu_csr_asid              10
    la132_ila_mmu_csr_pgdl              32
    la132_ila_mmu_csr_pgdh              32
    la132_ila_mmu_csr_dmw0              32
    la132_ila_mmu_csr_dmw1              32
    la132_ila_mmu_csr_ptw_en             1
    la132_ila_mmu_ifu_kill               1
    la132_ila_mmu_ifu_req_vld            1
    la132_ila_mmu_ifu_req_rdy            1
    la132_ila_mmu_ifu_req_vaddr         32
    la132_ila_mmu_ifu_expt_vld           1
    la132_ila_mmu_ifu_expt_code          6
    la132_ila_mmu_ifu_cache_req_vld      1
    la132_ila_mmu_ifu_cache_req_rdy      1
    la132_ila_mmu_ifu_cache_req_wait     1
    la132_ila_mmu_ifu_cache_req_vaddr   32
    la132_ila_mmu_ifu_cache_req_paddr   32
    la132_ila_mmu_ifu_cache_req_mat      2
    la132_ila_mmu_ifu_cache_xlat_vld     1
    la132_ila_mmu_ifu_cache_xlat_cancel  1
    la132_ila_mmu_ifu_cache_xlat_paddr  32
    la132_ila_mmu_ifu_cache_xlat_mat     2
    la132_ila_mmu_ifu_tlb_lookup_vld     1
    la132_ila_mmu_ifu_tlb_lookup_hit     1
    la132_ila_mmu_ifu_tlb_lookup_paddr  32
    la132_ila_mmu_ifu_ptw_req_vld        1
    la132_ila_mmu_ifu_ptw_req_rdy        1
    la132_ila_mmu_ifu_ptw_req_vaddr     32
    la132_ila_mmu_ifu_fill_vld           1
    la132_ila_mmu_ifu_auto_inv_vld       1
    la132_ila_mmu_lsu_kill               1
    la132_ila_mmu_lsu_req_vld            1
    la132_ila_mmu_lsu_req_rdy            1
    la132_ila_mmu_lsu_req_write          1
    la132_ila_mmu_lsu_req_vaddr         32
    la132_ila_mmu_lsu_expt_vld           1
    la132_ila_mmu_lsu_expt_code          6
    la132_ila_mmu_lsu_expt_write         1
    la132_ila_mmu_lsu_cache_req_vld      1
    la132_ila_mmu_lsu_cache_req_rdy      1
    la132_ila_mmu_lsu_cache_req_wait     1
    la132_ila_mmu_lsu_cache_req_vaddr   32
    la132_ila_mmu_lsu_cache_req_paddr   32
    la132_ila_mmu_lsu_cache_req_mat      2
    la132_ila_mmu_lsu_cache_xlat_vld     1
    la132_ila_mmu_lsu_cache_xlat_cancel  1
    la132_ila_mmu_lsu_cache_xlat_paddr  32
    la132_ila_mmu_lsu_cache_xlat_mat     2
    la132_ila_mmu_lsu_tlb_lookup_vld     1
    la132_ila_mmu_lsu_tlb_lookup_hit     1
    la132_ila_mmu_lsu_tlb_lookup_paddr  32
    la132_ila_mmu_lsu_ptw_req_vld        1
    la132_ila_mmu_lsu_ptw_req_rdy        1
    la132_ila_mmu_lsu_ptw_req_vaddr     32
    la132_ila_mmu_lsu_fill_vld           1
    la132_ila_mmu_lsu_auto_inv_vld       1
    la132_ila_mmu_ptw_req_vld            1
    la132_ila_mmu_ptw_req_rdy            1
    la132_ila_mmu_ptw_req_port           1
    la132_ila_mmu_ptw_req_write          1
    la132_ila_mmu_ptw_req_vaddr         32
    la132_ila_mmu_ptw_req_asid          10
    la132_ila_mmu_ptw_resp_vld           1
    la132_ila_mmu_ptw_resp_port          1
    la132_ila_mmu_ptw_resp_vaddr        32
    la132_ila_mmu_ptw_resp_ppn          20
    la132_ila_mmu_ptw_resp_page_vld      1
    la132_ila_mmu_ptw_resp_bus_err       1
    la132_ila_mmu_ptw_mem_req_vld        1
    la132_ila_mmu_ptw_mem_req_rdy        1
    la132_ila_mmu_ptw_mem_req_paddr     32
    la132_ila_mmu_ptw_mem_resp_vld       1
    la132_ila_mmu_ptw_mem_resp_data     32
    la132_ila_mmu_ptw_mem_resp_err       1
} {} {
    la132_ila_mmu_lsu_kill
    la132_ila_mmu_lsu_req_vld
    la132_ila_mmu_lsu_req_rdy
    la132_ila_mmu_lsu_expt_vld
    la132_ila_mmu_lsu_ptw_req_vld
    la132_ila_mmu_ptw_resp_vld
}
la132_ila_add_named_signals $mmu_core $lsu_stage_scope {
    la132_ila_lsu_reset                 1
    la132_ila_lsu_ex_cancel             1
    la132_ila_lsu_valid                 1
    la132_ila_lsu_pc                   32
    la132_ila_lsu_rtu_allowin           1
    la132_ila_lsu_valid_go_wb           1
    la132_ila_lsu_mem_valid_go          1
    la132_ila_lsu_mem_is_ld             1
    la132_ila_lsu_mem_is_st             1
    la132_ila_lsu_mem_ex                1
    la132_ila_lsu_mem_statcode          6
    la132_ila_lsu_mem_ex_pesudoint      1
    la132_ila_lsu_mmu_expt_vld          1
    la132_ila_lsu_mmu_expt_hold         1
    la132_ila_lsu_mmu_expt_write        1
    la132_ila_lsu_mmu_page_mode         1
    la132_ila_lsu_mem_st_retire_ready   1
    la132_ila_lsu_mem_st_cansend        1
    la132_ila_lsu_memld_req             1
    la132_ila_lsu_mem_ldsc_wait         1
    la132_ila_lsu_dals_wait             1
    la132_ila_lsu_llbit                 1
    la132_ila_lsu_mem_is_sc_valid       1
    la132_ila_lsu_mem_sc_ok             1
    la132_ila_lsu_sc_fail               1
    la132_ila_lsu_sc_data_result        1
    la132_ila_lsu_ifc_last_exok         1
    la132_ila_lsu_mark_int              1
    la132_ila_lsu_mem_nmi_ccerr         1
    la132_ila_lsu_userdef_supexc        1
    la132_ila_lsu_mem_load_wait_back    1
    la132_ila_lsu_de_load_wait          1
    la132_ila_lsu_lddata_ready          1
    la132_ila_lsu_lddata_err            1
    la132_ila_lsu_load_data_ok          1
    la132_ila_lsu_mem_load_ok           1
    la132_ila_lsu_ifc_ls_cmplt          1
    la132_ila_lsu_storeq_valid          1
    la132_ila_lsu_storeq_flush          1
    la132_ila_lsu_mem_st_go_sq          1
    la132_ila_lsu_st_req                1
    la132_ila_lsu_st_req_addr_rcv       1
    la132_ila_lsu_st_req_3byte          1
    la132_ila_lsu_storeq_vaddr         32
    la132_ila_lsu_storeq_size           2
    la132_ila_lsu_memld_st_req          1
    la132_ila_lsu_memld_st_req_ready    1
    la132_ila_lsu_memld_st_write        1
    la132_ila_lsu_memld_st_vaddr       32
} lsu_stage_ {
    la132_ila_lsu_mem_is_ld
    la132_ila_lsu_mem_is_st
    la132_ila_lsu_mem_ex
    la132_ila_lsu_mmu_expt_vld
    la132_ila_lsu_mem_st_retire_ready
    la132_ila_lsu_mem_ldsc_wait
    la132_ila_lsu_dals_wait
    la132_ila_lsu_mark_int
    la132_ila_lsu_mem_nmi_ccerr
    la132_ila_lsu_mem_load_ok
    la132_ila_lsu_memld_st_req
    la132_ila_lsu_memld_st_req_ready
}
la132_ila_add_named_signals $mmu_core $biu_sysbus_scope {
    la132_ila_biu_mmu_page_mode    1
    la132_ila_biu_lsu_req_vld      1
    la132_ila_biu_lsu_req_rdy      1
    la132_ila_biu_memld_st_req     1
    la132_ila_biu_memld_st_write   1
    la132_ila_biu_memld_st_ready   1
    la132_ila_biu_memld_st_vaddr  32
    la132_ila_biu_lsu_xlat_vld     1
    la132_ila_biu_lsu_xlat_cancel  1
    la132_ila_biu_lsu_cache_vld    1
    la132_ila_biu_lsu_cache_rdy    1
    la132_ila_biu_lsu_cache_wait   1
    la132_ila_biu_lsu_expt_vld     1
    la132_ila_biu_lsu_expt_write   1
    la132_ila_biu_lsu_store_done   1
    la132_ila_biu_dcpu_req_vld     1
    la132_ila_biu_dcpu_req_rdy     1
    la132_ila_biu_dcpu_req_wait    1
    la132_ila_biu_dcpu_req_replay  1
    la132_ila_biu_dcpu_req_rd      1
    la132_ila_biu_dcpu_req_vaddr  32
    la132_ila_biu_dcpu_req_paddr  32
} biu_
set port_signals {
    la132_ila_port_state          2
    la132_ila_port_write          1
    la132_ila_port_vaddr         32
    la132_ila_port_plv            2
    la132_ila_port_asid          10
    la132_ila_port_replay_paddr  32
    la132_ila_port_replay_mat     2
    la132_ila_port_drop           1
    la132_ila_port_pending_kill   1
    la132_ila_port_paging_mode    1
    la132_ila_port_dmw0_hit       1
    la132_ila_port_dmw1_hit       1
    la132_ila_port_mapped_lookup  1
    la132_ila_port_tlb_fault      1
    la132_ila_port_tlb_miss       1
    la132_ila_port_fast_success   1
    la132_ila_port_fast_paddr    32
    la132_ila_port_lookup_fault   1
    la132_ila_port_ptw_success    1
    la132_ila_port_ptw_fault      1
    la132_ila_port_ptw_paddr     32
}
la132_ila_add_named_signals $mmu_core $ifu_port_scope $port_signals ifu_
la132_ila_add_named_signals $mmu_core $lsu_port_scope $port_signals lsu_
la132_ila_add_named_signals $mmu_core $ptw_scope {
    la132_ila_ptw_state                  3
    la132_ila_ptw_port                   1
    la132_ila_ptw_write                  1
    la132_ila_ptw_vaddr                 32
    la132_ila_ptw_asid                  10
    la132_ila_ptw_dir_addr              32
    la132_ila_ptw_pte_addr              32
    la132_ila_ptw_pte                   32
    la132_ila_ptw_bus_err                1
    la132_ila_ptw_req_fire               1
    la132_ila_ptw_mem_req_fire           1
    la132_ila_ptw_selected_pgd          32
    la132_ila_ptw_selected_pgd_dmw0_hit  1
    la132_ila_ptw_selected_pgd_dmw1_hit  1
    la132_ila_ptw_selected_pgd_paddr    32
    la132_ila_ptw_req_dir_addr          32
    la132_ila_ptw_dir_entry_dmw0_hit     1
    la132_ila_ptw_dir_entry_dmw1_hit     1
    la132_ila_ptw_dir_entry_paddr       32
    la132_ila_ptw_resp_pte_addr         32
    la132_ila_ptw_dir_entry_empty        1
    la132_ila_ptw_dir_entry_huge         1
    la132_ila_ptw_pte_present            1
    la132_ila_ptw_pte_write_ok           1
} {}

set axi_core [la132_ila_create u_ila_la132_axi $axi_depth $cpu_clock]
la132_ila_add_probe $axi_core commit_pc $commit_pc DATA_AND_TRIGGER
la132_ila_add_probe $axi_core commit_valid $commit_valid DATA_AND_TRIGGER
la132_ila_add_named_signals $axi_core $adapter_scope {
    la132_ila_cpu_reset       1
    la132_ila_axi_arid        4
    la132_ila_axi_araddr     32
    la132_ila_axi_arlen       4
    la132_ila_axi_arsize      3
    la132_ila_axi_arvalid     1
    la132_ila_axi_arready     1
    la132_ila_axi_rid         4
    la132_ila_axi_rdata      32
    la132_ila_axi_rresp       2
    la132_ila_axi_rlast       1
    la132_ila_axi_rvalid      1
    la132_ila_axi_rready      1
    la132_ila_axi_awid        4
    la132_ila_axi_awaddr     32
    la132_ila_axi_awlen       4
    la132_ila_axi_awsize      3
    la132_ila_axi_awvalid     1
    la132_ila_axi_awready     1
    la132_ila_axi_wdata      32
    la132_ila_axi_wstrb       4
    la132_ila_axi_wlast       1
    la132_ila_axi_wvalid      1
    la132_ila_axi_wready      1
    la132_ila_axi_bid         4
    la132_ila_axi_bresp       2
    la132_ila_axi_bvalid      1
    la132_ila_axi_bready      1
} {}

set dcache_core [la132_ila_create u_ila_la132_dcache $dcache_depth $cpu_clock]
la132_ila_add_probe $dcache_core commit_pc $commit_pc DATA_AND_TRIGGER
la132_ila_add_probe $dcache_core commit_valid $commit_valid DATA_AND_TRIGGER
la132_ila_add_named_signals $dcache_core $dcache_arb_scope {
    la132_ila_darb_reset            1
    la132_ila_darb_cpu_req_vld      1
    la132_ila_darb_cpu_req_wait     1
    la132_ila_darb_cpu_req_replay   1
    la132_ila_darb_cpu_req_rd       1
    la132_ila_darb_cpu_req_size     2
    la132_ila_darb_cpu_req_vaddr   32
    la132_ila_darb_cpu_req_paddr   32
    la132_ila_darb_cpu_req_mat      2
    la132_ila_darb_cpu_req_bank     3
    la132_ila_darb_cpu_req_wdata   32
    la132_ila_darb_cpu_req_rdy      1
    la132_ila_darb_cpu_req_fire     1
    la132_ila_darb_cpu_hold_rd      1
    la132_ila_darb_cpu_hold_size    2
    la132_ila_darb_cpu_hold_bank    3
    la132_ila_darb_cpu_hold_wdata  32
    la132_ila_darb_cache_req_vld    1
    la132_ila_darb_cache_req_rdy    1
    la132_ila_darb_cache_req_wait   1
    la132_ila_darb_cache_req_rd     1
    la132_ila_darb_cache_req_size   2
    la132_ila_darb_cache_req_vaddr 32
    la132_ila_darb_cache_req_paddr 32
    la132_ila_darb_cache_req_mat    2
    la132_ila_darb_cache_req_bank   3
    la132_ila_darb_cache_req_wdata 32
    la132_ila_darb_cache_resp_vld   1
    la132_ila_darb_cache_resp_data 32
    la132_ila_darb_cache_idle       1
    la132_ila_darb_ptw_active       1
} arb_
la132_ila_add_named_signals $dcache_core $dcache_tag_scope {
    la132_ila_tag_reset              1
    la132_ila_tag_real_req           1
    la132_ila_tag_req_rd             1
    la132_ila_tag_req_wdata         32
    la132_ila_tag_req_vaddr         32
    la132_ila_tag_req_paddr         32
    la132_ila_tag_req_xlat_wait      1
    la132_ila_tag_req_attr_vld       1
    la132_ila_tag_req_cached         1
    la132_ila_tag_req_alloc          1
    la132_ila_tag_xlat_vld           1
    la132_ila_tag_xlat_cancel        1
    la132_ila_tag_xlat_paddr        32
    la132_ila_tag_xlat_cached        1
    la132_ila_tag_xlat_alloc         1
    la132_ila_tag_state              2
    la132_ila_tag_next_state         2
    la132_ila_tag_next_in            1
    la132_ila_tag_valid              1
    la132_ila_tag_cmp_valid          1
    la132_ila_tag_allowin            1
    la132_ila_tag_tc_vaddr          32
    la132_ila_tag_tc_addr           32
    la132_ila_tag_tc_paddr          32
    la132_ila_tag_tc_rd              1
    la132_ila_tag_tc_wr              1
    la132_ila_tag_tc_wdata          32
    la132_ila_tag_tc_strb            4
    la132_ila_tag_tc_bank_sel        3
    la132_ila_tag_tc_xlat_wait       1
    la132_ila_tag_tc_xlat_ready      1
    la132_ila_tag_tc_wait_xlat       1
    la132_ila_tag_tc_attr_vld        1
    la132_ila_tag_tc_cached          1
    la132_ila_tag_tc_alloc           1
    la132_ila_tag_tc_bacs            1
    la132_ila_tag_see_cache          1
    la132_ila_tag_see_mq             1
    la132_ila_tag_see_axi            1
    la132_ila_tag_tc_miss            1
    la132_ila_tag_ls_hit_tag         1
    la132_ila_tag_ls_hit_mq          1
    la132_ila_tag_bank_hit_mq_valid  1
    la132_ila_tag_ls_hit_mq_ok       1
    la132_ila_tag_mq_valid           1
    la132_ila_tag_mq_bacs            1
    la132_ila_tag_mq_wait_wr         1
    la132_ila_tag_mq_addr_31_5      27
    la132_ila_tag_mq_buf_valid       8
    la132_ila_tag_mq_bank_sel        8
    la132_ila_tag_mq_bank_valid      8
    la132_ila_tag_st_hit_mq_ok       1
    la132_ila_tag_st_hit_mq_sel      8
    la132_ila_tag_st_hit_mq_wstrb    4
    la132_ila_tag_st_hit_mq_wdata   32
    la132_ila_tag_axi_arvalid        1
    la132_ila_tag_axi_ar_ok          1
    la132_ila_tag_axi_arburst        1
    la132_ila_tag_axi_araddr        32
    la132_ila_tag_missq_valid        1
    la132_ila_tag_missq_addr        32
    la132_ila_tag_rdata_valid        1
    la132_ila_tag_rdata             32
} tag_
la132_ila_add_named_signals $dcache_core $dcache_mq_scope {
    la132_ila_mq_reset                 1
    la132_ila_mq_state                 3
    la132_ila_mq_next_state            3
    la132_ila_mq_addr                 32
    la132_ila_mq_size                  2
    la132_ila_mq_bacs                  1
    la132_ila_mq_dirty                 1
    la132_ila_mq_tag_valid             1
    la132_ila_mq_tag_aw_do             1
    la132_ila_mq_tag_bacs              1
    la132_ila_mq_tag_cached            1
    la132_ila_mq_tag_addr             32
    la132_ila_mq_tag_strb              4
    la132_ila_mq_axi_ar_ok             1
    la132_ila_mq_axi_rvalid            1
    la132_ila_mq_axi_rdata            32
    la132_ila_mq_next_rd_in            1
    la132_ila_mq_wait_rd               1
    la132_ila_mq_r_ok                  1
    la132_ila_mq_axi_sel               3
    la132_ila_mq_st_hit_ok             1
    la132_ila_mq_st_hit_sel            8
    la132_ila_mq_st_hit_wstrb          4
    la132_ila_mq_st_hit_wdata         32
    la132_ila_mq_buf_hit_wen           8
    la132_ila_mq_buf_upd_valid         8
    la132_ila_mq_buf_upd_data        256
    la132_ila_mq_buf_valid_clr         8
    la132_ila_mq_buf_valid_set         8
    la132_ila_mq_buf_valid             8
    la132_ila_mq_buf_data            256
    la132_ila_mq_buf_all_valid         1
    la132_ila_mq_r_valid_set           8
    la132_ila_mq_refill_valid          1
    la132_ila_mq_refill_way            1
    la132_ila_mq_refill_indx           5
    la132_ila_mq_refill_tag           22
    la132_ila_mq_wr_data               1
    la132_ila_mq_cache_indx_sel        1
    la132_ila_mq_cache_indx            5
    la132_ila_mq_cache_tagv_wen        1
    la132_ila_mq_cache_data_wen        8
    la132_ila_mq_cache_data_strb      32
    la132_ila_mq_cache_data_wdata    256
    la132_ila_mq_wrbuf_refill_lru      1
    la132_ila_mq_wrbuf_dirty_wdata     1
} mq_

puts "INFO: Added $la132_ila_probe_index($cpu_core) CPU probes at depth $cpu_depth"
puts "INFO: Added $la132_ila_probe_index($mmu_core) MMU probes at depth $mmu_depth"
puts "INFO: Added $la132_ila_probe_index($axi_core) AXI probes at depth $axi_depth"
puts "INFO: Added $la132_ila_probe_index($dcache_core) DCache probes at depth $dcache_depth"
report_debug_core

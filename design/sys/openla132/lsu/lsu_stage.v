// ------------------------------------------------------------------------------------//
//  Copyright (c) 2026 Loongson Technology Corporation Limited.
//
//  OpenLACores is licensed under Mulan PSL v2.
// 
//  You can use this software according to the terms and conditions of the Mulan PSL v2.
//
//  You may obtain a copy of Mulan PSL v2 at:
//           http://license.coscl.org.cn/MulanPSL2
// 
//  THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
//  KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
//  NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// 
//  See the Mulan PSL v2 for more details.
// ------------------------------------------------------------------------------------//

`include "openla132_global.h"

module lsu_stage #(
    parameter HAS_BTB       = -1,  // 0 or 1
    parameter MDU_TYPE      = -1,  // 0(quick) or 1(smart) or 2(area)
    // ICache
    parameter HAS_ICC       = -1,  // 0 or 1
    parameter ICC_SET_ASSOC = -1,  // 1/2/4 way set associative
    parameter ICC_WAYSIZE   = -1,  // 1/2/4/8/16 KB Size/way
    // DCache
    parameter HAS_DCC       = -1,  // 0 or 1
    parameter DCC_SET_ASSOC = -1,  // 1/2/4 way set associative
    parameter DCC_WAYSIZE   = -1,  // 1/2/4/8/16 KB Size/way
    // performance counter
    parameter PERF_CNT_NUM  = -1,  // 0, 1 or 2
    // Memory Protect Unit
    parameter MPU_NUM       = -1   // 0, 1, 2, 3 or 4
) (
    input  wire                                              clk_g,
    input  wire                                              clk_ng,  // clock can't be clock-gating
    input  wire                                              clk_count,  // for COUNT, can't be cg by wait
    input  wire                                              clk_cr,
    input  wire                                              sync_hresetn,
    input  wire                                              sync_sresetn,
    input  wire                                              reset,
    input  wire                                              data_reset,
    input  wire [                                     3: 0]  prid_revision,
    input  wire [                                     9: 0]  cpunum,
    input  wire [                                    31: 0]  boot_pc,

    input  wire                                              core_lsu_nmi,
    input  wire [                                     7: 0]  ext_int,

    input  wire                                              ex_cancel,
    input  wire [                                    31: 0]  rtu_lsu_cancel_pc,
    input  wire                                              rtu_lsu_commit,
    input  wire                                              rtu_lsu_allowin,  // NOTE:most use with ~ex_cancel.
    input  wire                                              idu_lsu_inst_valid,
    input  wire [       `OPEN132_IDU_LSU_INST_BUS_WIDTH-1: 0]  idu_lsu_inst_bus,
    input  wire                                              idu_lsu_fpu_clear_skip,
    input  wire [                                    31: 0]  idu_lsu_follow_pc,  // for satll-fetch to flush pipeline
    input  wire [                                    33: 0]  idu_lsu_load_attr_bus,
    input  wire [                                    34: 0]  idu_lsu_store_data_bus,  // store ldl/ldr rt data

    input  wire [                                     0: 0]  exu_lsu_ctrl_bus,
    // signal from ahbi
    input  wire [     `OPEN132_CACHE_LSU_RESP_BUS_WIDTH-1: 0]  cache_lsu_resp_bus,

    output wire [      `OPEN132_LSU_CACHE_REQ_BUS_WIDTH-1: 0]  lsu_cache_req_bus,
    output wire [     `OPEN132_CSR_CACHE_CTRL_BUS_WIDTH-1: 0]  csr_cache_ctrl_bus,
`ifdef CONFIG_MMU
    output wire [       `OPEN132_CSR_MMU_CTRL_BUS_WIDTH-1: 0]  csr_mmu_ctrl_bus,
`endif
    output wire                                              lsu_idu_allowin,
    output wire                                              lsu_rtu_inst_valid,
    output wire [       `OPEN132_LSU_RTU_INST_BUS_WIDTH-1: 0]  lsu_rtu_inst_bus,
    output wire                                              lsu_idu_forward_valid,
    output wire [    `OPEN132_LSU_IDU_FORWARD_BUS_WIDTH-1: 0]  lsu_idu_forward_bus,
    output wire [                                     2: 0]  lsu_exu_ctrl_bus,
    output wire [       `OPEN132_CSR_IFU_CTRL_BUS_WIDTH-1: 0]  csr_ifu_ctrl_bus,
    output wire [       `OPEN132_CSR_IDU_CTRL_BUS_WIDTH-1: 0]  csr_idu_ctrl_bus,
    output wire [                                     1: 0]  csr_bpu_ctrl_bus,
    output wire [      `OPEN132_LSU_CORE_CTRL_BUS_WIDTH-1: 0]  lsu_core_ctrl_bus,
    // performance count
    input  wire [       `OPEN132_IDU_CSR_PERF_BUS_WIDTH-1: 0]  idu_csr_perf_bus,  // performance cnt
    input  wire [     `OPEN132_CACHE_CSR_PERF_BUS_WIDTH-1: 0]  cache_csr_perf_bus,
    // ecc fatal
    input  wire [`OPEN132_CACHE_LSU_ECC_FATAL_BUS_WIDTH-1: 0]  cache_lsu_ecc_fatal_bus,

    input  wire [        `OPEN132_IDU_LSU_APP_BUS_WIDTH-1: 0]  idu_lsu_app_bus,
    output wire [        `OPEN132_LSU_RTU_APP_BUS_WIDTH-1: 0]  lsu_rtu_app_bus

`ifdef OPEN132_HAS_LJTAG
    ,
    input  wire                                              clk_dm,  // ff or dhb
    input  wire                                              clk_slp_en,  // clock gating, for debug_clkn
    // from/to ljtag module
    output wire [                                     7: 0]  asid,
    input  wire                                              jtag_core_break,
    // to interface
    output wire                                              lsu_clk_breakpoint_enable,  // ihb/dhb clock open
    output wire                                              lsu_jtag_debug_mode,
    output wire                                              lsu_ifu_debug_map_valid,
    output wire [                                    13: 0]  lsu_idu_debug_bus,
    // hb
    output wire [                                    80: 0]  jtag_idu_ihb_req_bus,
    input  wire [                                    31: 0]  idu_jtag_ihb_resp_bus
`endif

    ,
    input  wire [            `OPEN132_FPU_LSU_BUS_WIDTH-1: 0]  fpu_lsu_bus,
    output wire [            `OPEN132_LSU_FPU_BUS_WIDTH-1: 0]  lsu_fpu_bus,
    output wire                                              lsu_idu_mdu_busy

    ,
    input  wire [                         (1+32+32)*4-1: 0]  ibus_win,
    input  wire [                         (1+32+32)*4-1: 0]  dbus_win

`ifdef GODSON_DEBUG
    ,
    output wire [                                    31: 0]  gs_core_csr0,
    output wire [                                    31: 0]  gs_core_csr1,
    output wire [                                    31: 0]  gs_core_csr4,
    output wire [                                    31: 0]  gs_core_csr5,
    output wire [                                    31: 0]  gs_core_csr6,
    output wire [                                    31: 0]  gs_core_csr7
`endif
);

localparam HAS_ICC_CPUCFG       = HAS_ICC;
localparam ICC_SET_ASSOC_CPUCFG = ICC_SET_ASSOC;
localparam ICC_WAYSIZE_CPUCFG   = ICC_WAYSIZE;
localparam HAS_DCC_CPUCFG       = HAS_DCC;
localparam DCC_SET_ASSOC_CPUCFG = DCC_SET_ASSOC;
localparam DCC_WAYSIZE_CPUCFG   = DCC_WAYSIZE;

localparam TOTAL_NUM_MPU_REGION0 = MPU_NUM;
localparam THIS_NUM_MPU_REGION0  = 1;

localparam TOTAL_NUM_MPU_REGION1 = MPU_NUM;
localparam THIS_NUM_MPU_REGION1  = 2;

localparam TOTAL_NUM_MPU_REGION2 = MPU_NUM;
localparam THIS_NUM_MPU_REGION2  = 3;

localparam TOTAL_NUM_MPU_REGION3 = MPU_NUM;
localparam THIS_NUM_MPU_REGION3  = 4;

genvar i;

//============================================================//
//                     Regs Declarations
//============================================================//

wire          sleeping;  // cpu in sleeping.

reg          valid;
reg          ihb_debug;
reg          ihb_signal;
reg          ex_dbgss;
reg [  3: 0] inst_lisa;   // csr/rdtime/cpucfg, 4'b0001 means IBAR

// [3:2]: 1-csr;2-rdtime;3-cpucfg, 0-null
// for csr   ,[1:0]: 2-csrrd;1-csrxchg;0-csrwr.
// for rdtime,[1  ]: 1-rdtime_2nd; 0-rdtime_1st
//           [0  ]: 1-rdtimeh   ; 0-rdtimel
reg          mdu_inst;       // the inst in the main pipeline is a mdu inst
reg          fpu_inst;       // the inst in the main pipeline is a fpu inst
reg          see_int_flush;  // inst(mdu/fpu) go main because of seeing interrupt
reg          idle_ertn;      // wait or ertn
reg          ex;

reg          ls_cps_valid;  // inst is load/store/cps
reg [  8: 0] ls_cps;

`ifdef CONFIG_MMU
reg [  8: 0] ex_info;
`else
reg [  7: 0] ex_info;
`endif

// de_lisa_si14: csr number; sub_excode;
reg [ 13: 0] lisa_si14;
reg [  4: 0] dest;
reg [ 31: 0] result;
reg [  2: 0] nc_3bits;
reg          order_flag;  // keep the order of fixed and mdu inst
reg [ 31: 0] pc;

reg          mem_ldsc_wait;  // mem-load addr has been rcv, and wait for data; see {load}segment

// or mem-SC has ben received, and wait for (EX)Okay.
reg          de_load_wait;   // de-load addr has been rcv, and wait for data; see {load}segment
reg          load_data_ok;   // load data is ok, forward-all or back from bus; see{load}segment
reg          load_data_err;  // load data has bus error
`ifdef CONFIG_MMU
reg          mmu_expt_vld_r;
reg [  5: 0] mmu_expt_code_r;
`endif

reg          storeq_valid;  // store queue is valid

// SC
reg          llbit;  // see {llbit}segement.

reg [ 31: 0] ld_bdata_stldlr;  // load back data , or store, ldl/ldr rt value.

// store queue
reg [ 31: 0] storeq_data;      // storeq reges
reg [ 31: 0] storeq_vaddr;
reg [  2: 0] storeq_paddr_h3;
reg [  1: 0] storeq_size;
reg          storeq_dbgm;

reg          lsfd_part_r;  // for sys bus, need register lsfd_part, because when waiting for load data,

// maybe store has receive req_ready, so lsfd_flag maybe invalid;
reg [  3: 0] st_strobe_r;  // like lsfd_part_r, st_strobe also need be registered

// disabled in debug mode
reg          nmi_mask_r;

// perfromance_counter events
// exception


wire          da_r;
`ifdef CONFIG_MMU
wire          pg_r;
`endif









// count




// csrff: elusion

wire [ 31: 0] era_r;



wire [ 31: 0] merrera_r;

wire          userdef_supexc;  // Slave support exclusive access.


// csr500 and csr508 for lisa


// cache err0

// cache errtag

//

reg [`OPEN132_IDU_LSU_APP_BUS_WIDTH-1: 0] idu_lsu_app_bus_r;
`ifdef OPEN132_ASSERT

reg [ 31: 0] as_pre_pc;
`endif

//============================================================//
//                     Wire Declarations
//============================================================//

wire                    lisa_da_v2p;
wire [           23: 0] lisa_segpa_v2p;
wire [            2: 0] vaddr_h3_v2p;
wire [            2: 0] paddr_h3_v2p;
wire [            2: 0] lisa_vs_expt;
wire [            6: 0] lisa_vscode_expt;
wire [           19: 0] merrentry_expt;
wire [           19: 0] eentry_expt;
wire                    ex_debug_expt;
wire                    ex_general_in_debug_mode_expt;
wire                    ex_srnmi_expt;
wire [           31: 0] ex_entry_expt;

// debug_mode mask nmi
wire          debug_mode;  // see {LJTAG}
wire          nmi_mask;    // normal nmi

wire          mem_nmi_ccerr;  // nmi cache error

wire          ctrl_nowrap;         // axi no wrap.
wire          mem_wakeup;          // nmi/int need wakeup sleeping.
wire          ctrl_sleep_cg;       // clock-gated in sleeping,csr userdef.sleepcg
wire          ctrl_null_cg;        // clock-gated if module unused, csr userdef.sleepcg
wire          lsu_clk_csr_enable;  // csrr/csr clk open

wire          de_validout;

// ls_cps is reused by load/store and cps
wire [  1: 0] ls;           // 10:da-load; 11:ma-load; 01:store 00:not load or store
wire          ls_dbgm;
wire [  1: 0] lswidth;      // 00:1byte;01:2byte;11:3byte;10:4byte
wire          ll_sc;        // ll/sc, ll/sc must send in mem-stagae,wait_sync in de-stage
wire          lbh;          // lb/lbu/lh/lhu
wire          lbhsign_ldl;  // lb/lbh or ldl
wire          lb_ldr;       // lb/lbu or ldr
wire [  1: 0] inst_cps;     // cache(01)/pref(10)/isync(11) instruction
wire [  2: 0] cc_op;        // cache op
wire          cc_op_i;      // cache op to icache

wire          ls_sel;

// cache op
wire          sel_cps;

// ex_info is for {ex_dbcl,fetch_ade,ex_lserr,de_excode}
wire          ex_dbcl;    // inst SDBBP
wire          fetch_ade;
wire          ex_lserr;   // load/store address priv or unaligned
`ifdef CONFIG_MMU
wire [  5: 0] excode;
`else
wire [  4: 0] excode;
`endif

// mem inst is load
wire          cps_support;        // if NO Cache or Cache bypass, can't support cps_req.
wire          mem_isnot_ld_st;
wire          mem_is_ld;
wire          mem_is_dald;        // device-attribute
wire          mem_is_mald;        // memory-attribute
wire          mem_is_st;
wire          mem_is_ld_valid;
wire          mem_is_mald_valid;
wire          mem_is_st_valid;
wire          mem_is_cps_valid;
wire          mem_is_ll_valid;
wire          mem_is_sc_valid;

wire [ 31: 0] de_mald_vaddr;
wire          de_mald_go;
wire          de_load;

wire [ 31: 0] de_r1_data;
wire          de_store_valid;
wire          de_ldl_ldr_valid;
wire          de_csr_write;

wire          mdu_is_run;

wire          mem_stallf;     // lisa stallf
wire          mem_mdu;        // mdu
wire          mem_roll;       // roll pipelin:exception/ertn/csr
wire          mem_lbh;        // lb/lbu/lh/lhu
wire          mem_lbhsign;    // lb/lh
wire          mem_lb;         // lb/lbu
wire          mem_ld_rotr_0;
wire          mem_ld_rotr_1;  // load result need rotr
wire          mem_ld_rotr_2;
wire          mem_ld_rotr_3;
wire [  4: 0] mem_dest;
wire [ 31: 0] mem_result;
wire          mem_mdu_flag;
wire [ 31: 0] mem_pc;
wire          mem_valid_go;
wire          mem_validout;   // mem_valid_go|| mem_ex_pesudoint

// wire        mem_nmi_ccerr;
wire          mem_see_int;
wire          mem_ls_cmplt;   // load/store complete
wire          lsu_idu_roll;
wire          mem_isalu;
wire [  4: 0] mem_fd_dest;    // for forward
wire [ 31: 0] mem_fd_result;
wire [ 31: 0] lsu_idu_pc;     // for branch pc if delay-slot is in de-satge.

wire          mem_valid;
wire          mem_flag;
wire          mem_wait_mdu;



// segcalge
wire [4*`OPEN132_CFGSEG_NUM-1: 0] ctrl_segcalg_sa;  // implementation-dependent


wire          mem_cps_req_ready;
wire          mem_cps_data_ready;
wire [ 31: 0] mem_cps_data_rdata;
wire          de_mald_req_ready;
wire          memld_st_req_ready;
wire          lddata_ready;
wire          lddata_err;
wire          lddata_exok;
`ifdef CONFIG_MMU
wire          ld_mmu_expt_vld;
wire [  5: 0] ld_mmu_expt_code;
wire          ld_mmu_expt_write;
`endif
wire [ 31: 0] ld_rdata;
wire          ifc_last_exok;       // last store is exok
wire          ifc_ls_cmplt;
wire          ifc_null;

wire          memld_st_dald;   // memld_st_req is device-load
wire          mem_cps_req;     // cache isync pref
wire [ 31: 0] mem_sttag_data;  // store Tag
wire          mem_cc_op_i;
wire          mem_cc_op_d;
wire [  5: 0] mem_cc_op;
wire          mem_cc_fill;
wire          mem_cc_lock;
wire          mem_cc_pref;
wire          de_load_req;     // inst in de-stage is load
wire          de_mald_req;     // memory-attribute load requset to send address
wire          memld_st_req;    // load/store(in mem) requset to send address
wire          memld_st_exc;    // request exclusive access
wire          memld_st_dbgm;   // to dbgm

// wire [31:0] de_mald_vaddr;    //see {idu_lsu_load_attr_bus}
wire [ 31: 0] memld_st_vaddr;  // load (in mem stage, maybe cache) or store address
wire          memld_st_write;
wire [  1: 0] memld_st_size;
wire [ 31: 0] st_wdata;

wire          de_perf_inst_ibus;
wire          de_perf_inst_dbus;
wire          de_perf_inst_sbus;   // sysbus
wire          de_perf_load_stall;  // load to use
wire          de_perf_nop;

// dcc/icc uncached/cached for sysbus access
wire          dcc_uncached_sbus;  // dcc_cached_sbus is not precise, so we don't count it.
wire          icc_cached_sbus;    // icc_cached_sbus is precise as icc_uncached_sbus

// ecc performance count
wire          dcc_all_ecc_err_add1;
wire          dcc_refill_add1;       // cache refill
wire          icc_all_ecc_err_add1;
wire          icc_refill_add1;       // cache refill

// cache ecc
wire          dcc_fatal_in;  // Dcache 2 bit error go to mem-stage, see{CACHE}
wire          find_ccfatal;  // cache 2 bit error is received by mem, see{CACHE}

wire          lsfd_all;  // all data can be forward, see {forward}segement, only valid for cache load

wire          ls_ex_pesudoint;        // see{Exceptions}.mem_ex or pesudo int(see_int_flush)
wire          inst_oth_ex_pesudoint;  // see{Exceptions}.mem_ex or pesudo int(see_int_flush)
wire          mem_ex_pesudoint;       // see{Exceptions}.mem_ex or pesudo int(see_int_flush)
wire          inst_idle;              // see {csr instruction}segement

// the instruction won't be cancelled,because no ex in mem and wb
wire          inst_ls_noex;
wire          inst_oth_noex;  // not load/store/cache/pref/isync
wire          valid_go_wb;

wire          mem_load_wait_back;
wire          load_data_ok_noerr;
wire          mem_load_wait_ok;
wire          mem_cps_ok;
wire          mem_load_ok;

wire          mem_sc_ok;

wire          noex_lsok_go;

wire          csr_csr0_da;        // see csr regs
wire [ 23: 0] csr_csr190_segpa;
wire [ 31: 0] memls_vaddr;        // load/store addr in result
wire [ 31: 0] memls_vaddr_align;  // load/store addr in result
wire [ 31: 0] memls_paddr;        // load/store paddr

// storeq to ahb signals
wire          st_req_req;
wire [ 31: 0] st_req_vaddr;
wire [  1: 0] st_req_size;
wire [ 31: 0] st_req_wdata;

// store in mem
wire          mem_st_cansend;
wire [ 31: 0] mem_st_data;
wire [ 31: 0] mem_st_vaddr;
wire [  2: 0] mem_st_paddr_h3;
wire [  1: 0] mem_st_size;

wire          st_req_3byte;     // the store need to divide to 2 step
wire          st_req_addr_rcv;  // addr has been received
`ifdef CONFIG_MMU
wire          storeq_flush;
wire          mmu_page_mode;
wire          mem_st_retire_ready;
`endif

// SC won't go storeq
wire          mem_st_go_sq;

// storeq_size is 11, means 3bytes_store,need to divide to 2 store
// while addr is 00, the first size is 01
// while addr is 01, the first size is 00
// addr wouldn't be 1x
wire [  1: 0] st_req_size_t;

wire          icc_bypass;     // userdef: cache bypass
wire          dcc_bypass;
wire [ 21: 0] ctrl_taglo_pa;  // see{csr reg}
wire          ctrl_taglo_v;   // see{csr reg}
wire          ctrl_taglo_d;   // see{csr reg}
wire          ctrl_taglo_l;   // see{csr reg}

// cc_op     ICACHE       DCACHE
// 011       I_W_INV      I_W_INV
// 000       I_L_TAG     I_L_TAG
// 001       I_S_TAG     I_S_TAG
// 111       H_W_INV     H_W_INV
// 100        FILL          -
// 010        LOCK         LOCK
wire          storeq_empty;  // storeq is empty, then we can send da-load

// load data is ok, but wb don't allow in ,need register load data
wire [ 31: 0] load_data;  // load final data. see{load store forward}segement

// load to ifc signals
wire [  1: 0] memld_size;
wire          memld_req;   // load(in mem) requset to send address
wire          dals_wait;   // da-load/store(and SC) has sent address,and wait for data back

wire          inst_ldl;  // inst is ldl.w

wire          mem_dald_req;  // device-attribute
wire          mem_mald_req;  // memory-attribute

wire          de_load_back;

// ifc bus
// cache load
wire          mem_nmi;        // see{nmi handle}
wire          de_load_cango;  // SC stall de-load

// sc fail
wire          ctrl_userdef_supexc;  // slave support exclusive access.
wire          ctrl_llbit_keep;      // keep LLbit once when ERTN
wire          ctrl_llbit_wclr;      // csr write to clear ERTN
wire          sc_fail;

wire          llbit_clr;   // if SC exclusive fail, need clear llbit.
wire          llbit_wen;
wire          ertn_write;  // ertn(not debug-mode) will clear llbit

// ertn can't clear llbit.
wire          ertn_clr_llbit;

wire [ 31: 0] ld_paddr;   // load addr
wire [ 31: 0] st_paddr;   // store addr
wire [  3: 0] ld_strobe;
wire [  3: 0] st_strobe;

// addr[1:0]  lswidth   strobe     |   addr[1:0]  lswidth   strobe
//   00        00      0001       |    10        00      0100
//   00        01      0011       |    10        01      1100
//   00        11      0111       |    10        11      xxxx
//   00        10      1111       |    10        10      1111(xxxx)
//   01        00      0010       |    11        00      1000
//   01        01      0011(xxxx) |    11        01      1100(xxxx)
//   01        11      1110       |    11        11      xxxx
//   01        10      1111(xxxx) |    11        10      1111(xxxx)
wire          ld_a;
wire          ld_b;
wire          ld_c;
wire          ld_d;
wire          ld_4b;

wire          st_a;
wire          st_b;
wire          st_c;
wire          st_d;

// fd:forward
wire          lsfd_flag;  // cache load may need forward

wire [  3: 0] st_strobe_final;
wire [  3: 0] fd_strobe;

// ifc and storeq null
wire          ifc_storeq_null;

wire [ 12: 0] ctrl_cause_ip;

wire          debug_stall_nmi;  // see{LJTAG}

wire          nmi_end;
wire          inst_split_2nd;

// rtu_lsu_allowin and no ex_cancel, nmi can go to wb-stage.
wire          nmi_can_go;

wire          debug_ctrl_nocce;  // see{LJTAG}

// mark cache 2bit fatal, cache err need wait ifc/storeq null
// cache err need wait dald complete, also need debug_nocce==1'b0;
wire          ccfatal_cango;
wire          mark_ccerr;
wire          ccerr_wr_csr;

wire [ 12: 0] int_vec;
wire [ 12: 0] ctrl_im;
wire [ 12: 0] ctrl_ip;

// mem will received interrupt
wire          ctrl_ie;

wire          mark_int;

wire          mark_nmi_ccerr_int;

// bus error
wire          ex_dbe;        // data bus error
wire          load_has_err;
`ifdef CONFIG_MMU
wire          ex_mmu;
wire          ex_page;
wire [  5: 0] mmu_expt_code;
`endif

// mem_ex
wire          mem_ex;
wire          ex_ccerr;
wire          ex_interrupt;  // interrupt
wire          ex_general;    // exception except reset, softreset and nmi

// like:dbcl, interrupt in non-debug mode,general non-debug exceptions,
wire          ex_watch;
wire          ex_watch_inst;
`ifdef CONFIG_MMU
wire [  5: 0] mem_statcode;
`else
wire [  4: 0] mem_statcode;
`endif
wire [  1: 0] mem_sub_excode;  // for lisa

// see{LJTAG}
wire          debug_ex;       // see{LJTAG}
wire          debug_mode_ex;

wire          mem_pesudoint;
wire          mem_ex_nodebug;

// for lisa
wire [  2: 0] ctrl_lisa_vs;

// int_vscode
wire [  3: 0] int_vscode;

wire [  6: 0] ctrl_lisa_vscode;  // for norm_ex

wire [ 19: 0] ctrl_eentry;
wire [ 19: 0] ctrl_merrentry;  // for lisa
wire [ 31: 0] mem_ex_entry;


wire          inst_ertn;  // see csr instruction

// ertn,see {exceptions}segement
// inst_csr for lisa
wire          lisa_csr_rdt_cfg;

// write csrr/csr to flush pipeline
wire          inst_stall_fetch;



// control signals

// restart pc
wire [ 31: 0] brpc_or_pc;



// commit

// mem access

// mem perf can go



// cache refill

// ecc 1bit error


// csr wrmask, wrdata, csr_num,

// wire [31:0] csr_csr44 ; //write 1 to csr44[0] to clear TI

// mpu0~3

// debug
wire [ 31: 0] csr_csr300;  // MWPC
wire [ 31: 0] csr_csr301;  // MWPS
wire [ 31: 0] csr_csr380;  // FWPC
wire [ 31: 0] csr_csr500;  // debug

// wire        csr_csr0_da;

// wire        csr_csr90_errpwatchen;
wire          csr_csr90_errmode;

// wire [23:0] csr_csr190_segpa  ;


// rdtime
wire [ 31: 0] rdtime_result;  // csr_count will be 0 if not rdtimeLo&&rdtime_1st

// cpucfg
wire [ 31: 0] cpucfg_result;

// csrrd
wire [ 31: 0] csrrd_result;

// write enable;

// wire csr20_wen  = csr_wen&&csr_num==14'h20 ;
// wire csr21_wen  = csr_wen&&csr_num==14'h21 ;

// wire csr42_wen  = csr_wen&&csr_num==14'h42 ;

// wire csr92_wen  = csr_wen&&csr_num==14'h92 ;




// csr_count will be 0 for rdtimeHi or rdtime_2nd


wire          ctrl_ti;
wire          ctrl_pci;

// mpu0~3






wire [ 31: 0] stallf_pc;        // idu_lsu_follow_pc,so stallf can flush pipeline immediately
wire [ 31: 0] mem_inst_result;  // ertn/load/mdu result

wire          load_data_sel;
wire          sc_data_sel;
wire          mem_inst_result_sel;
wire          sc_data_result;
wire [ 31: 0] load_result;
wire [ 31: 0] ertn_result;          // merrera or era
wire [ 31: 0] dertn_result;         // dera

wire          ertn_sel_err;
`ifdef OPEN132_HAS_LJTAG


// ihb



// debug mode exception

// debug exception set enable

// change csr regs


wire [  3: 0] ihb_triggered;


`endif





// fpu_lsu_bus
wire [`OPEN132_FPU_LSU_BUS_WIDTH-1: 0] fpu_lsu_bus_nc;

`ifdef CONFIG_MMU
`endif

// Instance Parameter Aliases
// x_csr_cpucfg
// x_mmu_mpu_0
// x_mmu_mpu_1
// x_mmu_mpu_2
// x_mmu_mpu_3

// Instance Boundary Alias Mapping
// x_mmu_vaddr_to_paddr

assign lisa_da_v2p         =  csr_csr0_da;
assign lisa_segpa_v2p      =  csr_csr190_segpa;
assign vaddr_h3_v2p        =  memls_vaddr[31:29];
assign memls_paddr[31:29]  =  paddr_h3_v2p;
// x_rtu_expt_entry
assign lisa_vs_expt                   =  ctrl_lisa_vs;
assign lisa_vscode_expt               =  ctrl_lisa_vscode;
assign merrentry_expt                 =  ctrl_merrentry;
assign eentry_expt                    =  ctrl_eentry;
assign ex_debug_expt                  =  debug_ex;
assign ex_general_in_debug_mode_expt  =  debug_mode_ex;
assign ex_srnmi_expt                  =  nmi_end||ex_ccerr;
assign mem_ex_entry                   =  ex_entry_expt;
// CSR state and CSR-owned control logic
csr_regs #(
    .HAS_BTB       (HAS_BTB      ),
    .MDU_TYPE      (MDU_TYPE     ),
    .HAS_ICC       (HAS_ICC      ),
    .ICC_SET_ASSOC (ICC_SET_ASSOC),
    .ICC_WAYSIZE   (ICC_WAYSIZE  ),
    .HAS_DCC       (HAS_DCC      ),
    .DCC_SET_ASSOC (DCC_SET_ASSOC),
    .DCC_WAYSIZE   (DCC_WAYSIZE  ),
    .PERF_CNT_NUM  (PERF_CNT_NUM ),
    .MPU_NUM       (MPU_NUM      )
) x_csr_regs (
     .clk_g                           (clk_g)
    , .clk_ng                          (clk_ng)
    , .clk_count                       (clk_count)
    , .clk_cr                          (clk_cr)
    , .sync_sresetn                    (sync_sresetn)
    , .reset                           (reset)
    , .data_reset                      (data_reset)
    , .prid_revision                   (prid_revision)
    , .cpunum                          (cpunum)
    , .boot_pc                         (boot_pc)
    , .ext_int                         (ext_int)
    , .ex_cancel                       (ex_cancel)
    , .rtu_lsu_commit                  (rtu_lsu_commit)
    , .rtu_lsu_allowin                 (rtu_lsu_allowin)
    , .idu_lsu_fpu_clear_skip          (idu_lsu_fpu_clear_skip)
    , .idu_lsu_follow_pc               (idu_lsu_follow_pc)
    , .csr_cache_ctrl_bus              (csr_cache_ctrl_bus)
`ifdef CONFIG_MMU
    , .csr_mmu_ctrl_bus                (csr_mmu_ctrl_bus)
`endif
    , .csr_ifu_ctrl_bus                (csr_ifu_ctrl_bus)
    , .csr_idu_ctrl_bus                (csr_idu_ctrl_bus)
    , .csr_bpu_ctrl_bus                (csr_bpu_ctrl_bus)
    , .cache_lsu_ecc_fatal_bus         (cache_lsu_ecc_fatal_bus)
`ifdef OPEN132_HAS_LJTAG
    , .clk_slp_en                      (clk_slp_en)
    , .asid                            (asid)
    , .jtag_core_break                 (jtag_core_break)
    , .lsu_clk_breakpoint_enable       (lsu_clk_breakpoint_enable)
    , .lsu_jtag_debug_mode             (lsu_jtag_debug_mode)
    , .lsu_ifu_debug_map_valid         (lsu_ifu_debug_map_valid)
    , .lsu_idu_debug_bus               (lsu_idu_debug_bus)
    , .jtag_idu_ihb_req_bus            (jtag_idu_ihb_req_bus)
    , .idu_jtag_ihb_resp_bus           (idu_jtag_ihb_resp_bus)
`endif
    , .ibus_win                        (ibus_win)
    , .dbus_win                        (dbus_win)
`ifdef GODSON_DEBUG
    , .gs_core_csr0                    (gs_core_csr0)
    , .gs_core_csr1                    (gs_core_csr1)
    , .gs_core_csr4                    (gs_core_csr4)
    , .gs_core_csr5                    (gs_core_csr5)
    , .gs_core_csr6                    (gs_core_csr6)
    , .gs_core_csr7                    (gs_core_csr7)
`endif
    , .sleeping                        (sleeping)
    , .valid                           (valid)
    , .ihb_debug                       (ihb_debug)
    , .ihb_signal                      (ihb_signal)
    , .ex_dbgss                        (ex_dbgss)
    , .inst_lisa                       (inst_lisa)
    , .see_int_flush                   (see_int_flush)
    , .idle_ertn                       (idle_ertn)
    , .ex                              (ex)
    , .lisa_si14                       (lisa_si14)
    , .result                          (result)
    , .pc                              (pc)
    , .llbit                           (llbit)
    , .ld_bdata_stldlr                 (ld_bdata_stldlr)
    , .da_r                            (da_r)
`ifdef CONFIG_MMU
    , .pg_r                            (pg_r)
`endif
    , .era_r                           (era_r)
    , .merrera_r                       (merrera_r)
    , .userdef_supexc                  (userdef_supexc)
    , .debug_mode                      (debug_mode)
    , .mem_nmi_ccerr                   (mem_nmi_ccerr)
    , .ctrl_nowrap                     (ctrl_nowrap)
    , .ctrl_sleep_cg                   (ctrl_sleep_cg)
    , .ctrl_null_cg                    (ctrl_null_cg)
    , .lsu_clk_csr_enable              (lsu_clk_csr_enable)
    , .ex_dbcl                         (ex_dbcl)
    , .fetch_ade                       (fetch_ade)
    , .ex_lserr                        (ex_lserr)
    , .mem_is_ld                       (mem_is_ld)
    , .mem_is_st                       (mem_is_st)
    , .mem_is_ll_valid                 (mem_is_ll_valid)
    , .mdu_is_run                      (mdu_is_run)
    , .mem_valid_go                    (mem_valid_go)
    , .mem_cps_data_ready              (mem_cps_data_ready)
    , .mem_cps_data_rdata              (mem_cps_data_rdata)
    , .lddata_err                      (lddata_err)
    , .lddata_exok                     (lddata_exok)
    , .mem_cc_op                       (mem_cc_op)
    , .de_perf_inst_ibus               (de_perf_inst_ibus)
    , .de_perf_inst_dbus               (de_perf_inst_dbus)
    , .de_perf_inst_sbus               (de_perf_inst_sbus)
    , .de_perf_load_stall              (de_perf_load_stall)
    , .de_perf_nop                     (de_perf_nop)
    , .dcc_uncached_sbus               (dcc_uncached_sbus)
    , .icc_cached_sbus                 (icc_cached_sbus)
    , .dcc_all_ecc_err_add1            (dcc_all_ecc_err_add1)
    , .dcc_refill_add1                 (dcc_refill_add1)
    , .icc_all_ecc_err_add1            (icc_all_ecc_err_add1)
    , .icc_refill_add1                 (icc_refill_add1)
    , .dcc_fatal_in                    (dcc_fatal_in)
    , .find_ccfatal                    (find_ccfatal)
    , .inst_oth_ex_pesudoint           (inst_oth_ex_pesudoint)
    , .mem_ex_pesudoint                (mem_ex_pesudoint)
    , .inst_idle                       (inst_idle)
    , .inst_oth_noex                   (inst_oth_noex)
    , .valid_go_wb                     (valid_go_wb)
    , .mem_load_wait_back              (mem_load_wait_back)
    , .noex_lsok_go                    (noex_lsok_go)
    , .csr_csr0_da                     (csr_csr0_da)
    , .csr_csr190_segpa                (csr_csr190_segpa)
    , .memls_vaddr                     (memls_vaddr)
    , .icc_bypass                      (icc_bypass)
    , .dcc_bypass                      (dcc_bypass)
    , .ctrl_taglo_pa                   (ctrl_taglo_pa)
    , .ctrl_taglo_v                    (ctrl_taglo_v)
    , .ctrl_taglo_d                    (ctrl_taglo_d)
    , .ctrl_taglo_l                    (ctrl_taglo_l)
    , .ctrl_userdef_supexc             (ctrl_userdef_supexc)
    , .ctrl_llbit_keep                 (ctrl_llbit_keep)
    , .ctrl_llbit_wclr                 (ctrl_llbit_wclr)
    , .ertn_write                      (ertn_write)
    , .ifc_storeq_null                 (ifc_storeq_null)
    , .debug_stall_nmi                 (debug_stall_nmi)
    , .nmi_end                         (nmi_end)
    , .inst_split_2nd                  (inst_split_2nd)
    , .debug_ctrl_nocce                (debug_ctrl_nocce)
    , .mark_ccerr                      (mark_ccerr)
    , .ccerr_wr_csr                    (ccerr_wr_csr)
    , .ctrl_im                         (ctrl_im)
    , .ctrl_ip                         (ctrl_ip)
    , .ctrl_ie                         (ctrl_ie)
    , .mark_nmi_ccerr_int              (mark_nmi_ccerr_int)
`ifdef CONFIG_MMU
    , .ex_mmu                          (ex_mmu)
    , .ex_page                         (ex_page)
`endif
    , .mem_ex                          (mem_ex)
    , .ex_general                      (ex_general)
    , .ex_watch_inst                   (ex_watch_inst)
    , .mem_statcode                    (mem_statcode)
    , .mem_sub_excode                  (mem_sub_excode)
    , .debug_ex                        (debug_ex)
    , .debug_mode_ex                   (debug_mode_ex)
    , .mem_pesudoint                   (mem_pesudoint)
    , .ctrl_lisa_vs                    (ctrl_lisa_vs)
    , .ctrl_eentry                     (ctrl_eentry)
    , .ctrl_merrentry                  (ctrl_merrentry)
    , .inst_ertn                       (inst_ertn)
    , .lisa_csr_rdt_cfg                (lisa_csr_rdt_cfg)
    , .inst_stall_fetch                (inst_stall_fetch)
    , .brpc_or_pc                      (brpc_or_pc)
    , .csr_csr500                      (csr_csr500)
    , .csr_csr90_errmode               (csr_csr90_errmode)
    , .rdtime_result                   (rdtime_result)
    , .cpucfg_result                   (cpucfg_result)
    , .csrrd_result                    (csrrd_result)
    , .dertn_result                    (dertn_result)
);

assign nmi_mask  =  core_lsu_nmi && !debug_mode;

//------------------------------------------------------------//
//                      Bus Connections
//------------------------------------------------------------//
//------------------------------------------------------------//
//                     lsu_core_ctrl_bus
//------------------------------------------------------------//

assign lsu_core_ctrl_bus  =  {ctrl_nowrap  ,  // 5:5
                               mem_wakeup   ,  // 4:4
                               ctrl_sleep_cg,  // 3:3
                               ctrl_null_cg ,  // 2:2
                               lsu_clk_csr_enable    ,  // 1:1
                               sleeping  // 0:0
                             };
// End lsu_core_ctrl_bus

//------------------------------------------------------------//
//                          mem_bus
//------------------------------------------------------------//
assign de_validout  =  idu_lsu_inst_valid;

assign ls_sel       =  |ls_cps[8:7];
assign ls           =  ls_cps[8:7];
assign ls_dbgm      =  ls_cps[6  ];
assign lswidth      =  ls_cps[5:4];
assign ll_sc        =  ls_sel & ls_cps[3];
assign lbh          =  ls_sel & ls_cps[2];
assign lbhsign_ldl  =  ls_sel & ls_cps[1];
assign lb_ldr       =  ls_sel & ls_cps[0];

assign sel_cps      =  valid & ~ls_sel;
assign inst_cps[0]  =  sel_cps & ls_cps[0];
assign inst_cps[1]  =  sel_cps & ls_cps[1];
assign cc_op_i      =  sel_cps & ls_cps[2];
assign cc_op[0]     =  sel_cps & ls_cps[3];
assign cc_op[1]     =  sel_cps & ls_cps[4];
assign cc_op[2]     =  sel_cps & ls_cps[5];

`ifdef CONFIG_MMU
// {ex_dbcl,fetch_ade,ex_lserr,excode} = ex_info[8:0];  // need &ex
assign ex_dbcl    =  ex & ex_info[8];
assign fetch_ade  =  ex & ex_info[7];
assign ex_lserr   =  ex & ex_info[6];
assign excode     =  ex_info[5:0];
`else
// {ex_dbcl,fetch_ade,ex_lserr,excode} = ex_info[7:0];  //need &ex
assign ex_dbcl    =  ex & ex_info[7];
assign fetch_ade  =  ex & ex_info[6];
assign ex_lserr   =  ex & ex_info[5];
assign excode     =  ex_info[4:0];
`endif

assign mem_isnot_ld_st    =  ls==2'b00;
assign mem_is_ld          =  ls[1];
assign mem_is_dald        =  ls==2'b10;
assign mem_is_mald        =  ls==2'b11;
assign mem_is_st          =  ls==2'b01;
assign mem_is_ld_valid    =  valid && mem_is_ld;
assign mem_is_mald_valid  =  valid && mem_is_mald && !ex_cancel;
assign mem_is_st_valid    =  valid && mem_is_st;
assign mem_is_cps_valid   =  valid && (inst_cps!=2'b00) && cps_support;
assign mem_is_ll_valid    =  mem_is_ld_valid&&ll_sc;
assign mem_is_sc_valid    =  mem_is_st_valid&&ll_sc;

always @ ( posedge clk_g )
begin
    if(reset) begin
        valid <= 1'b0;
    end
    else if(mem_nmi_ccerr) begin
        valid <= 1'b1;
    end
    else if(ex_cancel) begin
        valid <= 1'b0;
    end
    else if(lsu_idu_allowin) begin
        valid <= de_validout;
    end

    if(data_reset) begin
        {ihb_debug,
         ihb_signal,
         ex_dbgss,
         inst_lisa,
         mdu_inst,
         fpu_inst,
         see_int_flush,  // inst(mdu/fpu) go main because of interrupt
         idle_ertn,
         ex,
         ls_cps_valid,
         ls_cps,
         ex_info,
         lisa_si14,
         dest,
         result,
         nc_3bits,
         order_flag,
         pc          } <= {`OPEN132_IDU_LSU_INST_BUS_WIDTH{1'b0}};
    end
    else if(mem_nmi_ccerr && (ex_cancel||sleeping)) begin
        ex_dbgss   <= idu_lsu_inst_bus[`OPEN132_IDU_LSU_INST_BUS_WIDTH-3];
        order_flag <= idu_lsu_inst_bus[32];  // order_flag is update and send to wb stage in order to ex_cancel
        // mdu correctly, while NMI get return_pc from fetch or de stage
        ex <= 1'b1;
        pc       <= sleeping ? idu_lsu_follow_pc     :
        rtu_lsu_cancel_pc ;
    end
    else if(lsu_idu_allowin&&(de_validout||mem_nmi_ccerr)) begin
        {ihb_debug,
         ihb_signal,
         ex_dbgss,
         inst_lisa,  // csr/rdtime/cpucfg
         mdu_inst,
         fpu_inst,
         see_int_flush,  // inst(mdu/fpu) go main because of interrupt
         idle_ertn,
         ex,
         ls_cps_valid,
         ls_cps,
         ex_info,
         lisa_si14,
         dest,
         result,
         nc_3bits,
         order_flag,
         pc          } <= idu_lsu_inst_bus[`OPEN132_IDU_LSU_INST_BUS_WIDTH-1: 0];
    end

end

// {mem_bus}en

//------------------------------------------------------------//
//                   idu_lsu_load_attr_bus
//------------------------------------------------------------//
assign {de_mald_vaddr,
        de_mald_go,
        de_load      }  =  idu_lsu_load_attr_bus;
// End idu_lsu_load_attr_bus

//------------------------------------------------------------//
//                   idu_lsu_store_data_bus
//------------------------------------------------------------//
assign {de_r1_data,de_store_valid,de_ldl_ldr_valid,de_csr_write}  =  idu_lsu_store_data_bus;
// End idu_lsu_store_data_bus

//------------------------------------------------------------//
//                      exu_lsu_ctrl_bus
//------------------------------------------------------------//
assign {mdu_is_run}  =  exu_lsu_ctrl_bus;
// End exu_lsu_ctrl_bus

//------------------------------------------------------------//
//                      lsu_rtu_inst_bus
//------------------------------------------------------------//

assign lsu_rtu_inst_valid  =  mem_validout;
assign lsu_rtu_inst_bus    =  {mem_stallf,
                                mem_mdu,
                                mem_roll,
                                mem_lbh,
                                mem_lbhsign,
                                mem_lb,
                                mem_ld_rotr_0,
                                mem_ld_rotr_1,
                                mem_ld_rotr_2,
                                mem_ld_rotr_3,
                                mem_dest,
                                mem_result,
                                mem_mdu_flag,
                                mem_pc       };
// End lsu_rtu_inst_bus

//------------------------------------------------------------//
//                    lsu_idu_forward_bus
//------------------------------------------------------------//
assign lsu_idu_forward_valid  =  valid;
assign lsu_idu_forward_bus    =  {mem_nmi_ccerr,  // 73:73
                                   mem_see_int  ,  // 72:72
                                   mem_ls_cmplt ,  // 71:71
                                   lsu_idu_roll  ,  // 70:70
                                   mem_isalu    ,  // 69:69
                                   mem_fd_dest  ,  // 68:64
                                   mem_fd_result,  // 63:32
                                   lsu_idu_pc  // 31:0
                                 };
// End lsu_idu_forward_bus

//------------------------------------------------------------//
//                      lsu_exu_ctrl_bus
//------------------------------------------------------------//
assign lsu_exu_ctrl_bus  =  {mem_valid,
                              mem_flag,
                              mem_wait_mdu};
// End lsu_exu_ctrl_bus

//------------------------------------------------------------//
//                     cache_lsu_resp_bus
//------------------------------------------------------------//
`ifdef CONFIG_MMU
assign { ld_mmu_expt_vld,
         ld_mmu_expt_code,
         ld_mmu_expt_write,
         mem_cps_req_ready,
`else
assign { mem_cps_req_ready,
`endif
         mem_cps_data_ready,
         mem_cps_data_rdata,
         de_mald_req_ready,
         memld_st_req_ready,
         lddata_ready ,
         lddata_err   ,
         lddata_exok  ,
         ld_rdata     ,
         ifc_last_exok,
         ifc_ls_cmplt ,
         ifc_null      }  =  cache_lsu_resp_bus;
// End cache_lsu_resp_bus

//------------------------------------------------------------//
//                     lsu_cache_req_bus
//------------------------------------------------------------//

assign lsu_cache_req_bus  =  {memld_st_dald,
                               mem_cps_req,
                               mem_sttag_data,
                               mem_cc_op_i,
                               mem_cc_op_d,
                               mem_cc_op,
                               mem_cc_fill,
                               mem_cc_lock,
                               mem_cc_pref,
                               de_load_req,
                               de_mald_req,
                               memld_st_req,
                               memld_st_exc,
                               memld_st_dbgm,
                               de_mald_vaddr,
                               memld_st_vaddr,
                               memld_st_write,
                               memld_st_size,
                               st_wdata };
// End lsu_cache_req_bus

//------------------------------------------------------------//
//                      idu_csr_perf_bus
//------------------------------------------------------------//
assign {de_perf_inst_ibus,
        de_perf_inst_dbus,
        de_perf_inst_sbus,
        de_perf_load_stall,
        de_perf_nop       }  =  idu_csr_perf_bus;
// End idu_csr_perf_bus

//------------------------------------------------------------//
//                     cache_csr_perf_bus
//------------------------------------------------------------//
assign {dcc_uncached_sbus   ,
        icc_cached_sbus     ,
        dcc_all_ecc_err_add1,
        dcc_refill_add1     ,
        icc_all_ecc_err_add1,
        icc_refill_add1
       }  =  cache_csr_perf_bus;
// End cache_csr_perf_bus

// End Bus Connections

//------------------------------------------------------------//
//                      Pipeline Control
//------------------------------------------------------------//

assign valid_go_wb    =  valid && rtu_lsu_allowin && !ex_cancel;
assign inst_ls_noex   =  valid_go_wb  & ~ls_ex_pesudoint  & ~mem_nmi_ccerr;
assign inst_oth_noex  =  valid_go_wb  & ~inst_oth_ex_pesudoint & ~mem_nmi_ccerr;

assign mem_load_wait_back  =  mem_ldsc_wait&&lddata_ready;
assign load_data_ok_noerr  =  load_data_ok&&!load_data_err;
assign mem_load_wait_ok    =  !mem_ldsc_wait&&load_data_ok_noerr;
assign mem_cps_ok          =  ~mem_cc_op[4]&mem_cps_req_ready | mem_cc_op[4]&mem_cps_data_ready&~dcc_fatal_in;
assign mem_load_ok         =  mem_load_wait_back&&!lddata_err&&!dcc_fatal_in
                              || mem_load_wait_ok;  // no bus error
assign mem_sc_ok           =  (mem_ldsc_wait&&ifc_ls_cmplt || !llbit&&ll_sc);
`ifdef CONFIG_MMU
assign mmu_page_mode       =  !da_r && pg_r;
assign mem_st_retire_ready =  mmu_page_mode
                               ? st_req_addr_rcv && !st_req_3byte
                               : !storeq_valid;
`endif

assign noex_lsok_go  =  mem_valid_go & rtu_lsu_allowin & ~ls_ex_pesudoint & ~ex_cancel;

assign mem_valid_go     =  (  valid
                           & ~mem_nmi_ccerr
                           & ~inst_idle
                           &(~mem_is_cps_valid | mem_cps_ok)
`ifdef CONFIG_MMU
                           &(~mem_is_st | mem_st_retire_ready&~ll_sc| mem_sc_ok)  // SC
`else
                           &(~mem_is_st | ~storeq_valid&~ll_sc| mem_sc_ok)  // SC
`endif
                           &(~mem_is_ld | mem_load_ok                    )
                             );
assign mem_validout     =  mem_valid_go | mem_ex_pesudoint;
assign lsu_idu_allowin  =  ~valid | (mem_valid_go & rtu_lsu_allowin);
// End Pipeline Control

//------------------------------------------------------------//
//                     Load Store Address
//------------------------------------------------------------//

assign memls_vaddr  =  result & {32{ls_cps_valid}};

assign memls_vaddr_align[31: 2]  =  memls_vaddr[31:2];
// lswidth[1]=1,means load 3bytes or 4bytes,
// the memls_vaddr[1:0] need be 2'b00,memld_size need be 2'b10;
assign memls_vaddr_align[1 : 0]  =  memls_vaddr[1 :0] & {2{~(lswidth[1]&mem_is_ld)}};

mmu_vaddr_to_paddr x_mmu_vaddr_to_paddr (
    .lisa_da    (lisa_da_v2p   ),  // da-mode
    .lisa_segpa (lisa_segpa_v2p),
    .vaddr_h3   (vaddr_h3_v2p  ),
    .paddr_h3   (paddr_h3_v2p  )
);
assign memls_paddr[28:0]  =  memls_vaddr[28:0];
// End Load Store Address

//------------------------------------------------------------//
//                        Store Queue
//------------------------------------------------------------//

// store in mem
assign mem_st_cansend   =  mem_is_st & inst_ls_noex & (~ll_sc | llbit)
                           & ~storeq_valid & ~mem_ldsc_wait;
assign mem_st_data      =  ld_bdata_stldlr;
assign mem_st_vaddr     =  memls_vaddr;
assign mem_st_paddr_h3  =  memls_paddr[31:29];
assign mem_st_size      =  lswidth;
//------------------------------------------------------------//
//                        Storeq Stage
//------------------------------------------------------------//
assign mem_st_go_sq  =  mem_st_cansend && !ll_sc &&(!st_req_addr_rcv||st_req_3byte);
`ifdef CONFIG_MMU
assign storeq_flush  =  ld_mmu_expt_vld && ld_mmu_expt_write;
`endif
always @ ( posedge clk_g )
begin
    if( reset ) begin
`ifdef CONFIG_MMU
        storeq_valid <= 1'b0;
    end
    else if(storeq_flush) begin
`endif
        storeq_valid <= 1'b0;
    end
    else if(mem_st_go_sq) begin
        storeq_valid <= 1'b1;
    end
    else if( st_req_addr_rcv && ~st_req_3byte ) begin
        storeq_valid <= 1'b0;
    end
end
// storeq regs
always @ ( posedge clk_g )
begin
    if(data_reset) begin
        storeq_data        <= 32'd0;
        storeq_dbgm        <= 1'd0;
        storeq_vaddr[31:2] <= 30'd0;
        storeq_paddr_h3    <= 3'd0;
    end
    else if(mem_st_go_sq) begin
        storeq_data        <= mem_st_data  ;
        storeq_dbgm        <= ls_dbgm      ;
        storeq_vaddr[31:2] <= mem_st_vaddr[31:2];
        storeq_paddr_h3    <= mem_st_paddr_h3;
    end

    if(data_reset) begin
        storeq_vaddr[1:0] <= 2'd0;
        storeq_size       <= 2'd0;
    end
    else if( st_req_3byte & st_req_addr_rcv ) begin  // store 3 bytes
        storeq_size       <= storeq_valid ? storeq_vaddr[1:0] : mem_st_vaddr[1:0];
        storeq_vaddr[1:0] <= 2'b10;
    end
    else if(mem_st_go_sq) begin
        storeq_vaddr[1:0] <= mem_st_vaddr[1:0];
        storeq_size       <= mem_st_size;
    end
end

// storeq addr_req received
assign st_req_addr_rcv  =  memld_st_write & memld_st_req_ready;

// no store, or store is finished completely
assign mem_ls_cmplt  =  ~mem_cps_req & ~mem_st_cansend & ~storeq_valid & ifc_ls_cmplt;
// End Storeq Stage

//------------------------------------------------------------//
//                  Store Queue Ahb Signals
//------------------------------------------------------------//
assign st_req_size_t  =  storeq_valid ? storeq_size : mem_st_size;
assign st_req_3byte   =  &st_req_size_t;

assign st_req_vaddr  =  storeq_valid ? storeq_vaddr : mem_st_vaddr;
assign st_req_size   =  st_req_3byte ? {st_req_vaddr[1],~st_req_vaddr[0]} : st_req_size_t;
assign st_req_wdata  =  storeq_valid ? storeq_data : mem_st_data;
assign st_req_req    =  (mem_st_cansend||storeq_valid) && !de_load_wait;
// End Store Queue Ahb Signals
// End Store Queue

//------------------------------------------------------------//
//                     Cache Instruction
//------------------------------------------------------------//
assign mem_cps_req     =  storeq_empty && mem_is_cps_valid && inst_oth_noex;
assign mem_sttag_data  =  {ctrl_taglo_pa,2'd0,ctrl_taglo_v,ctrl_taglo_d,ctrl_taglo_l,5'd0};
assign mem_cc_op[0]    =  inst_cps[0] && cc_op[2]&&!mem_cc_fill;  // hit
assign mem_cc_op[1]    =  inst_cps[0] &&!cc_op[2]&&!mem_cc_lock;  // index
assign mem_cc_op[2]    =  inst_cps[0] && cc_op[1]&&!mem_cc_lock;  // invalid
assign mem_cc_op[3]    =  inst_cps[0] && cc_op[0] && !mem_cc_op[5];  // writback
assign mem_cc_op[4]    =  inst_cps[0] && cc_op==3'b000;  // Load Tag
assign mem_cc_op[5]    =  inst_cps[0] && cc_op==3'b001;  // Store Tag
assign mem_cc_fill     =  inst_cps[0] && cc_op==3'b100;  // icache fill
assign mem_cc_lock     =  inst_cps[0] && cc_op==3'b010;  // fetch and lock
assign mem_cc_pref     =  inst_cps==2'b10;  // inst_pref
assign mem_cc_op_i     =  !icc_bypass &&   cc_op_i              ;
assign mem_cc_op_d     =  !dcc_bypass && (!cc_op_i||inst_cps[1]);  // inst_cache_d or inst_isync

// if NO Cache or Cache bypass, can't support cps_req.
assign cps_support  =  mem_cc_op_i || mem_cc_op_d;
// End Cache Instruction

//------------------------------------------------------------//
//                            Load
//------------------------------------------------------------//

assign inst_ldl  =  ~lbh & lbhsign_ldl;

assign storeq_empty  =  ~storeq_valid;

assign mem_dald_req  =  storeq_empty & mem_is_dald & inst_ls_noex;
assign mem_mald_req  =  mem_is_mald_valid;
assign memld_req     =  (mem_dald_req|mem_mald_req) & ~lsfd_all & ~mem_ldsc_wait & ~load_data_ok;

assign memld_size  =  {lswidth[1],(~lswidth[1] & lswidth[0])};
`ifdef CONFIG_MMU
// Loads and page-mode stores remain the owner of an accepted MMU/Cache request
// until they leave LSU. SC also keeps its side effect and exception atomic.
assign dals_wait  =  valid & (mem_is_ld
                              | mem_is_sc_valid
                              | (mmu_page_mode & mem_is_st));
`else
// uncache load won't set load_data_ok, because when uncache load can send, wb must allowin
// SC also need set it to stall NMI/INT/CCERR
assign dals_wait  =  valid&mem_ldsc_wait&(mem_is_dald | mem_is_sc_valid);
`endif

assign de_load_back  =  lddata_ready&&!mem_ldsc_wait;
`ifdef CONFIG_MMU

// A translation fault completes the Cache request handshake without producing
// load data. Hold it until the RTU accepts the exception.
assign ex_mmu         =  ld_mmu_expt_vld || mmu_expt_vld_r;
assign mmu_expt_code  =  ld_mmu_expt_vld ? ld_mmu_expt_code
                                           : mmu_expt_code_r;

always @ ( posedge clk_g )
begin
    if(reset || ex_cancel) begin
        mmu_expt_vld_r  <= 1'b0;
        mmu_expt_code_r <= 6'd0;
    end
    else if(ex_mmu && rtu_lsu_allowin) begin
        mmu_expt_vld_r <= 1'b0;
    end
    else if(ld_mmu_expt_vld) begin
        mmu_expt_vld_r  <= 1'b1;
        mmu_expt_code_r <= ld_mmu_expt_code;
    end
end

`endif
always @ ( posedge clk_g )
begin
    if(reset || ex_cancel) begin
        mem_ldsc_wait <= 1'b0;
    end
    else if( lsu_idu_allowin ) begin
        mem_ldsc_wait <= de_validout && ( de_mald_req && de_mald_req_ready
                                        ||de_load_wait&&!de_load_back );
    end
`ifdef CONFIG_MMU
    else if((memld_req || mem_st_cansend) && memld_st_req_ready
            && !ld_mmu_expt_vld) begin
`else
    else if( (memld_req||mem_st_cansend) && memld_st_req_ready ) begin
`endif
        mem_ldsc_wait <= 1'b1;
    end
`ifdef CONFIG_MMU
    else if(lddata_ready && !mem_is_sc_valid) begin
`else
    else if(lddata_ready) begin  // SC no need clear mem_ldsc_wait
`endif
        mem_ldsc_wait <= 1'b0;
    end

    if(reset || ex_cancel) begin
        de_load_wait <= 1'b0;
    end
    else if( lsu_idu_allowin && de_validout ) begin
        de_load_wait <= 1'b0;
    end
    else if( de_mald_req && de_mald_req_ready ) begin
        de_load_wait <= 1'b1;
    end
    else if(de_load_back) begin
        de_load_wait <= 1'b0;
    end
end

// load data ok
always @ ( posedge clk_g )
begin
    if(reset || ex_cancel) begin
        load_data_ok <= 1'b0;
    end
    else if(mem_valid_go && rtu_lsu_allowin) begin
        load_data_ok <= 1'b0;
    end
    else if( mem_is_ld_valid && (lsfd_all || mem_load_wait_back) ) begin
        load_data_ok <= 1'b1;
    end

    if( mem_is_ld_valid && (lsfd_all || mem_load_wait_back) ) begin
        load_data_err <= !lsfd_all && lddata_err;
    end
end
always @ ( posedge clk_g )
begin
    if(data_reset) begin
        ld_bdata_stldlr <= 32'd0;
    end
    else if(lsu_idu_allowin && (de_ldl_ldr_valid||de_store_valid||de_csr_write)) begin
        ld_bdata_stldlr <= de_r1_data;  // include csr write value
    end
    else if( mem_is_ld_valid && !load_data_ok && !lsu_idu_allowin) begin
        if(lsfd_all || mem_load_wait_back) begin
            ld_bdata_stldlr <= load_data;  // register the load data
        end
    end
end
// load data

assign de_load_cango  =  !(mem_is_st_valid&&(storeq_valid||ll_sc)       ) &&
                           (!mem_is_ld_valid||mem_ldsc_wait||load_data_ok ) &&
                           !mem_is_cps_valid && !de_load_wait              &&
                           !find_ccfatal && !mem_nmi;  // nmi ccfatal stall load

assign de_load_req  =  de_load    && de_load_cango;
assign de_mald_req  =  de_mald_go && de_load_cango;

assign memld_st_req    =  (memld_req|st_req_req);
assign memld_st_dbgm   =  (memld_req||!storeq_valid) ? ls_dbgm : storeq_dbgm;
assign memld_st_exc    =  ll_sc;
assign memld_st_vaddr  =  (memld_req||mem_cps_req||!storeq_valid) ? memls_vaddr_align : storeq_vaddr;
assign memld_st_write  =  ~memld_req & st_req_req;
assign memld_st_size   =  memld_req ? memld_size : st_req_size;
assign st_wdata        =  st_req_wdata;  // set at same time with st_req_vaddr!

assign memld_st_dald  =  mem_dald_req;
// End Load

//------------------------------------------------------------//
//                           ll_bit
//------------------------------------------------------------//
assign sc_fail  =  ctrl_userdef_supexc && !ifc_last_exok;

assign llbit_clr       =  mem_is_sc_valid & mem_sc_ok & sc_fail;
assign llbit_wen       =  mem_is_ll_valid & noex_lsok_go;
assign ertn_clr_llbit  =  ertn_write&&!ctrl_llbit_keep&&!(debug_mode);
always @ ( posedge clk_g )
begin
    if(reset) begin
        llbit <= 1'b0;
    end
    else if(llbit_wen) begin
        llbit <= 1'b1;
    end
    else if( ertn_clr_llbit || llbit_clr || ctrl_llbit_wclr) begin
        llbit <= 1'b0;
    end
end
// End ll_bit

//------------------------------------------------------------//
//                     Load Store Forward
//------------------------------------------------------------//

assign ld_paddr  =  memls_paddr;
assign st_paddr  =  {storeq_paddr_h3,storeq_vaddr[28:0]};

assign ld_a          =  ld_paddr[1];
assign ld_b          =  ld_paddr[0];
assign ld_c          =  lswidth[1];
assign ld_d          =  lswidth[0];
assign ld_4b         =  lswidth==2'b10;
assign ld_strobe[0]  =  ~ld_a & (~ld_b|(lswidth==2'b01)) | ld_4b;
assign ld_strobe[1]  =  ~ld_a & (ld_b|ld_c|ld_d) | ld_4b;
assign ld_strobe[2]  =  (ld_a&(~ld_b|ld_d)) | ld_c;
assign ld_strobe[3]  =  ld_a&(ld_b|ld_d) | ld_c&(ld_b|~ld_d);

assign st_a          =  st_paddr[1];
assign st_b          =  st_paddr[0];
assign st_c          =  storeq_size[1];
assign st_d          =  storeq_size[0];
assign st_strobe[0]  =  ~(st_a | st_b);
assign st_strobe[1]  =  ~st_a & (st_b|st_c|st_d);
assign st_strobe[2]  =  (st_a&~st_b) | st_c | (st_b&st_d);
assign st_strobe[3]  =  st_a&(st_b|st_d) | st_c&(st_b|~st_d);

assign st_strobe_final  =  lsfd_part_r ? st_strobe_r : st_strobe;
assign fd_strobe        =  ld_strobe & st_strobe_final & {4{lsfd_flag | lsfd_part_r}};
assign lsfd_flag        =  (ld_paddr[31:2] == st_paddr[31:2]) & storeq_valid & mem_is_mald;  // only valid for cache load
assign lsfd_all         =  (fd_strobe == ld_strobe) & lsfd_flag;
always @ ( posedge clk_g )
begin
    if(lsu_idu_allowin) begin
        lsfd_part_r <= 1'b0;
    end
    else if(lsfd_flag & ~lsfd_all) begin
        lsfd_part_r <= 1'b1;
    end

    if(data_reset) begin
        st_strobe_r <= 4'd0;
    end
    else if(lsfd_flag & ~lsfd_part_r) begin
        st_strobe_r <= st_strobe;
    end
end
assign load_data[31:24]  =  ld_strobe[3] ? (fd_strobe[3] ? storeq_data[31:24] :ld_rdata[31:24]) :
                              ld_bdata_stldlr[31:24];
assign load_data[23:16]  =  ld_strobe[2] ? (fd_strobe[2] ? storeq_data[23:16] :ld_rdata[23:16]) :
                              ld_bdata_stldlr[23:16];
assign load_data[15: 8]  =  ld_strobe[1] ? (fd_strobe[1] ? storeq_data[15: 8] :ld_rdata[15: 8]) :
                              ld_bdata_stldlr[15: 8];
assign load_data[ 7: 0]  =  ld_strobe[0] ? (fd_strobe[0] ? storeq_data[ 7: 0] :ld_rdata[ 7: 0]) :
                              ld_bdata_stldlr[ 7: 0];
// End Load Store Forward

//------------------------------------------------------------//
//                         Exceptions
//------------------------------------------------------------//
assign ifc_storeq_null  =  ifc_null && !storeq_valid;

//------------------------------------------------------------//
//                         Nmi Handle
//------------------------------------------------------------//

assign nmi_can_go  =  valid_go_wb && !debug_stall_nmi
                      && ifc_storeq_null && !dals_wait && !inst_split_2nd;
always @ ( posedge clk_g )
begin
    if(reset) begin
        nmi_mask_r <= 1'b0;
    end
    else if(nmi_mask) begin
        nmi_mask_r <= 1'b1;
    end
    else if(nmi_can_go) begin
        nmi_mask_r <= 1'b0;
    end
end
assign nmi_end  =  ~nmi_mask &  nmi_mask_r & nmi_can_go;
assign mem_nmi  =  (nmi_mask | nmi_mask_r) & ~debug_mode;
// End Nmi Handle

assign ccfatal_cango  =  find_ccfatal&&!dals_wait&&!debug_ctrl_nocce && !inst_split_2nd;
assign mark_ccerr     =  valid_go_wb
                         & ccfatal_cango
                         & ~mem_nmi & ifc_storeq_null;  // no need ex_cancel
assign ccerr_wr_csr   =  mark_ccerr&&!debug_mode;

//------------------------------------------------------------//
//                         Interrupts
//------------------------------------------------------------//
assign int_vec  =  ctrl_im & ctrl_ip;

assign mem_see_int  =  (|int_vec)&ctrl_ie&~debug_mode;

assign mark_int  =  valid_go_wb & ~dals_wait & mem_see_int & ~inst_split_2nd;
// End Interrupts

// nmi, ccfatal, int
assign mem_nmi_ccerr       =  mem_nmi&&!dals_wait&&!inst_split_2nd || ccfatal_cango;
assign mark_nmi_ccerr_int  =  mem_nmi_ccerr || mark_int;
assign mem_wakeup          =  mark_nmi_ccerr_int;

assign load_has_err  =  load_data_ok ? load_data_err
                        : mem_load_wait_back&&lddata_err;
assign ex_dbe        =  mem_is_ld && load_has_err;

assign ex_ccerr      =  mark_ccerr;
assign ex_interrupt  =  mark_int;
assign ex_watch      =  ex_watch_inst ;
`ifdef CONFIG_MMU
assign ex_page       =  ex && (excode == 6'd1 || excode == 6'd2
                               || excode == 6'd3 || excode == 6'd4
                               || excode == 6'd7 || excode == 6'h3f);
`endif
assign ex_general    =  ~mem_nmi_ccerr & ( mark_int | (ex&valid)
                        | ex_watch
`ifdef CONFIG_MMU
                        | ex_dbe
                        | ex_mmu              );
`else
                        | ex_dbe              );
`endif

//------------------------------------------------------------//
//                      Debug Exception
//------------------------------------------------------------//
assign debug_mode_ex  =  (ex_ccerr || ex_general) && debug_mode;
// End Debug Exception

`ifdef CONFIG_MMU
assign mem_statcode    =  mark_ccerr    ? 6'h0e :  // dm-ccerr need excode to 6'h0e
                            mark_int      ? 6'h00 :
                            ex_watch_inst ? 6'h13 :
                            ex_mmu        ? mmu_expt_code :
                            ex            ? excode : 6'h1a;  // 0x1a for OPEN132 bus-error
`else
assign mem_statcode    =  mark_ccerr   ? 5'he :  // dm-ccerr need excode to 5'he
                            mark_int     ? 5'h0 :
                            ex_watch_inst? 5'h13:
                            ex           ? excode : 5'h1a ;  // 0x1a for OPEN132 bus-error
`endif
assign mem_sub_excode  =  mark_ccerr||mark_int ? 2'd0 :
`ifdef CONFIG_MMU
                            ex_mmu               ? 2'd0 :
`endif
                            ex                   ? lisa_si14[1:0]:
                            ex_watch             ? 1'b0 :
                            ex_dbe               ? 2'd1 : 2'd0;

assign mem_pesudoint          =  see_int_flush&&valid&&!mem_nmi_ccerr;
assign mem_ex_nodebug         =  nmi_end || ex_ccerr || ex_general;
assign mem_ex                 =  mem_ex_nodebug || debug_ex;
assign mem_ex_pesudoint       =  mem_ex|| mem_pesudoint;
assign ls_ex_pesudoint        =  mem_ex_pesudoint;
assign inst_oth_ex_pesudoint  =  mem_ex_nodebug || debug_ex || mem_pesudoint;

//------------------------------------------------------------//
//                        Exception Pc
//------------------------------------------------------------//
assign int_vscode        =  int_vec[12] ? 4'd12 :
                              int_vec[11] ? 4'd11 :
                              int_vec[10] ? 4'd10 :
                              int_vec[ 9] ? 4'd9  :
                              int_vec[ 8] ? 4'd8  :
                              int_vec[ 7] ? 4'd7  :
                              int_vec[ 6] ? 4'd6  :
                              int_vec[ 5] ? 4'd5  :
                              int_vec[ 4] ? 4'd4  :
                              int_vec[ 3] ? 4'd3  :
                              int_vec[ 2] ? 4'd2  :
                              int_vec[ 1] ? 4'd1  : 4'd0;
`ifdef CONFIG_MMU
assign ctrl_lisa_vscode  =  mark_int ? (7'h40 | int_vscode) :
                              ex_watch ? 7'h13 : {1'b0, mem_statcode};
`else
assign ctrl_lisa_vscode  =  mark_int     ? (7'h40 | int_vscode) :
                              ex_watch     ?  7'h13 :
                              ex           ? {2'd0, excode}
                            :  7'h1a ;  // 0x1a for lisa bus-error
`endif

rtu_expt_entry x_rtu_expt_entry (
    .lisa_vs                  (lisa_vs_expt                 ),
    .lisa_vscode              (lisa_vscode_expt             ),
    .merrentry                (merrentry_expt               ),
    .eentry                   (eentry_expt                  ),
    .ex_debug                 (ex_debug_expt                ),
    .ex_general_in_debug_mode (ex_general_in_debug_mode_expt),
    // lisa machine check: NMI, CacheErr
    .ex_srnmi                 (ex_srnmi_expt                ),
    .ex_entry                 (ex_entry_expt                )
);
// End Exception Pc
// End Exceptions

//------------------------------------------------------------//

//------------------------------------------------------------//
//                  lsu_rtu_inst_bus Signals
//------------------------------------------------------------//
// wire [3:0] ldl_ldr_strobe;
assign mem_lbh       =  lbh;  // lb/lbu/lh/lhu
assign mem_lbhsign   =  lbhsign_ldl & lbh;  // lb/lh
assign mem_lb        =  lb_ldr & lbh;  // lb/lbu
assign mem_dest      =  dest;
assign mem_mdu_flag  =  order_flag;
assign mem_roll      =  mem_ex_pesudoint || inst_ertn;
assign mem_stallf    =  inst_stall_fetch;
assign mem_mdu       =  mdu_inst;

assign mem_pc  =  pc;
//              lswidth  ld_strobe      need rotr
// ldl(1byte)      00       0001           1byte
// ldl(2bytes)     01       0011           2bytes
// ldl(3bytes)     11       0111           3bytes
// ldl(4bytes)     10       1111             -
// ldr(1byte)      00       1000           3bytes
// ldr(2bytes)     01       1100           2bytes
// ldr(3bytes)     11       1110           1byte
// ldr(4bytes)     10       1111             -
//     lb          00       0001             -
//     lb          00       0010           1byte
//     lb          00       0100           2bytes
//     lb          00       1000           3bytes
//     lh          10       0011             -
//     lh          10       1100           2bytes
// for lb/lbu/lh/lhu, keep ld_strobe to wb_stage,so wb_stage can use it to generate lbh_sign
assign mem_ld_rotr_0  =  ~mem_ld_rotr_1 & ~mem_ld_rotr_2 & ~mem_ld_rotr_3;
assign mem_ld_rotr_1  =  ( inst_ldl    & lswidth==2'b00)
                         |( lb_ldr      & ld_strobe[1:0]==2'b10) ;
assign mem_ld_rotr_2  =  ( inst_ldl    & lswidth==2'b01)
                         |((lb_ldr|lbh) & ld_strobe[2:1]==2'b10);
assign mem_ld_rotr_3  =  ( inst_ldl    & lswidth==2'b11)
                         |( lb_ldr      & ld_strobe[3:2]==2'b10);
//------------------------------------------------------------//
//                     Select mem_result
//------------------------------------------------------------//

assign sc_data_sel          =  mem_is_sc_valid;
assign load_data_sel        =  mem_is_ld & ~load_data_ok;  // load_data_ok means select result
assign mem_inst_result_sel  =  inst_ertn | load_data_sel | sc_data_sel
                               |load_data_ok
                               |lisa_csr_rdt_cfg;
assign sc_data_result       =  llbit && !sc_fail;
assign load_result          =  load_data;

assign ertn_sel_err  =  csr_csr90_errmode;
// csrr_merrera==csr_csr94, csrr_era==csr_csr6
assign ertn_result  =  debug_mode ? dertn_result  :
                         ertn_sel_err  ? merrera_r : era_r;

assign mem_inst_result  =  (  {32{inst_ertn      }} &  ertn_result    )
                           |(  {32{load_data_sel  }} &  load_result    )
                           |(                           rdtime_result  )  //=0,if rdtime==0
                           |(                           cpucfg_result  )  //=0,if cpucfg==0
                           |(                           csrrd_result   )  //=0,if csrrd==0
                           |(  {32{load_data_ok   }} &  ld_bdata_stldlr)
                           |{   31'd0,   (sc_data_sel & sc_data_result)};  // sc_result
assign stallf_pc        =  idu_lsu_follow_pc;
// while ertn is valid, the roll pc is stored in result.
assign mem_result  =  mem_ex                       ? mem_ex_entry    :
                        see_int_flush                ? brpc_or_pc      :  // pesudo int
                        mem_inst_result_sel          ? mem_inst_result : result;
// inst(mdu go mem because of mem_see_int or debug_int,
// but after it arrived mem, there no mem/debug_int,
// it also need flush pipeline using its pc or branch_pc.
// End Select mem_result
// End lsu_rtu_inst_bus Signals

//------------------------------------------------------------//
//                lsu_idu_forward_bus Signals
//------------------------------------------------------------//
assign lsu_idu_roll  =  mem_roll&&mem_valid;

assign mem_isalu      =  ~mdu_inst & ~idle_ertn & mem_isnot_ld_st & ~lisa_csr_rdt_cfg;
assign mem_fd_result  =  result;

assign mem_fd_dest  =  dest;
assign lsu_idu_pc   =  pc;
// End lsu_idu_forward_bus Signals

//------------------------------------------------------------//
//                  lsu_exu_ctrl_bus Signals
//------------------------------------------------------------//
assign mem_valid     =  valid;
assign mem_flag      =  order_flag;
assign mem_wait_mdu  =  1'b0;
// End lsu_exu_ctrl_bus Signals

//------------------------------------------------------------//

//------------------------------------------------------------//

//------------------------------------------------------------//
//                            FPU
//------------------------------------------------------------//
assign fpu_lsu_bus_nc  =  fpu_lsu_bus;
// mem2fpu bus
assign lsu_fpu_bus  =  {`OPEN132_LSU_FPU_BUS_WIDTH{1'b0}};

// mem->de: main or mdu is running
assign lsu_idu_mdu_busy  =  mdu_is_run || mem_valid || !rtu_lsu_allowin;
// End FPU
//------------------------------------------------------------//
//                 Application-Specific Logic
//------------------------------------------------------------//
always @ ( posedge clk_g )
begin
    if(data_reset) begin
        idu_lsu_app_bus_r <= {`OPEN132_IDU_LSU_APP_BUS_WIDTH{1'b0}};
    end
    else if(lsu_idu_allowin&&(de_validout||mem_nmi_ccerr)) begin
        idu_lsu_app_bus_r <= idu_lsu_app_bus;
    end
end

`ifndef OPEN132_APP_SPEC
assign lsu_rtu_app_bus  =  {`OPEN132_LSU_RTU_APP_BUS_WIDTH{1'b0}};
`endif
// End Application-Specific Logic

// assert
`ifdef OPEN132_ASSERT
assert property (
    @(posedge clk_ng)
    (mem_is_dald&&!ex_dbe) |-> !load_data_ok
    )
else begin $display("Assert Error!!!"); #2 $finish; end
assert property (
    @(posedge clk_ng)
    (ex_cancel||mem_ex) |-> !(mem_dald_req&&!mem_ldsc_wait)
    )
else begin $display("Assert Error!!!"); #2 $finish; end
assert property (
    @(posedge clk_ng)
    (valid&&ll_sc&&!mem_nmi_ccerr) |-> !storeq_valid
    )
else begin $display("Assert Error!!!"); #2 $finish; end
assert property (
    @(posedge clk_ng)
`ifdef CONFIG_MMU
    dals_wait |-> !(mark_int || mem_nmi_ccerr)
`else
    dals_wait |-> !(mem_ex&&!(ex_general&&ex_dbe))
`endif
    )
else begin $display("Assert Error!!!"); #2 $finish; end

// merrera
assert property ( sleeping_pc)
else begin $display("Assert Error!!!"); #2 $finish; end
property sleeping_pc;
@(posedge clk_ng)  // no single-step mode
($fell(sleeping)&&!csr_csr500[0]&& $past(mem_nmi_ccerr,1)==1'b1, as_pre_pc=$past(pc,1))
        |-> ##[0:$] mem_validout |-> ##1 merrera_r!==as_pre_pc;
endproperty

`endif  // OPEN132_ASSERT
endmodule

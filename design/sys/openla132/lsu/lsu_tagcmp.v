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

module lsu_tagcmp #(
    parameter AXI_DATA    = 32,       // 32/64/128
    parameter AXI_STRB    = 4,        // axi32: 4
    parameter AXI_ALIGN_N = 2,        // axi32: 2
    parameter AXI_DIV_32  = 1,        // axi32: 1
    parameter CC_LINE_AXI = 8,        // axi32: 8

    // cache configuration
    // Cache size in KB: SET_ASSC*WAYSIZE
    parameter SET_ASSOC   = 4,        // 1/2/4 way set associative
    // parameter WAYSIZE    = 8*(2**10), //1/2/4/8/16 KB Size/way
    parameter BANK_WD     = 32*4,     // for 4way
    parameter SET_BITS    = 2,        // for 4way
    parameter INDEX_BITS  = 5,        // for waysize 1K
    parameter TAG_BITS    = 22,       // for waysize 1K
    parameter TAGV_BITS   = 22+2,     // for waysize 1K
    parameter RAM_TAGV_WD = (22+2)*4  // for waysize 1K * 4 ways
) (
    input  wire                     has_ecc,
    // clk and reset
    input  wire                     clk,
    input  wire                     reset,
    input  wire                     data_reset,
    input  wire                     ex_cancel,
    input  wire                     bypass,  // has cache, but no access to cache
    input  wire                     ctrl_nowrap,  // axi no wrap

    input  wire                     real_req,  // load/store req(predict right and no stall), or cache/pref/sync req
    input  wire                     ls_req_nocps,
    input  wire [           31: 0]  req_wdata,
    input  wire                     req_rd,  // request is read
    input  wire                     req_exc,  // request exclusive access
    input  wire [            1: 0]  size,  // request size
`ifdef CONFIG_MMU
    input  wire [           31: 0]  vaddr,  // request virtual address
`else
    input  wire [            2: 0]  vaddr_h3,  // request vaddr[31:29]
`endif
    input  wire [           31: 0]  paddr,  // request paddr
`ifdef CONFIG_MMU
    input  wire                     req_xlat_wait,
    input  wire                     req_attr_vld,
    input  wire                     req_sob,
    input  wire                     req_cached,
    input  wire                     req_alloc,
    input  wire                     xlat_vld,
    input  wire                     xlat_cancel,
    input  wire [           31: 0]  xlat_paddr,
    input  wire                     xlat_sob,
    input  wire                     xlat_cached,
    input  wire                     xlat_alloc,
`endif
    input  wire [            5: 0]  cc_op,  // cache/isync op
    input  wire                     cc_isync,
    input  wire                     cc_pref,  // pref
    input  wire                     cc_lock,  // lock

    input  wire                     axi_ar_ok,

    // to mmu
    output wire [           31: 0]  go_mmu_vaddr,
    output wire                     go_mmu_read,
    output wire                     go_mmu_dbgm,
    // from mmu
    input  wire                     mmu_sob,  // strong older back: wait previous mem-access complete
    input  wire                     mmu_cached,  // request is cached
    //  input         ucacc     , //request: uncache accelerate
    input  wire                     mmu_alloc,  // request: alloc if miss

    // CACHE RAM
    input  wire [RAM_TAGV_WD-1: 0]  cache_ram_tagcmp_tagv_rdata,
    output wire [            2: 0]  tagcmp_cache_ram_bank_sel,
    input  wire [    BANK_WD-1: 0]  cache_ram_tagcmp_bank_rdata,  // one bank
    input  wire                     cache_ram_tagcmp_tagv_err,  // ecc 1 or 2 bits error
    input  wire                     cache_ram_tagcmp_bank_err,

    // wrbuf
    input  wire [  SET_ASSOC-1: 0]  wrbuf_tagcmp_way,
    input  wire                     wrbuf_tagcmp_wr,
    input  wire                     wrbuf_tagcmp_ecc_fatal,
    input  wire                     wrbuf_tagcmp_hit_bank,  // wrbuf {index,bank} hit tagcmp
    input  wire [            3: 0]  wrbuf_tagcmp_strb,
    input  wire [           31: 0]  wrbuf_tagcmp_wdata,
    input  wire                     wrbuf_tagcmp_new_valid,  // for ecc correct
    input  wire [RAM_TAGV_WD-1: 0]  wrbuf_tagcmp_new_tagv,
    input  wire [    BANK_WD-1: 0]  wrbuf_tagcmp_new_bank,  // one bank
    // from missq
    input  wire                     missq_tagcmp_allowin,
    input  wire                     missq_tagcmp_ar_stall,  // ar addr hit axi-b-queue
    input  wire                     missq_tagcmp_bq_null,  // axi-b-queue is null
    input  wire                     missq_tagcmp_bq_full,  // axi-b-queue is full
    input  wire                     missq_tagcmp_valid,
    input  wire                     missq_tagcmp_bacs,
    input  wire                     missq_tagcmp_wait_wr,
    input  wire [           31: 5]  missq_tagcmp_addr_31_5,
    input  wire [CC_LINE_AXI-1: 0]  missq_tagcmp_buf_valid,
    input  wire [          255: 0]  missq_tagcmp_buf_data,
    input  wire                     req2dbgm,
    output wire                     dbgm_req_valid,
    output wire                     dbgm_req_wr,
    output wire [           31: 0]  dbgm_req_addr,
    output wire [            1: 0]  dbgm_req_size,
    output wire [           31: 0]  dbgm_req_wdata,
    input  wire                     dbgm_resp_valid,
    input  wire [           31: 0]  dbgm_resp_data,
    // to axi
    output wire                     axi_arvalid,
    output wire                     axi_arburst,
    output wire                     axi_arexc,
    output wire                     axi_arcache,
    output wire [            2: 0]  axi_arsize,
    output wire [           31: 0]  axi_araddr,
    input  wire                     axi_rvalid,  // for uncache
    input  wire [   AXI_DATA-1: 0]  axi_rdata,
    input  wire [            1: 0]  axi_rresp,  // read response
    // to wrbuf
    output wire                     tagcmp_wrbuf_ls_valid,
    output wire                     tagcmp_wrbuf_ecc_err,
    output wire [  SET_ASSOC-1: 0]  tagcmp_wrbuf_hit_way,
    output wire                     tagcmp_wrbuf_wr,
    output wire [            2: 0]  tagcmp_wrbuf_bank_sel,
    output wire [            3: 0]  tagcmp_wrbuf_strb,
    output wire [ INDEX_BITS-1: 0]  tagcmp_wrbuf_indx,
    output wire [           31: 0]  tagcmp_wrbuf_wdata,
    output wire [  SET_ASSOC-1: 0]  tagcmp_wrbuf_way_lock,
    output wire                     tagcmp_wrbuf_lru_wen,
    // to missq
    output wire                     tc_hit_mq,
    output wire                     tc_st_hit_mq_ok,
    output wire [CC_LINE_AXI-1: 0]  tc_st_hit_mq_sel,  // need see tc_st_hit_mq_ok
    output wire [   AXI_STRB-1: 0]  tc_st_hit_mq_wstrb,
    output wire [   AXI_DATA-1: 0]  tc_st_hit_mq_wdata,
    output wire                     tc_need_tagv,  // need see tagv ram
    output wire                     tc_need_data,  // need see data ram
    output wire                     tagcmp_missq_valid,  // tc_valid
    output wire                     tagcmp_missq_aw_do,  // go mq to send aw
    output wire                     tagcmp_missq_bacs,
    output wire                     tagcmp_missq_exc,  // exclusive
    output wire                     tagcmp_missq_cached,
    output wire [           26: 0]  tagcmp_missq_araddr31_5,  // check read/write conflict
    output wire [           31: 0]  tagcmp_missq_addr,
    output wire [   AXI_STRB-1: 0]  tagcmp_missq_strb,
    output wire [            1: 0]  tagcmp_missq_size,
    output wire                     tagcmp_missq_pref,
    output wire                     tagcmp_missq_lock,
    output wire                     tagcmp_missq_ccop_do,
    output wire                     tagcmp_missq_lock_exist,
    output wire                     tagcmp_missq_ccop_valid,
    output wire                     tagcmp_missq_ccop_inv,
    output wire                     tagcmp_missq_ccop_sttag,
    output wire                     tagcmp_missq_ccop_ldtag,
    output wire                     tagcmp_missq_ccop_wb,
    output wire                     tagcmp_missq_sttag_v,
    output wire                     tagcmp_missq_sttag_d,
    output wire                     tagcmp_missq_sttag_l,
    // read data to pipeline
    output wire                     tc_rdata_valid,
    output wire [           31: 0]  tc_rdata,
    output wire                     tc_rdata_exok,  // rdata is exokay
    output wire                     tc_rdata_err,  // rdata is error
    // pipeline control
    output wire                     tc_allow_refill,
    output wire                     tc_idle,
    output wire                     tc_stall_ram_en,  // for low power
    output wire                     tc_allowin,
    output wire                     rd_in_tc,
    output wire                     wr_in_tc
);

localparam M_DEC0 = 8;

localparam TC_IDLE       = 2'b00;
localparam TC_CMP        = 2'b01;
localparam TC_WAIT_MQ_AR = 2'b11;  // wait for ar_ok or missq_tagcmp_allowin
localparam TC_MQ_INV     = 2'b10;  // hit mq but mq data is invalid

genvar i, j;

//============================================================//
//                     Regs Declarations
//============================================================//

// register cc_req
`ifdef CONFIG_MMU
reg [ 31: 0] tc_vaddr;
`else
reg [  2: 0] tc_vaddr_h3;
`endif
reg [ 31: 0] tc_addr;      // paddr
reg          tc_exc;
reg [  1: 0] tc_size;
reg          tc_dbgm;
reg          tc_rd;
reg [ 31: 0] tc_wdata;
`ifdef CONFIG_MMU
reg          tc_xlat_wait;
reg          tc_attr_vld;
reg          tc_sob_r;
reg          tc_cached_r;
reg          tc_alloc_r;
`endif

// cache/isync/pref
reg [  5: 0] tc_ccop;
reg          tc_isync;  // isync, only valid if cc_op is hit_wb_inv
reg          tc_pref;   // pref instruction or ex_cancel will set it
reg          tc_lock;   // if locked way is in cache, tc_lock like ccop to write lock bit

reg [  1: 0] tc_next_state;
reg [  1: 0] tc_state;

//============================================================//
//                     Wire Declarations
//============================================================//

wire [$clog2(M_DEC0)-1: 0] decode_index_dec0;
wire [        M_DEC0-1: 0] decode_onehot_dec0;

// axi burst size
wire [  2: 0] axi_burst_size;

// if locked way is not in cache, tc_lock like pref to fetch locked way
wire          tc_ccop_hit;    // tc_ccop
wire          tc_ccop_indx;
wire          tc_ccop_inv;
wire          tc_ccop_wb;
wire          tc_ccop_sttag;
wire          tc_ccop_ldtag;
wire          tc_ccop_valid;

wire          tc_sob;
wire          tc_cached;

// for fetch-lock/pref, need be alloc
wire          tc_alloc;
wire          tc_bacs;   // burst access

// has cache and no cache-bypass, need look-up cache
wire          see_cache;
wire          see_mq;     // see_cache |-> see_mq
wire          see_axi;

wire          tc_wr;
wire [  3: 0] tc_strb;

// tc_aw need go to missq to send aw/w
// tc_ar need send ar in tagcmp
wire          tc_aw;     // write through, for uncached store or cached miss-no-alloct
wire          tc_ar;     // cache line requst, uncached/non-alloct load, pref
wire          tc_aw_do;
wire          tc_ar_do;

// cache op
wire [ SET_BITS-1: 0] tc_ccop_indx_way;
wire [SET_ASSOC-1: 0] tc_ccop_indx_way_d;

// tag indx bank
wire [  TAG_BITS-1: 0] tc_tag;
wire [INDEX_BITS-1: 0] tc_indx;
wire [           2: 0] tc_bank_sel;
wire [           7: 0] tc_bank_sel_d;

// hit/miss
wire          tc_miss;    // load/store/pref miss,
wire          ls_hit;     // load/store/pref hit tag or hit missq
wire          ls_hit_ok;  // load/store/pref hit tag or hit missq and data ok

wire          ls_hit_mq;          // load/store hit missq
wire          bank_hit_mq_valid;  // missq data is valid in tc_bank
wire          ls_hit_mq_ok;       // load/store hit missq, and mq data ok

wire          oneld_ok;               // not burst access
wire          wait_mq_inv_ok;         // uncache load, cache load/store, pref wait mq invalid ok
wire          wait_mq_inv_ok_nc_hit;  // wait_mq_inv_ok and no cace hit mq, for stall_ram_en

wire                  ls_hit_tag;   // load/store hit tag, must be cached
wire [SET_ASSOC-1: 0] hit_tag_way;

// if hit way is locked, isync do nothing
wire [SET_ASSOC-1: 0] hit_tag_way_lock;  // hit way is not locked

wire          tc_cmp_valid;

// ecc err stall tc_state
wire          all_ecc_err;           // for load/store
wire          true_ecc_err;
wire          see_ecc_err;
wire          all_ecc_err_stall;
wire          true_ecc_err_stall;
wire          true_err_fatal_stall;

// lock, won't hit mq
// if lock uncached, can't set lock_miss.
wire          tc_lock_hit;
wire          tc_lock_miss;

// ccop(include lock_hit) do , go to missq
// if hit way is locked, isync do nothing
wire          ccop_hit_cango;
wire          tc_ccop_hit_do;
wire          tc_ccop_indx_do;
wire          tc_lock_do;
wire          tc_ccop_do;

// lock miss or hit, also go to wait_mq_ar.
wire          tc_ccop_or_lock;  // no pref, fill
wire          tc_dbgm_ok;

wire [  1: 0] req_next_state;
wire [  1: 0] ar_next_state;

// write-through store stall
// cached shouldn't set sob.
wire          tc_sob_stall;  // strong-older-back need wait bq_null
wire          tc_aw_stall;   // stall aw
wire          tc_ar_stall;   // stall ar

wire          tagcmp_missq_ar_wait;

wire          tc_aw_ccop_dbgm_ok;

wire          tc_valid;
wire          tc_next_in;
wire          wait_mq_inv;

// axi_size
wire [  2: 0] tc_size_axi;

// axi_strb;axi rdata32
wire [        31: 0] axi_rdata32;
wire [AXI_STRB-1: 0] tc_strb_axi;

// axi_addr
wire [ 31: 0] tc_addr_axi;
wire [ 31: 0] tc_access_addr;
`ifdef CONFIG_MMU
wire [ 31: 0] tc_paddr;
wire          tc_xlat_ready;
wire          tc_wait_xlat;
wire          tc_sob_base;
wire          tc_cached_base;
wire          tc_alloc_base;
`endif

// to wrbuf
wire [SET_ASSOC-1: 0] way_rd_l;  // see{compare}

// to missq
wire [TAG_BITS-1: 0] tc_sttag_pa;

wire [RAM_TAGV_WD-1: 0] tc_tagv_rdata;
wire [   TAG_BITS-1: 0] way_rd_tag[SET_ASSOC-1:0];
wire [  SET_ASSOC-1: 0] way_rd_v;

wire [BANK_WD-1: 0] bank_rdata;
wire [       31: 0] way_rd_data[SET_ASSOC-1:0];
wire [       31: 0] way_rd_data_all;
wire [SET_ASSOC-1: 0] gen_wrd_sel;

wire          tc_wrbuf_fwd_valid;
wire [  3: 0] tc_wrbuf_fwd_strb;
wire [ 31: 0] tc_wrbuf_fwd_data;

wire [ 31: 0] tc_hit_tag_rdata;

// hit missq when missq is writing to axi
wire [  7: 0] tc_mq_buf_shf_sel;
wire [  7: 0] tc_mq_buf_shf_sel_v[CC_LINE_AXI-1:0];
wire [CC_LINE_AXI-1:0] gen_tcbss_sel;

wire [  7: 0] tc_mq_bank_sel;

// hit missq
wire [  7: 0] tc_mq_bank_valid;

// only
wire          tc_cmp_mq;

// load hit mq
wire [ 31: 0] tc_hit_mq_rdata;  // cache/uncache load get missq data

wire [ 31: 0] tc_hit_rdata;  // cache/uncache load get hited rdata

wire          axi_rresp1_nc;

`ifdef CONFIG_MMU

`endif
//============================================================//
//                    Module Implementation
//============================================================//

// Instance Parameter Aliases
// x_lsu_dec_n_m_0

// Instance Boundary Alias Mapping
// x_lsu_dec_n_m_0

assign decode_index_dec0  =  tc_bank_sel;
assign tc_bank_sel_d      =  decode_onehot_dec0;

generate
    case(AXI_DATA)
        32:
        begin: gen_axi_32bit
            assign axi_burst_size  =  3'b010;
        end
        64:
        begin: gen_axi_64bit
            assign axi_burst_size  =  3'b011;
        end
        128:
        begin: gen_axi_128bit
            assign axi_burst_size  =  3'b100;
        end
    endcase
endgenerate

//------------------------------------------------------------//
//                     Tc:register cc_req
//------------------------------------------------------------//

// <-> mmu
`ifdef CONFIG_MMU
assign go_mmu_vaddr  =  tc_vaddr;
`else
assign go_mmu_vaddr  =  {tc_vaddr_h3,tc_addr[28:0]};
`endif
assign go_mmu_read   =  tc_rd;
assign go_mmu_dbgm   =  tc_dbgm;
`ifdef CONFIG_MMU
assign tc_sob_base     =  tc_attr_vld ? tc_sob_r : mmu_sob;
assign tc_cached_base  =  tc_attr_vld ? tc_cached_r : mmu_cached;
assign tc_alloc_base   =  tc_attr_vld ? tc_alloc_r : mmu_alloc;
assign tc_sob          =  xlat_vld ? xlat_sob : tc_sob_base;
assign tc_cached       =  (xlat_vld ? xlat_cached : tc_cached_base)
                          || tc_ccop_indx;
assign tc_alloc        =  (xlat_vld ? xlat_alloc : tc_alloc_base)
                          || tc_lock || tc_pref || tc_ccop_valid;
`else
assign tc_sob        =  mmu_sob;
assign tc_cached     =  mmu_cached || tc_ccop_indx;
assign tc_alloc      =  mmu_alloc || tc_lock || tc_pref || tc_ccop_valid;
`endif
assign tc_bacs       =  tc_cached&&!bypass&&tc_alloc;

// some signals:
// (1) cached   : cacheable or noncacheable, used in ar/awcache
// (2) see_cache: look up cache
// (3) see_mq   : look up mq, maybe hit mq.
// (4) see_axi  : get rdata from axi directly.
// (5) bacs     : use burst access if miss or not see_cache.

assign see_cache  =  tc_cached&&!bypass;
assign see_mq     =  see_cache || tc_bacs;

`ifdef CONFIG_MMU
assign tc_paddr  =  xlat_vld ? xlat_paddr : tc_addr;
assign tc_access_addr  =  tc_paddr;
`else
assign tc_access_addr  =  tc_addr;
`endif
assign {tc_tag,tc_indx,tc_bank_sel}  =  tc_access_addr[31:2];
lsu_dec_n_m #(
    .M (M_DEC0)
) x_lsu_dec_n_m_0 (
    .decode_index  (decode_index_dec0 ),
    .decode_onehot (decode_onehot_dec0)
);

assign tagcmp_cache_ram_bank_sel  =  tc_bank_sel;

generate
    if(SET_ASSOC == 2 || SET_ASSOC == 4)
    begin: gen_indx_way_decode_2way_4way
        assign tc_ccop_indx_way  =  tc_access_addr[SET_BITS-1:0];
        lsu_dec_n_m #(
            .M (SET_ASSOC)
        ) x_lsu_ccop_indx_way_dec (
            .decode_index  (tc_ccop_indx_way  ),
            .decode_onehot (tc_ccop_indx_way_d)
        );
    end
    else
    begin: gen_indx_way_decode_1way
        assign tc_ccop_indx_way_d  =  1'b1;
    end
endgenerate

//------------------------------------------------------------//
//                      Tc State Machine
//------------------------------------------------------------//
always @ ( posedge clk )
begin
    if(reset) begin
        tc_state <= TC_IDLE;
    end
    else begin
        tc_state <= tc_next_state;
    end
end

assign all_ecc_err           =  cache_ram_tagcmp_tagv_err || cache_ram_tagcmp_bank_err;
assign true_ecc_err          =  cache_ram_tagcmp_tagv_err&&tc_need_tagv
                                ||cache_ram_tagcmp_bank_err&&tc_need_data;
assign see_ecc_err           =  has_ecc && tc_cmp_valid && see_cache && !wrbuf_tagcmp_new_valid;
assign all_ecc_err_stall     =  see_ecc_err && all_ecc_err;
assign true_ecc_err_stall    =  see_ecc_err && true_ecc_err;
assign true_err_fatal_stall  =  true_ecc_err_stall || wrbuf_tagcmp_ecc_fatal;

assign tc_lock_hit   =  tc_lock &&  ls_hit_tag;
assign tc_lock_miss  =  tc_lock && !ls_hit_tag && see_cache && tc_cmp_valid && !true_ecc_err_stall;

assign ccop_hit_cango   =  !((|hit_tag_way_lock) && tc_isync) && ls_hit_tag;
assign tc_ccop_hit_do   =  tc_ccop_hit &&ccop_hit_cango;
assign tc_ccop_indx_do  =  tc_ccop_indx&&tc_cmp_valid;
assign tc_lock_do       =  tc_lock_hit &&tc_cmp_valid;
assign tc_ccop_do       =  tc_ccop_hit_do || tc_ccop_indx_do || tc_lock_do;

assign tc_ccop_or_lock  =  tc_ccop_valid || tc_lock;
assign tc_dbgm_ok       =  dbgm_req_valid && dbgm_resp_valid;

assign req_next_state  =  real_req&&tc_allowin  ? TC_CMP    : TC_IDLE;
assign ar_next_state   =  axi_ar_ok             ? TC_MQ_INV : TC_WAIT_MQ_AR;

assign tc_sob_stall  =  tc_sob && !missq_tagcmp_bq_null;
assign tc_aw_stall   =  tc_sob_stall || missq_tagcmp_bq_full;
assign tc_ar_stall   =  tc_sob_stall || missq_tagcmp_ar_stall;

assign tagcmp_missq_ar_wait  =  (tc_aw&&tc_miss&&(!missq_tagcmp_allowin||tc_aw_stall))||tc_ccop_or_lock||tc_dbgm;

assign tc_aw_ccop_dbgm_ok  =  missq_tagcmp_allowin&&(tc_aw_do||tc_ccop_valid||tagcmp_missq_lock_exist)
                              ||tc_dbgm_ok;

always @ ( tc_state
           or req_next_state
           or wrbuf_tagcmp_ecc_fatal
           or true_ecc_err_stall
           or ls_hit_mq
           or bank_hit_mq_valid
           or tagcmp_missq_ar_wait
           or tc_ar
           or tc_miss
           or ar_next_state
           or tc_aw_ccop_dbgm_ok
           or wait_mq_inv_ok
`ifdef CONFIG_MMU
           or tc_wait_xlat
           or xlat_cancel
`endif
         )
begin
    case(tc_state)
        TC_IDLE: begin
            tc_next_state = req_next_state;
        end
        TC_CMP: begin
`ifdef CONFIG_MMU
            tc_next_state = xlat_cancel                         ? TC_IDLE        :
            tc_wait_xlat                        ? TC_CMP         :
            wrbuf_tagcmp_ecc_fatal              ? TC_IDLE        :
`else
            tc_next_state = wrbuf_tagcmp_ecc_fatal              ? TC_IDLE        :
`endif
            true_ecc_err_stall              ? TC_CMP         :
            ls_hit_mq&&!bank_hit_mq_valid   ? TC_MQ_INV      :
            tagcmp_missq_ar_wait               ? TC_WAIT_MQ_AR  :
            tc_ar    &&tc_miss              ? ar_next_state  :  // ucld(not ucacc) must be tc_miss
            req_next_state ;
        end
        TC_WAIT_MQ_AR: begin
            tc_next_state = tc_aw_ccop_dbgm_ok ? TC_IDLE : ar_next_state;
        end
        TC_MQ_INV: begin
            tc_next_state = wait_mq_inv_ok ? req_next_state : TC_MQ_INV ;
        end
    endcase
end

assign tc_idle       =  tc_state==TC_IDLE;
assign tc_valid      =  !tc_idle;
`ifdef CONFIG_MMU
assign tc_next_in    =  tc_next_state==TC_CMP && !true_ecc_err_stall
                        && !tc_wait_xlat;
assign tc_xlat_ready =  !tc_xlat_wait || xlat_vld;
assign tc_wait_xlat  =  tc_state==TC_CMP && !tc_xlat_ready && !xlat_cancel;
assign tc_cmp_valid  =  tc_state==TC_CMP && tc_xlat_ready && !xlat_cancel;
`else
assign tc_next_in    =  tc_next_state==TC_CMP&&!true_ecc_err_stall;
assign tc_cmp_valid  =  tc_state==TC_CMP;
`endif
// load/store request is prior to mq_refill
assign tc_allow_refill  =  (tc_state==TC_WAIT_MQ_AR)
                           ||(tc_state==TC_IDLE)&&!ls_req_nocps;  // cps req must allow refill
assign wait_mq_inv      =  tc_state==TC_MQ_INV;
assign tc_stall_ram_en  =  (tc_state==TC_WAIT_MQ_AR)
                           ||(tc_state==TC_MQ_INV    )&&!wait_mq_inv_ok_nc_hit;
assign tc_allowin       =  (tc_state==TC_IDLE  )
                           ||(tc_state==TC_CMP   )&&ls_hit_ok&&!tc_ccop_or_lock
                           ||(tc_state==TC_MQ_INV)&& wait_mq_inv_ok;
// End Tc State Machine

//------------------------------------------------------------//
//                             Tc
//------------------------------------------------------------//
always @ ( posedge clk )
begin
    if(data_reset) begin
`ifdef CONFIG_MMU
        tc_vaddr    <= 32'd0 ;
`else
        tc_vaddr_h3 <= 3'd0 ;
`endif
        tc_addr     <= 32'd0 ;
        tc_exc      <= 1'd0 ;
        tc_size     <= 2'd0 ;
        tc_dbgm     <= 1'd0 ;
        tc_rd       <= 1'd0 ;
        tc_wdata    <= 32'd0 ;
`ifdef CONFIG_MMU
        tc_xlat_wait <= 1'b0;
        tc_attr_vld  <= 1'b0;
`endif
        tc_ccop     <= 6'd0 ;
        tc_isync    <= 1'd0 ;
        tc_lock     <= 1'd0 ;
    end
    else if(tc_next_in) begin
`ifdef CONFIG_MMU
        tc_vaddr    <= vaddr     ;
`else
        tc_vaddr_h3 <= vaddr_h3  ;
`endif
        tc_addr     <= paddr     ;
        tc_exc      <= req_exc   ;
        tc_size     <= size      ;
        tc_dbgm     <= req2dbgm  ;
        tc_rd       <= req_rd    ;
        tc_wdata    <= req_wdata ;
`ifdef CONFIG_MMU
        tc_xlat_wait <= req_xlat_wait;
        tc_attr_vld  <= req_attr_vld;
`endif
        tc_ccop     <= cc_op     ;
        tc_isync    <= cc_isync  ;
        tc_lock     <= cc_lock   ;
`ifdef CONFIG_MMU
    end
    else if((tc_state == TC_CMP) && xlat_vld) begin
        tc_addr      <= xlat_paddr;
        tc_xlat_wait <= 1'b0;
        tc_attr_vld  <= 1'b1;
    end

    if(tc_next_in && req_attr_vld) begin
        tc_sob_r    <= req_sob;
        tc_cached_r <= req_cached;
        tc_alloc_r  <= req_alloc;
    end
    else if((tc_state == TC_CMP) && xlat_vld) begin
        tc_sob_r    <= xlat_sob;
        tc_cached_r <= xlat_cached;
        tc_alloc_r  <= xlat_alloc;
`endif
    end

    tc_pref  <= data_reset   ?  1'd0 :
    tc_next_in   ? cc_pref:
    tc_lock_miss ? 1'b1  :  // lock miss need set pref
    ex_cancel&&(tc_rd||tc_ccop_ldtag) ? 1'b1 : tc_pref ;
end
assign tc_wr  =  !tc_rd&&!tc_ccop_valid&&!tc_pref&&!tc_lock;
// byte enable
// size  addr[1:0]   strobe
//  00     00         0001
//  00     01         0010
//  00     10         0100
//  00     11         1000
//  01     00         0011
//  01     01          -
//  01     10         1100
//  01     11          -
//  10     00         1111
//  10     01          -
//  10     10          -
//  10     11          -
`ifdef CONFIG_MMU
assign tc_strb[3]  =  (tc_paddr[1:0]==2'b11) | tc_size[1] | (tc_size[0]& tc_paddr[1]);
assign tc_strb[2]  =  (tc_paddr[1:0]==2'b10) | tc_size[1]                            ;
assign tc_strb[1]  =  (tc_paddr[1:0]==2'b01) | tc_size[1] | (tc_size[0]&~tc_paddr[1]);
assign tc_strb[0]  =  (tc_paddr[1:0]==2'b00)                                         ;
`else
assign tc_strb[3]  =  (tc_addr[1:0]==2'b11) | tc_size[1] | (tc_size[0]& tc_addr[1]);
assign tc_strb[2]  =  (tc_addr[1:0]==2'b10) | tc_size[1]                           ;
assign tc_strb[1]  =  (tc_addr[1:0]==2'b01) | tc_size[1] | (tc_size[0]&~tc_addr[1]);
assign tc_strb[0]  =  (tc_addr[1:0]==2'b00)                                        ;
`endif

assign tc_size_axi      =  tc_bacs ? axi_burst_size : {1'b0,tc_size};
generate
    case(AXI_DATA)
        32:
        begin: gen_rdata_strb_axi32
            assign axi_rdata32  =  axi_rdata;
            assign tc_strb_axi  =  tc_strb;
        end
        64:
        begin: gen_rdata_strb_axi64
            assign axi_rdata32  =  tc_access_addr[2] ? axi_rdata[63:32] : axi_rdata[31:0];
            assign tc_strb_axi  =  tc_access_addr[2] ? {tc_strb,4'd0} : {4'd0,tc_strb};
        end
        128:
        begin: gen_rdata_strb_axi128
            assign axi_rdata32  =  {32{tc_access_addr[3:2]==2'd0}} & axi_rdata[31 : 0]
                                  |{32{tc_access_addr[3:2]==2'd1}} & axi_rdata[63 :32]
                                  |{32{tc_access_addr[3:2]==2'd2}} & axi_rdata[95 :64]
                                  |{32{tc_access_addr[3:2]==2'd3}} & axi_rdata[127:96];
            assign tc_strb_axi  =  {16{tc_access_addr[3:2]==2'd0}} & {12'd0,tc_strb      }
                                  |{16{tc_access_addr[3:2]==2'd1}} & { 8'd0,tc_strb, 4'd0}
                                  |{16{tc_access_addr[3:2]==2'd2}} & { 4'd0,tc_strb, 8'd0}
                                  |{16{tc_access_addr[3:2]==2'd3}} & {      tc_strb,12'd0};
        end
    endcase
endgenerate
// if ctrl_nowrap=1, mask addr[4          :0]=0 for burst(tc_bacs=1)
// if ctrl_nowrap=0, mask addr[AXI_ALIGN_N:0]=0 for burst(tc_bacs=1)
`ifdef CONFIG_MMU
assign tc_addr_axi[31:5]  =  tc_paddr[31:5];
assign tc_addr_axi[4  :AXI_ALIGN_N]  =  tc_paddr[4  :AXI_ALIGN_N]&{(5-AXI_ALIGN_N){!tc_bacs||!ctrl_nowrap}};
assign tc_addr_axi[AXI_ALIGN_N-1:0]  =  tc_paddr[AXI_ALIGN_N-1:0]&{AXI_ALIGN_N{!tc_bacs}};
`else
assign tc_addr_axi[31:5]  =  tc_addr[31:5];
assign tc_addr_axi[4  :AXI_ALIGN_N]  =  tc_addr[4  :AXI_ALIGN_N]&{(5-AXI_ALIGN_N){!tc_bacs||!ctrl_nowrap}};
assign tc_addr_axi[AXI_ALIGN_N-1:0]  =  tc_addr[AXI_ALIGN_N-1:0]&{AXI_ALIGN_N{!tc_bacs}};
`endif

// ccop[5:0]
//   [5]       [4]       [3]      [2]     [1]   [0]
// StoreTag  LoadTag  Writeback  invalid  Index  hit
assign tc_ccop_hit    =  tc_ccop[0];
assign tc_ccop_indx   =  tc_ccop[1];
assign tc_ccop_inv    =  tc_ccop[2];
assign tc_ccop_wb     =  tc_ccop[3];
assign tc_ccop_ldtag  =  tc_ccop[4];
assign tc_ccop_sttag  =  tc_ccop[5];
assign tc_ccop_valid  =  tc_ccop_hit|| tc_ccop_indx;  // not fill, not lock
assign tc_need_data   =  !((tc_ccop_valid||tc_pref||tc_lock)&&tc_cmp_valid);  // ccop/pref/lock no need data
assign tc_need_tagv   =  !(tc_ccop_indx&&tc_cmp_valid);  // ccop_index no need tagv

assign tc_aw  =  tc_wr && !tc_dbgm && (!see_cache || !tc_bacs);
// pref/fetch-lock uncached won't set tc_ar.
assign tc_ar  =  (tc_rd || see_cache&&tc_bacs)&& !tc_dbgm &&
                   !tc_ccop_valid && !tagcmp_missq_lock_exist;

assign tc_aw_do  =  tc_aw && !tc_aw_stall
                    &&(tc_miss || tc_state==TC_WAIT_MQ_AR);
assign tc_ar_do  =  tc_ar && missq_tagcmp_allowin && !tc_ar_stall
                    &&(tc_miss || tc_state==TC_WAIT_MQ_AR);
// to axi
assign axi_arvalid  =  tc_ar_do   ;
assign axi_arburst  =  tc_bacs    ;
assign axi_arexc    =  tc_exc     ;
assign axi_arcache  =  tc_cached  ;
assign axi_arsize   =  tc_size_axi;
assign axi_araddr   =  tc_addr_axi;

assign tagcmp_wrbuf_ls_valid  =  tc_cmp_valid&&ls_hit_tag
                                 &&tagcmp_wrbuf_lru_wen;  // read or write
assign tagcmp_wrbuf_ecc_err   =  true_ecc_err_stall;
assign tagcmp_wrbuf_hit_way   =  hit_tag_way;
assign tagcmp_wrbuf_wr        =  tc_wr;
assign tagcmp_wrbuf_bank_sel  =  tc_bank_sel;
assign tagcmp_wrbuf_strb      =  tc_strb;
assign tagcmp_wrbuf_indx      =  tc_indx;
assign tagcmp_wrbuf_wdata     =  tc_wdata;
assign tagcmp_wrbuf_way_lock  =  way_rd_l;
assign tagcmp_wrbuf_lru_wen   =  tc_rd || tc_wr;

assign tagcmp_missq_valid                         =  tc_valid   ;
assign tagcmp_missq_aw_do                         =  tc_aw_do   ;
assign tagcmp_missq_bacs                          =  tc_bacs    ;
assign tagcmp_missq_exc                           =  tc_exc     ;
assign tagcmp_missq_cached                        =  tc_cached  ;
`ifdef CONFIG_MMU
assign tagcmp_missq_araddr31_5                    =  tc_paddr[31:5];
`else
assign tagcmp_missq_araddr31_5                    =  tc_addr[31:5];
`endif
assign tagcmp_missq_strb                          =  tc_strb_axi;
assign tagcmp_missq_size                          =  tc_size_axi[1:0];
assign tagcmp_missq_addr[SET_ASSOC-1:        0]   =  tc_ccop_hit||tc_lock_hit ? hit_tag_way      :
                                                       tc_ccop_indx             ? tc_ccop_indx_way_d    :
`ifdef CONFIG_MMU
                                                       tc_paddr[SET_ASSOC-1:0];
assign tagcmp_missq_addr[INDEX_BITS+4:SET_ASSOC]  =  tc_paddr[INDEX_BITS+4:SET_ASSOC];
assign tagcmp_missq_addr[31:INDEX_BITS+5       ]  =  tc_ccop_indx ? tc_sttag_pa:tc_paddr[31:INDEX_BITS+5];
`else
                                                       tc_addr[SET_ASSOC-1:0];
assign tagcmp_missq_addr[INDEX_BITS+4:SET_ASSOC]  =  tc_addr[INDEX_BITS+4:SET_ASSOC];
assign tagcmp_missq_addr[31:INDEX_BITS+5       ]  =  tc_ccop_indx ? tc_sttag_pa:tc_addr[31:INDEX_BITS+5];
`endif
assign tagcmp_missq_pref                          =  tc_pref      ;
assign tagcmp_missq_lock                          =  tc_lock      ;
assign tagcmp_missq_ccop_do                       =  tc_ccop_do && !wrbuf_tagcmp_ecc_fatal;
// if lock miss, will set tc_pref, so "tc_lock&&!tc_pref" miss lock hit
assign tagcmp_missq_lock_exist  =  tc_lock&&!tc_pref;  // locked way is already in cache.
assign tagcmp_missq_ccop_valid  =  tc_ccop_valid || tagcmp_missq_lock_exist;
assign tagcmp_missq_ccop_inv    =  tc_ccop_inv  ;
assign tagcmp_missq_ccop_sttag  =  tc_ccop_sttag;
assign tagcmp_missq_ccop_ldtag  =  tc_ccop_ldtag;
assign tagcmp_missq_ccop_wb     =  tc_ccop_wb   ;
// store tag
assign tc_sttag_pa           =  tc_wdata[31:32-TAG_BITS];
assign tagcmp_missq_sttag_v  =  tc_wdata[7];
assign tagcmp_missq_sttag_d  =  tc_wdata[6];
assign tagcmp_missq_sttag_l  =  tc_wdata[5];
// End Tc

//------------------------------------------------------------//
//                          Compare
//------------------------------------------------------------//
assign tc_tagv_rdata      =  wrbuf_tagcmp_new_valid ? wrbuf_tagcmp_new_tagv : cache_ram_tagcmp_tagv_rdata;
generate
    if(SET_ASSOC == 1)
    begin: gen_only_1way
        assign {way_rd_tag[0],way_rd_v[0],way_rd_l[0]}  =  {tc_tagv_rdata[TAGV_BITS-1:0],1'b0};
    end
    else
    begin: gen_2_4_ways
        for(i = 0; i < SET_ASSOC; i = i + 1)
        begin: gen_tagv_per_way
            assign {way_rd_tag[i],way_rd_v[i],way_rd_l[i]}  =  tc_tagv_rdata[TAGV_BITS*i+:TAGV_BITS];
        end
    end
endgenerate

generate
    for(i = 0; i < SET_ASSOC; i = i + 1)
    begin: gen_tag_cmp
        assign hit_tag_way[i]       =  (way_rd_tag[i] == tc_tag) && way_rd_v[i];
        assign hit_tag_way_lock[i]  =  hit_tag_way[i] && way_rd_l[i];
    end
endgenerate
// only see_cache will hit tag
assign ls_hit_tag  =  (|hit_tag_way) && see_cache && tc_cmp_valid &&
                        !true_ecc_err_stall;
assign ls_hit      =  ls_hit_tag || ls_hit_mq;
// unld(not ucacc) must miss
assign tc_miss    =  !ls_hit && tc_cmp_valid && !true_err_fatal_stall;
assign ls_hit_ok  =  (ls_hit_tag || ls_hit_mq_ok);

// End Compare

//------------------------------------------------------------//
//                          Read Hit
//------------------------------------------------------------//
assign bank_rdata       =  wrbuf_tagcmp_new_valid ? wrbuf_tagcmp_new_bank : cache_ram_tagcmp_bank_rdata;
assign gen_wrd_sel      =  hit_tag_way & {SET_ASSOC{tc_rd}};
`GEN_1D_TO_2D(SET_ASSOC, 32, bank_rdata, way_rd_data)
`GEN_2D_SEL_1D(SET_ASSOC, 32, way_rd_data, way_rd_data_T, gen_wrd_sel, way_rd_data_all)
// End Read Hit

//------------------------------------------------------------//
//                     Forward From Wrbuf
//------------------------------------------------------------//

assign tc_wrbuf_fwd_valid  =  wrbuf_tagcmp_wr && wrbuf_tagcmp_hit_bank
                              &&(wrbuf_tagcmp_way == hit_tag_way);
assign tc_wrbuf_fwd_strb   =  wrbuf_tagcmp_strb;
assign tc_wrbuf_fwd_data   =  wrbuf_tagcmp_wdata;

assign tc_hit_tag_rdata[7 : 0]  =  tc_wrbuf_fwd_valid&&tc_wrbuf_fwd_strb[0] ?
                                     tc_wrbuf_fwd_data[7 : 0] : way_rd_data_all[7 : 0];
assign tc_hit_tag_rdata[15: 8]  =  tc_wrbuf_fwd_valid&&tc_wrbuf_fwd_strb[1] ?
                                     tc_wrbuf_fwd_data[15: 8] : way_rd_data_all[15: 8];
assign tc_hit_tag_rdata[23:16]  =  tc_wrbuf_fwd_valid&&tc_wrbuf_fwd_strb[2] ?
                                     tc_wrbuf_fwd_data[23:16] : way_rd_data_all[23:16];
assign tc_hit_tag_rdata[31:24]  =  tc_wrbuf_fwd_valid&&tc_wrbuf_fwd_strb[3] ?
                                     tc_wrbuf_fwd_data[31:24] : way_rd_data_all[31:24];
// End Forward From Wrbuf

//------------------------------------------------------------//
//                         Hit Missq
//------------------------------------------------------------//
assign tc_mq_buf_shf_sel_v[0]  =  {8{missq_tagcmp_buf_valid[0]}} & tc_bank_sel_d;
generate
    for(i = 1; i < CC_LINE_AXI; i = i + 1)
    begin: gen_tc_mq_buf_shf_sel_v
        assign tc_mq_buf_shf_sel_v[i]  =  {8{!missq_tagcmp_buf_valid[i-1] && missq_tagcmp_buf_valid[i]}} &
                                             {tc_bank_sel_d[7-i*AXI_DIV_32:0],
                                              tc_bank_sel_d[7:8-i*AXI_DIV_32]};
    end
endgenerate
assign gen_tcbss_sel  =  {CC_LINE_AXI{1'b1}};
`GEN_2D_SEL_1D(CC_LINE_AXI, 8, tc_mq_buf_shf_sel_v,
               tc_mq_buf_shf_sel_v_T, gen_tcbss_sel, tc_mq_buf_shf_sel)

assign tc_mq_bank_sel  =  missq_tagcmp_wait_wr ? tc_mq_buf_shf_sel : tc_bank_sel_d;

generate
    for(i = 0; i < 8; i = i + 1)
    begin: gen_tc_mq_bank_valid
        assign tc_mq_bank_valid[i]  =  missq_tagcmp_buf_valid[i/AXI_DIV_32] && tc_mq_bank_sel[i];
    end
endgenerate
assign tc_cmp_mq            =  ({tc_tag,tc_indx}==missq_tagcmp_addr_31_5)&&missq_tagcmp_valid&&tc_valid
                               &&missq_tagcmp_bacs&&see_mq;  // only see_mq will cmp mq.
assign ls_hit_mq            =  tc_cmp_mq&&!true_ecc_err_stall;
assign bank_hit_mq_valid    =  (|tc_mq_bank_valid);
assign ls_hit_mq_ok         =  ls_hit_mq&&bank_hit_mq_valid;

assign see_axi                =  wait_mq_inv && !missq_tagcmp_bacs;
assign oneld_ok               =  see_axi && axi_rvalid;
assign wait_mq_inv_ok         =  ls_hit_mq_ok || oneld_ok || tc_pref;
assign wait_mq_inv_ok_nc_hit  =  tc_cmp_mq&&bank_hit_mq_valid || oneld_ok || tc_pref;

assign tc_hit_mq_rdata  =  (missq_tagcmp_buf_data[32*0+31:32*0] & {32{tc_mq_bank_valid[0]}})
                           |(missq_tagcmp_buf_data[32*1+31:32*1] & {32{tc_mq_bank_valid[1]}})
                           |(missq_tagcmp_buf_data[32*2+31:32*2] & {32{tc_mq_bank_valid[2]}})
                           |(missq_tagcmp_buf_data[32*3+31:32*3] & {32{tc_mq_bank_valid[3]}})
                           |(missq_tagcmp_buf_data[32*4+31:32*4] & {32{tc_mq_bank_valid[4]}})
                           |(missq_tagcmp_buf_data[32*5+31:32*5] & {32{tc_mq_bank_valid[5]}})
                           |(missq_tagcmp_buf_data[32*6+31:32*6] & {32{tc_mq_bank_valid[6]}})
                           |(missq_tagcmp_buf_data[32*7+31:32*7] & {32{tc_mq_bank_valid[7]}});

`GEN_COMPRESS_OR(CC_LINE_AXI, AXI_DIV_32, tc_mq_bank_sel, tc_st_hit_mq_sel)
assign tc_hit_mq             =  ls_hit_mq && !tc_ccop_valid;
assign tc_st_hit_mq_ok       =  tc_wr&&ls_hit_mq_ok;
assign tc_st_hit_mq_wstrb    =  tc_strb_axi;
assign tc_st_hit_mq_wdata    =  {AXI_DIV_32{tc_wdata}};
// End Hit Missq

//------------------------------------------------------------//
//                        Tc Hit Rdata
//------------------------------------------------------------//
assign tc_hit_rdata  =  tc_cmp_mq ? tc_hit_mq_rdata : tc_hit_tag_rdata;

// rdata_ok no need see tc_pref(for ex_cancel)
assign tc_rdata_valid  =  (ls_hit_ok||oneld_ok||tc_dbgm_ok||wrbuf_tagcmp_ecc_fatal&&tc_cmp_valid)
                          &&tc_rd && !all_ecc_err_stall;  // load no ecc_error
assign tc_rdata        =  {32{tc_dbgm           }} & dbgm_resp_data |
                            {32{see_axi           }} & axi_rdata32    |
                            {32{!tc_dbgm&&!see_axi}} & tc_hit_rdata   ;
assign tc_rdata_exok   =  see_axi && axi_rvalid && axi_rresp[0];
assign tc_rdata_err    =  1'b0;  // unsupport bus error for Cache.

assign axi_rresp1_nc  =  axi_rresp[1];
// End Tc Hit Rdata

//------------------------------------------------------------//
//                        Sysbus Idle
//------------------------------------------------------------//
assign rd_in_tc  =  tc_valid&&tc_rd;
assign wr_in_tc  =  tc_valid&&tc_wr;
// End Sysbus Idle
// End Tc:register Tc

//------------------------------------------------------------//
//                      Access To Ljtag
//------------------------------------------------------------//
assign dbgm_req_valid  =  tc_valid && tc_dbgm;
assign dbgm_req_wr     =  tc_wr;
`ifdef CONFIG_MMU
assign dbgm_req_addr   =  tc_paddr & {32{tc_dbgm}};
`else
assign dbgm_req_addr   =  tc_addr & {32{tc_dbgm}};
`endif
assign dbgm_req_size   =  tc_size;
assign dbgm_req_wdata  =  tc_wdata;
// End Access To Ljtag
`ifdef CONFIG_MMU

`endif

//------------------------------------------------------------//
//                           Assert
//------------------------------------------------------------//
`ifdef OPEN132_ASSERT
assert property (
    @(posedge clk)
    tc_cmp_valid&&!tc_ccop_indx&&!tagcmp_wrbuf_ecc_err&&see_cache
    |-> $onehot0(hit_tag_way)
    )
else begin $display("Assert Error!!!"); #2 $finish; end
assert property (
    @(posedge clk)
    see_axi |-> !tc_dbgm
    )
else begin $display("see_axi Assert Error!!!"); #2 $finish; end
`endif
// End Assert
endmodule

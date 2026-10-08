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

module lsu_cache #(
    parameter AXI_DATA             = 32,                      // 32/64/128
    parameter AXI_WID_N            = 4,                       // 1/2/4/8, b-queue depth

    // cache configuration
    // Cache size in KB: SET_ASSC*WAYSIZE
    parameter SET_ASSOC            = 4,                       // 1/2/4 way set associative
    parameter WAYSIZE              = 8 * (2 ** 10),           // 1/2/4/8/16 KB Size/way
    parameter INDEX_BITS           = $clog2(WAYSIZE) - 5,
    parameter TAG_BITS             = 32 - INDEX_BITS - 5,

    parameter ECC_BITS             = 1,                       // 1/7/8 bits, for no ecc, 32+7, 64+8

    // cache ram
    parameter RAM_TAGV_REQ_BUS_WD  = 4 + 4 + 8 + 84,
    parameter RAM_TAGV_RESP_BUS_WD = 84,
    parameter RAM_DATA_REQ_BUS_WD  = (4 + 16 + 8 + 128) * 8,
    parameter RAM_DATA_RESP_BUS_WD = 128 * 8,
    parameter RAM_LRUD_REQ_BUS_WD  = 1 + (6 + 4) * 2 + 8,
    parameter RAM_LRUD_RESP_BUS_WD = 6 + 4

) (
    input  wire                              is_icache,
    // clk and reset
    input  wire                              clk,
    input  wire                              clk_ng,  // clk no-gating
    input  wire                              reset,
    input  wire                              data_reset,

    input  wire                              ctrl_nowrap,  // axi no wrap
    input  wire                              ex_cancel,

    // cache operation, address is in addr
    input  wire [                     5: 0]  cc_op,  // cache/isync op
    input  wire                              cc_isync,  // isync, only valid if cc_op is hit_wb_inv
    input  wire [                    31: 0]  cc_sttag,
    input  wire                              cc_pref,  // pref
    input  wire                              cc_lock,  // fetch and lock
    input  wire                              cc_op_stall,  // for isync, need wait another cache idle
    output wire                              cps_req_ok,
    output wire                              cps_data_ok,
    output wire [                    31: 0]  cps_rdata,
    // ifc <--> cache
    input  wire                              req_rd_wr,  // request is read or write
    input  wire                              req_rd,  // request is read
    input  wire                              req_exc,  // request exclusive access
    input  wire                              req_pre_err,  // request prediction is fail
    input  wire [                     1: 0]  size,  // request size
`ifdef CONFIG_MMU
    input  wire [                    31: 0]  vaddr,  // request virtual address
`else
    input  wire [                     2: 0]  vaddr_h3,  // request vaddr[31:29]
`endif
    input  wire [                    31: 0]  paddr,  // request paddr
`ifdef CONFIG_MMU
    input  wire                              req_xlat_wait,
    input  wire                              req_attr_vld,
    input  wire                              req_sob,
    input  wire                              req_cached,
    input  wire                              req_alloc,
    input  wire                              xlat_vld,
    input  wire                              xlat_cancel,
    input  wire [                    31: 0]  xlat_paddr,
    input  wire                              xlat_sob,
    input  wire                              xlat_cached,
    input  wire                              xlat_alloc,
`endif
    input  wire [                     2: 0]  req_bank,  // request bank, addr[4:2]
    input  wire [                    31: 0]  wdata,  // request write data
    output wire                              all_addr_ok,  // requect cmd can be received
    output wire [                    31: 0]  rdata,  // read data
    output wire                              rdata_valid,  // rdata is valid
    output wire                              rdata_exok,  // rdata is exokay
    output wire                              rdata_err,  // rdata is error

    output wire                              rd_in_sysbus,  // read access is doing
    output wire                              wr_in_sysbus,  // write access is doing
    output wire                              axi_null,  // no incomplete access/miss/writeback in cache

    // to mmu
    output wire [                    31: 0]  go_mmu_vaddr,
    output wire                              go_mmu_read,
    output wire                              go_mmu_dbgm,
    // from mmu
    input  wire                              mmu_sob,  // strong older back: wait previous mem-access complete
    input  wire                              mmu_cached,  // request is cached
    input  wire                              mmu_alloc,  // request: alloc if miss

    input  wire                              req2dbgm,
    output wire                              dbgm_req_valid,
    output wire                              dbgm_req_wr,
    output wire [                    31: 0]  dbgm_req_addr,
    output wire [                     1: 0]  dbgm_req_size,
    output wire [                    31: 0]  dbgm_req_wdata,
    input  wire                              dbgm_resp_valid,
    input  wire [                    31: 0]  dbgm_resp_data,

    // cache <--> axi
    output wire                              dcc_ar_stall_icc,  // dcc-ar stall icc-ar
    output wire                              axi_arvalid,  // read request
    input  wire                              axi_arready,  // read request received
    output wire                              axi_arburst,  // read burst
    output wire                              axi_arexc,  // read exclusive
    output wire                              axi_arcache,  // read cached
    output wire [                     2: 0]  axi_arsize,  // read size
    output wire [                    31: 0]  axi_araddr,  // read addr
    input  wire                              axi_rvalid,  // read response valid
    input  wire [            AXI_DATA-1: 0]  axi_rdata,  // read data
    input  wire [                     1: 0]  axi_rresp,  // read response

    output wire [                     2: 0]  axi_aw_wid,  // write id for awid/wid
    output wire                              axi_awvalid,  // write request
    input  wire                              axi_awready,  // write request received
    output wire                              axi_awburst,  // write burst
    output wire                              axi_awexc,  // write exclusive
    output wire                              axi_awcache,  // write cached
    output wire [                     2: 0]  axi_awsize,  // write size
    output wire [                    31: 0]  axi_awaddr,  // write addr
    output wire                              axi_wvalid,  // write data request
    input  wire                              axi_wready,  // write data received
    output wire [          AXI_DATA/8-1: 0]  axi_wstrb,  // write strobe
    output wire [            AXI_DATA-1: 0]  axi_wdata,  // write data
    output wire                              axi_wlast,  // write last
    input  wire                              axi_bvalid,  // write response valid
    input  wire [                     2: 0]  axi_bid,  // bid[2:0]

    input  wire                              bypass,  // has cache, but no access
    // for ecc
    // ecc fatal
    output wire                              all_fatal,  // ecc fatal in cache
    output wire                              load_fatal,  // ecc fatal in load access
    output wire                              store_fatal,  // ecc fatal in store access, imprecise
    output wire                              ccop_fatal,  // ecc fatal in cache op access, imprecise
    output wire                              rf_impr_fatal,  // refill
    output wire                              fatal_intagv,
    output wire [                     7: 0]  fatal_indata,
    output wire [          INDEX_BITS-1: 0]  fatal_indx,
    output wire [           SET_ASSOC-1: 0]  fatal_way,
    output wire                              fatal_dirtywb,  // 2bit err data has been writeback.
    output wire [            TAG_BITS-1: 0]  fatal_dirty_tag,  // if dirty writeback, log its tag
    // ecc 1bit error count
    output wire                              all_ecc_err_add1,
    output wire                              refill_add1,

    // only for cache
    input  wire                              resetn_in_d2,
    output wire                              ram_init_cmplt,
    // ram interface
    output wire [ RAM_TAGV_REQ_BUS_WD-1: 0]  ram_tagv_req_bus,
    output wire [ RAM_DATA_REQ_BUS_WD-1: 0]  ram_data_req_bus,
    output wire [ RAM_LRUD_REQ_BUS_WD-1: 0]  ram_lrud_req_bus,  // write by bit
    input  wire [RAM_TAGV_RESP_BUS_WD-1: 0]  ram_tagv_resp_bus,
    input  wire [RAM_DATA_RESP_BUS_WD-1: 0]  ram_data_resp_bus,
    input  wire [RAM_LRUD_RESP_BUS_WD-1: 0]  ram_lrud_resp_bus
);

// AXI
localparam AXI_STRB    = AXI_DATA / 8;
localparam AXI_ALIGN_N = 2 + AXI_DATA / 64;
localparam AXI_DIV_32  = AXI_DATA / 32;
localparam CC_LINE_AXI = 32 * 8 / AXI_DATA;

// Cache
// localparam SET_BITS = $clog2(SET_ASSOC);
localparam SET_BITS = (SET_ASSOC + 1) / 2;  // 1/1/2 for 1/2/4ways,

// localparam INDEX_BITS = $clog2(WAYSIZE) - 5;
// TAGV
// localparam TAG_BITS    = 32 - INDEX_BITS - 5;
localparam TAGV_BITS   = TAG_BITS + 1 + (SET_ASSOC + 2) / 4;  // 1 bit lock only for 2/4 ways
localparam RAM_TAGV_WD = TAGV_BITS * SET_ASSOC;

// DATA
localparam BANK_STRB = 4 * SET_ASSOC;
localparam BANK_WD   = 32 * SET_ASSOC;

// LRUD
localparam LRU_BITS    = SET_ASSOC * SET_ASSOC / 2 - SET_ASSOC / 2;  // 4-ways:6bit; 2-ways:1bit; 1-way:0bit
localparam RAM_LRUD_WD = LRU_BITS + SET_ASSOC;  // dirty; 1 bit per way

// ECC
// ECC_BITS    ECC_WAY    ECC_SET   ECC_BANK_BITS
//   0          1         assoc           0
//   7          1         assoc         7*assoc
//   8          2        assoc/2        8 or 16
//   9          4        assoc/4          9
localparam ECC_WAY       = (ECC_BITS < 7) ? 1 : 2 ** (ECC_BITS - 7);
localparam ECC_SET       = SET_ASSOC / ECC_WAY;
localparam ECC_BANK_BITS = (ECC_SET * ECC_BITS);

localparam RAM_TAGV_WD_ECC = (ECC_BITS < 7) ? RAM_TAGV_WD : RAM_TAGV_WD + ECC_BANK_BITS;
localparam BANK_WD_ECC     = (ECC_BITS < 7) ? BANK_WD : BANK_WD + ECC_BANK_BITS;

localparam BANK_WEN            = (ECC_BITS < 7) ? ECC_SET * 4 : ECC_SET;
localparam ONE_BANK_REQ_BUS_WD = SET_ASSOC + BANK_WEN + INDEX_BITS + BANK_WD_ECC;

localparam AXI_DATA_TAGCMP    = AXI_DATA;
localparam AXI_STRB_TAGCMP    = AXI_STRB;
localparam AXI_ALIGN_N_TAGCMP = AXI_ALIGN_N;
localparam AXI_DIV_32_TAGCMP  = AXI_DIV_32;
localparam CC_LINE_AXI_TAGCMP = CC_LINE_AXI;
localparam SET_ASSOC_TAGCMP   = SET_ASSOC;
localparam BANK_WD_TAGCMP     = BANK_WD;
localparam SET_BITS_TAGCMP    = SET_BITS;
localparam INDEX_BITS_TAGCMP  = INDEX_BITS;
localparam TAG_BITS_TAGCMP    = TAG_BITS;
localparam TAGV_BITS_TAGCMP   = TAGV_BITS;
localparam RAM_TAGV_WD_TAGCMP = RAM_TAGV_WD;

localparam SET_ASSOC_WRBUF     = SET_ASSOC;
localparam BANK_WD_WRBUF       = BANK_WD;
localparam BANK_STRB_WRBUF     = BANK_STRB;
localparam INDEX_BITS_WRBUF    = INDEX_BITS;
localparam TAGV_BITS_WRBUF     = TAGV_BITS;
localparam RAM_TAGV_WD_WRBUF   = RAM_TAGV_WD;
localparam ECC_BITS_WRBUF      = ECC_BITS;
localparam ECC_SET_WRBUF       = ECC_SET;
localparam ECC_WAY_WRBUF       = ECC_WAY;
localparam ECC_BANK_BITS_WRBUF = ECC_BANK_BITS;

localparam AXI_DATA_MQ      = AXI_DATA;
localparam AXI_STRB_MQ      = AXI_STRB;
localparam AXI_ALIGN_N_MQ   = AXI_ALIGN_N;
localparam AXI_WID_N_MQ     = AXI_WID_N;
localparam CC_LINE_AXI_MQ   = CC_LINE_AXI;
localparam SET_ASSOC_MQ     = SET_ASSOC;
localparam BANK_WD_MQ       = BANK_WD;
localparam BANK_STRB_MQ     = BANK_STRB;
localparam INDEX_BITS_MQ    = INDEX_BITS;
localparam TAG_BITS_MQ      = TAG_BITS;
localparam TAGV_BITS_MQ     = TAGV_BITS;
localparam RAM_TAGV_WD_MQ   = RAM_TAGV_WD;
localparam ECC_BITS_MQ      = ECC_BITS;
localparam ECC_SET_MQ       = ECC_SET;
localparam ECC_WAY_MQ       = ECC_WAY;
localparam ECC_BANK_BITS_MQ = ECC_BANK_BITS;

localparam SET_ASSOC_BANK_ECC0     = SET_ASSOC;
localparam DATA_BITS_BANK_ECC0     = TAGV_BITS;
localparam ECC_SET_BANK_ECC0       = ECC_SET;
localparam ECC_WAY_BANK_ECC0       = ECC_WAY;
localparam ECC_BITS_BANK_ECC0      = ECC_BITS;
localparam ECC_BANK_BITS_BANK_ECC0 = ECC_BANK_BITS;

localparam SET_ASSOC_BANK_ECC1     = SET_ASSOC;
localparam DATA_BITS_BANK_ECC1     = 32;
localparam ECC_BITS_BANK_ECC1      = ECC_BITS;
localparam ECC_SET_BANK_ECC1       = ECC_SET;
localparam ECC_WAY_BANK_ECC1       = ECC_WAY;
localparam ECC_BANK_BITS_BANK_ECC1 = ECC_BANK_BITS;

localparam SET_ASSOC_WAY_ECC = SET_ASSOC;
localparam ECC_WAY_WAY_ECC   = ECC_WAY;
localparam ECC_BITS_WAY_ECC  = ECC_BITS;

localparam SET_ASSOC_LRU   = SET_ASSOC;
localparam INDEX_BITS_LRU  = INDEX_BITS;
localparam LRU_BITS_LRU    = LRU_BITS;
localparam RAM_LRUD_WD_LRU = RAM_LRUD_WD;

genvar i, j, k;

//============================================================//
//                     Wire Declarations
//============================================================//

wire                                                has_ecc_tagcmp;
wire                                                clk_tagcmp;
wire                                                reset_tagcmp;
wire                                                data_reset_tagcmp;
wire                                                ex_cancel_tagcmp;
wire                                                bypass_tagcmp;
wire                                                ctrl_nowrap_tagcmp;
wire                                                real_req_tagcmp;
wire                                                ls_req_nocps_tagcmp;
wire [                                       31: 0] req_wdata_tagcmp;
wire                                                req_rd_tagcmp;
wire                                                req_exc_tagcmp;
wire [                                        1: 0] size_tagcmp;
`ifdef CONFIG_MMU
wire [                                       31: 0] vaddr_tagcmp;
`else
wire [                                        2: 0] vaddr_h3_tagcmp;
`endif
wire [                                       31: 0] paddr_tagcmp;
`ifdef CONFIG_MMU
wire                                                req_xlat_wait_tagcmp;
wire                                                req_attr_vld_tagcmp;
wire                                                req_sob_tagcmp;
wire                                                req_cached_tagcmp;
wire                                                req_alloc_tagcmp;
wire                                                xlat_vld_tagcmp;
wire                                                xlat_cancel_tagcmp;
wire [                                       31: 0] xlat_paddr_tagcmp;
wire                                                xlat_sob_tagcmp;
wire                                                xlat_cached_tagcmp;
wire                                                xlat_alloc_tagcmp;
`endif
wire [                                        5: 0] cc_op_tagcmp;
wire                                                cc_isync_tagcmp;
wire                                                cc_pref_tagcmp;
wire                                                cc_lock_tagcmp;
wire                                                axi_ar_ok_tagcmp;
wire [                                       31: 0] go_mmu_vaddr_tagcmp;
wire                                                go_mmu_read_tagcmp;
wire                                                go_mmu_dbgm_tagcmp;
wire                                                mmu_sob_tagcmp;
wire                                                mmu_cached_tagcmp;
wire                                                mmu_alloc_tagcmp;
wire [                     RAM_TAGV_WD_TAGCMP-1: 0] cache_ram_tagcmp_tagv_rdata_tagcmp;
wire [                                        2: 0] tagcmp_cache_ram_bank_sel_tagcmp;
wire [                         BANK_WD_TAGCMP-1: 0] cache_ram_tagcmp_bank_rdata_tagcmp;
wire                                                cache_ram_tagcmp_tagv_err_tagcmp;
wire                                                cache_ram_tagcmp_bank_err_tagcmp;
wire [                       SET_ASSOC_TAGCMP-1: 0] wrbuf_tagcmp_way_tagcmp;
wire                                                wrbuf_tagcmp_wr_tagcmp;
wire                                                wrbuf_tagcmp_ecc_fatal_tagcmp;
wire                                                wrbuf_tagcmp_hit_bank_tagcmp;
wire [                                        3: 0] wrbuf_tagcmp_strb_tagcmp;
wire [                                       31: 0] wrbuf_tagcmp_wdata_tagcmp;
wire                                                wrbuf_tagcmp_new_valid_tagcmp;
wire [                     RAM_TAGV_WD_TAGCMP-1: 0] wrbuf_tagcmp_new_tagv_tagcmp;
wire [                         BANK_WD_TAGCMP-1: 0] wrbuf_tagcmp_new_bank_tagcmp;
wire                                                missq_tagcmp_allowin_tagcmp;
wire                                                missq_tagcmp_ar_stall_tagcmp;
wire                                                missq_tagcmp_bq_null_tagcmp;
wire                                                missq_tagcmp_bq_full_tagcmp;
wire                                                missq_tagcmp_valid_tagcmp;
wire                                                missq_tagcmp_bacs_tagcmp;
wire                                                missq_tagcmp_wait_wr_tagcmp;
wire [                                       31: 5] missq_tagcmp_addr_31_5_tagcmp;
wire [                     CC_LINE_AXI_TAGCMP-1: 0] missq_tagcmp_buf_valid_tagcmp;
wire [                                      255: 0] missq_tagcmp_buf_data_tagcmp;
wire                                                req2dbgm_tagcmp;
wire                                                dbgm_req_valid_tagcmp;
wire                                                dbgm_req_wr_tagcmp;
wire [                                       31: 0] dbgm_req_addr_tagcmp;
wire [                                        1: 0] dbgm_req_size_tagcmp;
wire [                                       31: 0] dbgm_req_wdata_tagcmp;
wire                                                dbgm_resp_valid_tagcmp;
wire [                                       31: 0] dbgm_resp_data_tagcmp;
wire                                                axi_arvalid_tagcmp;
wire                                                axi_arburst_tagcmp;
wire                                                axi_arexc_tagcmp;
wire                                                axi_arcache_tagcmp;
wire [                                        2: 0] axi_arsize_tagcmp;
wire [                                       31: 0] axi_araddr_tagcmp;
wire                                                axi_rvalid_tagcmp;
wire [                        AXI_DATA_TAGCMP-1: 0] axi_rdata_tagcmp;
wire [                                        1: 0] axi_rresp_tagcmp;
wire                                                tagcmp_wrbuf_ls_valid_tagcmp;
wire                                                tagcmp_wrbuf_ecc_err_tagcmp;
wire [                       SET_ASSOC_TAGCMP-1: 0] tagcmp_wrbuf_hit_way_tagcmp;
wire                                                tagcmp_wrbuf_wr_tagcmp;
wire [                                        2: 0] tagcmp_wrbuf_bank_sel_tagcmp;
wire [                                        3: 0] tagcmp_wrbuf_strb_tagcmp;
wire [                      INDEX_BITS_TAGCMP-1: 0] tagcmp_wrbuf_indx_tagcmp;
wire [                                       31: 0] tagcmp_wrbuf_wdata_tagcmp;
wire [                       SET_ASSOC_TAGCMP-1: 0] tagcmp_wrbuf_way_lock_tagcmp;
wire                                                tagcmp_wrbuf_lru_wen_tagcmp;
wire                                                tc_hit_mq_tagcmp;
wire                                                tc_st_hit_mq_ok_tagcmp;
wire [                     CC_LINE_AXI_TAGCMP-1: 0] tc_st_hit_mq_sel_tagcmp;
wire [                        AXI_STRB_TAGCMP-1: 0] tc_st_hit_mq_wstrb_tagcmp;
wire [                        AXI_DATA_TAGCMP-1: 0] tc_st_hit_mq_wdata_tagcmp;
wire                                                tc_need_data_tagcmp;
wire                                                tc_need_tagv_tagcmp;
wire                                                tagcmp_missq_valid_tagcmp;
wire                                                tagcmp_missq_aw_do_tagcmp;
wire                                                tagcmp_missq_bacs_tagcmp;
wire                                                tagcmp_missq_exc_tagcmp;
wire                                                tagcmp_missq_cached_tagcmp;
wire [                                       26: 0] tagcmp_missq_araddr31_5_tagcmp;
wire [                                       31: 0] tagcmp_missq_addr_tagcmp;
wire [                        AXI_STRB_TAGCMP-1: 0] tagcmp_missq_strb_tagcmp;
wire [                                        1: 0] tagcmp_missq_size_tagcmp;
wire                                                tagcmp_missq_pref_tagcmp;
wire                                                tagcmp_missq_lock_tagcmp;
wire                                                tagcmp_missq_ccop_do_tagcmp;
wire                                                tagcmp_missq_lock_exist_tagcmp;
wire                                                tagcmp_missq_ccop_valid_tagcmp;
wire                                                tagcmp_missq_ccop_inv_tagcmp;
wire                                                tagcmp_missq_ccop_sttag_tagcmp;
wire                                                tagcmp_missq_ccop_ldtag_tagcmp;
wire                                                tagcmp_missq_ccop_wb_tagcmp;
wire                                                tagcmp_missq_sttag_v_tagcmp;
wire                                                tagcmp_missq_sttag_d_tagcmp;
wire                                                tagcmp_missq_sttag_l_tagcmp;
wire                                                tc_rdata_valid_tagcmp;
wire [                                       31: 0] tc_rdata_tagcmp;
wire                                                tc_rdata_exok_tagcmp;
wire                                                tc_rdata_err_tagcmp;
wire                                                tc_allow_refill_tagcmp;
wire                                                tc_idle_tagcmp;
wire                                                tc_stall_ram_en_tagcmp;
wire                                                tc_allowin_tagcmp;
wire                                                rd_in_tc_tagcmp;
wire                                                wr_in_tc_tagcmp;
wire                                                is_icache_wrbuf;
wire                                                has_ecc_wrbuf;
wire                                                clk_wrbuf;
wire                                                clk_ng_wrbuf;
wire                                                reset_wrbuf;
wire                                                resetn_in_d2_wrbuf;
wire                                                ram_init_cmplt_wrbuf;
wire                                                data_reset_wrbuf;
wire                                                tagcmp_wrbuf_ls_valid_wrbuf;
wire                                                tagcmp_wrbuf_ecc_err_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] tagcmp_wrbuf_hit_way_wrbuf;
wire                                                tagcmp_wrbuf_wr_wrbuf;
wire [                                        2: 0] tagcmp_wrbuf_bank_sel_wrbuf;
wire [                                        3: 0] tagcmp_wrbuf_strb_wrbuf;
wire [                       INDEX_BITS_WRBUF-1: 0] tagcmp_wrbuf_indx_wrbuf;
wire [                                       31: 0] tagcmp_wrbuf_wdata_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] tagcmp_wrbuf_way_lock_wrbuf;
wire                                                tagcmp_wrbuf_lru_wen_wrbuf;
wire                                                missq_wrbuf_ecc_in_wrbuf;
wire                                                missq_wrbuf_correct_wrbuf;
wire [                      RAM_TAGV_WD_WRBUF-1: 0] wrbuf_missq_new_tagv_wrbuf;
wire                                                wrbuf_missq_tagv_1_err_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] wrbuf_missq_tagv_fatal_wrbuf;
wire                                                missq_wrbuf_refill_lru_wrbuf;
wire [                       INDEX_BITS_WRBUF-1: 0] missq_wrbuf_indx_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] missq_wrbuf_way_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] missq_wrbuf_way_lock_wrbuf;
wire                                                missq_wrbuf_lru_clr_wrbuf;
wire                                                missq_wrbuf_dirty_wen_wrbuf;
wire                                                missq_wrbuf_dirty_wdata_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] wrbuf_tagcmp_way_wrbuf;
wire                                                wrbuf_tagcmp_wr_wrbuf;
wire                                                wrbuf_tagcmp_ecc_fatal_wrbuf;
wire                                                wrbuf_tagcmp_hit_bank_wrbuf;
wire [                                        3: 0] wrbuf_tagcmp_strb_wrbuf;
wire [                                       31: 0] wrbuf_tagcmp_wdata_wrbuf;
wire                                                wrbuf_tagcmp_new_valid_wrbuf;
wire [                      RAM_TAGV_WD_WRBUF-1: 0] wrbuf_tagcmp_new_tagv_wrbuf;
wire [                          BANK_WD_WRBUF-1: 0] wrbuf_tagcmp_new_bank_wrbuf;
wire [                      SET_ASSOC_WRBUF*8-1: 0] wrbuf_cache_data_ren_wrbuf;
wire [                      SET_ASSOC_WRBUF*8-1: 0] wrbuf_cache_data_wen_wrbuf;
wire [                      BANK_STRB_WRBUF*8-1: 0] wrbuf_cache_data_strb_wrbuf;
wire [                          BANK_WD_WRBUF-1: 0] wrbuf_cache_data_wdata_wrbuf;
wire [                        ECC_SET_WRBUF*8-1: 0] wrbuf_cache_data_ecc_w_wrbuf;
wire [                    ECC_BANK_BITS_WRBUF-1: 0] wrbuf_cache_data_wecc_wrbuf;
wire                                                wrbuf_cache_tagv_indx_sel_wrbuf;
wire [                                        7: 0] wrbuf_cache_data_indx_sel_wrbuf;
wire [                       INDEX_BITS_WRBUF-1: 0] wrbuf_cache_indx_wrbuf;
wire                                                wrbuf_cache_lrud_wen_wrbuf;
wire                                                wrbuf_cache_lrud_lru_clr_wrbuf;
wire [                       INDEX_BITS_WRBUF-1: 0] wrbuf_cache_lrud_indx_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] wrbuf_cache_lrud_wway_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] wrbuf_cache_lrud_wlock_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] wrbuf_cache_lrud_d_wen_wrbuf;
wire                                                wrbuf_cache_lrud_wdirty_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] wrbuf_cache_tagv_ren_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] wrbuf_cache_tagv_wen_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] wrbuf_cache_tagv_strb_wrbuf;
wire [                      RAM_TAGV_WD_WRBUF-1: 0] wrbuf_cache_tagv_wdata_wrbuf;
wire [                          ECC_SET_WRBUF-1: 0] wrbuf_cache_tagv_ecc_w_wrbuf;
wire [                    ECC_BANK_BITS_WRBUF-1: 0] wrbuf_cache_tagv_wecc_wrbuf;
wire [                      RAM_TAGV_WD_WRBUF-1: 0] tc_tagv_rdata_wrbuf;
wire [                          BANK_WD_WRBUF-1: 0] tc_bank_rdata_wrbuf;
wire [                    ECC_BANK_BITS_WRBUF-1: 0] tc_tagv_old_ecc_wrbuf;
wire [                    ECC_BANK_BITS_WRBUF-1: 0] tc_tagv_ecc_syndrome_wrbuf;
wire [                    ECC_BANK_BITS_WRBUF-1: 0] tc_bank_old_ecc_wrbuf;
wire [                    ECC_BANK_BITS_WRBUF-1: 0] tc_bank_ecc_syndrome_wrbuf;
wire                                                wrbuf_ecc_fatal_wrbuf;
wire                                                ls_ccop_ecc_fatal_wrbuf;
wire [                       INDEX_BITS_WRBUF-1: 0] ecc_fatal_indx_wrbuf;
wire [                        SET_ASSOC_WRBUF-1: 0] ecc_fatal_way_wrbuf;
wire                                                ecc_fatal_intagv_wrbuf;
wire                                                ecc_fatal_indata_wrbuf;
wire                                                ecc_err_add1_wrbuf;
wire                                                mq_stall_req_wrbuf;
wire                                                wrbuf_idle_wrbuf;
wire                                                wrbuf_wr_bank_wrbuf;
wire                                                wrbuf_wr_tagv_wrbuf;
wire [                                        2: 0] wrbuf_lock_bank_wrbuf;
wire                                                has_ecc_mq;
wire                                                clk_mq;
wire                                                reset_mq;
wire                                                data_reset_mq;
wire                                                ctrl_nowrap_mq;
wire                                                axi_ar_ok_mq;
wire                                                axi_rvalid_mq;
wire [                            AXI_DATA_MQ-1: 0] axi_rdata_mq;
wire                                                axi_aw_ok_mq;
wire                                                axi_w_ok_mq;
wire                                                axi_bvalid_mq;
wire [                                        2: 0] axi_bid_mq;
wire [                        32*ECC_WAY_MQ*8-1: 0] cache_ram_missq_data_rdata_mq;
wire                                                tc_allow_refill_mq;
wire                                                tc_hit_mq_mq;
wire                                                tc_st_hit_mq_ok_mq;
wire [                         CC_LINE_AXI_MQ-1: 0] tc_st_hit_mq_sel_mq;
wire [                            AXI_STRB_MQ-1: 0] tc_st_hit_mq_wstrb_mq;
wire [                            AXI_DATA_MQ-1: 0] tc_st_hit_mq_wdata_mq;
wire                                                tagcmp_missq_valid_mq;
wire                                                tagcmp_missq_aw_do_mq;
wire                                                tagcmp_missq_bacs_mq;
wire                                                tagcmp_missq_exc_mq;
wire                                                tagcmp_missq_cached_mq;
wire [                                       26: 0] tagcmp_missq_araddr31_5_mq;
wire [                                       31: 0] tagcmp_missq_addr_mq;
wire [                            AXI_STRB_MQ-1: 0] tagcmp_missq_strb_mq;
wire [                                        1: 0] tagcmp_missq_size_mq;
wire                                                tagcmp_missq_pref_mq;
wire                                                tagcmp_missq_lock_mq;
wire                                                tagcmp_missq_ccop_do_mq;
wire                                                tagcmp_missq_lock_exist_mq;
wire                                                tagcmp_missq_ccop_valid_mq;
wire                                                tagcmp_missq_ccop_inv_mq;
wire                                                tagcmp_missq_ccop_sttag_mq;
wire                                                tagcmp_missq_ccop_ldtag_mq;
wire                                                tagcmp_missq_ccop_wb_mq;
wire                                                tagcmp_missq_sttag_v_mq;
wire                                                tagcmp_missq_sttag_d_mq;
wire                                                tagcmp_missq_sttag_l_mq;
wire                                                wrbuf_allow_refill_mq;
wire                                                missq_wrbuf_ecc_in_mq;
wire                                                missq_wrbuf_correct_mq;
wire [                         RAM_TAGV_WD_MQ-1: 0] wrbuf_missq_new_tagv_mq;
wire                                                wrbuf_missq_tagv_1_err_mq;
wire [                           SET_ASSOC_MQ-1: 0] wrbuf_missq_tagv_fatal_mq;
wire                                                missq_wrbuf_refill_lru_mq;
wire [                          INDEX_BITS_MQ-1: 0] missq_wrbuf_indx_mq;
wire [                           SET_ASSOC_MQ-1: 0] missq_wrbuf_way_mq;
wire [                           SET_ASSOC_MQ-1: 0] missq_wrbuf_way_lock_mq;
wire                                                missq_wrbuf_lru_clr_mq;
wire                                                missq_wrbuf_dirty_wen_mq;
wire                                                missq_wrbuf_dirty_wdata_mq;
wire [                           SET_ASSOC_MQ-1: 0] lru_repl_way_mq;
wire [                           SET_ASSOC_MQ-1: 0] lru_repl_way_d_mq;
wire                                                mq_lrud_ren_mq;
wire [                          INDEX_BITS_MQ-1: 0] mq_lrud_indx_mq;
wire                                                missq_cache_indx_sel_mq;
wire [                          INDEX_BITS_MQ-1: 0] missq_cache_indx_mq;
wire [                           SET_ASSOC_MQ-1: 0] missq_cache_tagv_ren_mq;
wire [                           SET_ASSOC_MQ-1: 0] missq_cache_tagv_wen_mq;
wire [                           SET_ASSOC_MQ-1: 0] missq_cache_tagv_strb_mq;
wire [                         RAM_TAGV_WD_MQ-1: 0] missq_cache_tagv_wdata_mq;
wire [                             ECC_SET_MQ-1: 0] missq_cache_tagv_ecc_w_mq;
wire [                         SET_ASSOC_MQ*8-1: 0] missq_cache_data_ren_mq;
wire [                         SET_ASSOC_MQ*8-1: 0] missq_cache_data_wen_mq;
wire [                         BANK_STRB_MQ*8-1: 0] missq_cache_data_strb_mq;
wire [                        32*ECC_WAY_MQ*8-1: 0] missq_cache_data_wdata_mq;
wire [                           ECC_SET_MQ*8-1: 0] missq_cache_data_ecc_w_mq;
wire                                                missq_tagcmp_allowin_mq;
wire                                                missq_tagcmp_ar_stall_mq;
wire                                                missq_tagcmp_bq_null_mq;
wire                                                missq_tagcmp_bq_full_mq;
wire                                                missq_tagcmp_valid_mq;
wire                                                missq_tagcmp_bacs_mq;
wire                                                missq_tagcmp_wait_wr_mq;
wire [                                       31: 5] missq_tagcmp_addr_31_5_mq;
wire [                         CC_LINE_AXI_MQ-1: 0] missq_tagcmp_buf_valid_mq;
wire [                                      255: 0] missq_tagcmp_buf_data_mq;
wire [                                        2: 0] axi_aw_wid_mq;
wire                                                axi_awvalid_mq;
wire                                                axi_awburst_mq;
wire                                                axi_awexc_mq;
wire                                                axi_awcache_mq;
wire [                                        2: 0] axi_awsize_mq;
wire [                                       31: 0] axi_awaddr_mq;
wire                                                axi_wvalid_mq;
wire [                            AXI_STRB_MQ-1: 0] axi_wstrb_mq;
wire [                            AXI_DATA_MQ-1: 0] axi_wdata_mq;
wire                                                axi_wlast_mq;
wire                                                cps_data_ok_mq;
wire [                                       31: 0] cps_rdata_mq;
wire [                          ECC_BITS_MQ*8-1: 0] mqway_ecc_syndrome_mq;
wire                                                missq_ecc_gen_new_ecc_mq;
wire                                                missq_ecc_gen_old_ecc_mq;
wire [                             ECC_SET_MQ-1: 0] missq_ecc_refill_eccset_mq;
wire                                                mq_impr_fatal_mq;
wire [                          INDEX_BITS_MQ-1: 0] ecc_fatal_indx_mq;
wire [                           SET_ASSOC_MQ-1: 0] ecc_fatal_way_mq;
wire                                                ecc_fatal_intagv_mq;
wire [                                        7: 0] ecc_fatal_indata_mq;
wire                                                ecc_fatal_dirtywb_mq;
wire [                            TAG_BITS_MQ-1: 0] ecc_fatal_dirty_tag_mq;
wire                                                ecc_err_add1_mq;
wire                                                refill_add1_mq;
wire                                                mq_stall_req_mq;
wire                                                mq_idle_mq;
wire                                                mq_bq_null_mq;
wire [DATA_BITS_BANK_ECC0*SET_ASSOC_BANK_ECC0-1: 0] bank_rdata_bank_ecc0;
wire [                ECC_BANK_BITS_BANK_ECC0-1: 0] bank_recc_bank_ecc0;
wire [                      ECC_SET_BANK_ECC0-1: 0] mq_refill_eccset_bank_ecc0;
wire                                                tc_err_bank_ecc0;
wire [                ECC_BANK_BITS_BANK_ECC0-1: 0] tc_ecc_syndrome_bank_ecc0;
wire [                ECC_BANK_BITS_BANK_ECC0-1: 0] mq_gen_ecc_all_bank_ecc0;
wire [DATA_BITS_BANK_ECC1*SET_ASSOC_BANK_ECC1-1: 0] bank_rdata_bank_ecc1;
wire [                ECC_BANK_BITS_BANK_ECC1-1: 0] bank_recc_bank_ecc1;
wire [                      ECC_SET_BANK_ECC1-1: 0] mq_refill_eccset_bank_ecc1;
wire                                                tc_err_bank_ecc1;
wire [                ECC_BANK_BITS_BANK_ECC1-1: 0] tc_ecc_syndrome_bank_ecc1;
wire [                     ECC_BITS_BANK_ECC1-1: 0] mq_gen_ecc_one_bank_ecc1;
wire [                     ECC_BITS_BANK_ECC1-1: 0] mq_ecc_syndrome_bank_ecc1;
wire [                   32*ECC_WAY_WAY_ECC*7-1: 0] way_rdata_way_ecc;
wire [                     ECC_BITS_WAY_ECC*7-1: 0] way_old_ecc_way_ecc;
wire [                     ECC_BITS_WAY_ECC*7-1: 0] way_gen_ecc_way_ecc;
wire [                     ECC_BITS_WAY_ECC*7-1: 0] way_ecc_syndrome_way_ecc;
wire                                                wrbuf_lrud_wen_lru;
wire                                                wrbuf_lrud_lru_clr_lru;
wire [                         INDEX_BITS_LRU-1: 0] wrbuf_lrud_indx_lru;
wire [                          SET_ASSOC_LRU-1: 0] wrbuf_lrud_wway_lru;
wire [                          SET_ASSOC_LRU-1: 0] wrbuf_lrud_wlock_lru;
wire [                          SET_ASSOC_LRU-1: 0] wrbuf_lrud_d_wen_lru;
wire                                                wrbuf_lrud_wdirty_lru;
wire                                                mq_lrud_ren_lru;
wire [                         INDEX_BITS_LRU-1: 0] mq_lrud_indx_lru;
wire [                        RAM_LRUD_WD_LRU-1: 0] ram_lrud_rdata_lru;
wire                                                ram_lrud_en_lru;
wire [                        RAM_LRUD_WD_LRU-1: 0] ram_lrud_wen_lru;
wire [                         INDEX_BITS_LRU-1: 0] ram_lrud_addr_lru;
wire [                        RAM_LRUD_WD_LRU-1: 0] ram_lrud_wdata_lru;
wire [                          SET_ASSOC_LRU-1: 0] lru_repl_way_lru;
wire [                          SET_ASSOC_LRU-1: 0] lru_repl_way_d_lru;

// has ecc
wire          has_ecc;

// control
// cc_op[5:0]
//   [5]       [4]       [3]      [2]     [1]   [0]
// StoreTag  LoadTag  Writeback  invalid  Index  hit
wire          ccop_req;      // cache/isync
wire          hit_ccop_req;  // hit(not index) cache/isync
wire          cps_req;       // cache/isync/pref
wire          lookup_req;    // load/store/pref/cache op
wire          ls_req_nocps;  // load/store but not cps_req
wire          cps_req_go;    // cache/isync/pref and mq_idle
wire          cache_idle;    // tc/mq/wrbuf idle

wire          tc_stall_ram_en;
wire          mq_stall_req;
wire          wrbuf_stall_req;
wire          req_stall;
wire          real_req;

wire [ 31: 0] req_wdata;

wire [INDEX_BITS-1: 0] ifc_req_index;
wire [  TAG_BITS-1: 0] ifc_req_tag;

wire          stall_access;

// read tagv
wire [ SET_ASSOC-1: 0] req_tagv_ren;
wire [INDEX_BITS-1: 0] req_tagv_indx;

// read data
wire [SET_ASSOC-1: 0] req_data_ren[  7: 0];

// pipeline control
wire          tc_allowin;
wire          tc_idle;
wire          mq_idle;
wire          mq_bq_null;     // all axi-b back
wire          wrbuf_idle;
wire          all_req_cango;

// axi
wire          axi_ar_ok;

// cache ram
wire [RAM_TAGV_WD-1: 0] cache_ram_tagcmp_tagv_rdata;
wire [            2: 0] tagcmp_cache_ram_bank_sel;
wire [    BANK_WD-1: 0] cache_ram_tagcmp_bank_rdata;  // one bank
wire                    cache_ram_tagcmp_tagv_err;    // there are errors in access cache tagv
wire                    cache_ram_tagcmp_bank_err;    // there are errors in access cache data

// wrbuf_tagcmp_bus
wire [  SET_ASSOC-1: 0] wrbuf_tagcmp_way;
wire                    wrbuf_tagcmp_wr;
wire                    wrbuf_tagcmp_ecc_fatal;
wire                    wrbuf_tagcmp_hit_bank;
wire [            3: 0] wrbuf_tagcmp_strb;
wire [           31: 0] wrbuf_tagcmp_wdata;
wire                    wrbuf_tagcmp_new_valid;  // for ecc correct
wire [RAM_TAGV_WD-1: 0] wrbuf_tagcmp_new_tagv;
wire [    BANK_WD-1: 0] wrbuf_tagcmp_new_bank;   // one bank

// from missq
wire                    missq_tagcmp_allowin;
wire                    missq_tagcmp_ar_stall;
wire                    missq_tagcmp_bq_null;
wire                    missq_tagcmp_bq_full;
wire                    missq_tagcmp_valid;
wire                    missq_tagcmp_bacs;
wire                    missq_tagcmp_wait_wr;
wire [           31: 5] missq_tagcmp_addr_31_5;
wire [CC_LINE_AXI-1: 0] missq_tagcmp_buf_valid;
wire [          255: 0] missq_tagcmp_buf_data;

// to wrbuf
wire                   tagcmp_wrbuf_ls_valid;  // no ecc error
wire                   tagcmp_wrbuf_ecc_err;
wire [ SET_ASSOC-1: 0] tagcmp_wrbuf_hit_way;
wire                   tagcmp_wrbuf_wr;
wire [           2: 0] tagcmp_wrbuf_bank_sel;
wire [           3: 0] tagcmp_wrbuf_strb;
wire [INDEX_BITS-1: 0] tagcmp_wrbuf_indx;
wire [          31: 0] tagcmp_wrbuf_wdata;
wire [ SET_ASSOC-1: 0] tagcmp_wrbuf_way_lock;
wire                   tagcmp_wrbuf_lru_wen;

// to missq
wire                    tc_hit_mq;
wire                    tc_st_hit_mq_ok;
wire [CC_LINE_AXI-1: 0] tc_st_hit_mq_sel;         // need see tc_st_hit_mq_ok
wire [   AXI_STRB-1: 0] tc_st_hit_mq_wstrb;
wire [   AXI_DATA-1: 0] tc_st_hit_mq_wdata;
wire                    tc_need_data;
wire                    tc_need_tagv;
wire                    tagcmp_missq_valid;       // tc_valid
wire                    tagcmp_missq_aw_do;       // go mq to send aw
wire                    tagcmp_missq_bacs;
wire                    tagcmp_missq_exc;         // exclusive
wire                    tagcmp_missq_cached;
wire [           26: 0] tagcmp_missq_araddr31_5;
wire [           31: 0] tagcmp_missq_addr;
wire [   AXI_STRB-1: 0] tagcmp_missq_strb;
wire [            1: 0] tagcmp_missq_size;
wire                    tagcmp_missq_pref;
wire                    tagcmp_missq_lock;
wire                    tagcmp_missq_ccop_do;
wire                    tagcmp_missq_lock_exist;
wire                    tagcmp_missq_ccop_valid;
wire                    tagcmp_missq_ccop_inv;
wire                    tagcmp_missq_ccop_sttag;
wire                    tagcmp_missq_ccop_ldtag;
wire                    tagcmp_missq_ccop_wb;
wire                    tagcmp_missq_sttag_v;
wire                    tagcmp_missq_sttag_d;
wire                    tagcmp_missq_sttag_l;

// pipeline control
// load/store request is prior to mq_refill
wire          tc_allow_refill;

// wrbuf to data ram
wire [  SET_ASSOC*8-1: 0] wrbuf_cache_data_ren;    // all bank
wire [  SET_ASSOC*8-1: 0] wrbuf_cache_data_wen;    // all bank
wire [  BANK_STRB*8-1: 0] wrbuf_cache_data_strb;   // all bank
wire [      BANK_WD-1: 0] wrbuf_cache_data_wdata;  // only one bank
wire [    ECC_SET*8-1: 0] wrbuf_cache_data_ecc_w;  // all bank
wire [ECC_BANK_BITS-1: 0] wrbuf_cache_data_wecc;   // only one bank

wire                   wrbuf_cache_tagv_indx_sel;
wire [           7: 0] wrbuf_cache_data_indx_sel;
wire [INDEX_BITS-1: 0] wrbuf_cache_indx;

// wrbuf to lru
wire                   wrbuf_cache_lrud_wen;
wire                   wrbuf_cache_lru_clr;
wire                   wrbuf_cache_lrud_lru_clr;
wire [INDEX_BITS-1: 0] wrbuf_cache_lrud_indx;
wire [ SET_ASSOC-1: 0] wrbuf_cache_lrud_wway;
wire [ SET_ASSOC-1: 0] wrbuf_cache_lrud_wlock;
wire [ SET_ASSOC-1: 0] wrbuf_cache_lrud_d_wen;
wire                   wrbuf_cache_lrud_wdirty;

// wrbuf to tagv ram
wire [    SET_ASSOC-1: 0] wrbuf_cache_tagv_ren;
wire [    SET_ASSOC-1: 0] wrbuf_cache_tagv_wen;
wire [    SET_ASSOC-1: 0] wrbuf_cache_tagv_strb;
wire [  RAM_TAGV_WD-1: 0] wrbuf_cache_tagv_wdata;
wire [      ECC_SET-1: 0] wrbuf_cache_tagv_ecc_w;
wire [ECC_BANK_BITS-1: 0] wrbuf_cache_tagv_wecc;

// for ecc
wire [  RAM_TAGV_WD-1: 0] tc_tagv_rdata;
wire [      BANK_WD-1: 0] tc_bank_rdata;            // one bank
wire [ECC_BANK_BITS-1: 0] tc_tagv_old_ecc;          // all ways
wire [ECC_BANK_BITS-1: 0] tc_tagv_ecc_syndrome;     // all ways
wire [ECC_BANK_BITS-1: 0] tc_bank_old_ecc;          // all ways in one bank
wire [ECC_BANK_BITS-1: 0] tc_bank_ecc_syndrome;     // all ways in one bank
wire                      wrbuf_ecc_fatal;
wire                      wrbuf_ls_ccop_ecc_fatal;
wire [   INDEX_BITS-1: 0] wrbuf_ecc_fatal_indx;
wire [    SET_ASSOC-1: 0] wrbuf_ecc_fatal_way;
wire                      wrbuf_ecc_fatal_intagv;
wire                      wrbuf_ecc_fatal_indata;
wire                      wrbuf_ecc_err_add1;

// mq to wrbuf; use tagv_correct
wire                    missq_wrbuf_ecc_in;      // mq gen old ecc
wire                    missq_wrbuf_correct;     // mq correct tagv
wire [RAM_TAGV_WD-1: 0] wrbuf_missq_new_tagv;
wire                    wrbuf_missq_tagv_1_err;  // 1 bit error
wire [  SET_ASSOC-1: 0] wrbuf_missq_tagv_fatal;  // 2 bit error

// mq to wrbuf; set/clear lrud
wire                   missq_wrbuf_refill_lru;
wire [INDEX_BITS-1: 0] missq_wrbuf_indx;
wire [ SET_ASSOC-1: 0] missq_wrbuf_way;
wire [ SET_ASSOC-1: 0] missq_wrbuf_way_lock;
wire                   missq_wrbuf_lru_clr;
wire                   missq_wrbuf_dirty_wen;
wire                   missq_wrbuf_dirty_wdata;

// pipeline control
wire          wrbuf_wr_bank;
wire          wrbuf_wr_tagv;
wire [  2: 0] wrbuf_lock_bank;

// store/load bank conflict
wire          wrbuf_bank_conflict;

wire          wrbuf_allow_refill;

// axi
wire          axi_aw_ok;
wire          axi_w_ok;

// cache ram
wire [32*ECC_WAY*8-1: 0] cache_ram_missq_data_rdata;  // 8 bank

// from lru
wire [SET_ASSOC-1: 0] lru_repl_way;
wire [SET_ASSOC-1: 0] lru_repl_way_d;

// to lru
wire                   mq_lrud_ren;
wire [INDEX_BITS-1: 0] mq_lrud_indx;

// to cache ram
wire                     missq_cache_indx_sel;
wire [  INDEX_BITS-1: 0] missq_cache_indx;
wire [   SET_ASSOC-1: 0] missq_cache_tagv_ren;
wire [   SET_ASSOC-1: 0] missq_cache_tagv_wen;
wire [   SET_ASSOC-1: 0] missq_cache_tagv_strb;   // only set if wen is 1
wire [ RAM_TAGV_WD-1: 0] missq_cache_tagv_wdata;  // all way
wire [     ECC_SET-1: 0] missq_cache_tagv_ecc_w;
wire [ SET_ASSOC*8-1: 0] missq_cache_data_ren;
wire [ SET_ASSOC*8-1: 0] missq_cache_data_wen;
wire [ BANK_STRB*8-1: 0] missq_cache_data_strb;
wire [32*ECC_WAY*8-1: 0] missq_cache_data_wdata;
wire [   ECC_SET*8-1: 0] missq_cache_data_ecc_w;  // all bank, one eccset, if no ecc, one way

// for ecc
wire [ECC_BITS*8-1: 0] mqway_ecc_syndrome;       // all banks in one way
wire                   missq_ecc_gen_new_ecc;    // gen refill   data ecc in state_lru_cmp
wire                   missq_ecc_gen_old_ecc;    // gen replaced data ecc in state_gen_ecc
wire [   ECC_SET-1: 0] missq_ecc_refill_eccset;
wire                   mq_impr_fatal;
wire [INDEX_BITS-1: 0] mq_ecc_fatal_indx;
wire [ SET_ASSOC-1: 0] mq_ecc_fatal_way;
wire                   mq_ecc_fatal_intagv;
wire [           7: 0] mq_ecc_fatal_indata;
wire                   mq_ecc_fatal_dirtywb;     // 2bit err data has been writeback.
wire [  TAG_BITS-1: 0] mq_ecc_fatal_dirty_tag;
wire                   mq_ecc_err_add1;
wire                   mq_refill_add1;

wire [32*ECC_WAY-1: 0] mq_data_wdata[  7: 0];

// for tagcmp: all ways' tagv ecc to wrbuf
// for mq    : one ways' tagv ecc to mq
wire [  RAM_TAGV_WD-1: 0] ecc_tagv_rdata;
wire [ECC_BANK_BITS-1: 0] ecc_tagv_old_ecc;     // all ways
wire [ECC_BANK_BITS-1: 0] mq_tagv_gen_ecc_all;  // all ecc set

wire                      tc_tagv_err;               // there are errors in any way
wire [ECC_BANK_BITS-1: 0] tc_tagv_ecc_syndrome_tmp;  // all ways

// for tagcmp: all ways' selected bank ecc to wrbuf
// for mq    : one ways' bank0 ecc to mq
// select rdata recc
wire [      BANK_WD-1: 0] sel_bank_rdata;
wire [ECC_BANK_BITS-1: 0] sel_bank_recc;

wire                      tc_bank_err;               // errors in any way for tc selected bank
wire [ECC_BANK_BITS-1: 0] tc_bank_ecc_syndrome_tmp;  // all ways' one bank
wire [     ECC_BITS-1: 0] mq_bank0_gen_ecc;          // one way's bank0
wire [     ECC_BITS-1: 0] mq_bank0_ecc_syndrome;     // one way's bank0

// data 7 bank ecc
// for mq    : one ways' one ecc_set ecc to mq for all banks
wire [  32*ECC_WAY-1: 0] mq_eccset_rdata[  7: 0];       // bank0~7
wire [    ECC_BITS-1: 0] mq_eccset_old_ecc[  7: 0];
wire [  32*ECC_WAY-1: 0] bank7_eccset_rdata[  6: 0];    // bank1~7
wire [    ECC_BITS-1: 0] bank7_eccset_old_ecc[  6: 0];
wire [32*ECC_WAY*7-1: 0] bank7_rdata;                   // 7 banks
wire [  ECC_BITS*7-1: 0] bank7_old_ecc;                 // 7 banks
wire [  ECC_BITS*7-1: 0] bank7_gen_ecc;                 // 7 banks
wire [  ECC_BITS*7-1: 0] bank7_ecc_syndrome;            // 7 banks

// bank0~7 data and ecc
wire [ECC_BITS*8-1: 0] mqway_gen_ecc;  // all banks in one way one eccset

wire          ccop_ldsttag;

// mq reill ecc
wire [ECC_BANK_BITS-1: 0] missq_cache_tagv_wecc_allset;           // all eccset
wire [   ECC_BITS*8-1: 0] missq_cache_data_wecc_eccset;           // one eccset
wire [     ECC_BITS-1: 0] missq_cache_data_wecc_perbank[  7: 0];

// to lrud ram
wire                    ram_lrud_en;
wire [RAM_LRUD_WD-1: 0] ram_lrud_wen;
wire [ INDEX_BITS-1: 0] ram_lrud_addr;
wire [RAM_LRUD_WD-1: 0] ram_lrud_wdata;
wire [RAM_LRUD_WD-1: 0] ram_lrud_rdata;

// 4x1:
// miss-queue(r)  miss-queue(w)  cache_req(r)  wrbuf(r)     wrbuf(w)
//    |_______________|______________|____________|__________|
//                            |
//                          TAG/V
wire [  SET_ASSOC-1: 0] ram_tagv_en;
wire [    ECC_SET-1: 0] ram_tagv_wen;    // if no ecc, ECC_SET==SET_ASSOC
wire [ INDEX_BITS-1: 0] ram_tagv_addr;
wire [RAM_TAGV_WD-1: 0] ram_tagv_wdata;
wire [RAM_TAGV_WD-1: 0] ram_tagv_rdata;

// for ecc
wire [ECC_BANK_BITS-1: 0] ram_tagv_wecc;
wire [ECC_BANK_BITS-1: 0] ram_tagv_recc;  // all ways; zero when ECC is disabled

wire [          RAM_TAGV_WD_ECC-1: 0] ram_tagv_wall;      // data+ecc
wire [          RAM_TAGV_WD_ECC-1: 0] ram_tagv_rall;      // data+ecc

// icache fatal in refilling will set unchanged way's tagv invalid
wire          icache_fatal;

// 4x1:
// miss-queue(r)  miss-queue(w)  request(r)  wr_buf(r)    wr_buf(w)
//    |_______________|_____________|__________|___________|
//                         |
//                        DATA
wire [ SET_ASSOC-1: 0] ram_data_en[  7: 0];
wire [  BANK_WEN-1: 0] ram_data_wen[  7: 0];
wire [INDEX_BITS-1: 0] ram_data_addr[  7: 0];
wire [   BANK_WD-1: 0] ram_data_wdata[  7: 0];
wire [   BANK_WD-1: 0] ram_data_rdata[  7: 0];

// for ecc
wire [ECC_BANK_BITS-1: 0] ram_data_wecc[  7: 0];
wire [ECC_BANK_BITS-1: 0] ram_data_recc[  7: 0];

wire [          BANK_WD_ECC-1: 0] ram_data_wall[  7: 0];      // data+ecc
wire [          BANK_WD_ECC-1: 0] ram_data_rall[  7: 0];      // data+ecc

// sel bank rdata
wire [  2: 0] ram_bank_sel;

// Replaced data and ECC: select one ECC set from each physical bank.
wire [32*ECC_WAY-1: 0] mq_rdata_perecc[  7: 0][ECC_SET-1: 0];
wire [  ECC_BITS-1: 0] ram_data_recc_eccset[  7: 0][ECC_SET-1: 0];

// for per bank
wire [SET_ASSOC-1: 0] wrbuf_data_ren[  7: 0];
wire [SET_ASSOC-1: 0] wrbuf_data_wen[  7: 0];
wire [SET_ASSOC-1: 0] mq_data_ren[  7: 0];
wire [SET_ASSOC-1: 0] mq_data_wen[  7: 0];
wire [BANK_STRB-1: 0] wrbuf_data_strb[  7: 0];
wire [BANK_STRB-1: 0] mq_data_strb[  7: 0];
wire [  ECC_SET-1: 0] wrbuf_data_ecc_w[  7: 0];
wire [  ECC_SET-1: 0] mq_data_ecc_w[  7: 0];

//============================================================//
//                    Module Implementation
//============================================================//

// Instance Parameter Aliases
// x_lsu_tagcmp
// x_lsu_wrbuf
// x_lsu_mq
// x_lsu_bank_ecc_0
// x_lsu_bank_ecc_1
// x_lsu_way_ecc
// x_lsu_lru

// Instance Boundary Alias Mapping
// x_lsu_tagcmp

assign has_ecc_tagcmp                      =  has_ecc;
assign clk_tagcmp                          =  clk;
assign reset_tagcmp                        =  reset;
assign data_reset_tagcmp                   =  data_reset;
assign ex_cancel_tagcmp                    =  ex_cancel;
assign bypass_tagcmp                       =  bypass;
assign ctrl_nowrap_tagcmp                  =  ctrl_nowrap;
assign real_req_tagcmp                     =  real_req;
assign ls_req_nocps_tagcmp                 =  ls_req_nocps;
assign req_wdata_tagcmp                    =  req_wdata;
assign req_rd_tagcmp                       =  req_rd;
assign req_exc_tagcmp                      =  req_exc;
assign size_tagcmp                         =  size;
`ifdef CONFIG_MMU
assign vaddr_tagcmp                        =  vaddr;
`else
assign vaddr_h3_tagcmp                     =  vaddr_h3;
`endif
assign paddr_tagcmp                        =  paddr;
`ifdef CONFIG_MMU
assign req_xlat_wait_tagcmp                =  req_xlat_wait;
assign req_attr_vld_tagcmp                 =  req_attr_vld;
assign req_sob_tagcmp                      =  req_sob;
assign req_cached_tagcmp                   =  req_cached;
assign req_alloc_tagcmp                    =  req_alloc;
assign xlat_vld_tagcmp                     =  xlat_vld;
assign xlat_cancel_tagcmp                  =  xlat_cancel;
assign xlat_paddr_tagcmp                   =  xlat_paddr;
assign xlat_sob_tagcmp                     =  xlat_sob;
assign xlat_cached_tagcmp                  =  xlat_cached;
assign xlat_alloc_tagcmp                   =  xlat_alloc;
`endif
assign cc_op_tagcmp                        =  cc_op;
assign cc_isync_tagcmp                     =  cc_isync;
assign cc_pref_tagcmp                      =  cc_pref;
assign cc_lock_tagcmp                      =  cc_lock;
assign axi_ar_ok_tagcmp                    =  axi_ar_ok;
assign go_mmu_vaddr                        =  go_mmu_vaddr_tagcmp;
assign go_mmu_read                         =  go_mmu_read_tagcmp;
assign go_mmu_dbgm                         =  go_mmu_dbgm_tagcmp;
assign mmu_sob_tagcmp                      =  mmu_sob;
assign mmu_cached_tagcmp                   =  mmu_cached;
assign mmu_alloc_tagcmp                    =  mmu_alloc;
assign cache_ram_tagcmp_tagv_rdata_tagcmp  =  cache_ram_tagcmp_tagv_rdata;
assign tagcmp_cache_ram_bank_sel           =  tagcmp_cache_ram_bank_sel_tagcmp;
assign cache_ram_tagcmp_bank_rdata_tagcmp  =  cache_ram_tagcmp_bank_rdata;
assign cache_ram_tagcmp_tagv_err_tagcmp    =  cache_ram_tagcmp_tagv_err;
assign cache_ram_tagcmp_bank_err_tagcmp    =  cache_ram_tagcmp_bank_err;
assign wrbuf_tagcmp_way_tagcmp             =  wrbuf_tagcmp_way;
assign wrbuf_tagcmp_wr_tagcmp              =  wrbuf_tagcmp_wr;
assign wrbuf_tagcmp_ecc_fatal_tagcmp       =  wrbuf_tagcmp_ecc_fatal;
assign wrbuf_tagcmp_hit_bank_tagcmp        =  wrbuf_tagcmp_hit_bank;
assign wrbuf_tagcmp_strb_tagcmp            =  wrbuf_tagcmp_strb;
assign wrbuf_tagcmp_wdata_tagcmp           =  wrbuf_tagcmp_wdata;
assign wrbuf_tagcmp_new_valid_tagcmp       =  wrbuf_tagcmp_new_valid;
assign wrbuf_tagcmp_new_tagv_tagcmp        =  wrbuf_tagcmp_new_tagv;
assign wrbuf_tagcmp_new_bank_tagcmp        =  wrbuf_tagcmp_new_bank;
assign missq_tagcmp_allowin_tagcmp         =  missq_tagcmp_allowin;
assign missq_tagcmp_ar_stall_tagcmp        =  missq_tagcmp_ar_stall;
assign missq_tagcmp_bq_null_tagcmp         =  missq_tagcmp_bq_null;
assign missq_tagcmp_bq_full_tagcmp         =  missq_tagcmp_bq_full;
assign missq_tagcmp_valid_tagcmp           =  missq_tagcmp_valid;
assign missq_tagcmp_bacs_tagcmp            =  missq_tagcmp_bacs;
assign missq_tagcmp_wait_wr_tagcmp         =  missq_tagcmp_wait_wr;
assign missq_tagcmp_addr_31_5_tagcmp       =  missq_tagcmp_addr_31_5;
assign missq_tagcmp_buf_valid_tagcmp       =  missq_tagcmp_buf_valid;
assign missq_tagcmp_buf_data_tagcmp        =  missq_tagcmp_buf_data;
assign req2dbgm_tagcmp                     =  req2dbgm;
assign dbgm_req_valid                      =  dbgm_req_valid_tagcmp;
assign dbgm_req_wr                         =  dbgm_req_wr_tagcmp;
assign dbgm_req_addr                       =  dbgm_req_addr_tagcmp;
assign dbgm_req_size                       =  dbgm_req_size_tagcmp;
assign dbgm_req_wdata                      =  dbgm_req_wdata_tagcmp;
assign dbgm_resp_valid_tagcmp              =  dbgm_resp_valid;
assign dbgm_resp_data_tagcmp               =  dbgm_resp_data;
assign axi_arvalid                         =  axi_arvalid_tagcmp;
assign axi_arburst                         =  axi_arburst_tagcmp;
assign axi_arexc                           =  axi_arexc_tagcmp;
assign axi_arcache                         =  axi_arcache_tagcmp;
assign axi_arsize                          =  axi_arsize_tagcmp;
assign axi_araddr                          =  axi_araddr_tagcmp;
assign axi_rvalid_tagcmp                   =  axi_rvalid;
assign axi_rdata_tagcmp                    =  axi_rdata;
assign axi_rresp_tagcmp                    =  axi_rresp;
assign tagcmp_wrbuf_ls_valid               =  tagcmp_wrbuf_ls_valid_tagcmp;
assign tagcmp_wrbuf_ecc_err                =  tagcmp_wrbuf_ecc_err_tagcmp;
assign tagcmp_wrbuf_hit_way                =  tagcmp_wrbuf_hit_way_tagcmp;
assign tagcmp_wrbuf_wr                     =  tagcmp_wrbuf_wr_tagcmp;
assign tagcmp_wrbuf_bank_sel               =  tagcmp_wrbuf_bank_sel_tagcmp;
assign tagcmp_wrbuf_strb                   =  tagcmp_wrbuf_strb_tagcmp;
assign tagcmp_wrbuf_indx                   =  tagcmp_wrbuf_indx_tagcmp;
assign tagcmp_wrbuf_wdata                  =  tagcmp_wrbuf_wdata_tagcmp;
assign tagcmp_wrbuf_way_lock               =  tagcmp_wrbuf_way_lock_tagcmp;
assign tagcmp_wrbuf_lru_wen                =  tagcmp_wrbuf_lru_wen_tagcmp;
assign tc_hit_mq                           =  tc_hit_mq_tagcmp;
assign tc_st_hit_mq_ok                     =  tc_st_hit_mq_ok_tagcmp;
assign tc_st_hit_mq_sel                    =  tc_st_hit_mq_sel_tagcmp;
assign tc_st_hit_mq_wstrb                  =  tc_st_hit_mq_wstrb_tagcmp;
assign tc_st_hit_mq_wdata                  =  tc_st_hit_mq_wdata_tagcmp;
assign tc_need_data                        =  tc_need_data_tagcmp;
assign tc_need_tagv                        =  tc_need_tagv_tagcmp;
assign tagcmp_missq_valid                  =  tagcmp_missq_valid_tagcmp;
assign tagcmp_missq_aw_do                  =  tagcmp_missq_aw_do_tagcmp;
assign tagcmp_missq_bacs                   =  tagcmp_missq_bacs_tagcmp;
assign tagcmp_missq_exc                    =  tagcmp_missq_exc_tagcmp;
assign tagcmp_missq_cached                 =  tagcmp_missq_cached_tagcmp;
assign tagcmp_missq_araddr31_5             =  tagcmp_missq_araddr31_5_tagcmp;
assign tagcmp_missq_addr                   =  tagcmp_missq_addr_tagcmp;
assign tagcmp_missq_strb                   =  tagcmp_missq_strb_tagcmp;
assign tagcmp_missq_size                   =  tagcmp_missq_size_tagcmp;
assign tagcmp_missq_pref                   =  tagcmp_missq_pref_tagcmp;
assign tagcmp_missq_lock                   =  tagcmp_missq_lock_tagcmp;
assign tagcmp_missq_ccop_do                =  tagcmp_missq_ccop_do_tagcmp;
assign tagcmp_missq_lock_exist             =  tagcmp_missq_lock_exist_tagcmp;
assign tagcmp_missq_ccop_valid             =  tagcmp_missq_ccop_valid_tagcmp;
assign tagcmp_missq_ccop_inv               =  tagcmp_missq_ccop_inv_tagcmp;
assign tagcmp_missq_ccop_sttag             =  tagcmp_missq_ccop_sttag_tagcmp;
assign tagcmp_missq_ccop_ldtag             =  tagcmp_missq_ccop_ldtag_tagcmp;
assign tagcmp_missq_ccop_wb                =  tagcmp_missq_ccop_wb_tagcmp;
assign tagcmp_missq_sttag_v                =  tagcmp_missq_sttag_v_tagcmp;
assign tagcmp_missq_sttag_d                =  tagcmp_missq_sttag_d_tagcmp;
assign tagcmp_missq_sttag_l                =  tagcmp_missq_sttag_l_tagcmp;
assign rdata_valid                         =  tc_rdata_valid_tagcmp;
assign rdata                               =  tc_rdata_tagcmp;
assign rdata_exok                          =  tc_rdata_exok_tagcmp;
assign rdata_err                           =  tc_rdata_err_tagcmp;
assign tc_allow_refill                     =  tc_allow_refill_tagcmp;
assign tc_idle                             =  tc_idle_tagcmp;
assign tc_stall_ram_en                     =  tc_stall_ram_en_tagcmp;
assign tc_allowin                          =  tc_allowin_tagcmp;
assign rd_in_sysbus                        =  rd_in_tc_tagcmp;
assign wr_in_sysbus                        =  wr_in_tc_tagcmp;
// x_lsu_wrbuf
assign is_icache_wrbuf                =  is_icache;
assign has_ecc_wrbuf                  =  has_ecc;
assign clk_wrbuf                      =  clk;
assign clk_ng_wrbuf                   =  clk_ng;
assign reset_wrbuf                    =  reset;
assign resetn_in_d2_wrbuf             =  resetn_in_d2;
assign ram_init_cmplt                 =  ram_init_cmplt_wrbuf;
assign data_reset_wrbuf               =  data_reset;
assign tagcmp_wrbuf_ls_valid_wrbuf    =  tagcmp_wrbuf_ls_valid;
assign tagcmp_wrbuf_ecc_err_wrbuf     =  tagcmp_wrbuf_ecc_err;
assign tagcmp_wrbuf_hit_way_wrbuf     =  tagcmp_wrbuf_hit_way;
assign tagcmp_wrbuf_wr_wrbuf          =  tagcmp_wrbuf_wr;
assign tagcmp_wrbuf_bank_sel_wrbuf    =  tagcmp_wrbuf_bank_sel;
assign tagcmp_wrbuf_strb_wrbuf        =  tagcmp_wrbuf_strb;
assign tagcmp_wrbuf_indx_wrbuf        =  tagcmp_wrbuf_indx;
assign tagcmp_wrbuf_wdata_wrbuf       =  tagcmp_wrbuf_wdata;
assign tagcmp_wrbuf_way_lock_wrbuf    =  tagcmp_wrbuf_way_lock;
assign tagcmp_wrbuf_lru_wen_wrbuf     =  tagcmp_wrbuf_lru_wen;
assign missq_wrbuf_ecc_in_wrbuf       =  missq_wrbuf_ecc_in;
assign missq_wrbuf_correct_wrbuf      =  missq_wrbuf_correct;
assign wrbuf_missq_new_tagv           =  wrbuf_missq_new_tagv_wrbuf;
assign wrbuf_missq_tagv_1_err         =  wrbuf_missq_tagv_1_err_wrbuf;
assign wrbuf_missq_tagv_fatal         =  wrbuf_missq_tagv_fatal_wrbuf;
assign missq_wrbuf_refill_lru_wrbuf   =  missq_wrbuf_refill_lru;
assign missq_wrbuf_indx_wrbuf         =  missq_wrbuf_indx;
assign missq_wrbuf_way_wrbuf          =  missq_wrbuf_way;
assign missq_wrbuf_way_lock_wrbuf     =  missq_wrbuf_way_lock;
assign missq_wrbuf_lru_clr_wrbuf      =  missq_wrbuf_lru_clr;
assign missq_wrbuf_dirty_wen_wrbuf    =  missq_wrbuf_dirty_wen;
assign missq_wrbuf_dirty_wdata_wrbuf  =  missq_wrbuf_dirty_wdata;
assign wrbuf_tagcmp_way               =  wrbuf_tagcmp_way_wrbuf;
assign wrbuf_tagcmp_wr                =  wrbuf_tagcmp_wr_wrbuf;
assign wrbuf_tagcmp_ecc_fatal         =  wrbuf_tagcmp_ecc_fatal_wrbuf;
assign wrbuf_tagcmp_hit_bank          =  wrbuf_tagcmp_hit_bank_wrbuf;
assign wrbuf_tagcmp_strb              =  wrbuf_tagcmp_strb_wrbuf;
assign wrbuf_tagcmp_wdata             =  wrbuf_tagcmp_wdata_wrbuf;
assign wrbuf_tagcmp_new_valid         =  wrbuf_tagcmp_new_valid_wrbuf;
assign wrbuf_tagcmp_new_tagv          =  wrbuf_tagcmp_new_tagv_wrbuf;
assign wrbuf_tagcmp_new_bank          =  wrbuf_tagcmp_new_bank_wrbuf;
assign wrbuf_cache_data_ren           =  wrbuf_cache_data_ren_wrbuf;
assign wrbuf_cache_data_wen           =  wrbuf_cache_data_wen_wrbuf;
assign wrbuf_cache_data_strb          =  wrbuf_cache_data_strb_wrbuf;
assign wrbuf_cache_data_wdata         =  wrbuf_cache_data_wdata_wrbuf;
assign wrbuf_cache_data_ecc_w         =  wrbuf_cache_data_ecc_w_wrbuf;
assign wrbuf_cache_data_wecc          =  wrbuf_cache_data_wecc_wrbuf;
assign wrbuf_cache_tagv_indx_sel      =  wrbuf_cache_tagv_indx_sel_wrbuf;
assign wrbuf_cache_data_indx_sel      =  wrbuf_cache_data_indx_sel_wrbuf;
assign wrbuf_cache_indx               =  wrbuf_cache_indx_wrbuf;
assign wrbuf_cache_lrud_wen           =  wrbuf_cache_lrud_wen_wrbuf;
assign wrbuf_cache_lru_clr            =  wrbuf_cache_lrud_lru_clr_wrbuf;
assign wrbuf_cache_lrud_indx          =  wrbuf_cache_lrud_indx_wrbuf;
assign wrbuf_cache_lrud_wway          =  wrbuf_cache_lrud_wway_wrbuf;
assign wrbuf_cache_lrud_wlock         =  wrbuf_cache_lrud_wlock_wrbuf;
assign wrbuf_cache_lrud_d_wen         =  wrbuf_cache_lrud_d_wen_wrbuf;
assign wrbuf_cache_lrud_wdirty        =  wrbuf_cache_lrud_wdirty_wrbuf;
assign wrbuf_cache_tagv_ren           =  wrbuf_cache_tagv_ren_wrbuf;
assign wrbuf_cache_tagv_wen           =  wrbuf_cache_tagv_wen_wrbuf;
assign wrbuf_cache_tagv_strb          =  wrbuf_cache_tagv_strb_wrbuf;
assign wrbuf_cache_tagv_wdata         =  wrbuf_cache_tagv_wdata_wrbuf;
assign wrbuf_cache_tagv_ecc_w         =  wrbuf_cache_tagv_ecc_w_wrbuf;
assign wrbuf_cache_tagv_wecc          =  wrbuf_cache_tagv_wecc_wrbuf;
assign tc_tagv_rdata_wrbuf            =  tc_tagv_rdata;
assign tc_bank_rdata_wrbuf            =  tc_bank_rdata;
assign tc_tagv_old_ecc_wrbuf          =  tc_tagv_old_ecc;
assign tc_tagv_ecc_syndrome_wrbuf     =  tc_tagv_ecc_syndrome;
assign tc_bank_old_ecc_wrbuf          =  tc_bank_old_ecc;
assign tc_bank_ecc_syndrome_wrbuf     =  tc_bank_ecc_syndrome;
assign wrbuf_ecc_fatal                =  wrbuf_ecc_fatal_wrbuf;
assign wrbuf_ls_ccop_ecc_fatal        =  ls_ccop_ecc_fatal_wrbuf;
assign wrbuf_ecc_fatal_indx           =  ecc_fatal_indx_wrbuf;
assign wrbuf_ecc_fatal_way            =  ecc_fatal_way_wrbuf;
assign wrbuf_ecc_fatal_intagv         =  ecc_fatal_intagv_wrbuf;
assign wrbuf_ecc_fatal_indata         =  ecc_fatal_indata_wrbuf;
assign wrbuf_ecc_err_add1             =  ecc_err_add1_wrbuf;
assign mq_stall_req_wrbuf             =  mq_stall_req;
assign wrbuf_idle                     =  wrbuf_idle_wrbuf;
assign wrbuf_wr_bank                  =  wrbuf_wr_bank_wrbuf;
assign wrbuf_wr_tagv                  =  wrbuf_wr_tagv_wrbuf;
assign wrbuf_lock_bank                =  wrbuf_lock_bank_wrbuf;
// x_lsu_mq
assign has_ecc_mq                     =  has_ecc;
assign clk_mq                         =  clk;
assign reset_mq                       =  reset;
assign data_reset_mq                  =  data_reset;
assign ctrl_nowrap_mq                 =  ctrl_nowrap;
assign axi_ar_ok_mq                   =  axi_ar_ok;
assign axi_rvalid_mq                  =  axi_rvalid;
assign axi_rdata_mq                   =  axi_rdata;
assign axi_aw_ok_mq                   =  axi_aw_ok;
assign axi_w_ok_mq                    =  axi_w_ok;
assign axi_bvalid_mq                  =  axi_bvalid;
assign axi_bid_mq                     =  axi_bid;
assign cache_ram_missq_data_rdata_mq  =  cache_ram_missq_data_rdata;
assign tc_allow_refill_mq             =  tc_allow_refill;
assign tc_hit_mq_mq                   =  tc_hit_mq;
assign tc_st_hit_mq_ok_mq             =  tc_st_hit_mq_ok;
assign tc_st_hit_mq_sel_mq            =  tc_st_hit_mq_sel;
assign tc_st_hit_mq_wstrb_mq          =  tc_st_hit_mq_wstrb;
assign tc_st_hit_mq_wdata_mq          =  tc_st_hit_mq_wdata;
assign tagcmp_missq_valid_mq          =  tagcmp_missq_valid;
assign tagcmp_missq_aw_do_mq          =  tagcmp_missq_aw_do;
assign tagcmp_missq_bacs_mq           =  tagcmp_missq_bacs;
assign tagcmp_missq_exc_mq            =  tagcmp_missq_exc;
assign tagcmp_missq_cached_mq         =  tagcmp_missq_cached;
assign tagcmp_missq_araddr31_5_mq     =  tagcmp_missq_araddr31_5;
assign tagcmp_missq_addr_mq           =  tagcmp_missq_addr;
assign tagcmp_missq_strb_mq           =  tagcmp_missq_strb;
assign tagcmp_missq_size_mq           =  tagcmp_missq_size;
assign tagcmp_missq_pref_mq           =  tagcmp_missq_pref;
assign tagcmp_missq_lock_mq           =  tagcmp_missq_lock;
assign tagcmp_missq_ccop_do_mq        =  tagcmp_missq_ccop_do;
assign tagcmp_missq_lock_exist_mq     =  tagcmp_missq_lock_exist;
assign tagcmp_missq_ccop_valid_mq     =  tagcmp_missq_ccop_valid;
assign tagcmp_missq_ccop_inv_mq       =  tagcmp_missq_ccop_inv;
assign tagcmp_missq_ccop_sttag_mq     =  tagcmp_missq_ccop_sttag;
assign tagcmp_missq_ccop_ldtag_mq     =  tagcmp_missq_ccop_ldtag;
assign tagcmp_missq_ccop_wb_mq        =  tagcmp_missq_ccop_wb;
assign tagcmp_missq_sttag_v_mq        =  tagcmp_missq_sttag_v;
assign tagcmp_missq_sttag_d_mq        =  tagcmp_missq_sttag_d;
assign tagcmp_missq_sttag_l_mq        =  tagcmp_missq_sttag_l;
assign wrbuf_allow_refill_mq          =  wrbuf_allow_refill;
assign missq_wrbuf_ecc_in             =  missq_wrbuf_ecc_in_mq;
assign missq_wrbuf_correct            =  missq_wrbuf_correct_mq;
assign wrbuf_missq_new_tagv_mq        =  wrbuf_missq_new_tagv;
assign wrbuf_missq_tagv_1_err_mq      =  wrbuf_missq_tagv_1_err;
assign wrbuf_missq_tagv_fatal_mq      =  wrbuf_missq_tagv_fatal;
assign missq_wrbuf_refill_lru         =  missq_wrbuf_refill_lru_mq;
assign missq_wrbuf_indx               =  missq_wrbuf_indx_mq;
assign missq_wrbuf_way                =  missq_wrbuf_way_mq;
assign missq_wrbuf_way_lock           =  missq_wrbuf_way_lock_mq;
assign missq_wrbuf_lru_clr            =  missq_wrbuf_lru_clr_mq;
assign missq_wrbuf_dirty_wen          =  missq_wrbuf_dirty_wen_mq;
assign missq_wrbuf_dirty_wdata        =  missq_wrbuf_dirty_wdata_mq;
assign lru_repl_way_mq                =  lru_repl_way;
assign lru_repl_way_d_mq              =  lru_repl_way_d;
assign mq_lrud_ren                    =  mq_lrud_ren_mq;
assign mq_lrud_indx                   =  mq_lrud_indx_mq;
assign missq_cache_indx_sel           =  missq_cache_indx_sel_mq;
assign missq_cache_indx               =  missq_cache_indx_mq;
assign missq_cache_tagv_ren           =  missq_cache_tagv_ren_mq;
assign missq_cache_tagv_wen           =  missq_cache_tagv_wen_mq;
assign missq_cache_tagv_strb          =  missq_cache_tagv_strb_mq;
assign missq_cache_tagv_wdata         =  missq_cache_tagv_wdata_mq;
assign missq_cache_tagv_ecc_w         =  missq_cache_tagv_ecc_w_mq;
assign missq_cache_data_ren           =  missq_cache_data_ren_mq;
assign missq_cache_data_wen           =  missq_cache_data_wen_mq;
assign missq_cache_data_strb          =  missq_cache_data_strb_mq;
assign missq_cache_data_wdata         =  missq_cache_data_wdata_mq;
assign missq_cache_data_ecc_w         =  missq_cache_data_ecc_w_mq;
assign missq_tagcmp_allowin           =  missq_tagcmp_allowin_mq;
assign missq_tagcmp_ar_stall          =  missq_tagcmp_ar_stall_mq;
assign missq_tagcmp_bq_null           =  missq_tagcmp_bq_null_mq;
assign missq_tagcmp_bq_full           =  missq_tagcmp_bq_full_mq;
assign missq_tagcmp_valid             =  missq_tagcmp_valid_mq;
assign missq_tagcmp_bacs              =  missq_tagcmp_bacs_mq;
assign missq_tagcmp_wait_wr           =  missq_tagcmp_wait_wr_mq;
assign missq_tagcmp_addr_31_5         =  missq_tagcmp_addr_31_5_mq;
assign missq_tagcmp_buf_valid         =  missq_tagcmp_buf_valid_mq;
assign missq_tagcmp_buf_data          =  missq_tagcmp_buf_data_mq;
assign axi_aw_wid                     =  axi_aw_wid_mq;
assign axi_awvalid                    =  axi_awvalid_mq;
assign axi_awburst                    =  axi_awburst_mq;
assign axi_awexc                      =  axi_awexc_mq;
assign axi_awcache                    =  axi_awcache_mq;
assign axi_awsize                     =  axi_awsize_mq;
assign axi_awaddr                     =  axi_awaddr_mq;
assign axi_wvalid                     =  axi_wvalid_mq;
assign axi_wstrb                      =  axi_wstrb_mq;
assign axi_wdata                      =  axi_wdata_mq;
assign axi_wlast                      =  axi_wlast_mq;
assign cps_data_ok                    =  cps_data_ok_mq;
assign cps_rdata                      =  cps_rdata_mq;
assign mqway_ecc_syndrome_mq          =  mqway_ecc_syndrome;
assign missq_ecc_gen_new_ecc          =  missq_ecc_gen_new_ecc_mq;
assign missq_ecc_gen_old_ecc          =  missq_ecc_gen_old_ecc_mq;
assign missq_ecc_refill_eccset        =  missq_ecc_refill_eccset_mq;
assign mq_impr_fatal                  =  mq_impr_fatal_mq;
assign mq_ecc_fatal_indx              =  ecc_fatal_indx_mq;
assign mq_ecc_fatal_way               =  ecc_fatal_way_mq;
assign mq_ecc_fatal_intagv            =  ecc_fatal_intagv_mq;
assign mq_ecc_fatal_indata            =  ecc_fatal_indata_mq;
assign mq_ecc_fatal_dirtywb           =  ecc_fatal_dirtywb_mq;
assign mq_ecc_fatal_dirty_tag         =  ecc_fatal_dirty_tag_mq;
assign mq_ecc_err_add1                =  ecc_err_add1_mq;
assign mq_refill_add1                 =  refill_add1_mq;
assign mq_stall_req                   =  mq_stall_req_mq;
assign mq_idle                        =  mq_idle_mq;
assign mq_bq_null                     =  mq_bq_null_mq;
// x_lsu_bank_ecc_0
assign bank_rdata_bank_ecc0        =  ecc_tagv_rdata;
assign bank_recc_bank_ecc0         =  ecc_tagv_old_ecc;
assign mq_refill_eccset_bank_ecc0  =  missq_ecc_refill_eccset;
assign tc_tagv_err                 =  tc_err_bank_ecc0;
assign tc_tagv_ecc_syndrome_tmp    =  tc_ecc_syndrome_bank_ecc0;
assign mq_tagv_gen_ecc_all         =  mq_gen_ecc_all_bank_ecc0;
// x_lsu_bank_ecc_1
assign bank_rdata_bank_ecc1        =  sel_bank_rdata;
assign bank_recc_bank_ecc1         =  sel_bank_recc;
assign mq_refill_eccset_bank_ecc1  =  missq_ecc_refill_eccset;
assign tc_bank_err                 =  tc_err_bank_ecc1;
assign tc_bank_ecc_syndrome_tmp    =  tc_ecc_syndrome_bank_ecc1;
assign mq_bank0_gen_ecc            =  mq_gen_ecc_one_bank_ecc1;
assign mq_bank0_ecc_syndrome       =  mq_ecc_syndrome_bank_ecc1;
// x_lsu_way_ecc
assign way_rdata_way_ecc    =  bank7_rdata;
assign way_old_ecc_way_ecc  =  bank7_old_ecc;
assign bank7_gen_ecc        =  way_gen_ecc_way_ecc;
assign bank7_ecc_syndrome   =  way_ecc_syndrome_way_ecc;
// x_lsu_lru
assign wrbuf_lrud_wen_lru      =  wrbuf_cache_lrud_wen;
assign wrbuf_lrud_lru_clr_lru  =  wrbuf_cache_lru_clr;
assign wrbuf_lrud_indx_lru     =  wrbuf_cache_lrud_indx;
assign wrbuf_lrud_wway_lru     =  wrbuf_cache_lrud_wway;
assign wrbuf_lrud_wlock_lru    =  wrbuf_cache_lrud_wlock;
assign wrbuf_lrud_d_wen_lru    =  wrbuf_cache_lrud_d_wen;
assign wrbuf_lrud_wdirty_lru   =  wrbuf_cache_lrud_wdirty;
assign mq_lrud_ren_lru         =  mq_lrud_ren;
assign mq_lrud_indx_lru        =  mq_lrud_indx;
assign ram_lrud_rdata_lru      =  ram_lrud_rdata;
assign ram_lrud_en             =  ram_lrud_en_lru;
assign ram_lrud_wen            =  ram_lrud_wen_lru;
assign ram_lrud_addr           =  ram_lrud_addr_lru;
assign ram_lrud_wdata          =  ram_lrud_wdata_lru;
assign lru_repl_way            =  lru_repl_way_lru;
assign lru_repl_way_d          =  lru_repl_way_d_lru;

generate
    if (ECC_BITS >= 7) begin: gen_cache_has_ecc
        assign has_ecc = 1'b1;
    end else begin: gen_cache_no_ecc
        assign has_ecc = 1'b0;
    end
endgenerate

assign ccop_req      =  |cc_op[1:0];
assign hit_ccop_req  =  cc_op[0];
assign cps_req       =  ccop_req || cc_pref || cc_lock;
assign lookup_req    =  req_rd_wr || cc_pref || cc_lock || hit_ccop_req;
assign ls_req_nocps  =  req_rd_wr && !cps_req;
assign cps_req_go    =  cps_req && cache_idle && !cc_op_stall;  // cache op need wait cc_req/wrbuf/mq is idle

assign req_stall  =  mq_stall_req || wrbuf_stall_req;
assign real_req   =  ls_req_nocps && !req_pre_err && !req_stall || cps_req_go;

assign req_wdata  =  cps_req ? cc_sttag : wdata;
//------------------------------------------------------------//
//                       Cache Requests
//------------------------------------------------------------//
assign {ifc_req_tag, ifc_req_index}  =  paddr[31:5];
assign stall_access                  =  tc_stall_ram_en || mq_stall_req;
assign req_tagv_ren                  =  {SET_ASSOC{lookup_req && !stall_access}};
assign req_tagv_indx                 =  ifc_req_index;

generate
    for (i = 0; i < 8; i = i + 1) begin: gen_request_read_data_enable
        assign req_data_ren[i] = {SET_ASSOC{(req_bank == i) && req_rd_wr && !stall_access}};
    end
endgenerate

assign all_req_cango  =  tc_allowin && !req_stall;
assign cache_idle     =  tc_idle && mq_idle && wrbuf_idle;
assign axi_null       =  cache_idle && mq_bq_null;
assign cps_req_ok     =  cache_idle;
assign all_addr_ok    =  !cps_req && all_req_cango;
// End Cache Requests

//------------------------------------------------------------//
//                           Tagcmp
//------------------------------------------------------------//
assign axi_ar_ok         =  axi_arvalid && axi_arready;
assign dcc_ar_stall_icc  =  axi_arvalid && !is_icache;
lsu_tagcmp #(
    .AXI_DATA    (AXI_DATA_TAGCMP   ),
    .AXI_STRB    (AXI_STRB_TAGCMP   ),
    .AXI_ALIGN_N (AXI_ALIGN_N_TAGCMP),
    .AXI_DIV_32  (AXI_DIV_32_TAGCMP ),
    .CC_LINE_AXI (CC_LINE_AXI_TAGCMP),
    .SET_ASSOC   (SET_ASSOC_TAGCMP  ),
    .BANK_WD     (BANK_WD_TAGCMP    ),
    .SET_BITS    (SET_BITS_TAGCMP   ),
    .INDEX_BITS  (INDEX_BITS_TAGCMP ),
    .TAG_BITS    (TAG_BITS_TAGCMP   ),
    .TAGV_BITS   (TAGV_BITS_TAGCMP  ),
    .RAM_TAGV_WD (RAM_TAGV_WD_TAGCMP)   // without ecc
) x_lsu_tagcmp (
    .has_ecc                     (has_ecc_tagcmp                    ),
    // clk and reset
    .clk                         (clk_tagcmp                        ),
    .reset                       (reset_tagcmp                      ),
    .data_reset                  (data_reset_tagcmp                 ),
    .ex_cancel                   (ex_cancel_tagcmp                  ),
    .bypass                      (bypass_tagcmp                     ),
    .ctrl_nowrap                 (ctrl_nowrap_tagcmp                ),
    // load/store req(predict right and no stall), or cache/pref/sync req
    .real_req                    (real_req_tagcmp                   ),
    .ls_req_nocps                (ls_req_nocps_tagcmp               ),
    .req_wdata                   (req_wdata_tagcmp                  ),
    .req_rd                      (req_rd_tagcmp                     ),  // request is read
    .req_exc                     (req_exc_tagcmp                    ),  // request exclusive access
    .size                        (size_tagcmp                       ),  // request size
`ifdef CONFIG_MMU
    .vaddr                       (vaddr_tagcmp                      ),  // request virtual address
`else
    .vaddr_h3                    (vaddr_h3_tagcmp                   ),  // request vaddr[31:29]
`endif
    .paddr                       (paddr_tagcmp                      ),  // request paddr
`ifdef CONFIG_MMU
    .req_xlat_wait               (req_xlat_wait_tagcmp             ),
    .req_attr_vld                (req_attr_vld_tagcmp              ),
    .req_sob                     (req_sob_tagcmp                   ),
    .req_cached                  (req_cached_tagcmp                ),
    .req_alloc                   (req_alloc_tagcmp                 ),
    .xlat_vld                    (xlat_vld_tagcmp                  ),
    .xlat_cancel                 (xlat_cancel_tagcmp               ),
    .xlat_paddr                  (xlat_paddr_tagcmp                ),
    .xlat_sob                    (xlat_sob_tagcmp                  ),
    .xlat_cached                 (xlat_cached_tagcmp               ),
    .xlat_alloc                  (xlat_alloc_tagcmp                ),
`endif
    .cc_op                       (cc_op_tagcmp                      ),  // cache/isync op
    .cc_isync                    (cc_isync_tagcmp                   ),  // isync
    .cc_pref                     (cc_pref_tagcmp                    ),  // pref
    .cc_lock                     (cc_lock_tagcmp                    ),  // pref

    .axi_ar_ok                   (axi_ar_ok_tagcmp                  ),

    // to mmu
    .go_mmu_vaddr                (go_mmu_vaddr_tagcmp               ),
    .go_mmu_read                 (go_mmu_read_tagcmp                ),
    .go_mmu_dbgm                 (go_mmu_dbgm_tagcmp                ),
    // from mmu
    .mmu_sob                     (mmu_sob_tagcmp                    ),  // strong-older-back
    .mmu_cached                  (mmu_cached_tagcmp                 ),  // request is cached
    .mmu_alloc                   (mmu_alloc_tagcmp                  ),  // alloc if miss

    // CACHE RAM
    .cache_ram_tagcmp_tagv_rdata (cache_ram_tagcmp_tagv_rdata_tagcmp),
    .tagcmp_cache_ram_bank_sel   (tagcmp_cache_ram_bank_sel_tagcmp  ),
    .cache_ram_tagcmp_bank_rdata (cache_ram_tagcmp_bank_rdata_tagcmp),  // one bank
    .cache_ram_tagcmp_tagv_err   (cache_ram_tagcmp_tagv_err_tagcmp  ),
    .cache_ram_tagcmp_bank_err   (cache_ram_tagcmp_bank_err_tagcmp  ),
    // wrbuf
    .wrbuf_tagcmp_way            (wrbuf_tagcmp_way_tagcmp           ),
    .wrbuf_tagcmp_wr             (wrbuf_tagcmp_wr_tagcmp            ),
    .wrbuf_tagcmp_ecc_fatal      (wrbuf_tagcmp_ecc_fatal_tagcmp     ),
    .wrbuf_tagcmp_hit_bank       (wrbuf_tagcmp_hit_bank_tagcmp      ),
    .wrbuf_tagcmp_strb           (wrbuf_tagcmp_strb_tagcmp          ),
    .wrbuf_tagcmp_wdata          (wrbuf_tagcmp_wdata_tagcmp         ),
    .wrbuf_tagcmp_new_valid      (wrbuf_tagcmp_new_valid_tagcmp     ),  // for ecc correct
    .wrbuf_tagcmp_new_tagv       (wrbuf_tagcmp_new_tagv_tagcmp      ),
    .wrbuf_tagcmp_new_bank       (wrbuf_tagcmp_new_bank_tagcmp      ),  // one bank
    // from missq
    .missq_tagcmp_allowin        (missq_tagcmp_allowin_tagcmp       ),
    .missq_tagcmp_ar_stall       (missq_tagcmp_ar_stall_tagcmp      ),
    .missq_tagcmp_bq_null        (missq_tagcmp_bq_null_tagcmp       ),
    .missq_tagcmp_bq_full        (missq_tagcmp_bq_full_tagcmp       ),
    .missq_tagcmp_valid          (missq_tagcmp_valid_tagcmp         ),
    .missq_tagcmp_bacs           (missq_tagcmp_bacs_tagcmp          ),
    .missq_tagcmp_wait_wr        (missq_tagcmp_wait_wr_tagcmp       ),
    .missq_tagcmp_addr_31_5      (missq_tagcmp_addr_31_5_tagcmp     ),
    .missq_tagcmp_buf_valid      (missq_tagcmp_buf_valid_tagcmp     ),
    .missq_tagcmp_buf_data       (missq_tagcmp_buf_data_tagcmp      ),
    .req2dbgm                    (req2dbgm_tagcmp                   ),
    .dbgm_req_valid              (dbgm_req_valid_tagcmp             ),
    .dbgm_req_wr                 (dbgm_req_wr_tagcmp                ),
    .dbgm_req_addr               (dbgm_req_addr_tagcmp              ),
    .dbgm_req_size               (dbgm_req_size_tagcmp              ),
    .dbgm_req_wdata              (dbgm_req_wdata_tagcmp             ),
    .dbgm_resp_valid             (dbgm_resp_valid_tagcmp            ),
    .dbgm_resp_data              (dbgm_resp_data_tagcmp             ),
    // to axi
    .axi_arvalid                 (axi_arvalid_tagcmp                ),
    .axi_arburst                 (axi_arburst_tagcmp                ),
    .axi_arexc                   (axi_arexc_tagcmp                  ),
    .axi_arcache                 (axi_arcache_tagcmp                ),
    .axi_arsize                  (axi_arsize_tagcmp                 ),
    .axi_araddr                  (axi_araddr_tagcmp                 ),
    .axi_rvalid                  (axi_rvalid_tagcmp                 ),  // for uncache
    .axi_rdata                   (axi_rdata_tagcmp                  ),
    .axi_rresp                   (axi_rresp_tagcmp                  ),
    // to wrbuf
    .tagcmp_wrbuf_ls_valid       (tagcmp_wrbuf_ls_valid_tagcmp      ),
    .tagcmp_wrbuf_ecc_err        (tagcmp_wrbuf_ecc_err_tagcmp       ),
    .tagcmp_wrbuf_hit_way        (tagcmp_wrbuf_hit_way_tagcmp       ),
    .tagcmp_wrbuf_wr             (tagcmp_wrbuf_wr_tagcmp            ),
    .tagcmp_wrbuf_bank_sel       (tagcmp_wrbuf_bank_sel_tagcmp      ),
    .tagcmp_wrbuf_strb           (tagcmp_wrbuf_strb_tagcmp          ),
    .tagcmp_wrbuf_indx           (tagcmp_wrbuf_indx_tagcmp          ),
    .tagcmp_wrbuf_wdata          (tagcmp_wrbuf_wdata_tagcmp         ),
    .tagcmp_wrbuf_way_lock       (tagcmp_wrbuf_way_lock_tagcmp      ),
    .tagcmp_wrbuf_lru_wen        (tagcmp_wrbuf_lru_wen_tagcmp       ),
    // to missq
    .tc_hit_mq                   (tc_hit_mq_tagcmp                  ),
    .tc_st_hit_mq_ok             (tc_st_hit_mq_ok_tagcmp            ),
    // need see tc_st_hit_mq
    .tc_st_hit_mq_sel            (tc_st_hit_mq_sel_tagcmp           ),
    .tc_st_hit_mq_wstrb          (tc_st_hit_mq_wstrb_tagcmp         ),
    .tc_st_hit_mq_wdata          (tc_st_hit_mq_wdata_tagcmp         ),
    .tc_need_data                (tc_need_data_tagcmp               ),
    .tc_need_tagv                (tc_need_tagv_tagcmp               ),
    .tagcmp_missq_valid          (tagcmp_missq_valid_tagcmp         ),  // tc_valid
    .tagcmp_missq_aw_do          (tagcmp_missq_aw_do_tagcmp         ),
    .tagcmp_missq_bacs           (tagcmp_missq_bacs_tagcmp          ),
    .tagcmp_missq_exc            (tagcmp_missq_exc_tagcmp           ),  // exclusive
    .tagcmp_missq_cached         (tagcmp_missq_cached_tagcmp        ),
    .tagcmp_missq_araddr31_5     (tagcmp_missq_araddr31_5_tagcmp    ),
    .tagcmp_missq_addr           (tagcmp_missq_addr_tagcmp          ),
    .tagcmp_missq_strb           (tagcmp_missq_strb_tagcmp          ),
    .tagcmp_missq_size           (tagcmp_missq_size_tagcmp          ),
    .tagcmp_missq_pref           (tagcmp_missq_pref_tagcmp          ),
    .tagcmp_missq_lock           (tagcmp_missq_lock_tagcmp          ),
    .tagcmp_missq_ccop_do        (tagcmp_missq_ccop_do_tagcmp       ),
    .tagcmp_missq_lock_exist     (tagcmp_missq_lock_exist_tagcmp    ),
    .tagcmp_missq_ccop_valid     (tagcmp_missq_ccop_valid_tagcmp    ),
    .tagcmp_missq_ccop_inv       (tagcmp_missq_ccop_inv_tagcmp      ),
    .tagcmp_missq_ccop_sttag     (tagcmp_missq_ccop_sttag_tagcmp    ),
    .tagcmp_missq_ccop_ldtag     (tagcmp_missq_ccop_ldtag_tagcmp    ),
    .tagcmp_missq_ccop_wb        (tagcmp_missq_ccop_wb_tagcmp       ),
    .tagcmp_missq_sttag_v        (tagcmp_missq_sttag_v_tagcmp       ),
    .tagcmp_missq_sttag_d        (tagcmp_missq_sttag_d_tagcmp       ),
    .tagcmp_missq_sttag_l        (tagcmp_missq_sttag_l_tagcmp       ),
    // read data to pipeline
    .tc_rdata_valid              (tc_rdata_valid_tagcmp             ),
    .tc_rdata                    (tc_rdata_tagcmp                   ),
    .tc_rdata_exok               (tc_rdata_exok_tagcmp              ),  // rdata is exokay
    .tc_rdata_err                (tc_rdata_err_tagcmp               ),  // rdata is error
    // pipeline control
    .tc_allow_refill             (tc_allow_refill_tagcmp            ),
    .tc_idle                     (tc_idle_tagcmp                    ),
    .tc_stall_ram_en             (tc_stall_ram_en_tagcmp            ),  // for low power
    .tc_allowin                  (tc_allowin_tagcmp                 ),
    .rd_in_tc                    (rd_in_tc_tagcmp                   ),
    .wr_in_tc                    (wr_in_tc_tagcmp                   )
);
// End Tagcmp

//------------------------------------------------------------//
//                           Wrbuf
//------------------------------------------------------------//

lsu_wrbuf #(
    .SET_ASSOC     (SET_ASSOC_WRBUF    ),
    .BANK_WD       (BANK_WD_WRBUF      ),
    .BANK_STRB     (BANK_STRB_WRBUF    ),
    .INDEX_BITS    (INDEX_BITS_WRBUF   ),
    .TAGV_BITS     (TAGV_BITS_WRBUF    ),
    .RAM_TAGV_WD   (RAM_TAGV_WD_WRBUF  ),
    .ECC_BITS      (ECC_BITS_WRBUF     ),  // 1/7/8/9 bits
    .ECC_SET       (ECC_SET_WRBUF      ),  // for 4-ways, 64+8
    .ECC_WAY       (ECC_WAY_WRBUF      ),  // for 4-ways, 64+8
    .ECC_BANK_BITS (ECC_BANK_BITS_WRBUF)   // for 4-ways, 64+8
) x_lsu_wrbuf (
    .is_icache                 (is_icache_wrbuf                ),
    .has_ecc                   (has_ecc_wrbuf                  ),
    // clk and reset
    .clk                       (clk_wrbuf                      ),
    .clk_ng                    (clk_ng_wrbuf                   ),
    .reset                     (reset_wrbuf                    ),
    .resetn_in_d2              (resetn_in_d2_wrbuf             ),
    .ram_init_cmplt            (ram_init_cmplt_wrbuf           ),
    .data_reset                (data_reset_wrbuf               ),
    // tagcmp to wrbuf
    .tagcmp_wrbuf_ls_valid     (tagcmp_wrbuf_ls_valid_wrbuf    ),
    .tagcmp_wrbuf_ecc_err      (tagcmp_wrbuf_ecc_err_wrbuf     ),
    .tagcmp_wrbuf_hit_way      (tagcmp_wrbuf_hit_way_wrbuf     ),
    .tagcmp_wrbuf_wr           (tagcmp_wrbuf_wr_wrbuf          ),
    .tagcmp_wrbuf_bank_sel     (tagcmp_wrbuf_bank_sel_wrbuf    ),
    .tagcmp_wrbuf_strb         (tagcmp_wrbuf_strb_wrbuf        ),
    .tagcmp_wrbuf_indx         (tagcmp_wrbuf_indx_wrbuf        ),
    .tagcmp_wrbuf_wdata        (tagcmp_wrbuf_wdata_wrbuf       ),
    .tagcmp_wrbuf_way_lock     (tagcmp_wrbuf_way_lock_wrbuf    ),
    .tagcmp_wrbuf_lru_wen      (tagcmp_wrbuf_lru_wen_wrbuf     ),
    // mq to wrbuf; use tagv_correct
    .missq_wrbuf_ecc_in        (missq_wrbuf_ecc_in_wrbuf       ),  // mq gen old ecc
    .missq_wrbuf_correct       (missq_wrbuf_correct_wrbuf      ),  // mq correct
    .wrbuf_missq_new_tagv      (wrbuf_missq_new_tagv_wrbuf     ),
    .wrbuf_missq_tagv_1_err    (wrbuf_missq_tagv_1_err_wrbuf   ),  // 1 bit error
    .wrbuf_missq_tagv_fatal    (wrbuf_missq_tagv_fatal_wrbuf   ),  // 2 bit error
    // mq to wrbuf; set/clear lrud
    .missq_wrbuf_refill_lru    (missq_wrbuf_refill_lru_wrbuf   ),
    .missq_wrbuf_indx          (missq_wrbuf_indx_wrbuf         ),
    .missq_wrbuf_way           (missq_wrbuf_way_wrbuf          ),
    .missq_wrbuf_way_lock      (missq_wrbuf_way_lock_wrbuf     ),
    .missq_wrbuf_lru_clr       (missq_wrbuf_lru_clr_wrbuf      ),
    .missq_wrbuf_dirty_wen     (missq_wrbuf_dirty_wen_wrbuf    ),
    .missq_wrbuf_dirty_wdata   (missq_wrbuf_dirty_wdata_wrbuf  ),
    // wrbuf to tagcmp
    .wrbuf_tagcmp_way          (wrbuf_tagcmp_way_wrbuf         ),
    .wrbuf_tagcmp_wr           (wrbuf_tagcmp_wr_wrbuf          ),
    .wrbuf_tagcmp_ecc_fatal    (wrbuf_tagcmp_ecc_fatal_wrbuf   ),
    .wrbuf_tagcmp_hit_bank     (wrbuf_tagcmp_hit_bank_wrbuf    ),
    .wrbuf_tagcmp_strb         (wrbuf_tagcmp_strb_wrbuf        ),
    .wrbuf_tagcmp_wdata        (wrbuf_tagcmp_wdata_wrbuf       ),
    .wrbuf_tagcmp_new_valid    (wrbuf_tagcmp_new_valid_wrbuf   ),  // for ecc correct
    .wrbuf_tagcmp_new_tagv     (wrbuf_tagcmp_new_tagv_wrbuf    ),
    .wrbuf_tagcmp_new_bank     (wrbuf_tagcmp_new_bank_wrbuf    ),  // one bank
    // wrbuf to data ram
    .wrbuf_cache_data_ren      (wrbuf_cache_data_ren_wrbuf     ),  // all bank
    .wrbuf_cache_data_wen      (wrbuf_cache_data_wen_wrbuf     ),  // all bank
    .wrbuf_cache_data_strb     (wrbuf_cache_data_strb_wrbuf    ),  // all bank
    .wrbuf_cache_data_wdata    (wrbuf_cache_data_wdata_wrbuf   ),  // only one bank
    .wrbuf_cache_data_ecc_w    (wrbuf_cache_data_ecc_w_wrbuf   ),  // all one bank
    .wrbuf_cache_data_wecc     (wrbuf_cache_data_wecc_wrbuf    ),  // only one bank

    .wrbuf_cache_tagv_indx_sel (wrbuf_cache_tagv_indx_sel_wrbuf),
    .wrbuf_cache_data_indx_sel (wrbuf_cache_data_indx_sel_wrbuf),
    .wrbuf_cache_indx          (wrbuf_cache_indx_wrbuf         ),
    // wrbuf to lru
    .wrbuf_cache_lrud_wen      (wrbuf_cache_lrud_wen_wrbuf     ),
    .wrbuf_cache_lrud_lru_clr  (wrbuf_cache_lrud_lru_clr_wrbuf ),
    .wrbuf_cache_lrud_indx     (wrbuf_cache_lrud_indx_wrbuf    ),
    .wrbuf_cache_lrud_wway     (wrbuf_cache_lrud_wway_wrbuf    ),
    .wrbuf_cache_lrud_wlock    (wrbuf_cache_lrud_wlock_wrbuf   ),
    .wrbuf_cache_lrud_d_wen    (wrbuf_cache_lrud_d_wen_wrbuf   ),
    .wrbuf_cache_lrud_wdirty   (wrbuf_cache_lrud_wdirty_wrbuf  ),
    // wrbuf to tagv ram
    .wrbuf_cache_tagv_ren      (wrbuf_cache_tagv_ren_wrbuf     ),
    .wrbuf_cache_tagv_wen      (wrbuf_cache_tagv_wen_wrbuf     ),
    .wrbuf_cache_tagv_strb     (wrbuf_cache_tagv_strb_wrbuf    ),
    .wrbuf_cache_tagv_wdata    (wrbuf_cache_tagv_wdata_wrbuf   ),
    .wrbuf_cache_tagv_ecc_w    (wrbuf_cache_tagv_ecc_w_wrbuf   ),
    .wrbuf_cache_tagv_wecc     (wrbuf_cache_tagv_wecc_wrbuf    ),
    .tc_tagv_rdata             (tc_tagv_rdata_wrbuf            ),
    .tc_bank_rdata             (tc_bank_rdata_wrbuf            ),  // one bank
    .tc_tagv_old_ecc           (tc_tagv_old_ecc_wrbuf          ),  // all ways
    .tc_tagv_ecc_syndrome      (tc_tagv_ecc_syndrome_wrbuf     ),  // all ways
    .tc_bank_old_ecc           (tc_bank_old_ecc_wrbuf          ),  // all ways in one bank
    .tc_bank_ecc_syndrome      (tc_bank_ecc_syndrome_wrbuf     ),  // all ways in one bank
    .wrbuf_ecc_fatal           (wrbuf_ecc_fatal_wrbuf          ),
    .ls_ccop_ecc_fatal         (ls_ccop_ecc_fatal_wrbuf        ),
    .ecc_fatal_indx            (ecc_fatal_indx_wrbuf           ),
    .ecc_fatal_way             (ecc_fatal_way_wrbuf            ),
    .ecc_fatal_intagv          (ecc_fatal_intagv_wrbuf         ),
    .ecc_fatal_indata          (ecc_fatal_indata_wrbuf         ),
    .ecc_err_add1              (ecc_err_add1_wrbuf             ),

    // pipeline control
    .mq_stall_req              (mq_stall_req_wrbuf             ),
    .wrbuf_idle                (wrbuf_idle_wrbuf               ),
    .wrbuf_wr_bank             (wrbuf_wr_bank_wrbuf            ),
    .wrbuf_wr_tagv             (wrbuf_wr_tagv_wrbuf            ),
    .wrbuf_lock_bank           (wrbuf_lock_bank_wrbuf          )
);
assign wrbuf_bank_conflict  =  (req_bank == wrbuf_lock_bank) && wrbuf_wr_bank;
assign wrbuf_stall_req      =  wrbuf_bank_conflict || wrbuf_wr_tagv;
assign wrbuf_allow_refill   =  wrbuf_idle;
// End Wrbuf

//------------------------------------------------------------//
//                           Missq
//------------------------------------------------------------//
assign axi_aw_ok  =  axi_awvalid && axi_awready;
assign axi_w_ok   =  axi_wvalid && axi_wready;
// Queue/FIFO Entry Instances
lsu_mq #(
    .AXI_DATA      (AXI_DATA_MQ     ),
    .AXI_STRB      (AXI_STRB_MQ     ),
    .AXI_ALIGN_N   (AXI_ALIGN_N_MQ  ),
    .AXI_WID_N     (AXI_WID_N_MQ    ),
    .CC_LINE_AXI   (CC_LINE_AXI_MQ  ),
    .SET_ASSOC     (SET_ASSOC_MQ    ),
    .BANK_WD       (BANK_WD_MQ      ),
    .BANK_STRB     (BANK_STRB_MQ    ),
    .INDEX_BITS    (INDEX_BITS_MQ   ),
    .TAG_BITS      (TAG_BITS_MQ     ),
    .TAGV_BITS     (TAGV_BITS_MQ    ),
    .RAM_TAGV_WD   (RAM_TAGV_WD_MQ  ),
    .ECC_BITS      (ECC_BITS_MQ     ),  // 1/7/8/9 bits
    .ECC_SET       (ECC_SET_MQ      ),  // for 4-ways, 64+8
    .ECC_WAY       (ECC_WAY_MQ      ),  // for 4-ways, 64+8
    .ECC_BANK_BITS (ECC_BANK_BITS_MQ)   // for 4-ways, 64+8
) x_lsu_mq (
    .has_ecc                    (has_ecc_mq                   ),
    // clk and reset
    .clk                        (clk_mq                       ),
    .reset                      (reset_mq                     ),
    .data_reset                 (data_reset_mq                ),
    .ctrl_nowrap                (ctrl_nowrap_mq               ),
    // axi
    .axi_ar_ok                  (axi_ar_ok_mq                 ),
    .axi_rvalid                 (axi_rvalid_mq                ),
    .axi_rdata                  (axi_rdata_mq                 ),
    .axi_aw_ok                  (axi_aw_ok_mq                 ),
    .axi_w_ok                   (axi_w_ok_mq                  ),
    .axi_bvalid                 (axi_bvalid_mq                ),  // [2:0]
    .axi_bid                    (axi_bid_mq                   ),
    // from CACHE RAM
    .cache_ram_missq_data_rdata (cache_ram_missq_data_rdata_mq),  // 8 bank
    // tagcmp to missq
    .tc_allow_refill            (tc_allow_refill_mq           ),
    .tc_hit_mq                  (tc_hit_mq_mq                 ),
    .tc_st_hit_mq_ok            (tc_st_hit_mq_ok_mq           ),
    .tc_st_hit_mq_sel           (tc_st_hit_mq_sel_mq          ),  // need see tc_st_hit_mq_ok
    .tc_st_hit_mq_wstrb         (tc_st_hit_mq_wstrb_mq        ),
    .tc_st_hit_mq_wdata         (tc_st_hit_mq_wdata_mq        ),
    .tagcmp_missq_valid         (tagcmp_missq_valid_mq        ),  // tc_valid
    .tagcmp_missq_aw_do         (tagcmp_missq_aw_do_mq        ),
    .tagcmp_missq_bacs          (tagcmp_missq_bacs_mq         ),
    .tagcmp_missq_exc           (tagcmp_missq_exc_mq          ),  // exclusive
    .tagcmp_missq_cached        (tagcmp_missq_cached_mq       ),
    .tagcmp_missq_araddr31_5    (tagcmp_missq_araddr31_5_mq   ),
    .tagcmp_missq_addr          (tagcmp_missq_addr_mq         ),
    .tagcmp_missq_strb          (tagcmp_missq_strb_mq         ),
    .tagcmp_missq_size          (tagcmp_missq_size_mq         ),
    .tagcmp_missq_pref          (tagcmp_missq_pref_mq         ),
    .tagcmp_missq_lock          (tagcmp_missq_lock_mq         ),
    .tagcmp_missq_ccop_do       (tagcmp_missq_ccop_do_mq      ),
    .tagcmp_missq_lock_exist    (tagcmp_missq_lock_exist_mq   ),
    .tagcmp_missq_ccop_valid    (tagcmp_missq_ccop_valid_mq   ),
    .tagcmp_missq_ccop_inv      (tagcmp_missq_ccop_inv_mq     ),
    .tagcmp_missq_ccop_sttag    (tagcmp_missq_ccop_sttag_mq   ),
    .tagcmp_missq_ccop_ldtag    (tagcmp_missq_ccop_ldtag_mq   ),
    .tagcmp_missq_ccop_wb       (tagcmp_missq_ccop_wb_mq      ),
    .tagcmp_missq_sttag_v       (tagcmp_missq_sttag_v_mq      ),
    .tagcmp_missq_sttag_d       (tagcmp_missq_sttag_d_mq      ),
    .tagcmp_missq_sttag_l       (tagcmp_missq_sttag_l_mq      ),
    // from wrbuf; mq use tagv_correct in wrbuf
    .wrbuf_allow_refill         (wrbuf_allow_refill_mq        ),  // wrbuf is idle, allow refill
    .missq_wrbuf_ecc_in         (missq_wrbuf_ecc_in_mq        ),  // mq gen old ecc
    .missq_wrbuf_correct        (missq_wrbuf_correct_mq       ),  // mq correct
    .wrbuf_missq_new_tagv       (wrbuf_missq_new_tagv_mq      ),
    .wrbuf_missq_tagv_1_err     (wrbuf_missq_tagv_1_err_mq    ),  // 1 bit error
    .wrbuf_missq_tagv_fatal     (wrbuf_missq_tagv_fatal_mq    ),  // 2 bit error
    // mq to wrbuf; set/clear lrud
    .missq_wrbuf_refill_lru     (missq_wrbuf_refill_lru_mq    ),
    .missq_wrbuf_indx           (missq_wrbuf_indx_mq          ),
    .missq_wrbuf_way            (missq_wrbuf_way_mq           ),
    .missq_wrbuf_way_lock       (missq_wrbuf_way_lock_mq      ),
    .missq_wrbuf_lru_clr        (missq_wrbuf_lru_clr_mq       ),
    .missq_wrbuf_dirty_wen      (missq_wrbuf_dirty_wen_mq     ),
    .missq_wrbuf_dirty_wdata    (missq_wrbuf_dirty_wdata_mq   ),
    // from lru
    .lru_repl_way               (lru_repl_way_mq              ),
    .lru_repl_way_d             (lru_repl_way_d_mq            ),
    // read lru
    .mq_lrud_ren                (mq_lrud_ren_mq               ),
    .mq_lrud_indx               (mq_lrud_indx_mq              ),
    // to cache ram
    .missq_cache_indx_sel       (missq_cache_indx_sel_mq      ),
    .missq_cache_indx           (missq_cache_indx_mq          ),
    .missq_cache_tagv_ren       (missq_cache_tagv_ren_mq      ),
    .missq_cache_tagv_wen       (missq_cache_tagv_wen_mq      ),
    .missq_cache_tagv_strb      (missq_cache_tagv_strb_mq     ),
    .missq_cache_tagv_wdata     (missq_cache_tagv_wdata_mq    ),
    .missq_cache_tagv_ecc_w     (missq_cache_tagv_ecc_w_mq    ),
    .missq_cache_data_ren       (missq_cache_data_ren_mq      ),
    .missq_cache_data_wen       (missq_cache_data_wen_mq      ),
    .missq_cache_data_strb      (missq_cache_data_strb_mq     ),
    .missq_cache_data_wdata     (missq_cache_data_wdata_mq    ),
    .missq_cache_data_ecc_w     (missq_cache_data_ecc_w_mq    ),
    // to tagcmp
    .missq_tagcmp_allowin       (missq_tagcmp_allowin_mq      ),
    .missq_tagcmp_ar_stall      (missq_tagcmp_ar_stall_mq     ),
    .missq_tagcmp_bq_null       (missq_tagcmp_bq_null_mq      ),
    .missq_tagcmp_bq_full       (missq_tagcmp_bq_full_mq      ),
    .missq_tagcmp_valid         (missq_tagcmp_valid_mq        ),
    .missq_tagcmp_bacs          (missq_tagcmp_bacs_mq         ),
    .missq_tagcmp_wait_wr       (missq_tagcmp_wait_wr_mq      ),
    .missq_tagcmp_addr_31_5     (missq_tagcmp_addr_31_5_mq    ),
    .missq_tagcmp_buf_valid     (missq_tagcmp_buf_valid_mq    ),
    .missq_tagcmp_buf_data      (missq_tagcmp_buf_data_mq     ),
    // to axi
    .axi_aw_wid                 (axi_aw_wid_mq                ),  // awid/wid
    .axi_awvalid                (axi_awvalid_mq               ),  // write request
    .axi_awburst                (axi_awburst_mq               ),  // write burst
    .axi_awexc                  (axi_awexc_mq                 ),  // write exclusive
    .axi_awcache                (axi_awcache_mq               ),  // write cached
    .axi_awsize                 (axi_awsize_mq                ),  // write size
    .axi_awaddr                 (axi_awaddr_mq                ),  // write addr
    .axi_wvalid                 (axi_wvalid_mq                ),  // write data request
    .axi_wstrb                  (axi_wstrb_mq                 ),  // write strobe
    .axi_wdata                  (axi_wdata_mq                 ),  // write data
    .axi_wlast                  (axi_wlast_mq                 ),  // write last
    // read data to pipeline
    .cps_data_ok                (cps_data_ok_mq               ),
    .cps_rdata                  (cps_rdata_mq                 ),
    // for ecc
    .mqway_ecc_syndrome         (mqway_ecc_syndrome_mq        ),  // all banks in one way
    .missq_ecc_gen_new_ecc      (missq_ecc_gen_new_ecc_mq     ),
    .missq_ecc_gen_old_ecc      (missq_ecc_gen_old_ecc_mq     ),
    .missq_ecc_refill_eccset    (missq_ecc_refill_eccset_mq   ),
    .mq_impr_fatal              (mq_impr_fatal_mq             ),
    .ecc_fatal_indx             (ecc_fatal_indx_mq            ),
    .ecc_fatal_way              (ecc_fatal_way_mq             ),
    .ecc_fatal_intagv           (ecc_fatal_intagv_mq          ),
    .ecc_fatal_indata           (ecc_fatal_indata_mq          ),
    .ecc_fatal_dirtywb          (ecc_fatal_dirtywb_mq         ),  // 2bit err data has been writeback.
    .ecc_fatal_dirty_tag        (ecc_fatal_dirty_tag_mq       ),
    .ecc_err_add1               (ecc_err_add1_mq              ),
    .refill_add1                (refill_add1_mq               ),
    // pipeline control
    .mq_stall_req               (mq_stall_req_mq              ),
    .mq_idle                    (mq_idle_mq                   ),
    .mq_bq_null                 (mq_bq_null_mq                )
);
`GEN_1D_TO_2D(8, (32*ECC_WAY), missq_cache_data_wdata, mq_data_wdata)
// End Missq

//------------------------------------------------------------//
//                            Ecc
//------------------------------------------------------------//
//------------------------------------------------------------//
//                     All Ways' Tagv Ecc
//------------------------------------------------------------//
assign ecc_tagv_rdata    =  missq_ecc_gen_new_ecc ? missq_cache_tagv_wdata : tc_tagv_rdata;
assign ecc_tagv_old_ecc  =  tc_tagv_old_ecc;

lsu_bank_ecc #(
    .SET_ASSOC     (SET_ASSOC_BANK_ECC0    ),
    .DATA_BITS     (DATA_BITS_BANK_ECC0    ),
    .ECC_SET       (ECC_SET_BANK_ECC0      ),
    .ECC_WAY       (ECC_WAY_BANK_ECC0      ),
    .ECC_BITS      (ECC_BITS_BANK_ECC0     ),
    .ECC_BANK_BITS (ECC_BANK_BITS_BANK_ECC0)
) x_lsu_bank_ecc_0 (
    .bank_rdata       (bank_rdata_bank_ecc0      ),
    .bank_recc        (bank_recc_bank_ecc0       ),  // all ways
    .mq_refill_eccset (mq_refill_eccset_bank_ecc0),
    .tc_err           (tc_err_bank_ecc0          ),  // there are errors in any way
    .tc_ecc_syndrome  (tc_ecc_syndrome_bank_ecc0 ),  // all ecc set
    .mq_gen_ecc_all   (mq_gen_ecc_all_bank_ecc0  ),  // all ecc set
    .mq_gen_ecc_one   (                          ),  // one ecc set
    // Legacy mq_tagv_ecc_syndrome output is intentionally unconnected.
    .mq_ecc_syndrome  (                          )   // one ecc set
);
assign tc_tagv_ecc_syndrome  =  tc_tagv_ecc_syndrome_tmp & {ECC_BANK_BITS{tc_need_tagv}};
// End All Ways' Tagv Ecc

//------------------------------------------------------------//
//                One Bank All Ways' Data Ecc
//------------------------------------------------------------//
assign sel_bank_rdata  =  missq_ecc_gen_new_ecc ? {ECC_SET{mq_data_wdata[0]}} : tc_bank_rdata;
assign sel_bank_recc   =  tc_bank_old_ecc;

lsu_bank_ecc #(
    .SET_ASSOC     (SET_ASSOC_BANK_ECC1    ),
    .DATA_BITS     (DATA_BITS_BANK_ECC1    ),
    .ECC_BITS      (ECC_BITS_BANK_ECC1     ),
    .ECC_SET       (ECC_SET_BANK_ECC1      ),
    .ECC_WAY       (ECC_WAY_BANK_ECC1      ),
    .ECC_BANK_BITS (ECC_BANK_BITS_BANK_ECC1)
) x_lsu_bank_ecc_1 (
    .bank_rdata       (bank_rdata_bank_ecc1      ),  // 8 banks
    .bank_recc        (bank_recc_bank_ecc1       ),  // all ways
    .mq_refill_eccset (mq_refill_eccset_bank_ecc1),
    .tc_err           (tc_err_bank_ecc1          ),  // errors in any way for tc selected bank
    .tc_ecc_syndrome  (tc_ecc_syndrome_bank_ecc1 ),  // all ecc set
    .mq_gen_ecc_all   (                          ),  // all ecc set
    .mq_gen_ecc_one   (mq_gen_ecc_one_bank_ecc1  ),  // one ecc set
    .mq_ecc_syndrome  (mq_ecc_syndrome_bank_ecc1 )   // one eccset
);
// cps request no read data ram, so tc_bank_ecc_syndrome need be set to 0
assign tc_bank_ecc_syndrome  =  tc_bank_ecc_syndrome_tmp & {ECC_BANK_BITS{tc_need_data}};
// End One Bank All Ways' Data Ecc

// End bank1~7 All Ways' Data Ecc
generate
    for (i = 0; i < 7; i = i + 1) begin: gen_bank1_7_eccset
        assign bank7_eccset_rdata[i] = missq_ecc_gen_new_ecc ? mq_data_wdata[i+1]
                                                              : mq_eccset_rdata[i+1];
        assign bank7_eccset_old_ecc[i] = mq_eccset_old_ecc[i+1];
    end
endgenerate
`GEN_2D_TO_1D(7, (32*ECC_WAY), bank7_eccset_rdata, bank7_rdata)
`GEN_2D_TO_1D(7, ECC_BITS, bank7_eccset_old_ecc, bank7_old_ecc)
lsu_way_ecc #(
    .SET_ASSOC (SET_ASSOC_WAY_ECC),
    .ECC_WAY   (ECC_WAY_WAY_ECC  ),
    .ECC_BITS  (ECC_BITS_WAY_ECC )
) x_lsu_way_ecc (
    .way_rdata        (way_rdata_way_ecc       ),  // 7 banks
    .way_old_ecc      (way_old_ecc_way_ecc     ),  // 7 banks
    .way_gen_ecc      (way_gen_ecc_way_ecc     ),  // all banks in one way
    .way_ecc_syndrome (way_ecc_syndrome_way_ecc)   // all banks in one way
);
assign mqway_gen_ecc       =  {bank7_gen_ecc, mq_bank0_gen_ecc};
assign mqway_ecc_syndrome  =  {bank7_ecc_syndrome, mq_bank0_ecc_syndrome};
// End bank1~7 All Ways' Data Ecc

// output
// cps request no read data ram, so no care tc_bank_err
assign cache_ram_tagcmp_tagv_err  =  tc_tagv_err;
assign cache_ram_tagcmp_bank_err  =  tc_bank_err;

assign ccop_ldsttag  =  tagcmp_missq_ccop_ldtag || tagcmp_missq_ccop_sttag;

assign all_fatal         =  wrbuf_ecc_fatal || mq_impr_fatal;
assign load_fatal        =  wrbuf_ls_ccop_ecc_fatal && tagcmp_wrbuf_lru_wen && !tagcmp_wrbuf_wr;
assign store_fatal       =  wrbuf_ls_ccop_ecc_fatal && tagcmp_wrbuf_wr;
assign ccop_fatal        =  wrbuf_ls_ccop_ecc_fatal && !tagcmp_wrbuf_lru_wen || mq_impr_fatal && ccop_ldsttag;
assign rf_impr_fatal     =  mq_impr_fatal && !ccop_ldsttag;  // refill
assign fatal_intagv      =  mq_impr_fatal ? mq_ecc_fatal_intagv : wrbuf_ecc_fatal_intagv;
assign fatal_indata      =  mq_impr_fatal ? mq_ecc_fatal_indata : {7'd0, wrbuf_ecc_fatal_indata};
assign fatal_indx        =  mq_impr_fatal ? mq_ecc_fatal_indx : wrbuf_ecc_fatal_indx;
assign fatal_way         =  mq_impr_fatal ? mq_ecc_fatal_way : wrbuf_ecc_fatal_way;
assign fatal_dirtywb     =  mq_impr_fatal & mq_ecc_fatal_dirtywb;  // 2bit err data has been writeback
assign fatal_dirty_tag   =  {TAG_BITS{mq_impr_fatal}} & mq_ecc_fatal_dirty_tag;
assign all_ecc_err_add1  =  wrbuf_ecc_err_add1 || mq_ecc_err_add1;
assign refill_add1       =  mq_refill_add1;

assign missq_cache_tagv_wecc_allset      =  mq_tagv_gen_ecc_all;
assign missq_cache_data_wecc_eccset      =  mqway_gen_ecc;
`GEN_1D_TO_2D(8, ECC_BITS, missq_cache_data_wecc_eccset, missq_cache_data_wecc_perbank)
// End Ecc

//------------------------------------------------------------//
//                            Lru
//------------------------------------------------------------//
lsu_lru #(
    .SET_ASSOC   (SET_ASSOC_LRU  ),
    .INDEX_BITS  (INDEX_BITS_LRU ),
    .LRU_BITS    (LRU_BITS_LRU   ),
    .RAM_LRUD_WD (RAM_LRUD_WD_LRU)
) x_lsu_lru (
    // wrbuf update lru
    .wrbuf_lrud_wen     (wrbuf_lrud_wen_lru    ),
    .wrbuf_lrud_lru_clr (wrbuf_lrud_lru_clr_lru),
    .wrbuf_lrud_indx    (wrbuf_lrud_indx_lru   ),
    .wrbuf_lrud_wway    (wrbuf_lrud_wway_lru   ),
    .wrbuf_lrud_wlock   (wrbuf_lrud_wlock_lru  ),
    .wrbuf_lrud_d_wen   (wrbuf_lrud_d_wen_lru  ),
    .wrbuf_lrud_wdirty  (wrbuf_lrud_wdirty_lru ),
    // mq read lru
    .mq_lrud_ren        (mq_lrud_ren_lru       ),
    .mq_lrud_indx       (mq_lrud_indx_lru      ),
    // from lrud ram
    .ram_lrud_rdata     (ram_lrud_rdata_lru    ),
    // to lrud ram
    .ram_lrud_en        (ram_lrud_en_lru       ),
    .ram_lrud_wen       (ram_lrud_wen_lru      ),
    .ram_lrud_addr      (ram_lrud_addr_lru     ),
    .ram_lrud_wdata     (ram_lrud_wdata_lru    ),
    // to mq
    .lru_repl_way       (lru_repl_way_lru      ),
    .lru_repl_way_d     (lru_repl_way_d_lru    )
);
// End Lru

//------------------------------------------------------------//
//                           TAG V
//------------------------------------------------------------//

generate
    if (ECC_BITS >= 7) begin: gen_tagv_ram_has_ecc
        assign {ram_tagv_rdata, ram_tagv_recc} = ram_tagv_rall;
        assign ram_tagv_wall = {ram_tagv_wdata, ram_tagv_wecc};
    end else begin: gen_tagv_ram_no_ecc
        assign ram_tagv_rdata = ram_tagv_rall;
        assign ram_tagv_wall  = ram_tagv_wdata;
        assign ram_tagv_recc  = {ECC_SET{1'b0}};
    end
endgenerate

// ram bus
assign ram_tagv_rall     =  ram_tagv_resp_bus;
assign ram_tagv_req_bus  =  {ram_tagv_en, ram_tagv_wen, ram_tagv_addr, ram_tagv_wall};

assign tc_tagv_rdata    =  ram_tagv_rdata;
assign tc_tagv_old_ecc  =  ram_tagv_recc;
// 5x1:
// wrbuf write tagv and tagv-ecc together
assign ram_tagv_en     =  wrbuf_cache_tagv_ren | wrbuf_cache_tagv_wen | req_tagv_ren | missq_cache_tagv_ren |
                            missq_cache_tagv_wen;
generate
    if (ECC_BITS >= 7) begin: gen_ram_tagv_wen_has_ecc
        assign ram_tagv_wen = wrbuf_cache_tagv_ecc_w | missq_cache_tagv_ecc_w;
    end else begin: gen_ram_tagv_wen_no_ecc
        assign ram_tagv_wen = wrbuf_cache_tagv_strb | missq_cache_tagv_strb;
    end
endgenerate
assign ram_tagv_addr   =  wrbuf_cache_tagv_indx_sel ? wrbuf_cache_indx :
                            missq_cache_indx_sel ? missq_cache_indx : req_tagv_indx;
assign icache_fatal    =  mq_impr_fatal && is_icache && has_ecc;
assign ram_tagv_wdata  =  wrbuf_cache_tagv_wdata | missq_cache_tagv_wdata & {RAM_TAGV_WD{!icache_fatal}};
assign ram_tagv_wecc   =  missq_cache_indx_sel ? missq_cache_tagv_wecc_allset & {ECC_BANK_BITS{!icache_fatal}} :
                            wrbuf_cache_tagv_wecc;

assign cache_ram_tagcmp_tagv_rdata  =  ram_tagv_rdata;
// End TAG V

//------------------------------------------------------------//
//                            DATA
//------------------------------------------------------------//

generate
    for (i = 0; i < 8; i = i + 1) begin: gen_data_ram_data_ecc_all
        if (ECC_BITS >= 7) begin: gen_data_ecc_all_has_ecc
            assign {ram_data_rdata[i], ram_data_recc[i]} = ram_data_rall[i];
            assign ram_data_wall[i] = {ram_data_wdata[i], ram_data_wecc[i]};
        end else begin: gen_data_ecc_all_no_ecc
            assign ram_data_rdata[i] = ram_data_rall[i];
            assign ram_data_wall[i]  = ram_data_wdata[i];
            assign ram_data_recc[i]  = {ECC_SET{1'b0}};
        end
    end
endgenerate

// ram bus
`GEN_1D_TO_2D(8, BANK_WD_ECC, ram_data_resp_bus, ram_data_rall)
generate
    for (i = 0; i < 8; i = i + 1) begin: gen_ram_data_bank
        assign ram_data_req_bus[ONE_BANK_REQ_BUS_WD*i +: ONE_BANK_REQ_BUS_WD] =
            {ram_data_en[i], ram_data_wen[i], ram_data_addr[i], ram_data_wall[i]};
    end
endgenerate

// select bank read data
assign ram_bank_sel                         =  missq_ecc_gen_old_ecc ? 3'd0 : tagcmp_cache_ram_bank_sel;
assign cache_ram_tagcmp_bank_rdata          =  ram_data_rdata[ram_bank_sel];
assign tc_bank_rdata                        =  cache_ram_tagcmp_bank_rdata;

// replaced data
`GEN_2D_TO_3D(8, ECC_SET, (32*ECC_WAY), ram_data_rdata, mq_rdata_perecc)
`GEN_3D_SEL_2D(8, ECC_SET, (32*ECC_WAY), mq_rdata_perecc, mq_rdata_perecc_T,
               missq_ecc_refill_eccset, mq_eccset_rdata)
`GEN_2D_TO_1D(8, (32*ECC_WAY), mq_eccset_rdata, cache_ram_missq_data_rdata)

// ECC
`GEN_2D_TO_3D(8, ECC_SET, ECC_BITS, ram_data_recc, ram_data_recc_eccset)
`GEN_3D_SEL_2D(8, ECC_SET, ECC_BITS, ram_data_recc_eccset, ram_data_recc_eccset_T,
               missq_ecc_refill_eccset, mq_eccset_old_ecc)
assign tc_bank_old_ecc = ram_data_recc[ram_bank_sel];

// per-bank controls
`GEN_1D_TO_2D(8, SET_ASSOC, wrbuf_cache_data_ren, wrbuf_data_ren)
`GEN_1D_TO_2D(8, SET_ASSOC, wrbuf_cache_data_wen, wrbuf_data_wen)
`GEN_1D_TO_2D(8, SET_ASSOC, missq_cache_data_ren, mq_data_ren)
`GEN_1D_TO_2D(8, SET_ASSOC, missq_cache_data_wen, mq_data_wen)
`GEN_1D_TO_2D(8, BANK_STRB, wrbuf_cache_data_strb, wrbuf_data_strb)
`GEN_1D_TO_2D(8, BANK_STRB, missq_cache_data_strb, mq_data_strb)
`GEN_1D_TO_2D(8, ECC_SET, wrbuf_cache_data_ecc_w, wrbuf_data_ecc_w)
`GEN_1D_TO_2D(8, ECC_SET, missq_cache_data_ecc_w, mq_data_ecc_w)

// 5x1
generate
    for (i = 0; i < 8; i = i + 1) begin: gen_ram_data_ports
        assign ram_data_en[i] = req_data_ren[i] | wrbuf_data_ren[i] | wrbuf_data_wen[i] |
                                mq_data_ren[i] | mq_data_wen[i];
        if (ECC_BITS >= 7) begin: gen_ram_data_wen_has_ecc
            assign ram_data_wen[i] = wrbuf_data_ecc_w[i] | mq_data_ecc_w[i];
        end else begin: gen_ram_data_wen_no_ecc
            assign ram_data_wen[i] = wrbuf_data_strb[i] | mq_data_strb[i];
        end
        assign ram_data_addr[i] = wrbuf_cache_data_indx_sel[i] ? wrbuf_cache_indx :
                                  missq_cache_indx_sel ? missq_cache_indx : ifc_req_index;
        assign ram_data_wdata[i] = missq_cache_indx_sel ? {ECC_SET{mq_data_wdata[i]}} :
                                                             wrbuf_cache_data_wdata;
        assign ram_data_wecc[i] = missq_cache_indx_sel ?
                                  {ECC_SET{missq_cache_data_wecc_perbank[i]}} :
                                  wrbuf_cache_data_wecc;
    end
endgenerate
// End DATA

//------------------------------------------------------------//
//                           LRU D
//------------------------------------------------------------//
// 3x1:
// miss-queue(r)  miss-queue(w)  cc_req(w)  hardware-initial(w)
//    |______________|____________|_______________|
//                          |
//                        LRU/D
// wire                     ram_lrud_en;
// wire [RAM_LRUD_WD -1:0] ram_lrud_wen;
// wire [INDEX_BITS  -1:0] ram_lrud_addr;
// wire [RAM_LRUD_WD -1:0] ram_lrud_wdata;
// wire [RAM_LRUD_WD -1:0] ram_lrud_rdata;

// ram bus
assign ram_lrud_rdata    =  ram_lrud_resp_bus;
assign ram_lrud_req_bus  =  {ram_lrud_en, ram_lrud_wen, ram_lrud_addr, ram_lrud_wdata};
// End LRU D

//------------------------------------------------------------//
//                           Assert
//------------------------------------------------------------//
`ifdef OPEN132_ASSERT
// req
assert property (@(posedge clk) cps_req |-> !req_rd_wr)
else begin
    $display("Assert Error!!!");
    #2 $finish;
end

// tagv
assert property (@(posedge clk) |ram_tagv_en |-> (
                     ((|wrbuf_cache_tagv_ren + |wrbuf_cache_tagv_wen + |missq_cache_tagv_ren + |missq_cache_tagv_wen) ==
                      5'd1) ? !(|req_tagv_ren && all_req_cango) : |req_tagv_ren))
else begin
    $display("Assert Error!!!");
    #2 $finish;
end

generate if(ECC_BITS>=7)
begin
    assert property (
        @(posedge clk)
        ram_tagv_en
        |-> ( wrbuf_cache_tagv_wen&&wrbuf_cache_tagv_ecc_w && !missq_cache_tagv_ecc_w ||
             !wrbuf_cache_tagv_wen&&!wrbuf_cache_tagv_ecc_w )
        )
    else begin $display("Assert Error!!!"); #2 $finish; end

    assert property (
        @(posedge clk)
        ram_tagv_en
        |-> ( missq_cache_tagv_wen&&missq_cache_tagv_ecc_w && !wrbuf_cache_tagv_ecc_w ||
             !missq_cache_tagv_wen&&!missq_cache_tagv_ecc_w )
        )
    else begin $display("Assert Error!!!"); #2 $finish; end
end
else
begin
    assert property (
        @(posedge clk)
        ram_tagv_en
        |-> ( wrbuf_cache_tagv_wen&&wrbuf_cache_tagv_strb && !missq_cache_tagv_strb ||
             !wrbuf_cache_tagv_wen&&!wrbuf_cache_tagv_strb )
        )
    else begin $display("Assert Error!!!"); #2 $finish; end

    assert property (
        @(posedge clk)
        ram_tagv_en
        |-> ( missq_cache_tagv_wen&&missq_cache_tagv_strb && !wrbuf_cache_tagv_strb ||
             !missq_cache_tagv_wen&&!missq_cache_tagv_strb )
        )
    else begin $display("Assert Error!!!"); #2 $finish; end
end
endgenerate

assert property (
    @(posedge clk)
    ram_tagv_en
    |-> ( (wrbuf_cache_tagv_ren||wrbuf_cache_tagv_wen) ? wrbuf_cache_tagv_indx_sel :
                                                  !wrbuf_cache_tagv_indx_sel||!all_req_cango )
    )
else begin $display("Assert Error!!!"); #2 $finish; end

assert property (
    @(posedge clk)
    ram_tagv_en
    |-> ( (missq_cache_tagv_ren||missq_cache_tagv_wen) ? missq_cache_indx_sel :
                                            !missq_cache_indx_sel )
    )
else begin $display("Assert Error!!!"); #2 $finish; end

//data ram
generate for (i=0; i<8; i=i+1)
begin
    assert property (
        @(posedge clk)
        |ram_data_en[i]
        |-> (( (|wrbuf_data_ren[i] + |wrbuf_data_wen[i] +
                |mq_data_ren   [i] + |mq_data_wen   [i] ) ==5'd1
             )? !(|req_data_ren[i]&&all_req_cango) : |req_data_ren[i] )
        )
    else begin $display("Assert Error!!!"); #2 $finish; end
    if(ECC_BITS>=7)
    begin
        assert property (
            @(posedge clk)
            ram_data_en[i]
            |-> ( wrbuf_data_wen[i] && wrbuf_data_ecc_w[i] && !mq_data_ecc_w[i] ||
                 !wrbuf_data_wen[i] &&!wrbuf_data_ecc_w[i] )
            )
        else begin $display("Assert Error!!!"); #2 $finish; end

        assert property (
            @(posedge clk)
            ram_data_en[i]
            |-> ( mq_data_wen[i] && mq_data_ecc_w[i] && !wrbuf_data_ecc_w[i] ||
                 !mq_data_wen[i] &&!mq_data_ecc_w[i] )
            )
        else begin $display("Assert Error!!!"); #2 $finish; end
    end
    else
    begin
        assert property (
            @(posedge clk)
            ram_data_en[i]
            |-> ( wrbuf_data_wen[i] && wrbuf_data_strb[i] && !mq_data_strb[i] ||
                 !wrbuf_data_wen[i] &&!wrbuf_data_strb[i] )
            )
        else begin $display("Assert Error!!!"); #2 $finish; end

        assert property (
            @(posedge clk)
            ram_data_en[i]
            |-> ( mq_data_wen[i] && mq_data_strb[i] && !wrbuf_data_strb[i] ||
                 !mq_data_wen[i] &&!mq_data_strb[i] )
            )
        else begin $display("Assert Error!!!"); #2 $finish; end
    end

end
endgenerate
`endif
// End Assert
endmodule

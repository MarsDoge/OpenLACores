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

module lsu_mq #(
    parameter AXI_DATA      = 32,            // 32/64/128
    parameter AXI_STRB      = 4,             // axi32: 4
    parameter AXI_ALIGN_N   = 2,             // axi32: 2
    parameter AXI_WID_N     = 4,             // axi32: 4
    parameter CC_LINE_AXI   = 8,             // axi32: 8

    // cache configuration
    // Cache size in KB: SET_ASSC*WAYSIZE
    parameter SET_ASSOC     = 4,             // 1/2/4 way set associative
    // parameter WAYSIZE      = 8*(2**10), //1/2/4/8/16 KB Size/way
    parameter BANK_WD       = 32 * 4,        // for 4way
    parameter BANK_STRB     = 16,            // for 4way
    parameter INDEX_BITS    = 5,             // for waysize 1K
    parameter TAG_BITS      = 22,            // for waysize 1K
    parameter TAGV_BITS     = 22 + 2,        // for waysize 1K
    parameter RAM_TAGV_WD   = (22 + 2) * 4,  // for waysize 1K * 4 ways
    parameter ECC_BITS      = 8,             // 1/7/8/9 bits
    parameter ECC_SET       = 2,             // for 4-ways, 64+8
    parameter ECC_WAY       = 2,             // for 4-ways, 64+8
    parameter ECC_BANK_BITS = 8 * 2          // for 4-ways, 64+8
) (
    input  wire                      has_ecc,
    // clk and reset
    input  wire                      clk,
    input  wire                      reset,
    input  wire                      data_reset,
    input  wire                      ctrl_nowrap,  // axi no wrap
    // axi
    input  wire                      axi_ar_ok,
    input  wire                      axi_rvalid,
    input  wire [    AXI_DATA-1: 0]  axi_rdata,
    input  wire                      axi_aw_ok,
    input  wire                      axi_w_ok,
    input  wire                      axi_bvalid,
    input  wire [             2: 0]  axi_bid,

    // from CACHE RAM
    input  wire [32*ECC_WAY*8-1: 0]  cache_ram_missq_data_rdata,  // 8 bank

    // tagcmp to missq
    input  wire                      tc_allow_refill,
    input  wire                      tc_hit_mq,
    input  wire                      tc_st_hit_mq_ok,
    input  wire [ CC_LINE_AXI-1: 0]  tc_st_hit_mq_sel,  // need see tc_st_hit_mq_ok
    input  wire [    AXI_STRB-1: 0]  tc_st_hit_mq_wstrb,
    input  wire [    AXI_DATA-1: 0]  tc_st_hit_mq_wdata,
    input  wire                      tagcmp_missq_valid,  // tc_valid
    input  wire                      tagcmp_missq_aw_do,  // go mq to send aw
    input  wire                      tagcmp_missq_bacs,  // burst access
    input  wire                      tagcmp_missq_exc,  // exclusive
    input  wire                      tagcmp_missq_cached,
    input  wire [            26: 0]  tagcmp_missq_araddr31_5,  // check read/write conflict
    input  wire [            31: 0]  tagcmp_missq_addr,
    input  wire [    AXI_STRB-1: 0]  tagcmp_missq_strb,
    input  wire [             1: 0]  tagcmp_missq_size,
    input  wire                      tagcmp_missq_pref,
    input  wire                      tagcmp_missq_lock,
    input  wire                      tagcmp_missq_ccop_do,
    input  wire                      tagcmp_missq_lock_exist,
    input  wire                      tagcmp_missq_ccop_valid,
    input  wire                      tagcmp_missq_ccop_inv,
    input  wire                      tagcmp_missq_ccop_sttag,
    input  wire                      tagcmp_missq_ccop_ldtag,
    input  wire                      tagcmp_missq_ccop_wb,
    input  wire                      tagcmp_missq_sttag_v,
    input  wire                      tagcmp_missq_sttag_d,
    input  wire                      tagcmp_missq_sttag_l,

    // from wrbuf, mq use tagv_correct in wrbuf
    input  wire                      wrbuf_allow_refill,
    output wire                      missq_wrbuf_ecc_in,  // mq gen old ecc
    output wire                      missq_wrbuf_correct,  // mq correct tagv
    input  wire [ RAM_TAGV_WD-1: 0]  wrbuf_missq_new_tagv,
    input  wire                      wrbuf_missq_tagv_1_err,  // 1 bit error
    input  wire [   SET_ASSOC-1: 0]  wrbuf_missq_tagv_fatal,  // 2 bit error
    // mq to wrbuf; set/clear lrud
    output wire                      missq_wrbuf_refill_lru,
    output wire [  INDEX_BITS-1: 0]  missq_wrbuf_indx,
    output wire [   SET_ASSOC-1: 0]  missq_wrbuf_way,
    output wire [   SET_ASSOC-1: 0]  missq_wrbuf_way_lock,
    output wire                      missq_wrbuf_lru_clr,
    output wire                      missq_wrbuf_dirty_wen,
    output wire                      missq_wrbuf_dirty_wdata,
    // from lru
    input  wire [   SET_ASSOC-1: 0]  lru_repl_way,
    input  wire [   SET_ASSOC-1: 0]  lru_repl_way_d,
    // to lru
    output wire                      mq_lrud_ren,
    output wire [  INDEX_BITS-1: 0]  mq_lrud_indx,
    // to cache ram
    output wire                      missq_cache_indx_sel,
    output wire [  INDEX_BITS-1: 0]  missq_cache_indx,
    output wire [   SET_ASSOC-1: 0]  missq_cache_tagv_ren,
    output wire [   SET_ASSOC-1: 0]  missq_cache_tagv_wen,
    output wire [   SET_ASSOC-1: 0]  missq_cache_tagv_strb,
    output wire [ RAM_TAGV_WD-1: 0]  missq_cache_tagv_wdata,  // all way
    output wire [     ECC_SET-1: 0]  missq_cache_tagv_ecc_w,
    output wire [ SET_ASSOC*8-1: 0]  missq_cache_data_ren,
    output wire [ SET_ASSOC*8-1: 0]  missq_cache_data_wen,
    output wire [ BANK_STRB*8-1: 0]  missq_cache_data_strb,
    output wire [32*ECC_WAY*8-1: 0]  missq_cache_data_wdata,  // all bank, one eccset, if no ecc, one way
    output wire [   ECC_SET*8-1: 0]  missq_cache_data_ecc_w,  // all bank

    // to tagcmp
    output wire                      missq_tagcmp_allowin,
    output wire                      missq_tagcmp_ar_stall,  // ar addr hit axi-b-queue
    output wire                      missq_tagcmp_bq_null,  // axi-b-queue is null
    output wire                      missq_tagcmp_bq_full,  // axi-b-queue is full
    output wire                      missq_tagcmp_valid,
    output wire                      missq_tagcmp_bacs,
    output wire                      missq_tagcmp_wait_wr,
    output wire [            31: 5]  missq_tagcmp_addr_31_5,
    output wire [ CC_LINE_AXI-1: 0]  missq_tagcmp_buf_valid,
    output wire [           255: 0]  missq_tagcmp_buf_data,
    // to axi
    output wire [             2: 0]  axi_aw_wid,  // for aw/w
    output wire                      axi_awvalid,  // write request
    output wire                      axi_awburst,  // write burst
    output wire                      axi_awexc,  // write exclusive
    output wire                      axi_awcache,  // write cached
    output wire [             2: 0]  axi_awsize,  // write size
    output wire [            31: 0]  axi_awaddr,  // write addr
    output wire                      axi_wvalid,  // write data request
    output wire [    AXI_STRB-1: 0]  axi_wstrb,  // write strobe
    output wire [    AXI_DATA-1: 0]  axi_wdata,  // write data
    output wire                      axi_wlast,  // write last
    // read data to pipeline
    output wire                      cps_data_ok,
    output wire [            31: 0]  cps_rdata,

    // for ecc
    input  wire [  ECC_BITS*8-1: 0]  mqway_ecc_syndrome,  // all banks in one way
    output wire                      missq_ecc_gen_new_ecc,  // gen refill   data ecc in state_refill
    output wire                      missq_ecc_gen_old_ecc,  // gen replaced data ecc in state_gen_ecc
    output wire [     ECC_SET-1: 0]  missq_ecc_refill_eccset,
    output wire                      mq_impr_fatal,
    output wire [  INDEX_BITS-1: 0]  ecc_fatal_indx,
    output wire [   SET_ASSOC-1: 0]  ecc_fatal_way,
    output wire                      ecc_fatal_intagv,
    output wire [             7: 0]  ecc_fatal_indata,
    output wire                      ecc_fatal_dirtywb,  // 2bit err data has been writeback.
    output wire [    TAG_BITS-1: 0]  ecc_fatal_dirty_tag,
    output wire                      ecc_err_add1,
    output wire                      refill_add1,

    // pipeline control
    output wire                      mq_stall_req,
    output wire                      mq_idle,
    output wire                      mq_bq_null  // all axi back
);

localparam DATA_WD_MQ_BUFS = AXI_DATA;

localparam N_BQUEUE = AXI_WID_N;

genvar i, j, k;

localparam MQ_IDLE    = 3'b000;
localparam MQ_WAIT_RD = 3'b001;
localparam MQ_LRU_CMP = 3'b010;  // lru
localparam MQ_GEN_ECC = 3'b011;  // gen ecc, syndrome
localparam MQ_CORRECT = 3'b111;  // if ecc error, correct data
localparam MQ_REFILL  = 3'b110;  // refill ecc
localparam MQ_WAIT_WR = 3'b100;
localparam MQ_WR_OK   = 3'b101;  // write complete

//============================================================//
//                     Regs Declarations
//============================================================//

// register
reg          mq_bacs;    // burst access
reg          mq_exc;
reg          mq_cached;
reg          mq_lock;
reg [ 31: 0] mq_addr;
reg [  1: 0] mq_size;

reg                 mq_dirty;
reg [         2: 0] mq_aw_wid;
reg                 mq_awvalid;
reg                 mq_wvalid;
reg [AXI_STRB-1: 0] mq_strb;

reg          mq_hit_repl;

reg [  2: 0] mq_state;
reg [  2: 0] mq_next_state;

reg [SET_ASSOC-1: 0] mq_refill_way;  // see {refill}

reg          mq_repl_is_dirty;  // see{refill}

// mq_rdata/tagv register
reg [32*ECC_WAY*8-1: 0] cache_ram_missq_data_rdata_r;  // all banks, one ecc_set

//============================================================//
//                     Wire Declarations
//============================================================//

wire                                              clk_mq_bufs;
wire                                              reset_mq_bufs;
wire                                              data_reset_mq_bufs;
wire [                                      7: 0] hit_mq_wen_mq_bufs;
wire [                    DATA_WD_MQ_BUFS/8-1: 0] hit_mq_strb_mq_bufs;
wire [                      DATA_WD_MQ_BUFS-1: 0] hit_mq_wdata_mq_bufs;
wire [                                      7: 0] upd_valid_mq_bufs;
wire [                    8*DATA_WD_MQ_BUFS-1: 0] upd_data_mq_bufs;
wire [                                      7: 0] valid_clr_mq_bufs;
wire [                                      7: 0] valid_set_mq_bufs;
wire [                    8*DATA_WD_MQ_BUFS-1: 0] buf_data_mq_bufs;
wire [                                      7: 0] buf_valid_mq_bufs;
wire                                              clk_bqueue;
wire                                              reset_bqueue;
wire                                              in_en_bqueue;
wire [                                     26: 0] in_addr31_5_bqueue;
wire                                              axi_b_ok_bqueue;
wire [                                      2: 0] axi_bid_bqueue;
wire [                                     26: 0] ck_addr31_5_bqueue;
wire                                              ck_hit_bqueue;
wire [                                      2: 0] empty_id_bqueue;
wire                                              bq_full_bqueue;
wire                                              bq_null_bqueue;

wire [          255: 0] mq_buf_data;
wire [CC_LINE_AXI-1: 0] mq_buf_valid;
wire [ 8*AXI_DATA-1: 0] mq_buf_data_ext;
wire [            7: 0] mq_buf_valid_ext;
wire                    mq_buf_all_valid;

wire          mq_wlast;

// Queue/FIFO Submodule Interface Declarations
wire                   mq_ecc_in_valid;
wire [ECC_BITS*8-1: 0] mq_data_syndrome_in;
wire [ECC_BITS*8-1: 0] mq_data_syndrome_q;
wire [  ECC_BITS-1: 0] mq_tagv_syndrome_in;

wire          mq_can_refill;

// need replace
wire          mq_begin_wb;  // after refill complete, begin writeback replaced way

wire [  2: 0] mq_lru_cmp_next_state;
wire [  2: 0] mq_refill_next_state;
wire          ecc_need_correct;

wire          r_ok;

wire          mq_bq_full;  // see{axi-b queue}
wire          axi_aw_wok;

wire          mq_read_lrud;
wire          mq_lru_cmp;
wire          mq_gen_ecc;
wire          mq_correct;
wire          mq_refill;
wire          mq_next_in;
wire          mq_next_ls_pref_in;
wire          mq_next_rd_in;
wire          mq_next_aw_in;
wire          mq_next_ccop_in;
wire          mq_is_replace;
wire          mq_wait_rd;
wire          mq_wait_wr;

wire          mq_cor_refill;

wire [  2: 0] mq_bq_empty_id;   // see{axi-b queue}
wire [ 31: 0] mq_repl_addr;     // bit0 is tagv.v
wire [ 31: 0] mq_ecc_upd_addr;
wire          mq_dirty_sttag;

// refill way number
wire [ INDEX_BITS-1: 0] mq_refill_indx;
wire [   TAG_BITS-1: 0] mq_refill_tag;
wire [4-AXI_ALIGN_N: 0] mq_axi_sel_temp;

// if ctrl_nowrap=1, mask axi_sel=0 for burst(tc_bacs=1)
// if ctrl_nowrap=0, mask addr[AXI_ALIGN_N:0]=0 for burst(tc_bacs=1)
wire [4-AXI_ALIGN_N: 0] mq_axi_sel;

// store from tc(uncached or non-alloct): set mq_buf_valid[1]
wire [CC_LINE_AXI-1: 0] mq_buf_tcaw_valid_set;
wire [CC_LINE_AXI-1: 0] mq_buf_tcaw_upd_valid;
wire [          255: 0] mq_buf_tcaw_upd_data;

// miss/replace clear valid
wire [CC_LINE_AXI-1: 0] mq_buf_miss_repl_valid_clr;

// axi rdata back
wire [CC_LINE_AXI-1: 0] mq_buf_r_valid_set;
wire [CC_LINE_AXI-1: 0] mq_buf_r_upd_valid;
wire [          255: 0] mq_buf_r_upd_data;

// replace data
wire [       32*8-1: 0] repl_data_way;        // see{ecc}
wire [CC_LINE_AXI-1: 0] mq_buf_wb_upd_valid;
wire [          255: 0] mq_buf_wb_upd_data;

// shift data for write
wire [CC_LINE_AXI-1: 0] mq_buf_s_valid_set;
wire [CC_LINE_AXI-1: 0] mq_buf_s_upd_valid;
wire [          255: 0] mq_buf_s_upd_data;

// update mq_buf
wire [CC_LINE_AXI-1: 0] mq_buf_upd_valid;
wire [          255: 0] mq_buf_upd_data;

// valid set and clr
wire [CC_LINE_AXI-1: 0] mq_buf_valid_set;
wire [CC_LINE_AXI-1: 0] mq_buf_valid_clr;

// store hit mq
wire [CC_LINE_AXI-1: 0] tc_st_hit_mq_sel_shf;  // if mq_wait_wr and w_ok, need shift
wire [CC_LINE_AXI-1: 0] tc_st_hit_mq_wen;

// The physical refill storage has eight lanes; only CC_LINE_AXI low lanes are active.
wire [           7: 0] tc_st_hit_mq_wen_ext;
wire [           7: 0] mq_buf_upd_valid_ext;
wire [8*AXI_DATA-1: 0] mq_buf_upd_data_ext;
wire [           7: 0] mq_buf_valid_clr_ext;
wire [           7: 0] mq_buf_valid_set_ext;

// gen 8 bank data xor_word
wire [32*ECC_WAY*8-1: 0] data_xor_word;

// wire [ECC_BITS*8   -1:0] data_xor_ecc;
wire [         8-1: 0] data_data_1bit_err;             // err in this word
wire [         8-1: 0] data_ecc_1bit_err;
wire [         8-1: 0] data_fatal;

wire          one_tagv_fatal;
wire          one_data_fatal;

wire          repl_fatal;
wire          repl_1bit_err;

wire          mq_refill_valid;

wire [SET_ASSOC-1: 0] mq_refill_eccset_way;  // see{refill ecc way/set}

wire [32*ECC_WAY*8-1: 0] correct_repl_data;  // all banks, one ecc_set

wire [ECC_SET-1: 0] mq_refill_eccset;  // set_assoc -> ecc_set
wire [ECC_WAY-1: 0] mq_refill_eccway;

// refill ecc set
wire [ECC_SET-1: 0] mq_refill_eccset_tmp;      // set_assoc -> ecc_set

// new tagv in wrbuf
wire [RAM_TAGV_WD-1: 0] repl_tagv_allway;      // all ways

// final replaced data/tagv for refill eccset
wire [32*ECC_WAY*8-1: 0] repl_data_eccset;  // all banks, one ecc_set

wire [SET_ASSOC-1: 0] repl_ways_lock;

// repl data
wire [32*ECC_WAY-1: 0] repl_data_eccset_perbank[  7: 0];
wire [          31: 0] repl_data_eccset_eccway [  7: 0][ECC_WAY-1:0];
wire [        32-1: 0] repl_data_way_perbank[  7: 0];

// repl tagv
wire [TAGV_BITS-1: 0] repl_tagv_perway[SET_ASSOC-1:0];
wire [TAGV_BITS-1: 0] repl_tagv;

// mq axi b queue
wire          tc_addr_hit_bq;

// mq read/write to lru-d ram
wire [INDEX_BITS-1: 0] tagcmp_missq_ccop_indx;

// read out replaced way
wire [SET_ASSOC-1: 0] mq_repl_way;         // see{lru algorithm}
wire [SET_ASSOC-1: 0] mq_ccop_way;
wire [SET_ASSOC-1: 0] mq_repl_ccop_way;    // cache/isync way or lru replaced way
wire [SET_ASSOC-1: 0] mq_repl_ccop_way_d;
wire                  mq_repl_dirty;       // replaced way is dirty

// data
wire [SET_ASSOC-1: 0] mq_repl_data_ren[  7: 0];

// get replaced tag
wire [TAG_BITS-1: 0] way_rd_tag;
wire                 way_rd_v;
wire                 way_rd_l;

// if has ecc, cache op need write data/tagv to update ecc bit
wire                  ccop_no_upd_tagv;
wire                  ccop_no_upd_data;
wire [SET_ASSOC-1: 0] tagv_refill_allway;  // TAGV refill write all way
wire [  ECC_WAY-1: 0] data_refill_eccway;  // DATA refill write only one eccset

// refill tagv
wire                    mq_wr_tagv;
wire [  SET_ASSOC-1: 0] mq_tagv_wen;
wire [  TAGV_BITS-1: 0] mq_tagv_wdata;
wire [RAM_TAGV_WD-1: 0] mq_tagv_wdata_allway;
wire                    mq_w_sttag_v_0;
wire                    mq_w_sttag_l_0;
wire                    mq_w_sttag_l;

// ecc write tagv all way
wire [RAM_TAGV_WD-1: 0] mq_refill_allway_xtagv;

// refill data
wire                   mq_wr_data;                     // see{refill}
wire [ SET_ASSOC-1: 0] mq_refill_data_wen[  7: 0];
wire [ BANK_STRB-1: 0] mq_refill_data_strb[  7: 0];
wire [32*ECC_WAY-1: 0] mq_refill_data_eccway[  7: 0];

wire [BANK_STRB-1: 0] mq_refill_way_ben;
wire [         31: 0] mq_refill_data_wdata_way[  7: 0];

wire [32*ECC_WAY-1: 0] mq_refill_eccway_xdata;

wire          mq_will_we;
wire [ 26: 0] mq_will_wa;
`ifdef CONFIG_MMU

`endif

//============================================================//
//                    Module Implementation
//============================================================//

// Instance Parameter Aliases
// x_lsu_mq_axi_bufs
// x_lsu_ecc_corr_0
// x_lsu_ecc_corr_1
// x_lsu_ecc_corr_2
// x_lsu_ecc_corr_3
// x_lsu_ecc_corr_4
// x_lsu_ecc_corr_5
// x_lsu_ecc_corr_6
// x_lsu_ecc_corr_7
// x_lsu_mq_bqueue

//------------------------------------------------------------//
//                         Miss Queue
//------------------------------------------------------------//

// Instance Boundary Alias Mapping
// x_lsu_mq_axi_bufs

assign clk_mq_bufs           =  clk;
assign reset_mq_bufs         =  reset;
assign data_reset_mq_bufs    =  data_reset;
assign hit_mq_wen_mq_bufs    =  tc_st_hit_mq_wen_ext;
assign hit_mq_strb_mq_bufs   =  tc_st_hit_mq_wstrb;
assign hit_mq_wdata_mq_bufs  =  tc_st_hit_mq_wdata;
assign upd_valid_mq_bufs     =  mq_buf_upd_valid_ext;
assign upd_data_mq_bufs      =  mq_buf_upd_data_ext;
assign valid_clr_mq_bufs     =  mq_buf_valid_clr_ext;
assign valid_set_mq_bufs     =  mq_buf_valid_set_ext;
assign mq_buf_data_ext       =  buf_data_mq_bufs;
assign mq_buf_valid_ext      =  buf_valid_mq_bufs;
// x_lsu_mq_bqueue
assign clk_bqueue          =  clk;
assign reset_bqueue        =  reset;
assign in_en_bqueue        =  mq_will_we;
assign in_addr31_5_bqueue  =  mq_will_wa;
assign axi_b_ok_bqueue     =  axi_bvalid;
assign axi_bid_bqueue      =  axi_bid;
assign ck_addr31_5_bqueue  =  tagcmp_missq_araddr31_5;
assign tc_addr_hit_bq      =  ck_hit_bqueue;
assign mq_bq_empty_id      =  empty_id_bqueue;
assign mq_bq_full          =  bq_full_bqueue;
assign mq_bq_null          =  bq_null_bqueue;

// Queue/FIFO Entry Instances
lsu_mq_axi_bufs #(
    .DATA_WD (DATA_WD_MQ_BUFS)
) x_lsu_mq_axi_bufs (
    .clk          (clk_mq_bufs         ),
    .reset        (reset_mq_bufs       ),
    .data_reset   (data_reset_mq_bufs  ),
    .hit_mq_wen   (hit_mq_wen_mq_bufs  ),
    .hit_mq_strb  (hit_mq_strb_mq_bufs ),
    .hit_mq_wdata (hit_mq_wdata_mq_bufs),
    .upd_valid    (upd_valid_mq_bufs   ),
    .upd_data     (upd_data_mq_bufs    ),
    .valid_clr    (valid_clr_mq_bufs   ),
    .valid_set    (valid_set_mq_bufs   ),
    .buf_data     (buf_data_mq_bufs    ),
    .buf_valid    (buf_valid_mq_bufs   )
);

lsu_mq_ecc_buf #(
    .ECC_BITS (ECC_BITS)
) x_lsu_mq_ecc_buf (
    .has_ecc             (has_ecc            ),
    .clk                 (clk                ),
    .data_reset          (data_reset         ),
    .mq_ecc_in_valid     (mq_ecc_in_valid    ),
    .mq_tagv_syndrome_in (mq_tagv_syndrome_in),
    .mq_data_syndrome_in (mq_data_syndrome_in),
    // Legacy mq_tagv_syndrome_q output is intentionally unconnected.
    .mq_tagv_syndrome_q  (                   ),
    .mq_data_syndrome_q  (mq_data_syndrome_q )
);

lsu_mq_bqueue #(
    .N (N_BQUEUE)
) x_lsu_mq_bqueue (
    .clk         (clk_bqueue        ),
    .reset       (reset_bqueue      ),
    // enter
    .in_en       (in_en_bqueue      ),
    .in_addr31_5 (in_addr31_5_bqueue),  // addr[31:5]

    // quit
    .axi_b_ok    (axi_b_ok_bqueue   ),
    .axi_bid     (axi_bid_bqueue    ),

    // check conflict
    .ck_addr31_5 (ck_addr31_5_bqueue),
    .ck_hit      (ck_hit_bqueue     ),

    // full
    .empty_id    (empty_id_bqueue   ),
    .bq_full     (bq_full_bqueue    ),
    .bq_null     (bq_null_bqueue    )
);

assign mq_buf_all_valid  =  &mq_buf_valid;
assign mq_buf_data       =  mq_buf_data_ext[255:0];
assign mq_buf_valid      =  mq_buf_valid_ext[CC_LINE_AXI-1:0];

assign mq_can_refill  =  tc_allow_refill && wrbuf_allow_refill;

//------------------------------------------------------------//
//                      Mq State Machine
//------------------------------------------------------------//

assign r_ok  =  axi_rvalid;

assign axi_aw_wok  =  (!axi_awvalid || axi_aw_ok) && (!axi_wvalid || axi_w_ok && axi_wlast) &&
                        !mq_bq_full;  // if bq full, can't set aw_wok, to stop mq_state
always @ ( posedge clk )
begin
    if(reset) begin
        mq_state <= MQ_IDLE;
    end
    else begin
        mq_state <= mq_next_state;
    end
end
always @ ( mq_state
           or tagcmp_missq_valid
           or tagcmp_missq_aw_do
           or tagcmp_missq_ccop_do
           or axi_ar_ok
           or mq_bacs
           or r_ok
           or mq_can_refill
           or mq_buf_all_valid
           or mq_lru_cmp_next_state
           or ecc_need_correct
           or mq_refill_next_state
           or axi_aw_wok
           or mq_hit_repl
           or tc_hit_mq
         )
begin
    case(mq_state)
        MQ_IDLE: begin
            mq_next_state = tagcmp_missq_valid && tagcmp_missq_aw_do ? MQ_WAIT_WR : tagcmp_missq_valid &&
            tagcmp_missq_ccop_do ? MQ_LRU_CMP : tagcmp_missq_valid && axi_ar_ok ? MQ_WAIT_RD : MQ_IDLE;
        end
        MQ_WAIT_RD: begin
            mq_next_state = !mq_bacs && r_ok ? MQ_IDLE :
            mq_can_refill && mq_buf_all_valid ? MQ_LRU_CMP : MQ_WAIT_RD;
        end
        MQ_LRU_CMP: begin
            // mq_next_state = MQ_REFILL;
            mq_next_state = mq_lru_cmp_next_state;
        end
        MQ_GEN_ECC: begin
            mq_next_state = MQ_CORRECT;
        end
        MQ_CORRECT: begin
            mq_next_state = ecc_need_correct ? MQ_REFILL : mq_refill_next_state;
        end
        MQ_REFILL: begin
            mq_next_state = mq_refill_next_state;
        end
        MQ_WAIT_WR: begin
            mq_next_state = axi_aw_wok ? MQ_WR_OK : MQ_WAIT_WR;
        end
        MQ_WR_OK: begin
            mq_next_state = !mq_hit_repl && !tc_hit_mq ? MQ_IDLE : mq_can_refill ? MQ_LRU_CMP : MQ_WR_OK;
        end
        default: mq_next_state = MQ_IDLE;
    endcase
end

assign mq_lru_cmp_next_state  =  has_ecc ? MQ_GEN_ECC : MQ_REFILL;
assign mq_refill_next_state   =  mq_begin_wb ? MQ_WAIT_WR : MQ_IDLE;

assign mq_refill           =  (mq_state == MQ_REFILL);
assign mq_read_lrud        =  (mq_state == MQ_WAIT_RD) && mq_can_refill && mq_buf_all_valid ||
                                (mq_state == MQ_WR_OK) && mq_hit_repl && mq_can_refill || mq_next_ccop_in;
assign mq_lru_cmp          =  (mq_state == MQ_LRU_CMP);
assign mq_gen_ecc          =  (mq_state == MQ_GEN_ECC) && has_ecc;
assign mq_correct          =  (mq_state == MQ_CORRECT) && has_ecc;
assign mq_next_rd_in       =  (mq_state == MQ_IDLE) && tagcmp_missq_valid && axi_ar_ok;
assign mq_next_aw_in       =  (mq_state == MQ_IDLE) && tagcmp_missq_valid && tagcmp_missq_aw_do;
assign mq_next_ls_pref_in  =  mq_next_rd_in || mq_next_aw_in;
assign mq_next_ccop_in     =  (mq_state == MQ_IDLE) && tagcmp_missq_valid && tagcmp_missq_ccop_do;
assign mq_next_in          =  mq_next_ls_pref_in || mq_next_ccop_in;
assign mq_is_replace       =  (mq_state == MQ_WAIT_WR) || (mq_state == MQ_WR_OK);
assign mq_wait_rd          =  (mq_state == MQ_WAIT_RD);
assign mq_wait_wr          =  (mq_state == MQ_WAIT_WR);

assign mq_cor_refill  =  mq_correct || mq_refill;
assign mq_stall_req   =  mq_lru_cmp || mq_gen_ecc || mq_cor_refill;

assign mq_idle  =  mq_state == MQ_IDLE;
// End Mq State Machine

//------------------------------------------------------------//
//                    Tagcmp > Miss Queue
//------------------------------------------------------------//
assign mq_dirty_sttag  =  tagcmp_missq_sttag_d && tagcmp_missq_ccop_sttag && tagcmp_missq_sttag_v;
always @ ( posedge clk )
begin
    mq_bacs   <= reset ? 1'b0 : mq_next_in ? tagcmp_missq_bacs : mq_bacs;
    mq_exc    <= reset ? 1'b0 : mq_next_in ? tagcmp_missq_exc : mq_exc;
    mq_cached <= reset ? 1'b0 : mq_next_in ? tagcmp_missq_cached : mq_cached;
    mq_lock   <= reset ? 1'b0 : mq_next_in ? tagcmp_missq_lock : mq_begin_wb ? 1'b0 : mq_lock;
    mq_addr   <= reset ? 32'd0 : mq_next_in ? tagcmp_missq_addr : mq_begin_wb ? mq_repl_addr : mq_addr;
    mq_size   <= reset ? 2'd0 : mq_next_in ? tagcmp_missq_size : mq_size;
    mq_dirty <= reset ? 1'b0 : mq_next_ccop_in ? mq_dirty_sttag :
    mq_next_ls_pref_in || mq_begin_wb ? 1'b0 : tc_st_hit_mq_ok ? 1'b1 : mq_dirty;
    mq_aw_wid  <= reset ? 3'd0 : mq_begin_wb || mq_next_aw_in ? mq_bq_empty_id : mq_aw_wid;
    mq_awvalid <= reset ? 1'b0 : mq_begin_wb || mq_next_aw_in ? 1'b1 : axi_aw_ok ? 1'b0 : mq_awvalid;
    mq_wvalid <= reset ? 1'b0 :
    mq_next_rd_in ? 1'b0 : mq_next_aw_in ? 1'b1 : mq_begin_wb ? 1'b1 : mq_wlast && axi_w_ok ? 1'b0 : mq_wvalid;
    mq_strb <= reset ? {AXI_STRB{1'b0}} :
    mq_next_aw_in ? tagcmp_missq_strb : mq_begin_wb ? {AXI_STRB{1'b1}} : mq_strb;
    mq_hit_repl <= reset ? 1'b0 :
    mq_next_in || mq_begin_wb ? 1'b0 : tc_hit_mq && mq_is_replace ? 1'b1 : mq_hit_repl;
end
assign mq_wlast  =  mq_buf_valid[1];

assign {mq_refill_tag, mq_refill_indx, mq_axi_sel_temp}  =  mq_addr[31:AXI_ALIGN_N];

assign mq_axi_sel  =  mq_axi_sel_temp & {(5 - AXI_ALIGN_N) {!ctrl_nowrap}};
// End Tagcmp > Miss Queue

//------------------------------------------------------------//
//                     mq_buf Data&valid
//------------------------------------------------------------//
assign mq_buf_tcaw_valid_set       =  {{(CC_LINE_AXI - 2) {1'b0}}, mq_next_aw_in, 1'b0};
assign mq_buf_tcaw_upd_valid       =  {{(CC_LINE_AXI - 1) {1'b0}}, mq_next_aw_in};
assign mq_buf_tcaw_upd_data        =  {CC_LINE_AXI{tc_st_hit_mq_wdata}} & {256{mq_idle}};
assign mq_buf_miss_repl_valid_clr  =  {{CC_LINE_AXI{mq_next_rd_in || mq_begin_wb}}};

assign mq_buf_r_valid_set[0]  =  mq_wait_rd && mq_bacs && r_ok && !mq_buf_valid[0] &&
                                   (mq_buf_valid[CC_LINE_AXI-1] || !(|mq_axi_sel));
generate
    for(i = 1; i < CC_LINE_AXI; i = i + 1)
    begin: gen_mq_buf_read_back
        assign mq_buf_r_valid_set[i]  =  mq_wait_rd && mq_bacs && r_ok && !mq_buf_valid[i] &&
                                           (mq_buf_valid[i-1] || mq_axi_sel == i);
    end
endgenerate
assign mq_buf_r_upd_valid         =  mq_buf_r_valid_set;
assign mq_buf_r_upd_data          =  {CC_LINE_AXI{axi_rdata}} & {256{mq_wait_rd}};

assign mq_buf_wb_upd_valid  =  {CC_LINE_AXI{mq_begin_wb}};
assign mq_buf_wb_upd_data   =  repl_data_way & {256{mq_begin_wb}};
assign mq_buf_s_valid_set[CC_LINE_AXI-1]  =  mq_wait_wr && axi_w_ok;
generate
    for(i = 0; i < CC_LINE_AXI-1; i = i + 1)
    begin: gen_mq_buf_shift_write
        assign mq_buf_s_valid_set[i]  =  mq_wait_wr && axi_w_ok && mq_buf_valid[i+1];
    end
endgenerate
assign mq_buf_s_upd_valid   =  {CC_LINE_AXI{mq_wait_wr && axi_w_ok}};
assign mq_buf_s_upd_data    =  {mq_buf_data[AXI_DATA-1:0], mq_buf_data[255:AXI_DATA]} & {256{mq_wait_wr}};
assign mq_buf_upd_valid     =  mq_buf_tcaw_upd_valid | mq_buf_r_upd_valid | mq_buf_wb_upd_valid | mq_buf_s_upd_valid;
assign mq_buf_upd_data      =  mq_buf_tcaw_upd_data | mq_buf_r_upd_data | mq_buf_wb_upd_data | mq_buf_s_upd_data;
assign mq_buf_valid_set     =  mq_buf_tcaw_valid_set | mq_buf_r_valid_set | mq_buf_s_valid_set;
assign mq_buf_valid_clr     =  mq_buf_miss_repl_valid_clr;

assign tc_st_hit_mq_sel_shf  =  mq_wait_wr && axi_w_ok ? {tc_st_hit_mq_sel[0], tc_st_hit_mq_sel[CC_LINE_AXI-1:1]} :
                                  tc_st_hit_mq_sel;
assign tc_st_hit_mq_wen      =  tc_st_hit_mq_sel_shf & {CC_LINE_AXI{tc_st_hit_mq_ok}};
assign tc_st_hit_mq_wen_ext  =  {{(8 - CC_LINE_AXI) {1'b0}}, tc_st_hit_mq_wen};
assign mq_buf_upd_valid_ext  =  {{(8 - CC_LINE_AXI) {1'b0}}, mq_buf_upd_valid};
assign mq_buf_upd_data_ext   =  {{(8 * AXI_DATA - 256) {1'b0}}, mq_buf_upd_data};
assign mq_buf_valid_clr_ext  =  {{(8 - CC_LINE_AXI) {1'b0}}, mq_buf_valid_clr};
assign mq_buf_valid_set_ext  =  {{(8 - CC_LINE_AXI) {1'b0}}, mq_buf_valid_set};

// End mq_buf Data&valid
// End Miss Queue

//------------------------------------------------------------//
//                            Ecc
//------------------------------------------------------------//
// register ecc
assign mq_ecc_in_valid  =  mq_gen_ecc;

assign mq_data_syndrome_in  =  mqway_ecc_syndrome;

// mq tagv correct in wrbuf
// wire [ECC_BITS   -1:0] mq_tagv_syndrome_q;
assign mq_tagv_syndrome_in  =  {ECC_BITS{1'b0}};  // mq_tagv_ecc_syndrome;

generate
    for(i = 0; i < 8; i = i + 1)
    begin: gen_mq_data_correct_perbank
        lsu_ecc_corr #(
            .ECC_BITS  (ECC_BITS),
            .ECC_WAY   (ECC_WAY ),
            .DATA_BITS (32      )
        ) x_lsu_ecc_corr (
            .ecc_syndrome  (mq_data_syndrome_q[ECC_BITS*i+:ECC_BITS]  ),
            .xor_word      (data_xor_word[32*ECC_WAY*i+:32*ECC_WAY]  ),
            .xor_ecc       (                                               ),
            .data_1bit_err (data_data_1bit_err[i]                          ),
            .ecc_1bit_err  (data_ecc_1bit_err[i]                           ),
            .fatal         (data_fatal[i]                                  )
        );
    end
endgenerate

// tagv correct in wrbuf
assign missq_wrbuf_ecc_in   =  missq_ecc_gen_old_ecc;
assign missq_wrbuf_correct  =  mq_correct;
assign one_tagv_fatal       =  |wrbuf_missq_tagv_fatal;
assign one_data_fatal       =  |data_fatal;

assign repl_fatal        =  one_tagv_fatal || one_data_fatal;
assign repl_1bit_err     =  (wrbuf_missq_tagv_1_err || |data_data_1bit_err || |data_ecc_1bit_err);
assign ecc_need_correct  =  mq_correct && repl_1bit_err;
assign mq_refill_valid   =  mq_correct && !repl_1bit_err || mq_refill;
//------------------------------------------------------------//
//                    Ecc To Cpu Pipeline
//------------------------------------------------------------//
assign missq_ecc_gen_new_ecc  =  mq_cor_refill;  // gen buf data ecc in state_lru_cmp
assign missq_ecc_gen_old_ecc  =  mq_gen_ecc;  // gen replaced data ecc in state_gen_ecc
assign mq_impr_fatal          =  repl_fatal && mq_refill_valid;
assign ecc_fatal_indx         =  mq_refill_indx;
assign ecc_fatal_way          =  mq_refill_eccset_way & {SET_ASSOC{one_data_fatal}} | wrbuf_missq_tagv_fatal;
assign ecc_fatal_intagv       =  one_tagv_fatal;
assign ecc_fatal_indata       =  data_fatal;
assign ecc_fatal_dirtywb      =  mq_repl_is_dirty;
assign ecc_fatal_dirty_tag    =  mq_refill_tag;
assign ecc_err_add1           =  ecc_need_correct;
assign refill_add1            =  mq_refill_valid && !tagcmp_missq_ccop_valid;
// End Ecc To Cpu Pipeline

always @ ( posedge clk )
begin
    cache_ram_missq_data_rdata_r <= mq_gen_ecc ? cache_ram_missq_data_rdata :
    mq_correct ? correct_repl_data : cache_ram_missq_data_rdata_r;
end

// correct
assign correct_repl_data  =  cache_ram_missq_data_rdata_r ^ data_xor_word;
// End Ecc

//------------------------------------------------------------//
//                   Gen Replaced Tagv Data
//------------------------------------------------------------//
//------------------------------------------------------------//
//                     Refill Ecc Way Set
//------------------------------------------------------------//
`GEN_COMPRESS_OR(ECC_SET, ECC_WAY, mq_refill_way, mq_refill_eccset_tmp)
generate
    if(ECC_SET == 1)
    begin: gen_only_one_eccset
        assign mq_refill_eccset  =  1'b1;
    end
    else
    begin: gen_not_only_one_eccset
        assign mq_refill_eccset  =  mq_refill_eccset_tmp;
    end
endgenerate
`GEN_EXTEND(ECC_SET, ECC_WAY, mq_refill_eccset, mq_refill_eccset_way)

// refill ecc way
generate
    if(ECC_BITS <= 7)
    begin: gen_ecc_way_ecc7
        assign mq_refill_eccway  =  1'b1;
    end
    else if(ECC_BITS == 8)
    begin: gen_ecc_way_ecc8
        if(SET_ASSOC == 2)
        begin: gen_ecc_way_ecc8_assoc2
            assign mq_refill_eccway  =  mq_refill_way[1:0];
        end
        else
        begin: gen_ecc_way_ecc8_assoc4
            assign mq_refill_eccway  =  mq_refill_way[1:0] | mq_refill_way[3:2];
        end
    end
    else if(ECC_BITS == 9)
    begin: gen_ecc_way_ecc9
        assign mq_refill_eccway  =  mq_refill_way;
    end
endgenerate

assign missq_ecc_refill_eccset  =  mq_refill_eccset;
// End Refill Ecc Way Set

//------------------------------------------------------------//
//                  After Correct Data Tagv
//------------------------------------------------------------//
// if no ecc, wrbuf_missq_new_tagv=tc_tagv_rdata
assign repl_tagv_allway      =  wrbuf_missq_new_tagv;

assign repl_data_eccset  =  has_ecc ? cache_ram_missq_data_rdata_r : cache_ram_missq_data_rdata;
// End After Correct Data Tagv

//------------------------------------------------------------//
//                  Get All Ways' Lock Flag
//------------------------------------------------------------//
generate
    if(SET_ASSOC == 1)
    begin: gen_lock_only_1way
        assign repl_ways_lock  =  1'b0;
    end
    else
    begin: gen_lock_2_4_ways
        for(i = 0; i < SET_ASSOC; i = i + 1)
        begin: gen_lock_perway
            assign repl_ways_lock[i]  =  repl_tagv_allway[TAGV_BITS*i+:1];
        end
    end
endgenerate
// End Get All Ways' Lock Flag

//------------------------------------------------------------//
//                   Gen Replaced Data Tagv
//------------------------------------------------------------//
`GEN_1D_TO_2D(8, (32*ECC_WAY), repl_data_eccset, repl_data_eccset_perbank)
`GEN_2D_TO_3D(8, ECC_WAY, 32, repl_data_eccset_perbank, repl_data_eccset_eccway)
`GEN_3D_SEL_2D(8, ECC_WAY, 32, repl_data_eccset_eccway,
               repl_data_eccset_eccway_T, mq_refill_eccway, repl_data_way_perbank)
`GEN_2D_TO_1D(8, 32, repl_data_way_perbank, repl_data_way)

`GEN_1D_TO_2D(SET_ASSOC, TAGV_BITS, repl_tagv_allway, repl_tagv_perway)
`GEN_2D_SEL_1D(SET_ASSOC, TAGV_BITS, repl_tagv_perway,
               repl_tagv_perway_T, mq_refill_way, repl_tagv)
// End Gen Replaced Data Tagv
// End Gen Replaced Tagv Data

//------------------------------------------------------------//
//                        Mq To Tagcmp
//------------------------------------------------------------//
//------------------------------------------------------------//
//                        Mq To Tagcmp
//------------------------------------------------------------//
assign missq_tagcmp_allowin    =  (mq_state == MQ_IDLE);
assign missq_tagcmp_ar_stall   =  tc_addr_hit_bq;
assign missq_tagcmp_bq_null    =  mq_bq_null;
assign missq_tagcmp_bq_full    =  mq_bq_full;
assign missq_tagcmp_valid      =  (mq_state != MQ_IDLE);
assign missq_tagcmp_bacs       =  mq_bacs;
assign missq_tagcmp_wait_wr    =  mq_wait_wr;
assign missq_tagcmp_addr_31_5  =  mq_addr[31:5];
assign missq_tagcmp_buf_valid  =  mq_buf_valid;
assign missq_tagcmp_buf_data   =  mq_buf_data;
// End Mq To Tagcmp
// End Mq To Tagcmp

//------------------------------------------------------------//
//                      Mq To Cache Ram
//------------------------------------------------------------//
//------------------------------------------------------------//
//                          Read Lru
//------------------------------------------------------------//
assign tagcmp_missq_ccop_indx  =  tagcmp_missq_addr[INDEX_BITS+4 : 5];
assign mq_lrud_ren             =  mq_read_lrud;
assign mq_lrud_indx            =  mq_idle ? tagcmp_missq_ccop_indx : mq_refill_indx;
// End Read Lru

//------------------------------------------------------------//
//                   Read Replaced Tag Data
//------------------------------------------------------------//
assign mq_repl_way         =  lru_repl_way;
assign mq_ccop_way         =  mq_addr[SET_ASSOC-1:0];
assign mq_repl_ccop_way    =  tagcmp_missq_ccop_valid ? mq_ccop_way : mq_repl_way;
assign mq_repl_ccop_way_d  =  mq_repl_ccop_way & lru_repl_way_d;
assign mq_repl_dirty       =  (|mq_repl_ccop_way_d);

// tag
assign missq_cache_tagv_ren  =  {SET_ASSOC{mq_lru_cmp}};

generate
    for(i = 0; i < 8; i = i + 1)
    begin: gen_replace_read_data_enable
        assign mq_repl_data_ren[i]  =  {SET_ASSOC{mq_lru_cmp}};
    end
endgenerate
assign missq_cache_data_ren  =  {
                                  mq_repl_data_ren[7],
                                  mq_repl_data_ren[6],
                                  mq_repl_data_ren[5],
                                  mq_repl_data_ren[4],
                                  mq_repl_data_ren[3],
                                  mq_repl_data_ren[2],
                                  mq_repl_data_ren[1],
                                  mq_repl_data_ren[0]
                                };
// End Read Replaced Data

//------------------------------------------------------------//
//                           Refill
//------------------------------------------------------------//
// refill way number
// reg  mq_repl_is_dirty;
always @ ( posedge clk )
begin
    mq_refill_way    <= data_reset ? {SET_ASSOC{1'b0}} : mq_lru_cmp ? mq_repl_ccop_way : mq_refill_way;
    mq_repl_is_dirty <= data_reset ? 1'b0 : mq_lru_cmp ? mq_repl_dirty : mq_repl_is_dirty;
end
assign mq_begin_wb  =  mq_refill_valid && mq_repl_is_dirty && !(tagcmp_missq_ccop_valid && !tagcmp_missq_ccop_wb);

generate
    if(SET_ASSOC == 1)
    begin: gen_repl_tagv_only_1way
        assign {way_rd_tag, way_rd_v, way_rd_l}  =  {repl_tagv, 1'b0};
    end
    else
    begin: gen_repl_tagv_2_4_ways
        assign {way_rd_tag, way_rd_v, way_rd_l}  =  repl_tagv[TAGV_BITS-1:0];
    end
endgenerate

assign mq_repl_addr  =  {way_rd_tag, mq_refill_indx, 5'd0};

// cache op:load tag, if pref is 1, means ex cancel ldtag op
assign cps_data_ok  =  mq_refill_valid && tagcmp_missq_ccop_ldtag && !tagcmp_missq_pref;
assign cps_rdata    =  {way_rd_tag, {(24 - TAG_BITS) {1'b0}}, way_rd_v, mq_repl_is_dirty, way_rd_l, 5'd0};

assign ccop_no_upd_tagv    =  tagcmp_missq_ccop_ldtag || tagcmp_missq_ccop_wb && !tagcmp_missq_ccop_inv;
assign ccop_no_upd_data    =  tagcmp_missq_ccop_valid;
assign tagv_refill_allway  =  !has_ecc ? {SET_ASSOC{1'b1}} : ccop_no_upd_tagv ? {SET_ASSOC{1'b0}} : mq_refill_way;
assign data_refill_eccway  =  !has_ecc ? {ECC_WAY{1'b1}} : ccop_no_upd_data ? {ECC_WAY{1'b0}} : mq_refill_eccway;

assign mq_w_sttag_v_0  =  tagcmp_missq_ccop_sttag && !tagcmp_missq_sttag_v;
assign mq_w_sttag_l_0  =  tagcmp_missq_ccop_sttag && !tagcmp_missq_sttag_l;
assign mq_w_sttag_l    =  tagcmp_missq_ccop_sttag && tagcmp_missq_sttag_l && tagcmp_missq_sttag_v;
assign mq_wr_tagv      =  mq_refill_valid && (has_ecc || (tagcmp_missq_ccop_inv || tagcmp_missq_ccop_sttag ||
                            tagcmp_missq_lock_exist || !tagcmp_missq_ccop_valid));
// all way's tagv will be wrote if has ecc
assign mq_tagv_wen  =  (mq_refill_way | {SET_ASSOC{has_ecc}}) & {SET_ASSOC{mq_wr_tagv}};
generate
    if(SET_ASSOC == 1)
    begin: gen_tagv_wdata_only_1way
        assign mq_tagv_wdata  =  {mq_refill_tag, !(tagcmp_missq_ccop_inv || mq_w_sttag_v_0)};
    end
    else
    begin: gen_tagv_wdata_2_4_ways
        assign mq_tagv_wdata  =  {mq_refill_tag, !(tagcmp_missq_ccop_inv || mq_w_sttag_v_0),
                                  (mq_w_sttag_l || mq_lock)};
    end
endgenerate
assign missq_cache_tagv_wen    =  mq_tagv_wen;
assign missq_cache_tagv_strb   =  mq_tagv_wen;
assign missq_cache_tagv_wdata  =  {RAM_TAGV_WD{mq_cor_refill}} & mq_tagv_wdata_allway;

// tagv write all way
assign missq_cache_tagv_ecc_w  =  {ECC_SET{mq_wr_tagv}};

`GEN_EXTEND(SET_ASSOC, TAGV_BITS, tagv_refill_allway, mq_refill_allway_xtagv)
assign mq_tagv_wdata_allway        =  mq_refill_allway_xtagv & {SET_ASSOC{mq_tagv_wdata}} | ~mq_refill_allway_xtagv & repl_tagv_allway;

assign {mq_refill_data_wdata_way[7], mq_refill_data_wdata_way[6], mq_refill_data_wdata_way[5],
            mq_refill_data_wdata_way[4], mq_refill_data_wdata_way[3], mq_refill_data_wdata_way[2],
            mq_refill_data_wdata_way[1], mq_refill_data_wdata_way[0]}  =  mq_buf_data;
assign mq_wr_data             =  mq_refill_valid && (has_ecc || !tagcmp_missq_ccop_valid);
generate
    for(i = 0; i < SET_ASSOC; i = i + 1)
    begin: gen_refill_way_ben
        assign mq_refill_way_ben[i*4+:4]  =  {4{mq_refill_way[i] & mq_wr_data}};
    end
endgenerate

`GEN_EXTEND(ECC_WAY, 32, data_refill_eccway, mq_refill_eccway_xdata)
generate
    for(i = 0; i < 8; i = i + 1)
    begin: gen_replace_write_data_enable
        assign mq_refill_data_wen[i]  =  mq_refill_way & {SET_ASSOC{mq_wr_data}};
        assign mq_refill_data_strb[i]  =  mq_refill_way_ben;
        assign mq_refill_data_eccway[i]  =  mq_refill_eccway_xdata & {ECC_WAY{mq_refill_data_wdata_way[i]}} |
                                              ~mq_refill_eccway_xdata & repl_data_eccset_perbank[i];
    end
endgenerate
assign missq_cache_data_wen      =  {
                                      mq_refill_data_wen[7],
                                      mq_refill_data_wen[6],
                                      mq_refill_data_wen[5],
                                      mq_refill_data_wen[4],
                                      mq_refill_data_wen[3],
                                      mq_refill_data_wen[2],
                                      mq_refill_data_wen[1],
                                      mq_refill_data_wen[0]
                                    };
assign missq_cache_data_strb     =  {
                                      mq_refill_data_strb[7],
                                      mq_refill_data_strb[6],
                                      mq_refill_data_strb[5],
                                      mq_refill_data_strb[4],
                                      mq_refill_data_strb[3],
                                      mq_refill_data_strb[2],
                                      mq_refill_data_strb[1],
                                      mq_refill_data_strb[0]
                                    };
assign missq_cache_data_wdata    =  {
                                      mq_refill_data_eccway[7],
                                      mq_refill_data_eccway[6],
                                      mq_refill_data_eccway[5],
                                      mq_refill_data_eccway[4],
                                      mq_refill_data_eccway[3],
                                      mq_refill_data_eccway[2],
                                      mq_refill_data_eccway[1],
                                      mq_refill_data_eccway[0]
                                    };
assign missq_cache_data_ecc_w    =  {8{mq_refill_eccset & {ECC_SET{mq_wr_data}}}};
// addr
assign missq_cache_indx_sel  =  mq_stall_req;
assign missq_cache_indx      =  mq_refill_indx;

// refill lrud, to wrbuf
assign missq_wrbuf_refill_lru   =  mq_refill_valid && {!tagcmp_missq_ccop_ldtag};
assign missq_wrbuf_indx         =  mq_refill_indx;
assign missq_wrbuf_way          =  mq_refill_way;
assign missq_wrbuf_way_lock     =  repl_ways_lock;
assign missq_wrbuf_lru_clr      =  (tagcmp_missq_ccop_inv || mq_w_sttag_l_0);  // ccop invalid or sttag lock 0
assign missq_wrbuf_dirty_wdata  =  mq_dirty;
// tagcmp_missq_lock_exist means lock_hit, lock_hit can't write dirty
assign missq_wrbuf_dirty_wen  =  !tagcmp_missq_lock_exist;
// End Refill
// End Mq To Cache Ram

//------------------------------------------------------------//
//                         Mq To Axi
//------------------------------------------------------------//
//------------------------------------------------------------//
//                  Write: Miss Queue > Axi
//------------------------------------------------------------//
assign axi_aw_wid       =  mq_aw_wid;
assign axi_awvalid      =  mq_awvalid;
assign axi_awburst      =  mq_bacs;
assign axi_awexc        =  mq_exc;
assign axi_awcache      =  mq_cached;
assign axi_awaddr       =  mq_addr;
assign axi_awsize[1:0]  =  mq_size;
generate
    if(AXI_DATA == 128)
    begin: gen_axi_awsize_128bit
        assign axi_awsize[2]  =  axi_awburst;
    end
    else
    begin: gen_axi_awsize_less_128bit
        assign axi_awsize[2]  =  1'b0;
    end
endgenerate
assign axi_wvalid       =  mq_wvalid;
assign axi_wstrb        =  mq_strb;
assign axi_wdata        =  mq_buf_data[AXI_DATA-1:0];
assign axi_wlast        =  mq_wlast;
// End Write: Miss Queue > Axi
//------------------------------------------------------------//
//                        Axi B Queue
//------------------------------------------------------------//
assign mq_will_we  =  mq_begin_wb || mq_next_aw_in;
assign mq_will_wa  =  mq_idle ? tagcmp_missq_addr[31:5] : mq_repl_addr[31:5];
// End Axi B Queue
// End Mq To Axi

`ifdef CONFIG_MMU

`endif
//------------------------------------------------------------//
//                           Assert
//------------------------------------------------------------//
`ifdef OPEN132_ASSERT
assert property (@(posedge clk) mq_refill_valid |-> $onehot(mq_refill_way))
else begin
    $display("Assert Error!!!");
    #2 $finish;
end

assert property (@(posedge clk) mq_bq_full |-> !mq_will_we)
else begin
    $display("Assert Error!!!");
    #2 $finish;
end
`endif
// End Assert
endmodule

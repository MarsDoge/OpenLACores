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

module lsu_wrbuf #(
    // cache configuration
    // Cache size in KB: SET_ASSC*WAYSIZE
    parameter SET_ASSOC     = 4,             // 1/2/4 way set associative
    // parameter WAYSIZE         = 8*(2**10), //1/2/4/8/16 KB Size/way
    parameter BANK_WD       = 128,           // for 4way
    parameter BANK_STRB     = 16,            // for 4way
    parameter INDEX_BITS    = 5,             // for waysize 1K
    parameter TAGV_BITS     = (22 + 2),      // for waysize 1K * 4 ways
    parameter RAM_TAGV_WD   = (22 + 2) * 4,  // for waysize 1K * 4 ways
    parameter ECC_BITS      = 8,             // 1/7/8/9 bits
    parameter ECC_SET       = 2,             // for 4-ways, 64+8
    parameter ECC_WAY       = 2,             // for 4-ways, 64+8
    parameter ECC_BANK_BITS = 8 * 2          // for 4-ways, 64+8

) (
    input  wire                       is_icache,
    input  wire                       has_ecc,  // has ecc
    // clk and reset
    input  wire                       clk,  // clk after gating
    input  wire                       clk_ng,  // clk no-gating
    input  wire                       reset,
    input  wire                       data_reset,
    input  wire                       resetn_in_d2,
    output wire                       ram_init_cmplt,
    // tagcmp to wrbuf
    input  wire                       tagcmp_wrbuf_ls_valid,  // load store and no ecc error
    input  wire                       tagcmp_wrbuf_ecc_err,  // ecc err
    input  wire [    SET_ASSOC-1: 0]  tagcmp_wrbuf_hit_way,  // if ecc_err, cache req won't go to wrbuf
    input  wire                       tagcmp_wrbuf_wr,  // if ecc_err, store won't go to wrbuf
    input  wire [              2: 0]  tagcmp_wrbuf_bank_sel,
    input  wire [              3: 0]  tagcmp_wrbuf_strb,
    input  wire [   INDEX_BITS-1: 0]  tagcmp_wrbuf_indx,
    input  wire [             31: 0]  tagcmp_wrbuf_wdata,
    input  wire [    SET_ASSOC-1: 0]  tagcmp_wrbuf_way_lock,
    input  wire                       tagcmp_wrbuf_lru_wen,  // if ecc_err, load won't go to wrbuf
    // mq to wrbuf; use tagv_correct
    input  wire                       missq_wrbuf_ecc_in,  // mq gen old ecc
    input  wire                       missq_wrbuf_correct,  // mq correct tagv
    output wire [  RAM_TAGV_WD-1: 0]  wrbuf_missq_new_tagv,
    output wire                       wrbuf_missq_tagv_1_err,  // 1 bit error
    output wire [    SET_ASSOC-1: 0]  wrbuf_missq_tagv_fatal,  // 2 bit error
    // mq to wrbuf; set/clear lrud
    input  wire                       missq_wrbuf_refill_lru,
    input  wire [   INDEX_BITS-1: 0]  missq_wrbuf_indx,
    input  wire [    SET_ASSOC-1: 0]  missq_wrbuf_way,
    input  wire [    SET_ASSOC-1: 0]  missq_wrbuf_way_lock,
    input  wire                       missq_wrbuf_lru_clr,
    input  wire                       missq_wrbuf_dirty_wen,
    input  wire                       missq_wrbuf_dirty_wdata,
    // wrbuf to tagcmp
    output wire [    SET_ASSOC-1: 0]  wrbuf_tagcmp_way,
    output wire                       wrbuf_tagcmp_wr,
    output wire                       wrbuf_tagcmp_ecc_fatal,
    output wire                       wrbuf_tagcmp_hit_bank,
    output wire [              3: 0]  wrbuf_tagcmp_strb,
    output wire [             31: 0]  wrbuf_tagcmp_wdata,
    output wire                       wrbuf_tagcmp_new_valid,  // for ecc correct
    output wire [  RAM_TAGV_WD-1: 0]  wrbuf_tagcmp_new_tagv,
    output wire [      BANK_WD-1: 0]  wrbuf_tagcmp_new_bank,  // one bank

    // wrbuf to data ram, write all ways by one bank
    output wire [  SET_ASSOC*8-1: 0]  wrbuf_cache_data_ren,  // all bank
    output wire [  SET_ASSOC*8-1: 0]  wrbuf_cache_data_wen,  // all bank
    output wire [  BANK_STRB*8-1: 0]  wrbuf_cache_data_strb,  // all bank
    output wire [      BANK_WD-1: 0]  wrbuf_cache_data_wdata,  // only one bank
    output wire [    ECC_SET*8-1: 0]  wrbuf_cache_data_ecc_w,  // all bank
    output wire [ECC_BANK_BITS-1: 0]  wrbuf_cache_data_wecc,  // only one bank

    output wire                       wrbuf_cache_tagv_indx_sel,
    output wire [              7: 0]  wrbuf_cache_data_indx_sel,
    output wire [   INDEX_BITS-1: 0]  wrbuf_cache_indx,
    // wrbuf to tagv ram: write all ways
    output wire [    SET_ASSOC-1: 0]  wrbuf_cache_tagv_ren,
    output wire [    SET_ASSOC-1: 0]  wrbuf_cache_tagv_wen,
    output wire [    SET_ASSOC-1: 0]  wrbuf_cache_tagv_strb,
    output wire [  RAM_TAGV_WD-1: 0]  wrbuf_cache_tagv_wdata,
    output wire [      ECC_SET-1: 0]  wrbuf_cache_tagv_ecc_w,
    output wire [ECC_BANK_BITS-1: 0]  wrbuf_cache_tagv_wecc,

    // wrbuf to lru
    output wire                       wrbuf_cache_lrud_wen,
    output wire                       wrbuf_cache_lrud_lru_clr,
    output wire [   INDEX_BITS-1: 0]  wrbuf_cache_lrud_indx,
    output wire [    SET_ASSOC-1: 0]  wrbuf_cache_lrud_wway,
    output wire [    SET_ASSOC-1: 0]  wrbuf_cache_lrud_wlock,
    output wire [    SET_ASSOC-1: 0]  wrbuf_cache_lrud_d_wen,  // dirty_wen
    output wire                       wrbuf_cache_lrud_wdirty,

    input  wire [  RAM_TAGV_WD-1: 0]  tc_tagv_rdata,
    input  wire [      BANK_WD-1: 0]  tc_bank_rdata,  // one bank
    input  wire [ECC_BANK_BITS-1: 0]  tc_tagv_old_ecc,  // all ways
    input  wire [ECC_BANK_BITS-1: 0]  tc_tagv_ecc_syndrome,  // all ways
    input  wire [ECC_BANK_BITS-1: 0]  tc_bank_old_ecc,  // all ways in one bank
    input  wire [ECC_BANK_BITS-1: 0]  tc_bank_ecc_syndrome,  // all ways in one bank
    output wire                       wrbuf_ecc_fatal,  // load/store/cacheop find 2bits err
    output wire                       ls_ccop_ecc_fatal,  // load/store/cacheop find 2bits err
    output wire [   INDEX_BITS-1: 0]  ecc_fatal_indx,
    output wire [    SET_ASSOC-1: 0]  ecc_fatal_way,
    output wire                       ecc_fatal_intagv,
    output wire                       ecc_fatal_indata,
    output wire                       ecc_err_add1,

    // pipeline control
    input  wire                       mq_stall_req,  // mq is refilling, will stall req
    output wire                       wrbuf_idle,
    output wire                       wrbuf_wr_tagv,  // correct tagv
    output wire                       wrbuf_wr_bank,  // correct bank or store bank
    output wire [              2: 0]  wrbuf_lock_bank
);

localparam ECC_DATA_BITS = 32;

localparam SET_ASSOC_ECC_CORR_SETS0     = SET_ASSOC;
localparam ECC_BITS_ECC_CORR_SETS0      = ECC_BITS;
localparam ECC_SET_ECC_CORR_SETS0       = ECC_SET;
localparam ECC_WAY_ECC_CORR_SETS0       = ECC_WAY;
localparam DATA_BITS_ECC_CORR_SETS0     = ECC_DATA_BITS;
localparam ECC_BANK_BITS_ECC_CORR_SETS0 = ECC_BANK_BITS;

localparam SET_ASSOC_ECC_CORR_SETS1     = SET_ASSOC;
localparam ECC_BITS_ECC_CORR_SETS1      = ECC_BITS;
localparam ECC_SET_ECC_CORR_SETS1       = ECC_SET;
localparam ECC_WAY_ECC_CORR_SETS1       = ECC_WAY;
localparam DATA_BITS_ECC_CORR_SETS1     = TAGV_BITS;
localparam ECC_BANK_BITS_ECC_CORR_SETS1 = ECC_BANK_BITS;

localparam M_DEC = 8;

localparam ECC_WAY_ECC_GEN0   = ECC_WAY;
localparam DATA_BITS_ECC_GEN0 = 32;
localparam ECC_BITS_ECC_GEN0  = ECC_BITS;

localparam ECC_WAY_ECC_GEN1   = ECC_WAY;
localparam DATA_BITS_ECC_GEN1 = 32;
localparam ECC_BITS_ECC_GEN1  = ECC_BITS;

genvar i, j;

//============================================================//
//                     Regs Declarations
//============================================================//

reg [  9: 0] init_cnt;
reg          ram_init;

reg          wrbuf_valid;  // see{write hit buffer}

// tagcmp hit wrbuf, so new tagv/data is in wrbuf
reg [INDEX_BITS-1: 0] wrbuf_indx;
reg [           2: 0] wrbuf_bank;

// reg
reg [  RAM_TAGV_WD-1: 0] old_tagv_r;
reg [      BANK_WD-1: 0] old_bank_r;
reg [ECC_BANK_BITS-1: 0] old_bank_ecc_r;
reg [ECC_BANK_BITS-1: 0] old_tagv_ecc_r;
reg [ECC_BANK_BITS-1: 0] ecc_tagv_syndrome_r;
reg [ECC_BANK_BITS-1: 0] ecc_bank_syndrome_r;

// write buffer to cache
reg [SET_ASSOC-1: 0] wrbuf_way;
reg                  wrbuf_correct;
reg                  wrbuf_wr;
reg [          3: 0] wrbuf_strb;
reg [         31: 0] wrbuf_wdata;

// for lru
reg [SET_ASSOC-1: 0] way_lock;
reg                  lru_wen;
reg                  lru_clr;
reg                  dirty_wen;
reg                  dirty_wdata;

//============================================================//
//                     Wire Declarations
//============================================================//

wire [                     ECC_BANK_BITS_ECC_CORR_SETS0-1: 0] ecc_syndrome_ecc_corr_sets0;
wire [DATA_BITS_ECC_CORR_SETS0*SET_ASSOC_ECC_CORR_SETS0-1: 0] xor_word_ecc_corr_sets0;
wire [                     ECC_BANK_BITS_ECC_CORR_SETS0-1: 0] xor_ecc_ecc_corr_sets0;
wire                                                          data_1bit_err_ecc_corr_sets0;
wire                                                          ecc_1bit_err_ecc_corr_sets0;
wire                                                          syndrome_err_ecc_corr_sets0;
wire [                           ECC_SET_ECC_CORR_SETS0-1: 0] fatal_ecc_corr_sets0;
wire [                     ECC_BANK_BITS_ECC_CORR_SETS1-1: 0] ecc_syndrome_ecc_corr_sets1;
wire [DATA_BITS_ECC_CORR_SETS1*SET_ASSOC_ECC_CORR_SETS1-1: 0] xor_word_ecc_corr_sets1;
wire [                     ECC_BANK_BITS_ECC_CORR_SETS1-1: 0] xor_ecc_ecc_corr_sets1;
wire                                                          data_1bit_err_ecc_corr_sets1;
wire                                                          ecc_1bit_err_ecc_corr_sets1;
wire                                                          syndrome_err_ecc_corr_sets1;
wire [                           ECC_SET_ECC_CORR_SETS1-1: 0] fatal_ecc_corr_sets1;
wire [                                    $clog2(M_DEC)-1: 0] decode_index_dec;
wire [                                            M_DEC-1: 0] decode_onehot_dec;
wire [                                 ECC_WAY_ECC_GEN0-1: 0] way_ecc_gen0;
wire [                               DATA_BITS_ECC_GEN0-1: 0] data_in_ecc_gen0;
wire [                                ECC_BITS_ECC_GEN0-1: 0] ecc_out_ecc_gen0;
wire [                                 ECC_WAY_ECC_GEN1-1: 0] way_ecc_gen1;
wire [                               DATA_BITS_ECC_GEN1-1: 0] data_in_ecc_gen1;
wire [                                ECC_BITS_ECC_GEN1-1: 0] ecc_out_ecc_gen1;

wire          init_cnt_all1;
wire          do_init;

// write to tag-v ram
wire [    SET_ASSOC-1: 0] hd_tagv_wen;
wire [  RAM_TAGV_WD-1: 0] hd_tagv_wdata;
wire [      ECC_SET-1: 0] hd_tagv_ecc_w;
wire [ECC_BANK_BITS-1: 0] hd_tagv_wecc;

// write to data ram
wire [  SET_ASSOC*8-1: 0] hd_data_wen;    // all bank
wire [   INDEX_BITS-1: 0] hd_data_indx;   // only one bank
wire [  BANK_STRB*8-1: 0] hd_data_strb;   // all bank
wire [      BANK_WD-1: 0] hd_data_wdata;  // only one bank
wire [    ECC_SET*8-1: 0] hd_data_ecc_w;  // all bank
wire [ECC_BANK_BITS-1: 0] hd_data_wecc;   // only one bank

// write to lru-d ram
wire                   hd_lrud_wen;
wire [INDEX_BITS-1: 0] hd_lrud_indx;

wire          tagcmp_wrbuf_valid;  // load/store or ecc_ecc
wire          wrbuf_validin;       // load/store or ecc_ecc read valid

wire                      bank_need_correct;
wire [      BANK_WD-1: 0] new_bank_data;       // correct_data and wrbuf_wdata
wire [ECC_BANK_BITS-1: 0] new_bank_ecc;
wire                      tagv_need_correct;
wire [  RAM_TAGV_WD-1: 0] new_tagv;            // correct tagv
wire [ECC_BANK_BITS-1: 0] new_tagv_ecc;
wire [      BANK_WD-1: 0] wr_old_bank_1d;
wire [ECC_BANK_BITS-1: 0] wr_old_bank_ecc_1d;

wire          tc_indx_hit;
wire          tc_bank_hit;

// only cache ecc need register tagv/data
wire          tagv_in_wrbuf;
wire          bank_in_wrbuf;
wire          tagvbank_in_tc;

// see{write hit buffer}
wire [  RAM_TAGV_WD-1: 0] fwd_tagv_new;
wire [      BANK_WD-1: 0] fwd_bank_new;      // only one bank
wire [ECC_BANK_BITS-1: 0] fwd_tagv_new_ecc;
wire [ECC_BANK_BITS-1: 0] fwd_bank_new_ecc;  // only one bank

// icache fatal will set fatal way invalid
wire                      icache_data_fatal;
wire [      ECC_SET-1: 0] icache_fatal;
wire [  RAM_TAGV_WD-1: 0] icache_fatal_tagvmask;
wire [ECC_BANK_BITS-1: 0] icache_fatal_eccmask;

wire [      BANK_WD-1: 0] bank_xor_word_od;    // one-dimension
wire [ECC_BANK_BITS-1: 0] bank_xor_ecc_od;     // one-dimension
wire                      bank_data_1bit_err;  // 1bit data or check bit err
wire                      bank_ecc_1bit_err;
wire                      bank_syndrome_err;
wire [      ECC_SET-1: 0] bank_fatal_perset;

wire                      bank_1bit_err;
wire [      BANK_WD-1: 0] bank_correct_data;  // only one bank
wire [ECC_BANK_BITS-1: 0] bank_correct_ecc;

wire [SET_ASSOC-1: 0] bank_fatal_perway;

wire [  RAM_TAGV_WD-1: 0] tagv_xor_word_od;    // one-dimension
wire [ECC_BANK_BITS-1: 0] tagv_xor_ecc_od;     // one-dimension
wire                      tagv_data_1bit_err;  // 1bit data or check bit err
wire                      tagv_ecc_1bit_err;
wire                      tagv_syndrome_err;
wire [      ECC_SET-1: 0] tagv_fatal_perset;

wire                      tagv_1bit_err;
wire [  RAM_TAGV_WD-1: 0] tagv_correct_data;  // only one bank
wire [ECC_BANK_BITS-1: 0] tagv_correct_ecc;

wire [SET_ASSOC-1: 0] tagv_fatal_perway;

wire                      bank_need_correct_t;
wire [      BANK_WD-1: 0] new_bank_data_t;       // correct_data and wrbuf_wdata
wire [ECC_BANK_BITS-1: 0] new_bank_ecc_t;
wire                      tagv_need_correct_t;
wire [  RAM_TAGV_WD-1: 0] new_tagv_t;            // correct tagv
wire [ECC_BANK_BITS-1: 0] new_tagv_ecc_t;
wire [      BANK_WD-1: 0] wr_old_bank_1d_t;
wire [ECC_BANK_BITS-1: 0] wr_old_bank_ecc_1d_t;

wire [  7: 0] wrbuf_bank_d;

wire          lru_busy;

// to tagcmp
wire          ecc_fatal_intagvdata;

wire [SET_ASSOC-1: 0] wr_way;
wire [BANK_STRB-1: 0] wrbuf_way_ben;

wire [ECC_SET-1: 0] wr_eccset_tmp;
wire [ECC_SET-1: 0] wr_eccset;
wire [ECC_WAY-1: 0] wr_eccway;

// gen ecc
wire [ 31: 0] wr_old_data;
wire [ 31: 0] wr_new_data;
wire [ 31: 0] old_data_2d[SET_ASSOC-1:0];

wire [ECC_BITS-1: 0] wr_old_ecc;
wire [ECC_BITS-1: 0] wr_new_ecc;

// write new ecc
wire [ECC_BANK_BITS-1: 0] wr_eccset_xeccbits;

wire [     ECC_BITS-1: 0] old_new_ecc;
wire [ECC_BANK_BITS-1: 0] old_new_ecc_bank;
wire [ECC_BANK_BITS-1: 0] wr_bank_wecc;

wire [  SET_ASSOC*8-1: 0] wr_data_wen;    // all bank
wire [   INDEX_BITS-1: 0] wr_data_indx;   // only one bank
wire [  BANK_STRB*8-1: 0] wr_data_strb;   // all bank
wire [      BANK_WD-1: 0] wr_data_wdata;  // only one bank
wire [    ECC_SET*8-1: 0] wr_data_ecc_w;  // all bank
wire [ECC_BANK_BITS-1: 0] wr_data_wecc;   // only one bank

wire [SET_ASSOC-1: 0] bank_wen;
wire [BANK_STRB-1: 0] bank_strb;
wire [  ECC_SET-1: 0] bank_ecc_w;

wire [BANK_STRB*8-1: 0] wrbuf_way_ben_x8;

wire [    SET_ASSOC-1: 0] wr_tagv_wen;
wire [  RAM_TAGV_WD-1: 0] wr_tagv_wdata;
wire [      ECC_SET-1: 0] wr_tagv_ecc_w;
wire [ECC_BANK_BITS-1: 0] wr_tagv_wecc;

//============================================================//
//                    Module Implementation
//============================================================//

// Instance Parameter Aliases
// x_lsu_ecc_corr_sets_0
// x_lsu_ecc_corr_sets_1
// x_lsu_dec_n_m
// x_lsu_ecc_gen_0
// x_lsu_ecc_gen_1

//------------------------------------------------------------//
//                      Hardware Initial
//------------------------------------------------------------//
//------------------------------------------------------------//
//                      Hardware Initial
//------------------------------------------------------------//
// Instance Boundary Alias Mapping
// x_lsu_ecc_corr_sets_0

assign ecc_syndrome_ecc_corr_sets0  =  ecc_bank_syndrome_r;
assign bank_xor_word_od             =  xor_word_ecc_corr_sets0;
assign bank_xor_ecc_od              =  xor_ecc_ecc_corr_sets0;
assign bank_data_1bit_err           =  data_1bit_err_ecc_corr_sets0;
assign bank_ecc_1bit_err            =  ecc_1bit_err_ecc_corr_sets0;
assign bank_syndrome_err            =  syndrome_err_ecc_corr_sets0;
assign bank_fatal_perset            =  fatal_ecc_corr_sets0;
// x_lsu_ecc_corr_sets_1
assign ecc_syndrome_ecc_corr_sets1  =  ecc_tagv_syndrome_r;
assign tagv_xor_word_od             =  xor_word_ecc_corr_sets1;
assign tagv_xor_ecc_od              =  xor_ecc_ecc_corr_sets1;
assign tagv_data_1bit_err           =  data_1bit_err_ecc_corr_sets1;
assign tagv_ecc_1bit_err            =  ecc_1bit_err_ecc_corr_sets1;
assign tagv_syndrome_err            =  syndrome_err_ecc_corr_sets1;
assign tagv_fatal_perset            =  fatal_ecc_corr_sets1;
// x_lsu_dec_n_m
assign decode_index_dec  =  wrbuf_bank;
assign wrbuf_bank_d      =  decode_onehot_dec;
// x_lsu_ecc_gen_0
assign way_ecc_gen0      =  wr_eccway;
assign data_in_ecc_gen0  =  wr_old_data;
assign wr_old_ecc        =  ecc_out_ecc_gen0;
// x_lsu_ecc_gen_1
assign way_ecc_gen1      =  wr_eccway;
assign data_in_ecc_gen1  =  wr_new_data;
assign wr_new_ecc        =  ecc_out_ecc_gen1;

always @ ( posedge clk_ng )
begin
    if(!resetn_in_d2) begin
        init_cnt <= 10'h0;
    end
    else if(ram_init) begin
        init_cnt <= init_cnt + 1'b1;
    end
end

always @ ( posedge clk )
begin
    if(!resetn_in_d2) begin
        ram_init <= 1'b1;
    end
    else if(init_cnt_all1) begin
        ram_init <= 1'b0;
    end
end
assign init_cnt_all1   =  &init_cnt;
assign do_init         =  (&init_cnt[9:INDEX_BITS]) && ram_init;
assign ram_init_cmplt  =  !ram_init;

assign hd_tagv_wen    =  {SET_ASSOC{do_init}};
assign hd_tagv_wdata  =  {RAM_TAGV_WD{1'b0}};
assign hd_tagv_ecc_w  =  {ECC_SET{do_init}};
assign hd_tagv_wecc   =  {ECC_BANK_BITS{1'b0}};

assign hd_data_wen    =  {(SET_ASSOC * 8) {do_init}};
assign hd_data_indx   =  init_cnt[INDEX_BITS-1:0];
assign hd_data_strb   =  {(BANK_STRB * 8) {do_init}};
assign hd_data_wdata  =  {BANK_WD{1'b0}};
assign hd_data_ecc_w  =  {(ECC_SET * 8) {do_init}};
assign hd_data_wecc   =  {ECC_BANK_BITS{1'b0}};

assign hd_lrud_wen   =  do_init;
assign hd_lrud_indx  =  init_cnt[INDEX_BITS-1:0];
// End Hardware Initial

// End Hardware Initial

assign tagcmp_wrbuf_valid  =  tagcmp_wrbuf_ls_valid || tagcmp_wrbuf_ecc_err;
assign wrbuf_validin       =  tagcmp_wrbuf_valid;

//------------------------------------------------------------//
//                            Ecc
//------------------------------------------------------------//

assign tc_indx_hit  =  wrbuf_valid && (tagcmp_wrbuf_indx == wrbuf_indx);
assign tc_bank_hit  =  tc_indx_hit && (tagcmp_wrbuf_bank_sel == wrbuf_bank);

assign tagv_in_wrbuf   =  has_ecc && (wrbuf_tagcmp_new_valid || tagcmp_wrbuf_valid && tc_indx_hit);
assign bank_in_wrbuf   =  has_ecc && (wrbuf_tagcmp_new_valid || tagcmp_wrbuf_valid && tc_bank_hit);
assign tagvbank_in_tc  =  has_ecc && wrbuf_validin;

always @ ( posedge clk )
begin
    old_tagv_r <= tagv_in_wrbuf || missq_wrbuf_correct ? fwd_tagv_new :
    tagvbank_in_tc || missq_wrbuf_ecc_in ? tc_tagv_rdata : old_tagv_r;
    old_bank_r     <= bank_in_wrbuf ? fwd_bank_new : tagvbank_in_tc ? tc_bank_rdata : old_bank_r;
    old_tagv_ecc_r <= tagv_in_wrbuf ? fwd_tagv_new_ecc : tagvbank_in_tc ? tc_tagv_old_ecc : old_tagv_ecc_r;
    old_bank_ecc_r <= bank_in_wrbuf ? fwd_bank_new_ecc : tagvbank_in_tc ? tc_bank_old_ecc : old_bank_ecc_r;
    ecc_tagv_syndrome_r <= tagv_in_wrbuf ? {ECC_BANK_BITS{1'b0}} :
    tagvbank_in_tc || missq_wrbuf_ecc_in ? tc_tagv_ecc_syndrome : ecc_tagv_syndrome_r;
    ecc_bank_syndrome_r <= bank_in_wrbuf ? {ECC_BANK_BITS{1'b0}} :
    tagvbank_in_tc ? tc_bank_ecc_syndrome : ecc_bank_syndrome_r;
end
//------------------------------------------------------------//
//                     Correct Bank Data
//------------------------------------------------------------//
assign icache_data_fatal  =  ecc_fatal_indata && is_icache;
// icache fatal, need clear all ways' tagv
assign icache_fatal_tagvmask  =  {RAM_TAGV_WD{|icache_fatal}};
assign icache_fatal_eccmask   =  {ECC_BANK_BITS{|icache_fatal}};

lsu_ecc_corr_sets #(
    .SET_ASSOC     (SET_ASSOC_ECC_CORR_SETS0    ),  // 1/2/4
    .ECC_BITS      (ECC_BITS_ECC_CORR_SETS0     ),  // 1/7/8/9
    .ECC_SET       (ECC_SET_ECC_CORR_SETS0      ),
    .ECC_WAY       (ECC_WAY_ECC_CORR_SETS0      ),
    .DATA_BITS     (DATA_BITS_ECC_CORR_SETS0    ),
    .ECC_BANK_BITS (ECC_BANK_BITS_ECC_CORR_SETS0)
) x_lsu_ecc_corr_sets_0 (
    .ecc_syndrome  (ecc_syndrome_ecc_corr_sets0 ),
    .xor_word      (xor_word_ecc_corr_sets0     ),
    .xor_ecc       (xor_ecc_ecc_corr_sets0      ),
    .data_1bit_err (data_1bit_err_ecc_corr_sets0),
    .ecc_1bit_err  (ecc_1bit_err_ecc_corr_sets0 ),
    .syndrome_err  (syndrome_err_ecc_corr_sets0 ),
    .fatal         (fatal_ecc_corr_sets0        )
);
assign bank_1bit_err  =  bank_data_1bit_err || bank_ecc_1bit_err;
// if icache fatal, set all 0
assign bank_correct_data  =  (old_bank_r ^ bank_xor_word_od);
assign bank_correct_ecc   =  (old_bank_ecc_r ^ bank_xor_ecc_od);

`GEN_EXTEND(ECC_SET, ECC_WAY, bank_fatal_perset, bank_fatal_perway)
// End Correct Bank Data

//------------------------------------------------------------//
//                       Correct Tag V
//------------------------------------------------------------//

lsu_ecc_corr_sets #(
    .SET_ASSOC     (SET_ASSOC_ECC_CORR_SETS1    ),  // 1/2/4
    .ECC_BITS      (ECC_BITS_ECC_CORR_SETS1     ),  // 1/7/8/9
    .ECC_SET       (ECC_SET_ECC_CORR_SETS1      ),
    .ECC_WAY       (ECC_WAY_ECC_CORR_SETS1      ),
    .DATA_BITS     (DATA_BITS_ECC_CORR_SETS1    ),
    .ECC_BANK_BITS (ECC_BANK_BITS_ECC_CORR_SETS1)
) x_lsu_ecc_corr_sets_1 (
    .ecc_syndrome  (ecc_syndrome_ecc_corr_sets1 ),
    .xor_word      (xor_word_ecc_corr_sets1     ),
    .xor_ecc       (xor_ecc_ecc_corr_sets1      ),
    .data_1bit_err (data_1bit_err_ecc_corr_sets1),
    .ecc_1bit_err  (ecc_1bit_err_ecc_corr_sets1 ),
    .syndrome_err  (syndrome_err_ecc_corr_sets1 ),
    .fatal         (fatal_ecc_corr_sets1        )
);
assign tagv_1bit_err  =  tagv_data_1bit_err || tagv_ecc_1bit_err;
// if icache fatal, set all 0
assign tagv_correct_data  =  (old_tagv_r ^ tagv_xor_word_od) & ~icache_fatal_tagvmask;
assign tagv_correct_ecc   =  (old_tagv_ecc_r ^ tagv_xor_ecc_od) & ~icache_fatal_eccmask;

assign icache_fatal           =  (bank_fatal_perset | tagv_fatal_perset) & {ECC_SET{is_icache && wrbuf_valid}};
`GEN_EXTEND(ECC_SET, ECC_WAY, tagv_fatal_perset, tagv_fatal_perway)

// to mq, mq use tagv_correct to correct replaced tagv
assign wrbuf_missq_new_tagv    =  has_ecc ? old_tagv_r : tc_tagv_rdata;  // new tagv in old_tagv registers
assign wrbuf_missq_tagv_1_err  =  tagv_1bit_err;
assign wrbuf_missq_tagv_fatal  =  tagv_fatal_perway;
// End Correct Tag V

//------------------------------------------------------------//
//                      Update Cache Ram
//------------------------------------------------------------//

// bank
assign bank_need_correct_t   =  (bank_syndrome_err) && wrbuf_valid;
assign new_bank_data_t       =  bank_correct_data;
assign new_bank_ecc_t        =  bank_correct_ecc;
assign tagv_need_correct_t   =  (tagv_syndrome_err || icache_data_fatal) && wrbuf_valid;
assign new_tagv_t            =  tagv_correct_data & {RAM_TAGV_WD{wrbuf_valid}};
assign new_tagv_ecc_t        =  tagv_correct_ecc & {ECC_BANK_BITS{wrbuf_valid}};
assign wr_old_bank_1d_t      =  old_bank_r;
assign wr_old_bank_ecc_1d_t  =  old_bank_ecc_r;
// to module: if no ecc, set following be 0
assign bank_need_correct   =  bank_need_correct_t & has_ecc;
assign new_bank_data       =  new_bank_data_t & {BANK_WD{has_ecc}};
assign new_bank_ecc        =  new_bank_ecc_t & {ECC_BANK_BITS{has_ecc}};
assign tagv_need_correct   =  tagv_need_correct_t & has_ecc;
assign new_tagv            =  new_tagv_t & {RAM_TAGV_WD{has_ecc}};
assign new_tagv_ecc        =  new_tagv_ecc_t & {ECC_BANK_BITS{has_ecc}};
assign wr_old_bank_1d      =  wr_old_bank_1d_t & {BANK_WD{has_ecc}};
assign wr_old_bank_ecc_1d  =  wr_old_bank_ecc_1d_t & {ECC_BANK_BITS{has_ecc}};
// End Update Cache Ram
// End Ecc

//------------------------------------------------------------//
//                      Write Hit Buffer
//------------------------------------------------------------//

lsu_dec_n_m #(
    .M (M_DEC)
) x_lsu_dec_n_m (
    .decode_index  (decode_index_dec ),
    .decode_onehot (decode_onehot_dec)
);

always @ ( posedge clk )
begin
    wrbuf_valid   <= wrbuf_validin ? 1'b1 : 1'b0;
    wrbuf_correct <= tagcmp_wrbuf_ecc_err ? 1'b1 : 1'b0;
    wrbuf_way <= tagcmp_wrbuf_ls_valid ? tagcmp_wrbuf_hit_way :
    missq_wrbuf_refill_lru ? missq_wrbuf_way : {SET_ASSOC{1'b0}};
    wrbuf_wr   <= tagcmp_wrbuf_ls_valid ? tagcmp_wrbuf_wr : {1'b0};
    wrbuf_bank <= data_reset ? {3{1'b0}} : tagcmp_wrbuf_valid ? tagcmp_wrbuf_bank_sel : wrbuf_bank;
    wrbuf_strb <= data_reset ? {4{1'b0}} : tagcmp_wrbuf_valid ? tagcmp_wrbuf_strb : wrbuf_strb;
    wrbuf_indx <= data_reset ? {INDEX_BITS{1'b0}} :
    tagcmp_wrbuf_valid ? tagcmp_wrbuf_indx : missq_wrbuf_refill_lru ? missq_wrbuf_indx : wrbuf_indx;
    wrbuf_wdata <= data_reset ? {32{1'b0}} : tagcmp_wrbuf_valid ? tagcmp_wrbuf_wdata : wrbuf_wdata;
end
always @ ( posedge clk )
begin
    way_lock <= tagcmp_wrbuf_ls_valid ? tagcmp_wrbuf_way_lock :
    missq_wrbuf_refill_lru ? missq_wrbuf_way_lock : {SET_ASSOC{1'b0}};
    lru_wen   <= tagcmp_wrbuf_ls_valid ? tagcmp_wrbuf_lru_wen : missq_wrbuf_refill_lru ? 1'b1 : {1'b0};
    lru_clr   <= missq_wrbuf_refill_lru ? missq_wrbuf_lru_clr : {1'b0};
    dirty_wen <= tagcmp_wrbuf_ls_valid ? tagcmp_wrbuf_wr : missq_wrbuf_refill_lru ? missq_wrbuf_dirty_wen : {1'b0};
    dirty_wdata <= tagcmp_wrbuf_ls_valid ? tagcmp_wrbuf_wr :
    missq_wrbuf_refill_lru ? missq_wrbuf_dirty_wdata : {1'b0};
end
assign lru_busy  =  lru_wen;

assign wrbuf_idle       =  !wrbuf_valid && !lru_busy;
assign wrbuf_wr_bank    =  bank_need_correct || wrbuf_wr;
assign wrbuf_wr_tagv    =  tagv_need_correct;
assign wrbuf_lock_bank  =  wrbuf_bank;

assign ecc_fatal_intagvdata    =  (ecc_fatal_intagv || ecc_fatal_indata);
assign wrbuf_tagcmp_way        =  wrbuf_way;
assign wrbuf_tagcmp_wr         =  wrbuf_wr;
assign wrbuf_tagcmp_ecc_fatal  =  ecc_fatal_intagvdata && wrbuf_valid;
assign wrbuf_tagcmp_hit_bank   =  tc_bank_hit;
assign wrbuf_tagcmp_strb       =  wrbuf_strb;
assign wrbuf_tagcmp_wdata      =  wrbuf_wdata;
assign wrbuf_tagcmp_new_valid  =  wrbuf_correct && has_ecc;
assign wrbuf_tagcmp_new_tagv   =  new_tagv;
assign wrbuf_tagcmp_new_bank   =  new_bank_data;
//------------------------------------------------------------//
//                         Write Data
//------------------------------------------------------------//
assign wr_way             =  wrbuf_way & {SET_ASSOC{wrbuf_wr}};
generate
    for(i = 0; i < SET_ASSOC; i = i + 1)
    begin: gen_wrbuf_write_way_ben
        assign wrbuf_way_ben[i*4+:4]  =  {4{wr_way[i]}} & wrbuf_strb;
    end
endgenerate
// End Write Data

//------------------------------------------------------------//
//                       Write Data Ecc
//------------------------------------------------------------//

`GEN_COMPRESS_OR(ECC_SET, ECC_WAY, wrbuf_way, wr_eccset_tmp)
generate
    if(ECC_SET == 1)
    begin: gen_only_one_eccset
        assign wr_eccset  =  1'b1;
    end
    else
    begin: gen_not_only_one_eccset
        assign wr_eccset  =  wr_eccset_tmp;
    end
endgenerate
// ecc way
generate
    if(ECC_BITS <= 7)
    begin: gen_ecc_way_ecc7
        assign wr_eccway  =  1'b1;
    end
    else if(ECC_BITS == 8)
    begin: gen_ecc_way_ecc8
        if(SET_ASSOC == 2)
        begin: gen_ecc_way_ecc8_assoc2
            assign wr_eccway  =  wrbuf_way[1:0];
        end
        else
        begin: gen_ecc_way_ecc8_assoc4
            assign wr_eccway  =  wrbuf_way[1:0] | wrbuf_way[3:2];
        end
    end
    else if(ECC_BITS == 9)
    begin: gen_ecc_way_ecc9
        assign wr_eccway  =  wrbuf_way;
    end
endgenerate

`GEN_1D_TO_2D(SET_ASSOC, 32, wr_old_bank_1d, old_data_2d)
`GEN_2D_SEL_1D(SET_ASSOC, 32, old_data_2d, old_data_2d_T, wrbuf_way, wr_old_data)
assign wr_new_data[7 : 0]                                =  wrbuf_strb[0] ? wrbuf_wdata[7 : 0] : wr_old_data[7 : 0];
assign wr_new_data[15:8]                                 =  wrbuf_strb[1] ? wrbuf_wdata[15:8] : wr_old_data[15:8];
assign wr_new_data[23:16]                                =  wrbuf_strb[2] ? wrbuf_wdata[23:16] : wr_old_data[23:16];
assign wr_new_data[31:24]                                =  wrbuf_strb[3] ? wrbuf_wdata[31:24] : wr_old_data[31:24];

lsu_ecc_gen #(
    .ECC_WAY   (ECC_WAY_ECC_GEN0  ),
    .DATA_BITS (DATA_BITS_ECC_GEN0),
    .ECC_BITS  (ECC_BITS_ECC_GEN0 )   // 1/2/4
) x_lsu_ecc_gen_0 (
    .way     (way_ecc_gen0    ),
    .data_in (data_in_ecc_gen0),
    .ecc_out (ecc_out_ecc_gen0)
);
lsu_ecc_gen #(
    .ECC_WAY   (ECC_WAY_ECC_GEN1  ),
    .DATA_BITS (DATA_BITS_ECC_GEN1),
    .ECC_BITS  (ECC_BITS_ECC_GEN1 )   // 1/2/4
) x_lsu_ecc_gen_1 (
    .way     (way_ecc_gen1    ),
    .data_in (data_in_ecc_gen1),
    .ecc_out (ecc_out_ecc_gen1)
);
`GEN_EXTEND(ECC_SET, ECC_BITS, wr_eccset, wr_eccset_xeccbits)

assign old_new_ecc       =  wr_old_ecc ^ wr_new_ecc;
assign old_new_ecc_bank  =  wr_eccset_xeccbits & {ECC_SET{old_new_ecc}};
assign wr_bank_wecc      =  wr_old_bank_ecc_1d ^ old_new_ecc_bank;
// End Write Data Ecc

//------------------------------------------------------------//
//           Store ecc_correct Write Cache Data Ram
//------------------------------------------------------------//

assign bank_wen    =  wr_way | {SET_ASSOC{bank_need_correct}};
assign bank_strb   =  wrbuf_way_ben | {BANK_STRB{bank_need_correct}};
assign bank_ecc_w  =  wr_eccset & {ECC_SET{wrbuf_wr}} | {ECC_SET{bank_need_correct}};
//
assign wr_data_wen           =  {
                                  {SET_ASSOC{wrbuf_bank_d[7]}} & bank_wen,
                                  {SET_ASSOC{wrbuf_bank_d[6]}} & bank_wen,
                                  {SET_ASSOC{wrbuf_bank_d[5]}} & bank_wen,
                                  {SET_ASSOC{wrbuf_bank_d[4]}} & bank_wen,
                                  {SET_ASSOC{wrbuf_bank_d[3]}} & bank_wen,
                                  {SET_ASSOC{wrbuf_bank_d[2]}} & bank_wen,
                                  {SET_ASSOC{wrbuf_bank_d[1]}} & bank_wen,
                                  {SET_ASSOC{wrbuf_bank_d[0]}} & bank_wen
                                };
assign wr_data_indx          =  wrbuf_indx;
assign wr_data_strb          =  {
                                  {BANK_STRB{wrbuf_bank_d[7]}} & bank_strb,
                                  {BANK_STRB{wrbuf_bank_d[6]}} & bank_strb,
                                  {BANK_STRB{wrbuf_bank_d[5]}} & bank_strb,
                                  {BANK_STRB{wrbuf_bank_d[4]}} & bank_strb,
                                  {BANK_STRB{wrbuf_bank_d[3]}} & bank_strb,
                                  {BANK_STRB{wrbuf_bank_d[2]}} & bank_strb,
                                  {BANK_STRB{wrbuf_bank_d[1]}} & bank_strb,
                                  {BANK_STRB{wrbuf_bank_d[0]}} & bank_strb
                                };
`GEN_EXTEND(BANK_STRB, 8, wrbuf_way_ben, wrbuf_way_ben_x8)
assign wr_data_wdata         =  (~wrbuf_way_ben_x8 & new_bank_data) | (wrbuf_way_ben_x8 & {SET_ASSOC{wrbuf_wdata}});

assign wr_data_ecc_w  =  {
                           {ECC_SET{wrbuf_bank_d[7]}} & bank_ecc_w,
                           {ECC_SET{wrbuf_bank_d[6]}} & bank_ecc_w,
                           {ECC_SET{wrbuf_bank_d[5]}} & bank_ecc_w,
                           {ECC_SET{wrbuf_bank_d[4]}} & bank_ecc_w,
                           {ECC_SET{wrbuf_bank_d[3]}} & bank_ecc_w,
                           {ECC_SET{wrbuf_bank_d[2]}} & bank_ecc_w,
                           {ECC_SET{wrbuf_bank_d[1]}} & bank_ecc_w,
                           {ECC_SET{wrbuf_bank_d[0]}} & bank_ecc_w
                         };
assign wr_data_wecc   =  wrbuf_wr ? wr_bank_wecc : new_bank_ecc;

assign fwd_bank_new      =  wr_data_wdata;  // only one bank
assign fwd_bank_new_ecc  =  wr_data_wecc;
// End Store ecc_correct Write Cache Data Ram

//------------------------------------------------------------//
//              ecc_correct Write Cache Tagv Ram
//------------------------------------------------------------//

assign wr_tagv_wen    =  {SET_ASSOC{tagv_need_correct}};
assign wr_tagv_wdata  =  new_tagv;
assign wr_tagv_ecc_w  =  {ECC_SET{tagv_need_correct}};
assign wr_tagv_wecc   =  new_tagv_ecc;

// if wrbuf_valid is 0, wr_tagv_wdata is all 0, so fwd_tagv_new can't set wr_tagv_wdata
assign fwd_tagv_new      =  tagv_correct_data;  // wr_tagv_wdata;
assign fwd_tagv_new_ecc  =  tagv_correct_ecc;  // wr_tagv_wecc;
// End ecc_correct Write Cache Tagv Ram

//------------------------------------------------------------//
//                    Ecc To Cpu Pipeline
//------------------------------------------------------------//
assign wrbuf_ecc_fatal    =  ecc_fatal_intagvdata && wrbuf_valid;
assign ls_ccop_ecc_fatal  =  ecc_fatal_intagvdata && wrbuf_valid;
assign ecc_fatal_indx     =  wrbuf_indx;
assign ecc_fatal_way      =  tagv_fatal_perway | bank_fatal_perway;
assign ecc_fatal_intagv   =  |tagv_fatal_perset;
assign ecc_fatal_indata   =  |bank_fatal_perset;
assign ecc_err_add1       =  (tagv_1bit_err || bank_1bit_err) && wrbuf_valid;
// End Ecc To Cpu Pipeline
// End Write Hit Buffer

//------------------------------------------------------------//
//                      Update Cache Ram
//------------------------------------------------------------//
//------------------------------------------------------------//
//                        Update Data
//------------------------------------------------------------//
assign wrbuf_cache_data_ren    =  {SET_ASSOC * 8{1'b0}};
assign wrbuf_cache_data_wen    =  hd_data_wen | wr_data_wen;
assign wrbuf_cache_data_strb   =  do_init ? hd_data_strb : wr_data_strb;  // if no wen, strb is 0
assign wrbuf_cache_data_wdata  =  do_init ? hd_data_wdata : wr_data_wdata;
assign wrbuf_cache_data_ecc_w  =  hd_data_ecc_w | wr_data_ecc_w;
assign wrbuf_cache_data_wecc   =  do_init ? hd_data_wecc : wr_data_wecc;
// End Update Data
assign wrbuf_cache_data_indx_sel  =  {8{do_init}} | ({8{|bank_wen}} & wrbuf_bank_d);
assign wrbuf_cache_tagv_indx_sel  =  do_init || tagv_need_correct;
assign wrbuf_cache_indx           =  do_init ? hd_data_indx : wr_data_indx;
//------------------------------------------------------------//
//                        Update Tag V
//------------------------------------------------------------//
assign wrbuf_cache_tagv_ren    =  1'b0;
assign wrbuf_cache_tagv_wen    =  hd_tagv_wen | wr_tagv_wen;
assign wrbuf_cache_tagv_strb   =  wrbuf_cache_tagv_wen;
assign wrbuf_cache_tagv_wdata  =  do_init ? hd_tagv_wdata : wr_tagv_wdata;
assign wrbuf_cache_tagv_ecc_w  =  hd_tagv_ecc_w | wr_tagv_ecc_w;
assign wrbuf_cache_tagv_wecc   =  do_init ? hd_tagv_wecc : wr_tagv_wecc;
// End Update Tag V

//------------------------------------------------------------//
//                        Update Lru D
//------------------------------------------------------------//
assign wrbuf_cache_lrud_wen      =  lru_wen || hd_lrud_wen;
assign wrbuf_cache_lrud_lru_clr  =  lru_clr;
assign wrbuf_cache_lrud_indx     =  do_init ? hd_lrud_indx : wrbuf_indx;
// if load in wrbuf, won't set wway.
// if do_init after reset, wway need be all'1
assign wrbuf_cache_lrud_wway    =  do_init ? {SET_ASSOC{1'b1}} : wrbuf_way;
assign wrbuf_cache_lrud_wlock   =  way_lock;  // do_init ? {SET_ASSOC{1'b0}} : way_lock;
assign wrbuf_cache_lrud_d_wen   =  do_init ? {SET_ASSOC{1'b1}} : wrbuf_way & {SET_ASSOC{dirty_wen}};
assign wrbuf_cache_lrud_wdirty  =  dirty_wdata;  // do_init ? 1'b0 : dirty_wdata;
// End Update Lru D
// End Update Cache Ram
endmodule

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

`ifdef OPEN132_INTERFACE_AXI
module biu_axi_if #(
    parameter PERF_CNT_NUM  = -1,
    parameter AXI_DATA_WD   = -1,  // 32/64/128
    // ICache
    parameter HAS_ICC       = -1,  // 0 or 1
    parameter ICC_SET_ASSOC = -1,  // 1/2/4 way set associative
    parameter ICC_WAYSIZE   = -1,  // 1/2/4/8/16 KB Size/way
    parameter ICC_ECC_BITS  = -1,  // 1/7/8/9 bits, for no ecc, 32+7, 64+8, 128+9
    // DCache
    parameter HAS_DCC       = -1,  // 0 or 1
    parameter DCC_SET_ASSOC = -1,  // 1/2/4 way set associative
    parameter DCC_WAYSIZE   = -1,  // 1/2/4/8/16 KB Size/way
    parameter DCC_ECC_BITS  = -1   // 1/7/8/9 bits, for no ecc, 32+7, 64+8, 128+9
) (
    input  wire                                              clk_g,
    input  wire                                              clk_ng,  // clk no-gating
    input  wire                                              reset,
    input  wire                                              data_reset,

    input  wire                                              ctrl_nowrap,  // axi no wrap

    input  wire                                              ex_cancel,
    input  wire [      `OPEN132_IFU_CACHE_REQ_BUS_WIDTH-1: 0]  ifu_cache_req_bus,
    input  wire [      `OPEN132_LSU_CACHE_REQ_BUS_WIDTH-1: 0]  lsu_cache_req_bus,
    input  wire [     `OPEN132_CSR_CACHE_CTRL_BUS_WIDTH-1: 0]  csr_cache_ctrl_bus,
`ifdef CONFIG_MMU
    input  wire [       `OPEN132_CSR_MMU_CTRL_BUS_WIDTH-1: 0]  csr_mmu_ctrl_bus,
`endif

    // inst sram
    output wire                                              inst_sram_en,
    output wire [                                     3: 0]  inst_sram_strb,
    output wire                                              inst_sram_wr,
    output wire                                              inst_sram_fetch,
    output wire [                                    31: 0]  inst_sram_addr,
    output wire [                                    31: 0]  inst_sram_wdata,
    input  wire [                                    31: 0]  inst_sram_rdata,

    // data sram
    output wire                                              data_sram_en,
    output wire [                                     3: 0]  data_sram_strb,
    output wire                                              data_sram_wr,
    output wire                                              data_sram_fetch,
    output wire [                                    31: 0]  data_sram_addr,
    output wire [                                    31: 0]  data_sram_wdata,
    input  wire [                                    31: 0]  data_sram_rdata,

`ifdef OPEN132_AXI_HANDSHAKE
    input  wire                                              inst_sram_ack,
    input  wire                                              inst_sram_rrdy,
    input  wire                                              inst_sram_resp,  // 1: error; 0: okay
    input  wire                                              data_sram_ack,
    input  wire                                              data_sram_rrdy,
    input  wire                                              data_sram_resp,  // 1: error; 0: okay
`endif

    // sys axi
    // ar
    input  wire                                              arready,
    output wire [                                     3: 0]  arid,
    output wire [                                    31: 0]  araddr,
    output wire [                                     3: 0]  arlen,
    output wire [                                     2: 0]  arsize,
    output wire [                                     1: 0]  arburst,
    output wire [                                     1: 0]  arlock,
    output wire [                                     3: 0]  arcache,
    output wire [                                     2: 0]  arprot,
    output wire                                              arvalid,
    // r
    input  wire [                                     3: 0]  rid,
    input  wire [                         AXI_DATA_WD-1: 0]  rdata,
    input  wire [                                     1: 0]  rresp,
    input  wire                                              rlast,
    input  wire                                              rvalid,
    output wire                                              rready,
    // aw
    input  wire                                              awready,
    output wire [                                     3: 0]  awid,
    output wire [                                    31: 0]  awaddr,
    output wire [                                     3: 0]  awlen,
    output wire [                                     2: 0]  awsize,
    output wire [                                     1: 0]  awburst,
    output wire [                                     1: 0]  awlock,
    output wire [                                     3: 0]  awcache,
    output wire [                                     2: 0]  awprot,
    output wire                                              awvalid,
    // w
    input  wire                                              wready,
    output wire [                                     3: 0]  wid,
    output wire [                         AXI_DATA_WD-1: 0]  wdata,
    output wire [                       AXI_DATA_WD/8-1: 0]  wstrb,
    output wire                                              wlast,
    output wire                                              wvalid,
    // b
    input  wire [                                     3: 0]  bid,
    input  wire [                                     1: 0]  bresp,
    input  wire                                              bvalid,
    output wire                                              bready,

    output wire [     `OPEN132_CACHE_IFU_RESP_BUS_WIDTH-1: 0]  cache_ifu_resp_bus,
    output wire [     `OPEN132_CACHE_LSU_RESP_BUS_WIDTH-1: 0]  cache_lsu_resp_bus,
    output wire [     `OPEN132_CACHE_CSR_PERF_BUS_WIDTH-1: 0]  cache_csr_perf_bus,

    // only for cache
    input  wire                                              resetn_in_d2,
    output wire                                              ram_init_cmplt,
    // ecc fatal
    output wire [`OPEN132_CACHE_LSU_ECC_FATAL_BUS_WIDTH-1: 0]  cache_lsu_ecc_fatal_bus,

    // dcache ram
    output wire [    `OPEN132_DCC_RAM_TAGV_REQ_BUS_WD-1: 0]  dcc_ram_tagv_req_bus,
    output wire [    `OPEN132_DCC_RAM_DATA_REQ_BUS_WD-1: 0]  dcc_ram_data_req_bus,
    output wire [    `OPEN132_DCC_RAM_LRUD_REQ_BUS_WD-1: 0]  dcc_ram_lrud_req_bus,  // write by bit
    input  wire [   `OPEN132_DCC_RAM_TAGV_RESP_BUS_WD-1: 0]  dcc_ram_tagv_resp_bus,
    input  wire [   `OPEN132_DCC_RAM_DATA_RESP_BUS_WD-1: 0]  dcc_ram_data_resp_bus,
    input  wire [   `OPEN132_DCC_RAM_LRUD_RESP_BUS_WD-1: 0]  dcc_ram_lrud_resp_bus,
    // icache ram
    output wire [    `OPEN132_ICC_RAM_TAGV_REQ_BUS_WD-1: 0]  icc_ram_tagv_req_bus,
    output wire [    `OPEN132_ICC_RAM_DATA_REQ_BUS_WD-1: 0]  icc_ram_data_req_bus,
    output wire [    `OPEN132_ICC_RAM_LRUD_REQ_BUS_WD-1: 0]  icc_ram_lrud_req_bus,  // write by bit
    input  wire [   `OPEN132_ICC_RAM_TAGV_RESP_BUS_WD-1: 0]  icc_ram_tagv_resp_bus,
    input  wire [   `OPEN132_ICC_RAM_DATA_RESP_BUS_WD-1: 0]  icc_ram_data_resp_bus,
    input  wire [   `OPEN132_ICC_RAM_LRUD_RESP_BUS_WD-1: 0]  icc_ram_lrud_resp_bus

`ifdef OPEN132_HAS_LJTAG
    ,
    output wire [                                    55: 0]  biu_jtag_debug_req_bus,
    input  wire [                                    32: 0]  jtag_biu_debug_resp_bus
`endif

    ,
    input  wire [                         (1+32+32)*4-1: 0]  ibus_win,
    input  wire [                         (1+32+32)*4-1: 0]  dbus_win
);

localparam PERF_CNT_NUM_SYSBUS  = PERF_CNT_NUM;
localparam AXI_DATA_WD_SYSBUS   = AXI_DATA_WD;
localparam HAS_ICC_SYSBUS       = HAS_ICC;
localparam ICC_SET_ASSOC_SYSBUS = ICC_SET_ASSOC;
localparam ICC_WAYSIZE_SYSBUS   = ICC_WAYSIZE;
localparam ICC_ECC_BITS_SYSBUS  = ICC_ECC_BITS;
localparam HAS_DCC_SYSBUS       = HAS_DCC;
localparam DCC_SET_ASSOC_SYSBUS = DCC_SET_ASSOC;
localparam DCC_WAYSIZE_SYSBUS   = DCC_WAYSIZE;
localparam DCC_ECC_BITS_SYSBUS  = DCC_ECC_BITS;

//============================================================//
//                     Regs Declarations
//============================================================//

// previous fetch/cache_load request to
reg          pre_ft_sel_i;
reg          pre_ft_sel_d;
reg          pre_ft_sel_s;
reg          pre_mald_sel_i;
reg          pre_mald_sel_d;
reg          pre_mald_sel_s;

reg          i_cancel_data;  // cancel ibus back data.
reg          d_cancel_data;
reg          ft_wait_i;
reg          ld_wait_i;
reg          ft_wait_d;
reg          ld_wait_d;

// exclusive back
reg          axi_b_last_exok;
`ifdef OPEN132_AXI_HANDSHAKE
reg [  1: 0] wait_i_2;  // 2 request CMD has been received by ibus-slave
reg [  1: 0] wait_d_2;  // 10: 2nd request is load; 11:fetch
`endif

// i/d bus data ready
reg          canc_wait_i;  // ex_cancel is valid,and wait_i_2 is valid at same time.
reg          canc_wait_d;

//============================================================//
//                     Wire Declarations
//============================================================//

wire [                                    31: 0] vaddr_vaddr_sel0;
wire [                         (1+32+32)*4-1: 0] ibus_win_vaddr_sel0;
wire [                         (1+32+32)*4-1: 0] dbus_win_vaddr_sel0;
wire                                             ibus_hit_vaddr_sel0;
wire                                             dbus_hit_vaddr_sel0;
wire                                             sysbus_hit_vaddr_sel0;
wire [                                    31: 0] vaddr_vaddr_sel1;
wire [                         (1+32+32)*4-1: 0] ibus_win_vaddr_sel1;
wire [                         (1+32+32)*4-1: 0] dbus_win_vaddr_sel1;
wire                                             ibus_hit_vaddr_sel1;
wire                                             dbus_hit_vaddr_sel1;
wire                                             sysbus_hit_vaddr_sel1;
wire [                                    31: 0] vaddr_vaddr_sel2;
wire [                         (1+32+32)*4-1: 0] ibus_win_vaddr_sel2;
wire [                         (1+32+32)*4-1: 0] dbus_win_vaddr_sel2;
wire                                             ibus_hit_vaddr_sel2;
wire                                             dbus_hit_vaddr_sel2;
wire                                             sysbus_hit_vaddr_sel2;
wire                                             clk_sysbus;
wire                                             clk_ng_sysbus;
wire                                             reset_sysbus;
wire                                             data_reset_sysbus;
wire                                             ctrl_nowrap_sysbus;
wire                                             ex_cancel_sysbus;
wire                                             fetch_dbgm_sysbus;
wire [                                    31: 0] fetch_vaddr_sysbus;
wire                                             memld_st_dbgm_sysbus;
wire [                                    31: 0] de_mald_vaddr_sysbus;
wire [                                    31: 0] memld_st_vaddr_sysbus;
wire                                             memld_st_write_sysbus;
wire [                                     1: 0] memld_st_size_sysbus;
wire [                                     3: 0] memld_st_strb_sysbus;
wire [                                    31: 0] st_wdata_sysbus;
wire                                             de_load_req_sysbus;
wire                                             memld_st_req_sysbus;
wire                                             memld_st_exc_sysbus;
wire                                             memld_st_dald_sysbus;
wire                                             sbus_sel_ft_sysbus;
wire                                             sbus_sel_mald_sysbus;
wire                                             sbus_real_sel_ft_sysbus;
wire                                             sbus_real_sel_mald_sysbus;
wire                                             sbus_sel_memld_st_sysbus;
wire                                             ft_pre_s_ok_sysbus;
wire                                             mald_pre_s_ok_sysbus;
wire                                             ft_pre_s_err_sysbus;
wire                                             mald_pre_s_err_sysbus;
wire                                             ft_in_sysbus_sysbus;
wire                                             ld_in_sysbus_sysbus;
wire                                             sysbus_mem_null_sysbus;
wire                                             sysbus_ft_null_sysbus;
wire                                             fetch_req_s_ready_sysbus;
wire                                             de_mald_req_s_ready_sysbus;
wire                                             memld_st_req_s_ready_sysbus;
wire                                             ft_data_s_ready_sysbus;
wire                                             ld_data_s_ready_sysbus;
wire                                             ld_data_s_exok_sysbus;
wire [                                    31: 0] ft_data_s_rdata_sysbus;
wire [                                    31: 0] ld_data_s_rdata_sysbus;
wire                                             ft_data_s_err_sysbus;
wire                                             ld_data_s_err_sysbus;
`ifdef CONFIG_MMU
wire                                             ft_mmu_expt_vld_sysbus;
wire [                                     5: 0] ft_mmu_expt_code_sysbus;
wire                                             ld_mmu_expt_vld_sysbus;
wire [                                     5: 0] ld_mmu_expt_code_sysbus;
wire                                             ld_mmu_expt_write_sysbus;
`endif
wire                                             sys_arready_sysbus;
wire [                                     3: 0] sys_arid_sysbus;
wire [                                    31: 0] sys_araddr_sysbus;
wire [                                     3: 0] sys_arlen_sysbus;
wire [                                     2: 0] sys_arsize_sysbus;
wire [                                     1: 0] sys_arburst_sysbus;
wire [                                     1: 0] sys_arlock_sysbus;
wire [                                     3: 0] sys_arcache_sysbus;
wire [                                     2: 0] sys_arprot_sysbus;
wire                                             sys_arvalid_sysbus;
wire [                                     3: 0] sys_rid_sysbus;
wire [                  AXI_DATA_WD_SYSBUS-1: 0] sys_rdata_sysbus;
wire [                                     1: 0] sys_rresp_sysbus;
wire                                             sys_rlast_sysbus;
wire                                             sys_rvalid_sysbus;
wire                                             sys_rready_sysbus;
wire                                             sys_awready_sysbus;
wire [                                     3: 0] sys_awid_sysbus;
wire [                                    31: 0] sys_awaddr_sysbus;
wire [                                     3: 0] sys_awlen_sysbus;
wire [                                     2: 0] sys_awsize_sysbus;
wire [                                     1: 0] sys_awburst_sysbus;
wire [                                     1: 0] sys_awlock_sysbus;
wire [                                     3: 0] sys_awcache_sysbus;
wire [                                     2: 0] sys_awprot_sysbus;
wire                                             sys_awvalid_sysbus;
wire                                             sys_wready_sysbus;
wire [                                     3: 0] sys_wid_sysbus;
wire [                  AXI_DATA_WD_SYSBUS-1: 0] sys_wdata_sysbus;
wire [                AXI_DATA_WD_SYSBUS/8-1: 0] sys_wstrb_sysbus;
wire                                             sys_wlast_sysbus;
wire                                             sys_wvalid_sysbus;
wire [                                     3: 0] sys_bid_sysbus;
wire [                                     1: 0] sys_bresp_sysbus;
wire                                             sys_bvalid_sysbus;
wire                                             sys_bready_sysbus;
wire                                             mem_cps_req_sysbus;
wire [                                    31: 0] mem_sttag_data_sysbus;
wire                                             mem_cc_op_i_sysbus;
wire                                             mem_cc_op_d_sysbus;
wire [                                     5: 0] mem_cc_op_sysbus;
wire                                             mem_cc_fill_sysbus;
wire                                             mem_cc_lock_sysbus;
wire                                             mem_cc_pref_sysbus;
wire                                             mem_cps_req_ready_sysbus;
wire                                             mem_cps_data_ready_sysbus;
wire [                                    31: 0] mem_cps_data_rdata_sysbus;
wire                                             resetn_in_d2_sysbus;
wire                                             ram_init_cmplt_sysbus;
wire [     `OPEN132_CSR_CACHE_CTRL_BUS_WIDTH-1: 0] csr_cache_ctrl_bus_sysbus;
`ifdef CONFIG_MMU
wire [       `OPEN132_CSR_MMU_CTRL_BUS_WIDTH-1: 0] csr_mmu_ctrl_bus_sysbus;
`endif
wire [   `OPEN132_CACHE_PERF_EVENT_BUS_WIDTH-1: 0] cache_csr_perf_bus_sysbus;
wire [`OPEN132_CACHE_LSU_ECC_FATAL_BUS_WIDTH-1: 0] cache_lsu_ecc_fatal_bus_sysbus;
wire [    `OPEN132_DCC_RAM_TAGV_REQ_BUS_WD-1: 0] dcc_ram_tagv_req_bus_sysbus;
wire [    `OPEN132_DCC_RAM_DATA_REQ_BUS_WD-1: 0] dcc_ram_data_req_bus_sysbus;
wire [    `OPEN132_DCC_RAM_LRUD_REQ_BUS_WD-1: 0] dcc_ram_lrud_req_bus_sysbus;
wire [   `OPEN132_DCC_RAM_TAGV_RESP_BUS_WD-1: 0] dcc_ram_tagv_resp_bus_sysbus;
wire [   `OPEN132_DCC_RAM_DATA_RESP_BUS_WD-1: 0] dcc_ram_data_resp_bus_sysbus;
wire [   `OPEN132_DCC_RAM_LRUD_RESP_BUS_WD-1: 0] dcc_ram_lrud_resp_bus_sysbus;
wire [    `OPEN132_ICC_RAM_TAGV_REQ_BUS_WD-1: 0] icc_ram_tagv_req_bus_sysbus;
wire [    `OPEN132_ICC_RAM_DATA_REQ_BUS_WD-1: 0] icc_ram_data_req_bus_sysbus;
wire [    `OPEN132_ICC_RAM_LRUD_REQ_BUS_WD-1: 0] icc_ram_lrud_req_bus_sysbus;
wire [   `OPEN132_ICC_RAM_TAGV_RESP_BUS_WD-1: 0] icc_ram_tagv_resp_bus_sysbus;
wire [   `OPEN132_ICC_RAM_DATA_RESP_BUS_WD-1: 0] icc_ram_data_resp_bus_sysbus;
wire [   `OPEN132_ICC_RAM_LRUD_RESP_BUS_WD-1: 0] icc_ram_lrud_resp_bus_sysbus;
wire [                                    55: 0] biu_jtag_debug_req_bus_sysbus;
wire [                                    32: 0] jtag_biu_debug_resp_bus_sysbus;

wire          fetch_req;
wire          fetch_dbgm;
wire [ 31: 0] fetch_vaddr;
`ifdef CONFIG_MMU
wire          mmu_page_mode_if;
`endif

wire          fetch_hit_ibus;
wire          fetch_hit_dbus;
wire          fetch_hit_sbus;

// wire fetch_req_ibus = fetch_req && fetch_hit_ibus;
// wire fetch_req_dbus = fetch_req && fetch_hit_dbus;
wire          fetch_req_sbus;

wire          memld_st_dald;   // memld_st_req is device-load
wire          mem_cps_req;
wire [ 31: 0] mem_sttag_data;  // store Tag
wire          mem_cc_op_i;
wire          mem_cc_op_d;
wire [  5: 0] mem_cc_op;
wire          mem_cc_fill;
wire          mem_cc_lock;
wire          mem_cc_pref;
wire          de_load_req;     // inst in de-stage is load
wire          de_mald_req;     // cache load requset to send address
wire          memld_st_req;    // load/store in mem-stage requset to send address
wire          memld_st_exc;    // request exclusive access
wire          memld_st_dbgm;
wire [ 31: 0] de_mald_vaddr;   // mem-attribute load
wire [ 31: 0] memld_st_vaddr;  // load (in mem stage, maybe cache) or store address
wire          memld_st_write;
wire [  1: 0] memld_st_size;
wire [ 31: 0] st_wdata;        // set at same time with addr request! so need be registered for ahb.

wire          de_mald_hit_ibus;
wire          de_mald_hit_dbus;
wire          de_mald_hit_sbus;
wire          memld_st_hit_ibus;
wire          memld_st_hit_dbus;
wire          memld_st_hit_sbus;
wire          de_mald_req_ibus;
wire          de_mald_req_dbus;
wire          de_mald_req_sbus;
wire          memld_st_req_ibus;
wire          memld_st_req_dbus;
wire          memld_st_req_sbus;

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
wire [  1: 0] size;
wire [  1: 0] addr;
wire [  3: 0] memld_st_strb;

wire          fetchreq_ready;
wire          fetchdata_ready;
wire          fetchdata_err;
`ifdef CONFIG_MMU
wire          fetch_mmu_expt_vld;
wire [  5: 0] fetch_mmu_expt_code;
`endif
wire [  1: 0] fetch_whichbus;
wire [ 31: 0] fetch_rdata;

wire          mem_cps_req_ready;
wire          mem_cps_data_ready;
wire [ 31: 0] mem_cps_data_rdata;
wire          de_mald_req_ready;
wire          memld_st_req_ready;
wire          lddata_ready;        // for load
wire          lddata_err;
wire          lddata_exok;
`ifdef CONFIG_MMU
wire          ld_mmu_expt_vld;
wire [  5: 0] ld_mmu_expt_code;
wire          ld_mmu_expt_write;
`endif
wire [ 31: 0] ld_rdata;
wire          ifc_last_exok;       // last store is exok
wire          ifc_ls_cmplt;        // no load/store wait in interface
wire          ifc_null;            // no fetch/load/store wait in interface

// ft/ld/st in id/sysbus, see{signals output to ibus/dbus/sysbus}
wire          ibus_mem_null;
wire          ibus_ft_null;
wire          dbus_mem_null;
wire          dbus_ft_null;
wire          sysbus_mem_null;
wire          sysbus_ft_null;

wire          fetch_pre_ibus;  // fetch: prediction to ibus
wire          fetch_pre_dbus;
wire          fetch_pre_sbus;
wire          de_ld_pre_ibus;
wire          de_ld_pre_dbus;
wire          de_ld_pre_sbus;

// previous access
wire          ft_in_ibus;
wire          ld_in_ibus;
wire          ft_in_dbus;
wire          ld_in_dbus;
wire          ft_in_sysbus;
wire          ld_in_sysbus;

// i/d/sysbus sel
wire          ibus_sel_ft;
wire          ibus_sel_mald;
wire          ibus_sel_memld_st;
wire          ibus_sel_mem;
wire          dbus_sel_ft;
wire          dbus_sel_memld_st;
wire          dbus_sel_mald;
wire          dbus_sel_mem;
wire          sbus_sel_ft;
wire          sbus_sel_mald;
wire          sbus_sel_memld_st;
wire          sbus_real_sel_ft;
wire          sbus_real_sel_mald;

// fetch/cache_load prediction bus right/fail!
wire          ft_pre_i_ok;
wire          ft_pre_d_ok;
wire          ft_pre_s_ok;
wire          mald_pre_i_ok;
wire          mald_pre_d_ok;
wire          mald_pre_s_ok;
wire          ft_pre_i_err;
wire          ft_pre_d_err;
wire          ft_pre_s_err;
wire          mald_pre_i_err;
wire          mald_pre_d_err;
wire          mald_pre_s_err;

// i/d/sysbus req ready
wire          i_req_ready;
wire          d_req_ready;
wire          fetch_req_s_ready;
wire          de_mald_req_s_ready;
wire          memld_st_req_s_ready;

// i/d/sysbus data ready and rdata
wire          ft_data_i_ready;
wire          ld_data_i_ready;
wire          ft_data_d_ready;
wire          ld_data_d_ready;
wire          ft_data_s_ready;
wire          ld_data_s_ready;
wire          ld_data_s_exok;

wire          ft_data_i_err;
wire          ld_data_i_err;
wire          ft_data_d_err;
wire          ld_data_d_err;
wire          ft_data_s_err;
wire          ld_data_s_err;

wire [ 31: 0] data_i_rdata;
wire [ 31: 0] data_d_rdata;
wire [ 31: 0] ft_data_s_rdata;  // if no data_ready, must be zero.
wire [ 31: 0] ld_data_s_rdata;

wire          ibus_do_ft;
wire          ibus_do_ld;

// wire ibus_do_st = ~ibus_sel_mald &  ibus_sel_memld_st &  memld_st_write ;
wire          dbus_do_ft;
wire          dbus_do_ld;

wire          ft_ld_wait_i;
wire          ft_ld_wait_d;
`ifndef OPEN132_AXI_HANDSHAKE

wire          inst_sram_ack;
wire          inst_sram_rrdy;
wire          inst_sram_resp;
wire          data_sram_ack;
wire          data_sram_rrdy;
wire          data_sram_resp;
wire [  1: 0] wait_i_2;
wire [  1: 0] wait_d_2;
`endif

wire          i_data_ready;
wire          d_data_ready;

wire          i_data_err;
wire          d_data_err;

// cancel wait
wire          pre_i_ready_err;
wire          pre_d_ready_err;

//============================================================//
//                    Module Implementation
//============================================================//

// Instance Parameter Aliases
// x_biu_axi_sysbus

//------------------------------------------------------------//
//                      Bus Connections
//------------------------------------------------------------//
//------------------------------------------------------------//
//                     ifu_cache_req_bus
//------------------------------------------------------------//

// Instance Boundary Alias Mapping
// x_mmu_vaddr_sel_bus_0

assign vaddr_vaddr_sel0     =  fetch_vaddr;
assign ibus_win_vaddr_sel0  =  ibus_win;
assign dbus_win_vaddr_sel0  =  dbus_win;
`ifdef CONFIG_MMU
assign fetch_hit_ibus       =  mmu_page_mode_if ? 1'b0 : ibus_hit_vaddr_sel0;
assign fetch_hit_dbus       =  mmu_page_mode_if ? 1'b0 : dbus_hit_vaddr_sel0;
assign fetch_hit_sbus       =  mmu_page_mode_if ? 1'b1 : sysbus_hit_vaddr_sel0;
`else
assign fetch_hit_ibus       =  ibus_hit_vaddr_sel0;
assign fetch_hit_dbus       =  dbus_hit_vaddr_sel0;
assign fetch_hit_sbus       =  sysbus_hit_vaddr_sel0;
`endif
// x_mmu_vaddr_sel_bus_1
assign vaddr_vaddr_sel1     =  de_mald_vaddr;
assign ibus_win_vaddr_sel1  =  ibus_win;
assign dbus_win_vaddr_sel1  =  dbus_win;
`ifdef CONFIG_MMU
assign de_mald_hit_ibus     =  mmu_page_mode_if ? 1'b0 : ibus_hit_vaddr_sel1;
assign de_mald_hit_dbus     =  mmu_page_mode_if ? 1'b0 : dbus_hit_vaddr_sel1;
assign de_mald_hit_sbus     =  mmu_page_mode_if ? 1'b0 : sysbus_hit_vaddr_sel1;
`else
assign de_mald_hit_ibus     =  ibus_hit_vaddr_sel1;
assign de_mald_hit_dbus     =  dbus_hit_vaddr_sel1;
assign de_mald_hit_sbus     =  sysbus_hit_vaddr_sel1;
`endif
// x_mmu_vaddr_sel_bus_2
assign vaddr_vaddr_sel2     =  memld_st_vaddr;
assign ibus_win_vaddr_sel2  =  ibus_win;
assign dbus_win_vaddr_sel2  =  dbus_win;
`ifdef CONFIG_MMU
assign memld_st_hit_ibus    =  mmu_page_mode_if ? 1'b0 : ibus_hit_vaddr_sel2;
assign memld_st_hit_dbus    =  mmu_page_mode_if ? 1'b0 : dbus_hit_vaddr_sel2;
assign memld_st_hit_sbus    =  mmu_page_mode_if ? 1'b1 : sysbus_hit_vaddr_sel2;
`else
assign memld_st_hit_ibus    =  ibus_hit_vaddr_sel2;
assign memld_st_hit_dbus    =  dbus_hit_vaddr_sel2;
assign memld_st_hit_sbus    =  sysbus_hit_vaddr_sel2;
`endif
// x_biu_axi_sysbus
assign clk_sysbus                      =  clk_g;
assign clk_ng_sysbus                   =  clk_ng;
assign reset_sysbus                    =  reset;
assign data_reset_sysbus               =  data_reset;
assign ctrl_nowrap_sysbus              =  ctrl_nowrap;
assign ex_cancel_sysbus                =  ex_cancel;
assign fetch_dbgm_sysbus               =  fetch_dbgm;
assign fetch_vaddr_sysbus              =  fetch_vaddr;
assign memld_st_dbgm_sysbus            =  memld_st_dbgm;
assign de_mald_vaddr_sysbus            =  de_mald_vaddr;
assign memld_st_vaddr_sysbus           =  memld_st_vaddr;
assign memld_st_write_sysbus           =  memld_st_write;
assign memld_st_size_sysbus            =  memld_st_size;
assign memld_st_strb_sysbus            =  memld_st_strb;
assign st_wdata_sysbus                 =  st_wdata;
assign de_load_req_sysbus              =  de_load_req;
assign memld_st_req_sysbus             =  memld_st_req;
assign memld_st_exc_sysbus             =  memld_st_exc;
assign memld_st_dald_sysbus            =  memld_st_dald;
assign sbus_sel_ft_sysbus              =  sbus_sel_ft;
assign sbus_sel_mald_sysbus            =  sbus_sel_mald;
assign sbus_real_sel_ft_sysbus         =  sbus_real_sel_ft;
assign sbus_real_sel_mald_sysbus       =  sbus_real_sel_mald;
assign sbus_sel_memld_st_sysbus        =  sbus_sel_memld_st;
assign ft_pre_s_ok_sysbus              =  ft_pre_s_ok;
assign mald_pre_s_ok_sysbus            =  mald_pre_s_ok;
assign ft_pre_s_err_sysbus             =  ft_pre_s_err;
assign mald_pre_s_err_sysbus           =  mald_pre_s_err;
assign ft_in_sysbus                    =  ft_in_sysbus_sysbus;
assign ld_in_sysbus                    =  ld_in_sysbus_sysbus;
assign sysbus_mem_null                 =  sysbus_mem_null_sysbus;
assign sysbus_ft_null                  =  sysbus_ft_null_sysbus;
assign fetch_req_s_ready               =  fetch_req_s_ready_sysbus;
assign de_mald_req_s_ready             =  de_mald_req_s_ready_sysbus;
assign memld_st_req_s_ready            =  memld_st_req_s_ready_sysbus;
assign ft_data_s_ready                 =  ft_data_s_ready_sysbus;
assign ld_data_s_ready                 =  ld_data_s_ready_sysbus;
assign ld_data_s_exok                  =  ld_data_s_exok_sysbus;
assign ft_data_s_rdata                 =  ft_data_s_rdata_sysbus;
assign ld_data_s_rdata                 =  ld_data_s_rdata_sysbus;
assign ft_data_s_err                   =  ft_data_s_err_sysbus;
assign ld_data_s_err                   =  ld_data_s_err_sysbus;
`ifdef CONFIG_MMU
assign fetch_mmu_expt_vld              =  ft_mmu_expt_vld_sysbus;
assign fetch_mmu_expt_code             =  ft_mmu_expt_code_sysbus;
assign ld_mmu_expt_vld                 =  ld_mmu_expt_vld_sysbus;
assign ld_mmu_expt_code                =  ld_mmu_expt_code_sysbus;
assign ld_mmu_expt_write               =  ld_mmu_expt_write_sysbus;
`endif
assign sys_arready_sysbus              =  arready;
assign arid                            =  sys_arid_sysbus;
assign araddr                          =  sys_araddr_sysbus;
assign arlen                           =  sys_arlen_sysbus;
assign arsize                          =  sys_arsize_sysbus;
assign arburst                         =  sys_arburst_sysbus;
assign arlock                          =  sys_arlock_sysbus;
assign arcache                         =  sys_arcache_sysbus;
assign arprot                          =  sys_arprot_sysbus;
assign arvalid                         =  sys_arvalid_sysbus;
assign sys_rid_sysbus                  =  rid;
assign sys_rdata_sysbus                =  rdata;
assign sys_rresp_sysbus                =  rresp;
assign sys_rlast_sysbus                =  rlast;
assign sys_rvalid_sysbus               =  rvalid;
assign rready                          =  sys_rready_sysbus;
assign sys_awready_sysbus              =  awready;
assign awid                            =  sys_awid_sysbus;
assign awaddr                          =  sys_awaddr_sysbus;
assign awlen                           =  sys_awlen_sysbus;
assign awsize                          =  sys_awsize_sysbus;
assign awburst                         =  sys_awburst_sysbus;
assign awlock                          =  sys_awlock_sysbus;
assign awcache                         =  sys_awcache_sysbus;
assign awprot                          =  sys_awprot_sysbus;
assign awvalid                         =  sys_awvalid_sysbus;
assign sys_wready_sysbus               =  wready;
assign wid                             =  sys_wid_sysbus;
assign wdata                           =  sys_wdata_sysbus;
assign wstrb                           =  sys_wstrb_sysbus;
assign wlast                           =  sys_wlast_sysbus;
assign wvalid                          =  sys_wvalid_sysbus;
assign sys_bid_sysbus                  =  bid;
assign sys_bresp_sysbus                =  bresp;
assign sys_bvalid_sysbus               =  bvalid;
assign bready                          =  sys_bready_sysbus;
assign mem_cps_req_sysbus              =  mem_cps_req;
assign mem_sttag_data_sysbus           =  mem_sttag_data;
assign mem_cc_op_i_sysbus              =  mem_cc_op_i;
assign mem_cc_op_d_sysbus              =  mem_cc_op_d;
assign mem_cc_op_sysbus                =  mem_cc_op;
assign mem_cc_fill_sysbus              =  mem_cc_fill;
assign mem_cc_lock_sysbus              =  mem_cc_lock;
assign mem_cc_pref_sysbus              =  mem_cc_pref;
assign mem_cps_req_ready               =  mem_cps_req_ready_sysbus;
assign mem_cps_data_ready              =  mem_cps_data_ready_sysbus;
assign mem_cps_data_rdata              =  mem_cps_data_rdata_sysbus;
assign resetn_in_d2_sysbus             =  resetn_in_d2;
assign ram_init_cmplt                  =  ram_init_cmplt_sysbus;
assign csr_cache_ctrl_bus_sysbus       =  csr_cache_ctrl_bus;
`ifdef CONFIG_MMU
assign csr_mmu_ctrl_bus_sysbus         =  csr_mmu_ctrl_bus;
assign mmu_page_mode_if                =  !csr_mmu_ctrl_bus[192]
                                          && csr_mmu_ctrl_bus[191];
`endif
assign cache_csr_perf_bus              =  cache_csr_perf_bus_sysbus;
assign cache_lsu_ecc_fatal_bus         =  cache_lsu_ecc_fatal_bus_sysbus;
assign dcc_ram_tagv_req_bus            =  dcc_ram_tagv_req_bus_sysbus;
assign dcc_ram_data_req_bus            =  dcc_ram_data_req_bus_sysbus;
assign dcc_ram_lrud_req_bus            =  dcc_ram_lrud_req_bus_sysbus;
assign dcc_ram_tagv_resp_bus_sysbus    =  dcc_ram_tagv_resp_bus;
assign dcc_ram_data_resp_bus_sysbus    =  dcc_ram_data_resp_bus;
assign dcc_ram_lrud_resp_bus_sysbus    =  dcc_ram_lrud_resp_bus;
assign icc_ram_tagv_req_bus            =  icc_ram_tagv_req_bus_sysbus;
assign icc_ram_data_req_bus            =  icc_ram_data_req_bus_sysbus;
assign icc_ram_lrud_req_bus            =  icc_ram_lrud_req_bus_sysbus;
assign icc_ram_tagv_resp_bus_sysbus    =  icc_ram_tagv_resp_bus;
assign icc_ram_data_resp_bus_sysbus    =  icc_ram_data_resp_bus;
assign icc_ram_lrud_resp_bus_sysbus    =  icc_ram_lrud_resp_bus;
assign biu_jtag_debug_req_bus          =  biu_jtag_debug_req_bus_sysbus;
assign jtag_biu_debug_resp_bus_sysbus  =  jtag_biu_debug_resp_bus;

assign {fetch_req   ,
        fetch_dbgm  ,
        fetch_vaddr }  =  ifu_cache_req_bus;

assign fetch_req_sbus  =  fetch_req && fetch_hit_sbus;
`ifndef PERFORMANCE_TEST
// 1:normal
mmu_vaddr_sel_bus x_mmu_vaddr_sel_bus_0 (
    .vaddr      (vaddr_vaddr_sel0     ),
    .ibus_win   (ibus_win_vaddr_sel0  ),  // I, (1+32+32)*4
    .dbus_win   (dbus_win_vaddr_sel0  ),  // I, (1+32+32)*4
    .ibus_hit   (ibus_hit_vaddr_sel0  ),
    .dbus_hit   (dbus_hit_vaddr_sel0  ),
    .sysbus_hit (sysbus_hit_vaddr_sel0)
);
`else
// 2:for dhrystone and coremark
// all fetch to ibus, all load/store to dbus,uart to sysbus;
assign fetch_hit_ibus  =  1'b1;
assign fetch_hit_dbus  =  1'b0;
assign fetch_hit_sbus  =  1'b0;
`endif
// End ifu_cache_req_bus

//------------------------------------------------------------//
//                     lsu_cache_req_bus
//------------------------------------------------------------//

assign {memld_st_dald,
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
        st_wdata}  =  lsu_cache_req_bus;
assign de_mald_req_ibus   =  de_mald_req  && de_mald_hit_ibus;
assign de_mald_req_dbus   =  de_mald_req  && de_mald_hit_dbus;
assign de_mald_req_sbus   =  de_mald_req  && de_mald_hit_sbus;
assign memld_st_req_ibus  =  memld_st_req && memld_st_hit_ibus;
assign memld_st_req_dbus  =  memld_st_req && memld_st_hit_dbus;
assign memld_st_req_sbus  =  memld_st_req && memld_st_hit_sbus;
`ifndef PERFORMANCE_TEST
// 1:normal
mmu_vaddr_sel_bus x_mmu_vaddr_sel_bus_1 (
    .vaddr      (vaddr_vaddr_sel1     ),
    .ibus_win   (ibus_win_vaddr_sel1  ),  // I, (1+32+32)*4
    .dbus_win   (dbus_win_vaddr_sel1  ),  // I, (1+32+32)*4
    .ibus_hit   (ibus_hit_vaddr_sel1  ),
    .dbus_hit   (dbus_hit_vaddr_sel1  ),
    .sysbus_hit (sysbus_hit_vaddr_sel1)
);
mmu_vaddr_sel_bus x_mmu_vaddr_sel_bus_2 (
    .vaddr      (vaddr_vaddr_sel2     ),
    .ibus_win   (ibus_win_vaddr_sel2  ),  // I, (1+32+32)*4
    .dbus_win   (dbus_win_vaddr_sel2  ),  // I, (1+32+32)*4
    .ibus_hit   (ibus_hit_vaddr_sel2  ),
    .dbus_hit   (dbus_hit_vaddr_sel2  ),
    .sysbus_hit (sysbus_hit_vaddr_sel2)
);
`else
// 2:for dhrystone and coremark
// all fetch to ibus, all load/store to dbus,uart to sysbus;
`define UART_BASE_VADDR_H16 16'hbad0  // 1ad0_0000~1ad0_ffff, used only for performance test
assign de_mald_hit_ibus   =  1'b0;
assign de_mald_hit_dbus   =  ~(de_mald_vaddr[31:16] == `UART_BASE_VADDR_H16);
assign de_mald_hit_sbus   =  (de_mald_vaddr[31:16] == `UART_BASE_VADDR_H16);
assign memld_st_hit_ibus  =  1'b0;
assign memld_st_hit_dbus  =  ~(memld_st_vaddr[31:16] == `UART_BASE_VADDR_H16);
assign memld_st_hit_sbus  =  (memld_st_vaddr[31:16] == `UART_BASE_VADDR_H16);
`endif

assign size              =  memld_st_size[1:0];
assign addr              =  memld_st_vaddr[1:0];
assign memld_st_strb[3]  =  size[1] | (size[0]& addr[1]) | (addr[1:0]==2'b11);
assign memld_st_strb[2]  =  size[1] | (addr[1:0]==2'b10 );
assign memld_st_strb[1]  =  size[1] | (size[0]&~addr[1]) | (addr[1:0]==2'b01);
assign memld_st_strb[0]  =  size[1] | (addr[1:0]==2'b00 );
// End lsu_cache_req_bus

//------------------------------------------------------------//
//                     cache_ifu_resp_bus
//------------------------------------------------------------//

`ifdef CONFIG_MMU
assign cache_ifu_resp_bus  =  { fetch_mmu_expt_vld ,
                                fetch_mmu_expt_code,
                                fetchreq_ready ,
`else
assign cache_ifu_resp_bus  =  { fetchreq_ready ,
`endif
                                fetchdata_ready,
                                fetchdata_err  ,
                                fetch_whichbus,
                                fetch_rdata    };
// End cache_ifu_resp_bus

//------------------------------------------------------------//
//                     cache_lsu_resp_bus
//------------------------------------------------------------//
`ifdef CONFIG_MMU
assign cache_lsu_resp_bus  =  { ld_mmu_expt_vld ,
                                ld_mmu_expt_code,
                                ld_mmu_expt_write,
                                mem_cps_req_ready,
`else
assign cache_lsu_resp_bus  =  { mem_cps_req_ready,
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
                                ifc_null      };
// End cache_lsu_resp_bus

// The cache performance bus is driven directly by biu_axi_sysbus.
// End Bus Connections

//------------------------------------------------------------//
//                       Bus Selection
//------------------------------------------------------------//

assign ifc_ls_cmplt  =  ibus_mem_null && dbus_mem_null && sysbus_mem_null;
assign ifc_null      =  ibus_ft_null  && dbus_ft_null  && sysbus_ft_null&&ifc_ls_cmplt;

always @ ( posedge clk_g )
begin
    pre_ft_sel_i   <= reset ? 1'b0 : fetch_req   ? fetch_hit_ibus   : pre_ft_sel_i;
    pre_ft_sel_d   <= reset ? 1'b0 : fetch_req   ? fetch_hit_dbus   : pre_ft_sel_d;
    pre_ft_sel_s   <= reset ? 1'b1 : fetch_req   ? fetch_hit_sbus   : pre_ft_sel_s;
    pre_mald_sel_i <= reset ? 1'b0 : de_mald_req ? de_mald_hit_ibus : pre_mald_sel_i;
    pre_mald_sel_d <= reset ? 1'b0 : de_mald_req ? de_mald_hit_dbus : pre_mald_sel_d;
    pre_mald_sel_s <= reset ? 1'b1 : de_mald_req ? de_mald_hit_sbus : pre_mald_sel_s;
end

assign fetch_pre_ibus  =  fetch_req   && pre_ft_sel_i;
assign fetch_pre_dbus  =  fetch_req   && pre_ft_sel_d;
assign fetch_pre_sbus  =  fetch_req   && pre_ft_sel_s;
assign de_ld_pre_ibus  =  de_load_req && pre_mald_sel_i;
assign de_ld_pre_dbus  =  de_load_req && pre_mald_sel_d;
assign de_ld_pre_sbus  =  de_load_req && pre_mald_sel_s;

`ifdef CONFIG_MMU
assign ibus_sel_mald       =  !mmu_page_mode_if && de_ld_pre_ibus
                               && !ld_in_dbus && !ld_in_sysbus;
assign dbus_sel_mald       =  !mmu_page_mode_if && de_ld_pre_dbus
                               && !ld_in_ibus && !ld_in_sysbus;
assign sbus_sel_mald       =  !mmu_page_mode_if && de_ld_pre_sbus
                               && !ld_in_ibus && !ld_in_dbus;
assign sbus_real_sel_mald  =  !mmu_page_mode_if && de_mald_req_sbus
                               && !ld_in_ibus && !ld_in_dbus;
assign ibus_sel_memld_st   =  !mmu_page_mode_if && memld_st_req_ibus;
assign dbus_sel_memld_st   =  !mmu_page_mode_if && memld_st_req_dbus;
assign sbus_sel_memld_st   =  mmu_page_mode_if ? memld_st_req
                                                  : memld_st_req_sbus;
`else
assign ibus_sel_mald       =  de_ld_pre_ibus && !ld_in_dbus && !ld_in_sysbus;
assign dbus_sel_mald       =  de_ld_pre_dbus && !ld_in_ibus && !ld_in_sysbus;
assign sbus_sel_mald       =  de_ld_pre_sbus && !ld_in_ibus && !ld_in_dbus;
assign sbus_real_sel_mald  =  de_mald_req_sbus && !ld_in_ibus && !ld_in_dbus;
assign ibus_sel_memld_st   =  memld_st_req_ibus  ;  // && !st_in_dbus && !st_in_sysbus;//no need see ld_in_d/sysbus
assign dbus_sel_memld_st   =  memld_st_req_dbus;  // && !st_in_ibus && !st_in_sysbus;
assign sbus_sel_memld_st   =  memld_st_req_sbus;  // && !st_in_ibus && !st_in_dbus;
`endif
assign ibus_sel_mem        =  ibus_sel_mald   || ibus_sel_memld_st;
assign dbus_sel_mem        =  dbus_sel_mald   || dbus_sel_memld_st;

`ifdef CONFIG_MMU
assign ibus_sel_ft       =  !mmu_page_mode_if && fetch_pre_ibus
                             && !ft_in_dbus && !ft_in_sysbus;
assign dbus_sel_ft       =  !mmu_page_mode_if && fetch_pre_dbus
                             && !ft_in_ibus && !ft_in_sysbus;
assign sbus_sel_ft       =  mmu_page_mode_if ? fetch_req :
                             fetch_pre_sbus && !ft_in_ibus && !ft_in_dbus;
assign sbus_real_sel_ft  =  mmu_page_mode_if ? fetch_req :
                             fetch_req_sbus && !ft_in_ibus && !ft_in_dbus;
`else
assign ibus_sel_ft       =  fetch_pre_ibus && !ft_in_dbus && !ft_in_sysbus;
assign dbus_sel_ft       =  fetch_pre_dbus && !ft_in_ibus && !ft_in_sysbus;
assign sbus_sel_ft       =  fetch_pre_sbus && !ft_in_ibus && !ft_in_dbus;
assign sbus_real_sel_ft  =  fetch_req_sbus && !ft_in_ibus && !ft_in_dbus;
`endif
// End Bus Selection

//------------------------------------------------------------//
//               Read Data And Ready Selection
//------------------------------------------------------------//
assign ft_pre_i_ok     =  ibus_sel_ft   && fetch_hit_ibus;
assign ft_pre_d_ok     =  dbus_sel_ft   && fetch_hit_dbus;
assign ft_pre_s_ok     =  sbus_sel_ft   && fetch_hit_sbus;
assign mald_pre_i_ok   =  ibus_sel_mald && de_mald_req_ibus;
assign mald_pre_d_ok   =  dbus_sel_mald && de_mald_req_dbus;
assign mald_pre_s_ok   =  sbus_sel_mald && de_mald_req_sbus;
assign ft_pre_i_err    =  ibus_sel_ft   && !fetch_hit_ibus;
assign ft_pre_d_err    =  dbus_sel_ft   && !fetch_hit_dbus;
assign ft_pre_s_err    =  sbus_sel_ft   && !fetch_hit_sbus;
assign mald_pre_i_err  =  ibus_sel_mald && !de_mald_req_ibus;
assign mald_pre_d_err  =  dbus_sel_mald && !de_mald_req_dbus;
assign mald_pre_s_err  =  sbus_sel_mald && !de_mald_req_sbus;

// req ready
assign de_mald_req_ready   =  ( i_req_ready & mald_pre_i_ok)
                              |( d_req_ready & mald_pre_d_ok)
                              |  de_mald_req_s_ready;
assign memld_st_req_ready  =  ( i_req_ready & ~ibus_sel_mald & ibus_sel_memld_st )
                              |( d_req_ready & ~dbus_sel_mald & dbus_sel_memld_st )
                              |  memld_st_req_s_ready;
assign fetchreq_ready      =  ( i_req_ready & ~ibus_sel_mem     & ft_pre_i_ok       )
                              |( d_req_ready & ~dbus_sel_mem     & ft_pre_d_ok       )
                              |  fetch_req_s_ready;

// select data_ready and rdata
assign fetch_whichbus[1]  =  ft_data_i_ready;
assign fetch_whichbus[0]  =  ft_data_d_ready;
assign fetchdata_ready    =  ft_data_i_ready
                             | ft_data_d_ready
                             | ft_data_s_ready;
assign lddata_ready       =  ld_data_i_ready
                             | ld_data_d_ready
                             | ld_data_s_ready;
assign ld_rdata           =  ( data_i_rdata  & {32{ld_wait_i&&!i_cancel_data}} )
                             | ( data_d_rdata  & {32{ld_wait_d&&!d_cancel_data}} )
                             |   ld_data_s_rdata;
assign fetch_rdata        =  ( data_i_rdata  & {32{ft_wait_i&&!i_cancel_data}} )
                             | ( data_d_rdata  & {32{ft_wait_d&&!d_cancel_data}} )
                             |   ft_data_s_rdata;
// bus error
assign fetchdata_err  =  ft_data_i_err
                         | ft_data_d_err
                         | ft_data_s_err;
assign lddata_err     =  ld_data_i_err
                         | ld_data_d_err
                         | ld_data_s_err;
always @ ( posedge clk_g )
begin
    if(reset) begin
        axi_b_last_exok <= 1'b0;
    end
    else if(bvalid&&bready) begin
        axi_b_last_exok <= bresp[0];
    end
end
// SC need send request and wait ifc_null.
// so axi_b_last_exok is SC exokay.
assign ifc_last_exok  =  axi_b_last_exok;

assign lddata_exok  =  ld_data_s_exok;

// End Read Data And Ready Selection

//------------------------------------------------------------//
//                Signals Output To Ibus Dbus
//------------------------------------------------------------//
assign ibus_do_ft  =  ~ibus_sel_mem  &  ibus_sel_ft;
assign ibus_do_ld  =  ibus_sel_mald | (ibus_sel_memld_st & ~memld_st_write);
assign dbus_do_ft  =  ~dbus_sel_mem  &  dbus_sel_ft;
assign dbus_do_ld  =  dbus_sel_mald | (dbus_sel_memld_st & ~memld_st_write);
// wire dbus_do_st = ~dbus_sel_mald &  dbus_sel_memld_st &  memld_st_write ;

assign ft_ld_wait_i  =  ft_wait_i || ld_wait_i;
assign ft_ld_wait_d  =  ft_wait_d || ld_wait_d;
`ifndef OPEN132_AXI_HANDSHAKE
assign inst_sram_ack   =  1'b1;
assign inst_sram_rrdy  =  1'b1;
assign inst_sram_resp  =  1'b0;
assign data_sram_ack   =  1'b1;
assign data_sram_rrdy  =  1'b1;
assign data_sram_resp  =  1'b0;
assign wait_i_2        =  2'b00;
assign wait_d_2        =  2'b00;
`else
always @ ( posedge clk_g )
begin
    wait_i_2[1] <= reset                  ? 1'b0 :
    inst_sram_rrdy            ? 1'b0 :
    (ft_ld_wait_i)&&i_req_ready ? (ibus_do_ft||ibus_do_ld) : wait_i_2[1];
    wait_i_2[0] <= reset                  ? 1'b0 :
    inst_sram_rrdy            ? 1'b0 :
    (ft_ld_wait_i)&&i_req_ready ? (ibus_do_ft) : wait_i_2[0];
    wait_d_2[1] <= reset                  ? 1'b0 :
    data_sram_rrdy            ? 1'b0 :
    (ft_ld_wait_d)&&d_req_ready ? (dbus_do_ft||dbus_do_ld) : wait_d_2[1];
    wait_d_2[0] <= reset                  ? 1'b0 :
    data_sram_rrdy            ? 1'b0 :
    (ft_ld_wait_d)&&d_req_ready ? (dbus_do_ft) : wait_d_2[0];
end
`endif
// inst bus
assign inst_sram_en  =  (ibus_sel_mem || ibus_sel_ft) && !wait_i_2[1];
// Only the store request has an uncertain transfer size.
assign inst_sram_strb   =  (~ibus_sel_mald & ibus_sel_memld_st)? memld_st_strb : 4'b1111;
assign inst_sram_wr     =  ~ibus_sel_mald & ibus_sel_memld_st & memld_st_write;
assign inst_sram_fetch  =  ~ibus_sel_mald &~ibus_sel_memld_st;
assign inst_sram_addr   =  ibus_sel_mald  ? de_mald_vaddr :
                             ibus_sel_memld_st ? memld_st_vaddr:
                             ibus_sel_ft       ? fetch_vaddr   : 32'd0;
assign inst_sram_wdata  =  st_wdata;

// inst bus
assign data_sram_en     =  (dbus_sel_mem || dbus_sel_ft) && !wait_d_2[1];
assign data_sram_strb   =  (~dbus_sel_mald & dbus_sel_memld_st)? memld_st_strb : 4'b1111;
assign data_sram_wr     =  ~dbus_sel_mald & dbus_sel_memld_st & memld_st_write;
assign data_sram_fetch  =  ~dbus_sel_mald &~dbus_sel_memld_st;
assign data_sram_addr   =  dbus_sel_mald  ? de_mald_vaddr :
                             dbus_sel_memld_st ? memld_st_vaddr:
                             dbus_sel_ft       ? fetch_vaddr   : 32'd0;
assign data_sram_wdata  =  st_wdata;

// i/dbus req ready
assign i_req_ready  =  inst_sram_ack && !wait_i_2[1];
assign d_req_ready  =  data_sram_ack && !wait_d_2[1];

assign i_data_ready     =  inst_sram_rrdy && !i_cancel_data;
assign d_data_ready     =  data_sram_rrdy && !d_cancel_data;
assign ft_data_i_ready  =  ft_wait_i && i_data_ready;
assign ld_data_i_ready  =  ld_wait_i && i_data_ready;
assign ft_data_d_ready  =  ft_wait_d && d_data_ready;
assign ld_data_d_ready  =  ld_wait_d && d_data_ready;

assign i_data_err     =  inst_sram_resp && !i_cancel_data;
assign d_data_err     =  data_sram_resp && !d_cancel_data;
assign ft_data_i_err  =  ft_wait_i && i_data_err;
assign ld_data_i_err  =  ld_wait_i && i_data_err;
assign ft_data_d_err  =  ft_wait_d && d_data_err;
assign ld_data_d_err  =  ld_wait_d && d_data_err;

// i/dbus rdata
assign data_i_rdata  =  inst_sram_rdata;
assign data_d_rdata  =  data_sram_rdata;

assign pre_i_ready_err  =  i_req_ready&&(mald_pre_i_err||(!ibus_sel_mem&&ft_pre_i_err));
assign pre_d_ready_err  =  d_req_ready&&(mald_pre_d_err||(!dbus_sel_mem&&ft_pre_d_err));
always @ ( posedge clk_g )
begin
    if(reset) begin
        i_cancel_data <= 1'b0;
    end
    else if(ex_cancel) begin
        i_cancel_data <= inst_sram_rrdy ? wait_i_2[1] : ft_ld_wait_i;
    end
    else if(inst_sram_rrdy) begin
        i_cancel_data <= wait_i_2[1] ? canc_wait_i : pre_i_ready_err;
    end
    else if(!ft_ld_wait_i) begin
        i_cancel_data <= pre_i_ready_err;
    end

    if(reset) begin
        d_cancel_data <= 1'b0;
    end
    else if(ex_cancel) begin
        d_cancel_data <= data_sram_rrdy ? wait_d_2[1] : ft_ld_wait_d;
    end
    else if(data_sram_rrdy) begin
        d_cancel_data <= wait_d_2[1] ? canc_wait_d : pre_d_ready_err;
    end
    else if(!ft_ld_wait_d) begin
        d_cancel_data <= pre_d_ready_err;
    end

    canc_wait_i <= reset ? 1'b0 :
    inst_sram_rrdy ? 1'b0 :
    ex_cancel&&wait_i_2[1] ? 1'b1 :
    ft_ld_wait_i && pre_i_ready_err ? 1'b1 : canc_wait_i;
    canc_wait_d <= reset ? 1'b0 :
    data_sram_rrdy ? 1'b0 :
    ex_cancel&&wait_d_2[1] ? 1'b1 :
    ft_ld_wait_d && pre_d_ready_err  ? 1'b1 : canc_wait_d;

end

// wait rdata/response
always @ ( posedge clk_g )
begin
    ft_wait_i <= reset       ? 1'b0 :
    inst_sram_rrdy ? wait_i_2[1] ? wait_i_2[0] : i_req_ready&&ibus_do_ft :
    i_req_ready && ibus_do_ft && !ft_ld_wait_i ? 1'b1 : ft_wait_i;
    ft_wait_d <= reset       ? 1'b0 :
    data_sram_rrdy ? wait_d_2[1] ? wait_d_2[0] : d_req_ready&&dbus_do_ft :
    d_req_ready && dbus_do_ft && !ft_ld_wait_d ? 1'b1 : ft_wait_d;
    ld_wait_i <= reset       ? 1'b0 :
    inst_sram_rrdy ? wait_i_2[1] ? ~wait_i_2[0] : i_req_ready&&ibus_do_ld :
    i_req_ready && ibus_do_ld && !ft_ld_wait_i ? 1'b1 : ld_wait_i;
    ld_wait_d <= reset       ? 1'b0 :
    data_sram_rrdy ? wait_d_2[1] ? ~wait_d_2[0] : d_req_ready&&dbus_do_ld :
    d_req_ready && dbus_do_ld && !ft_ld_wait_d ? 1'b1 : ld_wait_d;
end

// ft/ld/st in ibus/dbus
assign ft_in_ibus     =  ft_wait_i&&!i_cancel_data || wait_i_2[0]    &&!canc_wait_i;
assign ld_in_ibus     =  ld_wait_i&&!i_cancel_data || wait_i_2==2'b10&&!canc_wait_i;
assign ft_in_dbus     =  ft_wait_d&&!d_cancel_data || wait_d_2[0]    &&!canc_wait_d;
assign ld_in_dbus     =  ld_wait_d&&!d_cancel_data || wait_d_2==2'b10&&!canc_wait_d;
assign ibus_mem_null  =  !ld_wait_i && !(wait_i_2==2'b10);
assign dbus_mem_null  =  !ld_wait_d && !(wait_d_2==2'b10);
assign ibus_ft_null   =  !ft_wait_i && !wait_i_2[0];
assign dbus_ft_null   =  !ft_wait_d && !wait_d_2[0];
// End Signals Output To Ibus Dbus

//------------------------------------------------------------//
//                   Connect To Sysbus Axi
//------------------------------------------------------------//
biu_axi_sysbus #(
    .PERF_CNT_NUM  (PERF_CNT_NUM_SYSBUS ),
    .AXI_DATA_WD   (AXI_DATA_WD_SYSBUS  ),  // 32/64/128
    .HAS_ICC       (HAS_ICC_SYSBUS      ),
    .ICC_SET_ASSOC (ICC_SET_ASSOC_SYSBUS),
    .ICC_WAYSIZE   (ICC_WAYSIZE_SYSBUS  ),
    .ICC_ECC_BITS  (ICC_ECC_BITS_SYSBUS ),
    .HAS_DCC       (HAS_DCC_SYSBUS      ),
    .DCC_SET_ASSOC (DCC_SET_ASSOC_SYSBUS),
    .DCC_WAYSIZE   (DCC_WAYSIZE_SYSBUS  ),
    .DCC_ECC_BITS  (DCC_ECC_BITS_SYSBUS )
) x_biu_axi_sysbus (
    // clk and reset
    .clk                     (clk_sysbus                    ),
    .clk_ng                  (clk_ng_sysbus                 ),
    .reset                   (reset_sysbus                  ),
    .data_reset              (data_reset_sysbus             ),
    .ctrl_nowrap             (ctrl_nowrap_sysbus            ),
    .ex_cancel               (ex_cancel_sysbus              ),
    // <->ifc
    .fetch_dbgm              (fetch_dbgm_sysbus             ),
    .fetch_vaddr             (fetch_vaddr_sysbus            ),
    .memld_st_dbgm           (memld_st_dbgm_sysbus          ),
    .de_mald_vaddr           (de_mald_vaddr_sysbus          ),
    .memld_st_vaddr          (memld_st_vaddr_sysbus         ),
    .memld_st_write          (memld_st_write_sysbus         ),
    .memld_st_size           (memld_st_size_sysbus          ),
    .memld_st_strb           (memld_st_strb_sysbus          ),
    .st_wdata                (st_wdata_sysbus               ),
    .de_load_req             (de_load_req_sysbus            ),
    .memld_st_req            (memld_st_req_sysbus           ),
    .memld_st_exc            (memld_st_exc_sysbus           ),
    .memld_st_dald           (memld_st_dald_sysbus          ),
    .sbus_sel_ft             (sbus_sel_ft_sysbus            ),
    .sbus_sel_mald           (sbus_sel_mald_sysbus          ),
    .sbus_real_sel_ft        (sbus_real_sel_ft_sysbus       ),
    .sbus_real_sel_mald      (sbus_real_sel_mald_sysbus     ),
    .sbus_sel_memld_st       (sbus_sel_memld_st_sysbus      ),
    .ft_pre_s_ok             (ft_pre_s_ok_sysbus            ),
    .mald_pre_s_ok           (mald_pre_s_ok_sysbus          ),
    .ft_pre_s_err            (ft_pre_s_err_sysbus           ),
    .mald_pre_s_err          (mald_pre_s_err_sysbus         ),
    .ft_in_sysbus            (ft_in_sysbus_sysbus           ),
    .ld_in_sysbus            (ld_in_sysbus_sysbus           ),
    .sysbus_mem_null         (sysbus_mem_null_sysbus        ),
    .sysbus_ft_null          (sysbus_ft_null_sysbus         ),
    .fetch_req_s_ready       (fetch_req_s_ready_sysbus      ),
    .de_mald_req_s_ready     (de_mald_req_s_ready_sysbus    ),
    .memld_st_req_s_ready    (memld_st_req_s_ready_sysbus   ),
    .ft_data_s_ready         (ft_data_s_ready_sysbus        ),
    .ld_data_s_ready         (ld_data_s_ready_sysbus        ),
    .ld_data_s_exok          (ld_data_s_exok_sysbus         ),
    .ft_data_s_rdata         (ft_data_s_rdata_sysbus        ),
    .ld_data_s_rdata         (ld_data_s_rdata_sysbus        ),
    .ft_data_s_err           (ft_data_s_err_sysbus          ),
    .ld_data_s_err           (ld_data_s_err_sysbus          ),
`ifdef CONFIG_MMU
    .ft_mmu_expt_vld         (ft_mmu_expt_vld_sysbus        ),
    .ft_mmu_expt_code        (ft_mmu_expt_code_sysbus       ),
    .ld_mmu_expt_vld         (ld_mmu_expt_vld_sysbus        ),
    .ld_mmu_expt_code        (ld_mmu_expt_code_sysbus       ),
    .ld_mmu_expt_write       (ld_mmu_expt_write_sysbus      ),
`endif
    // sys axi
    // ar
    .sys_arready             (sys_arready_sysbus            ),
    .sys_arid                (sys_arid_sysbus               ),
    .sys_araddr              (sys_araddr_sysbus             ),
    .sys_arlen               (sys_arlen_sysbus              ),
    .sys_arsize              (sys_arsize_sysbus             ),
    .sys_arburst             (sys_arburst_sysbus            ),
    .sys_arlock              (sys_arlock_sysbus             ),
    .sys_arcache             (sys_arcache_sysbus            ),
    .sys_arprot              (sys_arprot_sysbus             ),
    .sys_arvalid             (sys_arvalid_sysbus            ),
    // r
    .sys_rid                 (sys_rid_sysbus                ),
    .sys_rdata               (sys_rdata_sysbus              ),
    .sys_rresp               (sys_rresp_sysbus              ),
    .sys_rlast               (sys_rlast_sysbus              ),
    .sys_rvalid              (sys_rvalid_sysbus             ),
    .sys_rready              (sys_rready_sysbus             ),
    // aw
    .sys_awready             (sys_awready_sysbus            ),
    .sys_awid                (sys_awid_sysbus               ),
    .sys_awaddr              (sys_awaddr_sysbus             ),
    .sys_awlen               (sys_awlen_sysbus              ),
    .sys_awsize              (sys_awsize_sysbus             ),
    .sys_awburst             (sys_awburst_sysbus            ),
    .sys_awlock              (sys_awlock_sysbus             ),
    .sys_awcache             (sys_awcache_sysbus            ),
    .sys_awprot              (sys_awprot_sysbus             ),
    .sys_awvalid             (sys_awvalid_sysbus            ),
    // w
    .sys_wready              (sys_wready_sysbus             ),
    .sys_wid                 (sys_wid_sysbus                ),
    .sys_wdata               (sys_wdata_sysbus              ),
    .sys_wstrb               (sys_wstrb_sysbus              ),
    .sys_wlast               (sys_wlast_sysbus              ),
    .sys_wvalid              (sys_wvalid_sysbus             ),
    // b
    .sys_bid                 (sys_bid_sysbus                ),
    .sys_bresp               (sys_bresp_sysbus              ),
    .sys_bvalid              (sys_bvalid_sysbus             ),
    .sys_bready              (sys_bready_sysbus             ),

    // cache/isync/pref inst
    .mem_cps_req             (mem_cps_req_sysbus            ),
    .mem_sttag_data          (mem_sttag_data_sysbus         ),
    .mem_cc_op_i             (mem_cc_op_i_sysbus            ),
    .mem_cc_op_d             (mem_cc_op_d_sysbus            ),
    .mem_cc_op               (mem_cc_op_sysbus              ),
    .mem_cc_fill             (mem_cc_fill_sysbus            ),
    .mem_cc_lock             (mem_cc_lock_sysbus            ),
    .mem_cc_pref             (mem_cc_pref_sysbus            ),
    .mem_cps_req_ready       (mem_cps_req_ready_sysbus      ),
    .mem_cps_data_ready      (mem_cps_data_ready_sysbus     ),
    .mem_cps_data_rdata      (mem_cps_data_rdata_sysbus     ),
    .resetn_in_d2            (resetn_in_d2_sysbus           ),
    .ram_init_cmplt          (ram_init_cmplt_sysbus         ),
    // mmu
    .csr_cache_ctrl_bus      (csr_cache_ctrl_bus_sysbus     ),
`ifdef CONFIG_MMU
    .csr_mmu_ctrl_bus        (csr_mmu_ctrl_bus_sysbus       ),
`endif
    // performance count
    .cache_csr_perf_bus      (cache_csr_perf_bus_sysbus     ),
    // ecc fatal
    .cache_lsu_ecc_fatal_bus (cache_lsu_ecc_fatal_bus_sysbus),
    // dcache ram
    .dcc_ram_tagv_req_bus    (dcc_ram_tagv_req_bus_sysbus   ),
    .dcc_ram_data_req_bus    (dcc_ram_data_req_bus_sysbus   ),
    .dcc_ram_lrud_req_bus    (dcc_ram_lrud_req_bus_sysbus   ),  // write by bit
    .dcc_ram_tagv_resp_bus   (dcc_ram_tagv_resp_bus_sysbus  ),
    .dcc_ram_data_resp_bus   (dcc_ram_data_resp_bus_sysbus  ),
    .dcc_ram_lrud_resp_bus   (dcc_ram_lrud_resp_bus_sysbus  ),
    // icache ram
    .icc_ram_tagv_req_bus    (icc_ram_tagv_req_bus_sysbus   ),
    .icc_ram_data_req_bus    (icc_ram_data_req_bus_sysbus   ),
    .icc_ram_lrud_req_bus    (icc_ram_lrud_req_bus_sysbus   ),  // write by bit
    .icc_ram_tagv_resp_bus   (icc_ram_tagv_resp_bus_sysbus  ),
    .icc_ram_data_resp_bus   (icc_ram_data_resp_bus_sysbus  ),
    .icc_ram_lrud_resp_bus   (icc_ram_lrud_resp_bus_sysbus  )

`ifdef OPEN132_HAS_LJTAG
    ,
    .biu_jtag_debug_req_bus  (biu_jtag_debug_req_bus_sysbus ),
    .jtag_biu_debug_resp_bus (jtag_biu_debug_resp_bus_sysbus)
`endif

);
// End Connect To Sysbus Axi
endmodule
`endif

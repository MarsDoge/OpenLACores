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

module la132_core #(
    // for axi interface
    parameter AXI_DATA_WD   = 32,         // 32/64/128
    // ICache
    parameter HAS_ICC       = 0,          // 0 or 1
    parameter ICC_SET_ASSOC = 1,          // 1/2/4 way set associative
    parameter ICC_WAYSIZE   = 1*(2**10),  // 1/2/4/8/16 KB Size/way
    parameter ICC_ECC_BITS  = 1,          // 1/7/8/9 bits, for no ecc, 32+7, 64+8, 128+9
    // DCache
    parameter HAS_DCC       = 0,          // 0 or 1
    parameter DCC_SET_ASSOC = 1,          // 1/2/4 way set associative
    parameter DCC_WAYSIZE   = 1*(2**10),  // 1/2/4/8/16 KB Size/way
    parameter DCC_ECC_BITS  = 1           // 1/7/8/9 bits, for no ecc, 32+7, 64+8, 128+9
) (
    input  wire [                                 31: 0]  boot_pc,
    // ip global clock and reset except debug logic
    input  wire                                           clk,
    input  wire                                           hard_resetn,

    // miscellaneous signals
    output wire                                           sleeping,  // safe to cut clock or power off in sleeping mode

    // interrupt inputs
    input  wire [                                  7: 0]  ext_int,

    // core cpu number
    input  wire [                                  9: 0]  cpunum,

`ifdef OPEN132_INTERFACE_AXI
    // sys axi
    // ar
    output wire [                                  3: 0]  arid,
    output wire [                                 31: 0]  araddr,
    output wire [                                  3: 0]  arlen,
    output wire [                                  2: 0]  arsize,
    output wire [                                  1: 0]  arburst,
    output wire [                                  1: 0]  arlock,
    output wire [                                  3: 0]  arcache,
    output wire [                                  2: 0]  arprot,
    output wire                                           arvalid,
    input  wire                                           arready,
    // r
    input  wire [                                  3: 0]  rid,
    input  wire [                      AXI_DATA_WD-1: 0]  rdata,
    input  wire [                                  1: 0]  rresp,
    input  wire                                           rlast,
    input  wire                                           rvalid,
    output wire                                           rready,
    // aw
    output wire [                                  3: 0]  awid,
    output wire [                                 31: 0]  awaddr,
    output wire [                                  3: 0]  awlen,
    output wire [                                  2: 0]  awsize,
    output wire [                                  1: 0]  awburst,
    output wire [                                  1: 0]  awlock,
    output wire [                                  3: 0]  awcache,
    output wire [                                  2: 0]  awprot,
    output wire                                           awvalid,
    input  wire                                           awready,
    // w
    output wire [                                  3: 0]  wid,
    output wire [                      AXI_DATA_WD-1: 0]  wdata,
    output wire [                    AXI_DATA_WD/8-1: 0]  wstrb,
    output wire                                           wlast,
    output wire                                           wvalid,
    input  wire                                           wready,
    // b
    input  wire [                                  3: 0]  bid,
    input  wire [                                  1: 0]  bresp,
    input  wire                                           bvalid,
    output wire                                           bready,
    // inst sram
    output wire                                           inst_sram_en,
    output wire [                                  3: 0]  inst_sram_strb,
    output wire                                           inst_sram_wr,
    output wire                                           inst_sram_fetch,
    output wire [                                 31: 0]  inst_sram_addr,
    output wire [                                 31: 0]  inst_sram_wdata,
    input  wire [                                 31: 0]  inst_sram_rdata,
    // data sram
    output wire                                           data_sram_en,
    output wire [                                  3: 0]  data_sram_strb,
    output wire                                           data_sram_wr,
    output wire                                           data_sram_fetch,
    output wire [                                 31: 0]  data_sram_addr,
    output wire [                                 31: 0]  data_sram_wdata,
    input  wire [                                 31: 0]  data_sram_rdata,

`ifdef OPEN132_AXI_HANDSHAKE
    input  wire                                           inst_sram_ack,
    input  wire                                           inst_sram_rrdy,
    input  wire                                           inst_sram_resp,
    input  wire                                           data_sram_ack,
    input  wire                                           data_sram_rrdy,
    input  wire                                           data_sram_resp,
`endif
`endif

    // LJTAG signals
`ifdef OPEN132_HAS_LJTAG
    input  wire                                           cjtag_sel,

    input  wire                                           cjtag_trstn,
    input  wire                                           cjtag_clk,
    input  wire                                           cjtag_tckc,
    input  wire                                           cjtag_tmsc_i,
    output wire                                           cjtag_tmsc_o,
    output wire                                           cjtag_tmsc_oe,

    input  wire                                           jtag_trstn,
    input  wire                                           jtag_tck,
    input  wire                                           jtag_tms,
    input  wire                                           jtag_tdi,
    output wire                                           jtag_tdo,
`endif  // OPEN132_HAS_LJTAG

    // CACHE RAM
    // dcache ram
    output wire [ `OPEN132_DCC_RAM_TAGV_REQ_BUS_WD-1: 0]  dcc_ram_tagv_req_bus,
    output wire [ `OPEN132_DCC_RAM_DATA_REQ_BUS_WD-1: 0]  dcc_ram_data_req_bus,
    output wire [ `OPEN132_DCC_RAM_LRUD_REQ_BUS_WD-1: 0]  dcc_ram_lrud_req_bus,  // write by bit
    input  wire [`OPEN132_DCC_RAM_TAGV_RESP_BUS_WD-1: 0]  dcc_ram_tagv_resp_bus,
    input  wire [`OPEN132_DCC_RAM_DATA_RESP_BUS_WD-1: 0]  dcc_ram_data_resp_bus,
    input  wire [`OPEN132_DCC_RAM_LRUD_RESP_BUS_WD-1: 0]  dcc_ram_lrud_resp_bus,
    // icache ram
    output wire [ `OPEN132_ICC_RAM_TAGV_REQ_BUS_WD-1: 0]  icc_ram_tagv_req_bus,
    output wire [ `OPEN132_ICC_RAM_DATA_REQ_BUS_WD-1: 0]  icc_ram_data_req_bus,
    output wire [ `OPEN132_ICC_RAM_LRUD_REQ_BUS_WD-1: 0]  icc_ram_lrud_req_bus,  // write by bit
    input  wire [`OPEN132_ICC_RAM_TAGV_RESP_BUS_WD-1: 0]  icc_ram_tagv_resp_bus,
    input  wire [`OPEN132_ICC_RAM_DATA_RESP_BUS_WD-1: 0]  icc_ram_data_resp_bus,
    input  wire [`OPEN132_ICC_RAM_LRUD_RESP_BUS_WD-1: 0]  icc_ram_lrud_resp_bus,

    // output wb-stage state
`ifdef OPEN132_OUTPUT_WB_STATE
    output wire [                                 31: 0]  wb_pc,
    output wire [                                  4: 0]  wb_rf_dest,
    output wire                                           wb_rf_wen,  // open132 regfile is word enable
    output wire [                                 31: 0]  wb_rf_value,
`endif

    // test input/output signals
`ifdef OPEN132_INCLUDE_DFT
    input  wire [              `OPEN132_LTESTBUSIN-1: 0]  testbusin,
    output wire [             `OPEN132_LTESTBUSOUT-1: 0]  testbusout,
`endif  // OPEN132_INCLUDE_DFT

    // i/d bus configuration
    input  wire                                           ibus0_valid,
    input  wire [                                 31: 0]  ibus0_base,
    input  wire [                                 31: 0]  ibus0_mask,
    input  wire                                           ibus1_valid,
    input  wire [                                 31: 0]  ibus1_base,
    input  wire [                                 31: 0]  ibus1_mask,
    input  wire                                           ibus2_valid,
    input  wire [                                 31: 0]  ibus2_base,
    input  wire [                                 31: 0]  ibus2_mask,
    input  wire                                           ibus3_valid,
    input  wire [                                 31: 0]  ibus3_base,
    input  wire [                                 31: 0]  ibus3_mask,
    input  wire                                           dbus0_valid,
    input  wire [                                 31: 0]  dbus0_base,
    input  wire [                                 31: 0]  dbus0_mask,
    input  wire                                           dbus1_valid,
    input  wire [                                 31: 0]  dbus1_base,
    input  wire [                                 31: 0]  dbus1_mask,
    input  wire                                           dbus2_valid,
    input  wire [                                 31: 0]  dbus2_base,
    input  wire [                                 31: 0]  dbus2_mask,
    input  wire                                           dbus3_valid,
    input  wire [                                 31: 0]  dbus3_base,
    input  wire [                                 31: 0]  dbus3_mask,

    // runnig mode
    input  wire                                           test_mode

`ifdef GODSON_DEBUG
    ,
    output wire                                           gs_core_exe_valid,
    output wire [                                 31: 0]  gs_core_exe_pc,
    output wire [                                 31: 0]  gs_core_exe_inst,
    output wire                                           gs_core_gr_we,
    output wire [                                  4: 0]  gs_core_gr_waddr,
    output wire [                                 31: 0]  gs_core_gr_wdata,
    output wire [                                  4: 0]  gs_core_gr_raddr0,
    output wire [                                 31: 0]  gs_core_gr_rdata0,
    output wire [                                  4: 0]  gs_core_gr_raddr1,
    output wire [                                 31: 0]  gs_core_gr_rdata1,
    output wire [                                 31: 0]  gs_core_csr0,
    output wire [                                 31: 0]  gs_core_csr1,
    output wire [                                 31: 0]  gs_core_csr4,
    output wire [                                 31: 0]  gs_core_csr5,
    output wire [                                 31: 0]  gs_core_csr6,
    output wire [                                 31: 0]  gs_core_csr7
`endif
);

// BTB
localparam HAS_BTB = 1'b1     ;  // 0 or 1

// MDU(mul&div unit)
localparam MDU_TYPE = 2'd0     ;  // 0(quick) or 1(smart) or 2(area)

// performance counter
localparam PERF_CNT_NUM = 0       ;  // 0

// Memory Protect Unit
localparam MPU_NUM = 2       ;  // 0; 1; 2; 3 or 4

// breakpoint
localparam IHB_NUM = 2       ;  // 0(no ihb); 1~15

// Published top-level constants are owned inside the functional core.
localparam CORE_SOFT_RESETN = 1'b1;
localparam CORE_NMI         = 1'b0;

// Fixed cache ECC configuration retained from the legacy integration.
localparam ICC_ECC_BITS_AXI_IF = 1;
localparam DCC_ECC_BITS_AXI_IF = 1;

//============================================================//
//                     Regs Declarations
//============================================================//

reg          nmi_r;

reg          hard_resetn_in_d1;
reg          soft_resetn_in_d1;
reg          hard_resetn_in_d2;
reg          soft_resetn_in_d2;

//============================================================//
//                     Wire Declarations
//============================================================//

wire          clk_cjtag;
wire          reset_in_cjtag;
wire          tckc_cjtag;
wire          tmsc_i_cjtag;
wire          tmsc_o_cjtag;
wire          tmsc_oe_cjtag;
wire          ljtag_trstn_cjtag;
wire          ljtag_tck_cjtag;
wire          ljtag_tms_cjtag;
wire          ljtag_tdi_cjtag;
wire          ljtag_tdo_cjtag;
wire          clk_ljt_dm;
wire          clk_ng_dm;
wire          reset_dm;
wire [ 55: 0] biu_jtag_debug_req_bus_dm;
wire          dm_dm;
wire [ 31: 0] pc_dm;
wire [  7: 0] asid_dm;
wire          ljtag_ce_dm;
wire [ 32: 0] jtag_biu_debug_resp_bus_dm;
wire          jtag_core_break_dm;
wire          ljtag_lock_dm;
wire          tck_dm;
wire          trstn_dm;
wire          tms_dm;
wire          tdi_dm;
wire          tdo_dm;
wire          testmode_jtag_rst;
wire          tck_jtag_rst;
wire          trstn_in_jtag_rst;
wire          trstn_out_jtag_rst;
wire          D0_cmux0;
wire          D1_cmux0;
wire          S0_cmux0;
wire          Z_cmux0;
wire          D0_cmux1;
wire          D1_cmux1;
wire          S0_cmux1;
wire          Z_cmux1;

wire [(1+32+32)*4-1: 0] ibus_win;
wire [(1+32+32)*4-1: 0] dbus_win;
wire                    clk_count;
wire [            3: 0] prid_revision_lsu_stage;

// register nmi, ext_int
wire          core_lsu_nmi;

wire          debug_int;  // for clock gating

wire          reset;
wire          data_reset;

wire          resetn_in_d2;
wire          ram_init_cmplt;

// after sync
wire          sync_hresetn;
wire          sync_sresetn;

wire [`OPEN132_LSU_CORE_CTRL_BUS_WIDTH-1: 0] lsu_core_ctrl_bus;

// wire sleeping     ;  //cpu in sleeping.
wire          ctrl_nowrap;         // axi no wrap.
wire          mem_wakeup;          // nmi/int need wakeup sleeping.
wire          ctrl_sleep_cg;       // clock-gated in sleeping,csr(16.6) userdef.sleepcg
wire          ctrl_null_cg;        // clock-gated if module unused, csr(16.6) userdef.sleepcg
wire          lsu_clk_csr_enable;  // csrr/csr clk open

wire          clk_slp_en;
wire          clk_g;
wire          clk_gpr_en;
wire          clk_gpr;
wire          clk_cr_en;
wire          clk_cr;
wire          rtu_clk_gpr_enable;  // wb enable gpr clock
`ifdef OPEN132_HAS_LJTAG

wire          clk_ljt_en;  // see{LJTAG}
wire          clk_ljt;
wire          clk_dm_en;
wire          clk_dm;      // for ihb/dhb/dcr

//
wire          ljtag_ce;
wire          lsu_clk_breakpoint_enable;  // ihb/dhb clock enable
`endif

wire          clk_fpr_en;  // see{FPU}
wire          clk_fpr;
wire          clk_fpu_en;
wire          clk_fpu;

// fpu-cg
wire          dec_is_fpu;    // from de-stage
wire          fpu_is_valid;  // from fpu

// no-cg clk
wire          clk_ng;

// pipeline stage allowin
wire          idu_ifu_allowin;
wire          lsu_idu_allowin;
wire          exu_idu_allowin;
wire          rtu_lsu_allowin;

// fetch2de signals
wire                                      ifu_idu_inst_valid;
wire [`OPEN132_IFU_IDU_INST_BUS_WIDTH-1: 0] ifu_idu_inst_bus;
wire [                             31: 0] ifu_idu_seq_pc;

wire [ 31: 0] ifu_jtag_pc;
wire [ 31: 0] ifu_bpu_pc;

// de2fetch signals
wire [ 35: 0] idu_ifu_branch_bus;

// de2mem signals
wire                                      idu_lsu_inst_valid;
wire [`OPEN132_IDU_LSU_INST_BUS_WIDTH-1: 0] idu_lsu_inst_bus;
wire [                             31: 0] idu_lsu_follow_pc;       // pc of inst follow de-stage
wire [                             33: 0] idu_lsu_load_attr_bus;   // memory attribute load
wire [                             34: 0] idu_lsu_store_data_bus;

// mem2de signals
wire                                         lsu_idu_forward_valid;
wire [`OPEN132_LSU_IDU_FORWARD_BUS_WIDTH-1: 0] lsu_idu_forward_bus;
wire [   `OPEN132_CSR_IDU_CTRL_BUS_WIDTH-1: 0] csr_idu_ctrl_bus;

// dec2mdu signals
wire [`OPEN132_IDU_EXU_MDU_BUS_WIDTH-1: 0] idu_exu_mdu_bus;

// mem2fetch signals
wire [`OPEN132_CSR_IFU_CTRL_BUS_WIDTH-1: 0] csr_ifu_ctrl_bus;

// csr2pred bus
wire [  1: 0] csr_bpu_ctrl_bus;

// mem2mdu signals
wire [  2: 0] lsu_exu_ctrl_bus;

// mdu2mem signals
wire [  0: 0] exu_lsu_ctrl_bus;

// mem2wb signals
wire                                      lsu_rtu_inst_valid;
wire [`OPEN132_LSU_RTU_INST_BUS_WIDTH-1: 0] lsu_rtu_inst_bus;

// wb2fetch signals
wire [ 32: 0] rtu_ifu_redirect_bus;

// wb2de signals
wire                                         rtu_idu_forward_valid;
wire [`OPEN132_RTU_IDU_FORWARD_BUS_WIDTH-1: 0] rtu_idu_forward_bus;

// wb2mdu signals
wire [  5: 0] rtu_exu_ctrl_bus;

// mdu2wb signals
wire [ 32: 0] exu_rtu_result_bus;

// ifc2fetch signals
wire [`OPEN132_CACHE_IFU_RESP_BUS_WIDTH-1: 0] cache_ifu_resp_bus;

// fetch2ifc signals
wire [`OPEN132_IFU_CACHE_REQ_BUS_WIDTH-1: 0] ifu_cache_req_bus;

// ifc2mem signals
wire [`OPEN132_CACHE_LSU_RESP_BUS_WIDTH-1: 0] cache_lsu_resp_bus;

// mem2ifc signals
wire [ `OPEN132_LSU_CACHE_REQ_BUS_WIDTH-1: 0] lsu_cache_req_bus;
wire [`OPEN132_CSR_CACHE_CTRL_BUS_WIDTH-1: 0] csr_cache_ctrl_bus;
`ifdef CONFIG_MMU
wire [ `OPEN132_CSR_MMU_CTRL_BUS_WIDTH-1: 0] csr_mmu_ctrl_bus;
`endif

// performance count
wire [  `OPEN132_IDU_CSR_PERF_BUS_WIDTH-1: 0] idu_csr_perf_bus;
wire [`OPEN132_CACHE_CSR_PERF_BUS_WIDTH-1: 0] cache_csr_perf_bus;

// wb ex_cancel
wire          ex_cancel;
wire [ 31: 0] rtu_lsu_cancel_pc;
wire          rtu_lsu_commit;

// for ecc
wire [`OPEN132_CACHE_LSU_ECC_FATAL_BUS_WIDTH-1: 0] cache_lsu_ecc_fatal_bus;

// application-specific
wire [`OPEN132_IDU_LSU_APP_BUS_WIDTH-1: 0] idu_lsu_app_bus;
wire [`OPEN132_LSU_RTU_APP_BUS_WIDTH-1: 0] lsu_rtu_app_bus;
wire [`OPEN132_RTU_EXU_APP_BUS_WIDTH-1: 0] rtu_exu_app_bus;
`ifdef OPEN132_HAS_LJTAG

// ifc2tap
wire [ 55: 0] biu_jtag_debug_req_bus;

// tap2ifc
wire [ 32: 0] jtag_biu_debug_resp_bus;

// ifc2ihb
wire [ 80: 0] jtag_idu_ihb_req_bus;

// ihb2ifc
wire [ 31: 0] idu_jtag_ihb_resp_bus;

// mem2fetch debug
wire          lsu_ifu_debug_map_valid;

// mem2de debug
wire [ 13: 0] lsu_idu_debug_bus;

// mem2tap
wire          lsu_jtag_debug_mode;
wire [  7: 0] asid;

// tap2mem
wire          jtag_core_break;
`endif

wire [  `OPEN132_BPU_IFU_PRED_BUS_WIDTH-1: 0] bpu_ifu_pred_bus;
wire [                               33: 0] pred_cancel_bus;
wire [  `OPEN132_IFU_IDU_PRED_BUS_WIDTH-1: 0] ifu_idu_pred_bus;
wire [`OPEN132_IDU_BPU_UPDATE_BUS_WIDTH-1: 0] idu_bpu_update_bus;
wire [                               32: 0] idu_ifu_return_bus;

// wb-> fpu
wire [`OPEN132_RTU_FPU_BUS_WIDTH-1: 0] rtu_fpu_bus;

// mem->de
wire          lsu_idu_mdu_busy;

// fpu<->mem
wire [`OPEN132_LSU_FPU_BUS_WIDTH-1: 0] lsu_fpu_bus;
wire [`OPEN132_FPU_LSU_BUS_WIDTH-1: 0] fpu_lsu_bus;

// fpu<->de
wire                                        fpu_idu_exception_enable;
wire                                        idu_fpu_inst_valid;
wire                                        idu_lsu_fpu_clear_skip;
wire [  `OPEN132_IDU_FPU_INST_BUS_WIDTH-1: 0] idu_fpu_inst_bus;
wire [`OPEN132_FPU_IDU_RESULT_BUS_WIDTH-1: 0] fpu_idu_result_bus;

// main-dec read FCRs
wire [  3: 0] idu_fpu_fcsr_read_enable;
wire [ 31: 0] fpu_idu_fcsr_read_data;
`ifdef OPEN132_HAS_LJTAG

wire          trstn_sync;
wire          tck_e;
wire          tms_e;
wire          tdi_e;
wire          trstn_e;
wire          tck_e_func;

wire          tck_c;
wire          tms_c;
wire          tdi_c;
wire          trstn_c;

//============================================================//
//                    Module Implementation
//============================================================//

// synopsys sync_set_reset "hard_resetn"
// synopsys sync_set_reset "CORE_SOFT_RESETN"
// synopsys async_set_reset "jtag_trstn"
// i/d-bus windows
// Instance Boundary Alias Mapping
// x_open132_std_cell_cmux2_0

assign D0_cmux0    =  jtag_tck;
assign D1_cmux0    =  tck_c;
assign S0_cmux0    =  cjtag_sel;
assign tck_e_func  =  Z_cmux0;
// x_open132_std_cell_cmux2_1
assign D0_cmux1  =  tck_e_func;
assign D1_cmux1  =  jtag_tck;
assign S0_cmux1  =  test_mode;
assign tck_e     =  Z_cmux1;
// x_jtag_cjtag
assign clk_cjtag        =  cjtag_clk;
assign reset_in_cjtag   =  ~cjtag_trstn;
assign tckc_cjtag       =  cjtag_tckc;
assign tmsc_i_cjtag     =  cjtag_tmsc_i;
assign cjtag_tmsc_o     =  tmsc_o_cjtag;
assign cjtag_tmsc_oe    =  tmsc_oe_cjtag;
assign trstn_c          =  ljtag_trstn_cjtag;
assign tck_c            =  ljtag_tck_cjtag;
assign tms_c            =  ljtag_tms_cjtag;
assign tdi_c            =  ljtag_tdi_cjtag;
assign ljtag_tdo_cjtag  =  jtag_tdo;
// x_jtag_dm
assign clk_ljt_dm                 =  clk_ljt;
assign clk_ng_dm                  =  clk_ng;
assign reset_dm                   =  reset;
assign biu_jtag_debug_req_bus_dm  =  biu_jtag_debug_req_bus;
assign dm_dm                      =  lsu_jtag_debug_mode;
assign pc_dm                      =  ifu_jtag_pc;
assign asid_dm                    =  asid;
assign ljtag_ce                   =  ljtag_ce_dm;
assign jtag_biu_debug_resp_bus    =  jtag_biu_debug_resp_bus_dm;
assign jtag_core_break            =  jtag_core_break_dm;
assign ljtag_lock_dm              =  1'b0;
assign tck_dm                     =  tck_e;
assign trstn_dm                   =  trstn_e;
assign tms_dm                     =  tms_e;
assign tdi_dm                     =  tdi_e;
assign jtag_tdo                   =  tdo_dm;
// x_core_jtag_rst
assign testmode_jtag_rst  =  test_mode;
assign tck_jtag_rst       =  jtag_tck;
assign trstn_in_jtag_rst  =  jtag_trstn;
assign trstn_sync         =  trstn_out_jtag_rst;
`endif

assign clk_count                =  clk;
assign prid_revision_lsu_stage  =  4'b0;
assign ibus_win                 =  {ibus0_valid,  // 1
                                     ibus0_base ,  // 32
                                     ibus0_mask ,  // 32
                                     ibus1_valid,  // 1
                                     ibus1_base ,  // 32
                                     ibus1_mask ,  // 32
                                     ibus2_valid,  // 1
                                     ibus2_base ,  // 32
                                     ibus2_mask ,  // 32
                                     ibus3_valid,  // 1
                                     ibus3_base ,  // 32
                                     ibus3_mask  // 32
                                   };
assign dbus_win                 =  {dbus0_valid,  // 1
                                     dbus0_base ,  // 32
                                     dbus0_mask ,  // 32
                                     dbus1_valid,  // 1
                                     dbus1_base ,  // 32
                                     dbus1_mask ,  // 32
                                     dbus2_valid,  // 1
                                     dbus2_base ,  // 32
                                     dbus2_mask ,  // 32
                                     dbus3_valid,  // 1
                                     dbus3_base ,  // 32
                                     dbus3_mask  // 32
                                   };
always @ ( posedge clk )
begin
    nmi_r <= CORE_NMI;
end
assign core_lsu_nmi  =  nmi_r;

`ifndef OPEN132_HAS_LJTAG
assign debug_int  =  1'b0;
`endif

//------------------------------------------------------------//
//                           Reset
//------------------------------------------------------------//
`ifdef OPEN132_DATA_PATH_RESET
assign data_reset  =  reset;
`else
assign data_reset  =  1'b0;
`endif

always @ ( posedge clk )
begin
    hard_resetn_in_d1 <= hard_resetn;
    hard_resetn_in_d2 <= hard_resetn_in_d1;
    soft_resetn_in_d1 <= CORE_SOFT_RESETN;
    soft_resetn_in_d2 <= soft_resetn_in_d1;
end
assign resetn_in_d2  =  hard_resetn_in_d2&&soft_resetn_in_d2;
core_rst x_core_rst (
    .clk            (clk           ),
    .resetn_in_d2   (resetn_in_d2  ),
    .ram_init_cmplt (ram_init_cmplt),
    .reset          (reset         )
);
assign sync_hresetn  =  hard_resetn_in_d2;
assign sync_sresetn  =  soft_resetn_in_d2;
// End Reset

//------------------------------------------------------------//
//                 Top-Level Bus Connections
//------------------------------------------------------------//
//------------------------------------------------------------//
//                     lsu_core_ctrl_bus
//------------------------------------------------------------//

assign {ctrl_nowrap  ,  // 5:5
        mem_wakeup   ,  // 4:4
        ctrl_sleep_cg,  // 3:3
        ctrl_null_cg ,  // 2:2
        lsu_clk_csr_enable    ,  // 1:1
        sleeping  // 0:0
       }  =  lsu_core_ctrl_bus;
// End lsu_core_ctrl_bus
// End Top-Level Bus Connections

//------------------------------------------------------------//
//                        Clock Gating
//------------------------------------------------------------//
// sleeping clock-cg
assign clk_slp_en  =  ~(sleeping&ctrl_sleep_cg) | mem_wakeup | debug_int;
// GPR clock-cg
assign clk_gpr_en  =  !ctrl_null_cg || rtu_clk_gpr_enable;  // if sleeping, rtu_clk_gpr_enable must be 1'b0;
// cr clock-cg
assign clk_cr_en  =  reset || !ctrl_null_cg || lsu_clk_csr_enable;  // if sleeping, lsu_clk_csr_enable must be 1'b0;
`ifdef OPEN132_HAS_LJTAG
assign clk_ljt_en  =  reset || !ctrl_null_cg || ljtag_ce;
assign clk_dm_en   =  reset || !ctrl_null_cg || lsu_clk_breakpoint_enable;
`endif

assign clk_fpr_en  =  !ctrl_null_cg || fpu_is_valid;
assign clk_fpu_en  =  reset||!ctrl_null_cg || fpu_is_valid||dec_is_fpu&&!sleeping;

assign clk_ng  =  clk;
// all clock-gating
core_clk_ctrl x_core_clk_ctrl (
    .clk        (clk       ),
    .test_mode  (test_mode ),
    // sleeping
    .clk_slp_en (clk_slp_en),
    .clk_g      (clk_g     ),
    // GPR-cg
    .clk_gpr_en (clk_gpr_en),
    .clk_gpr    (clk_gpr   ),
    .clk_cr_en  (clk_cr_en ),
    .clk_cr     (clk_cr    )

`ifdef OPEN132_HAS_LJTAG
    ,
    // ljtag-mode-cg
    .clk_ljt_en (clk_ljt_en),
    .clk_ljt    (clk_ljt   ),
    // debug-mode-cg, for dcr/ihb/dhb write
    .clk_dm_en  (clk_dm_en ),
    .clk_dm     (clk_dm    )
`endif

    ,
    // FPR-cg
    .clk_fpr_en (clk_fpr_en),
    .clk_fpr    (clk_fpr   ),
    // fpu-cg
    .clk_fpu_en (clk_fpu_en),
    .clk_fpu    (clk_fpu   )
);
// End Clock Gating

//------------------------------------------------------------//
//                       LJTAG Signals
//------------------------------------------------------------//
`ifdef OPEN132_HAS_LJTAG

assign debug_int  =  jtag_core_break;  // jtag_core_break set debug_int
`endif
// End LJTAG Signals

//============================================================//
//                     Submodule Instances
//============================================================//

ifu_stage #(
    .HAS_BTB (HAS_BTB)
) x_ifu_stage (
    .clk_g                   (clk_g                  ),  // I,1
    .reset                   (reset                  ),  // I,1
    .data_reset              (data_reset             ),  // I,1
    .boot_pc                 (boot_pc                ),  // I,32

    .idu_ifu_allowin         (idu_ifu_allowin        ),  // I,1
    .rtu_ifu_redirect_bus    (rtu_ifu_redirect_bus   ),  // I,33
    .idu_ifu_branch_bus      (idu_ifu_branch_bus     ),  // I,36
    .csr_ifu_ctrl_bus        (csr_ifu_ctrl_bus       ),  // I,`OPEN132_CP2FETCH_BUS_WD
    .cache_ifu_resp_bus      (cache_ifu_resp_bus     ),  // I,`OPEN132_CACHE_IFU_RESP_BUS_WIDTH

    .ifu_cache_req_bus       (ifu_cache_req_bus      ),  // O,`OPEN132_IFU_CACHE_REQ_BUS_WIDTH
    .ifu_idu_inst_valid      (ifu_idu_inst_valid     ),  // O,1
    .ifu_idu_inst_bus        (ifu_idu_inst_bus       ),  // O,`OPEN132_IFU_IDU_INST_BUS_WIDTH
    .ifu_idu_seq_pc          (ifu_idu_seq_pc         ),  // O,32
    .ifu_jtag_pc             (ifu_jtag_pc            ),  // O,32
    .ifu_bpu_pc              (ifu_bpu_pc             )   // O,32

    ,
    .bpu_ifu_pred_bus        (bpu_ifu_pred_bus       ),  // I,`OPEN132_BPU_IFU_PRED_BUS_WIDTH
    .ifu_idu_pred_bus        (ifu_idu_pred_bus       ),  // O,`OPEN132_IFU_IDU_PRED_BUS_WIDTH
    .idu_ifu_return_bus      (idu_ifu_return_bus     )   // I,ret value from regfile[31]
`ifdef OPEN132_HAS_LJTAG
    ,
    .lsu_ifu_debug_map_valid (lsu_ifu_debug_map_valid)   // I,1, from mem
`endif
);

dsu_stage #(
    .HAS_BTB (HAS_BTB),
    .IHB_NUM (IHB_NUM)
) x_dsu_stage (
    .clk_g                    (clk_g                   ),  // I,1
    .clk_gpr                  (clk_gpr                 ),  // I,1
    .sync_hresetn             (sync_hresetn            ),  // I,1
    .reset                    (reset                   ),  // I,1
    .data_reset               (data_reset              ),  // I,1
    .debug_int                (debug_int               ),  // I,1

    .ifu_idu_inst_valid       (ifu_idu_inst_valid      ),  // I,1
    .ifu_idu_inst_bus         (ifu_idu_inst_bus        ),  // I,`OPEN132_IFU_IDU_INST_BUS_WIDTH
    .ifu_idu_seq_pc           (ifu_idu_seq_pc          ),  // I,32

    .exu_idu_allowin          (exu_idu_allowin         ),  // I,1
    .lsu_idu_allowin          (lsu_idu_allowin         ),  // I,1
    .lsu_idu_forward_valid    (lsu_idu_forward_valid   ),  // I,1
    .lsu_idu_forward_bus      (lsu_idu_forward_bus     ),  // I,`OPEN132_LSU_IDU_FORWARD_BUS_WIDTH
    .csr_idu_ctrl_bus         (csr_idu_ctrl_bus        ),  // I,`OPEN132_CSR_IDU_CTRL_BUS_WIDTH
    .rtu_idu_forward_valid    (rtu_idu_forward_valid   ),  // I,1
    .rtu_idu_forward_bus      (rtu_idu_forward_bus     ),  // I,`OPEN132_RTU_IDU_FORWARD_BUS_WIDTH
    .ex_cancel                (ex_cancel               ),  // I,1

    .idu_ifu_allowin          (idu_ifu_allowin         ),  // O,1
    .idu_ifu_branch_bus       (idu_ifu_branch_bus      ),  // O,36
    .idu_lsu_inst_valid       (idu_lsu_inst_valid      ),  // O,1
    .idu_lsu_inst_bus         (idu_lsu_inst_bus        ),  // O,`OPEN132_IDU_LSU_INST_BUS_WIDTH
    .idu_lsu_follow_pc        (idu_lsu_follow_pc       ),  // O,32
    .idu_lsu_load_attr_bus    (idu_lsu_load_attr_bus   ),  // O,34
    .idu_lsu_store_data_bus   (idu_lsu_store_data_bus  ),  // O,35
    .idu_csr_perf_bus         (idu_csr_perf_bus        ),  // O,`OPEN132_IDU_CSR_PERF_BUS_WIDTH
    .idu_exu_mdu_bus          (idu_exu_mdu_bus         ),  // O,`OPEN132_IDU_EXU_MDU_BUS_WIDTH
    .idu_lsu_app_bus          (idu_lsu_app_bus         )   // O,`OPEN132_IDU_LSU_APP_BUS_WIDTH
`ifdef OPEN132_HAS_LJTAG
    ,
    .clk_dm                   (clk_dm                  ),  // I,1
    .lsu_idu_debug_bus        (lsu_idu_debug_bus       ),  // I,14
    .jtag_idu_ihb_req_bus     (jtag_idu_ihb_req_bus    ),  // I,81
    .idu_jtag_ihb_resp_bus    (idu_jtag_ihb_resp_bus   )   // O,32
`endif

    ,
    .ifu_idu_pred_bus         (ifu_idu_pred_bus        ),  // I,`OPEN132_IFU_IDU_PRED_BUS_WIDTH
    .idu_bpu_update_bus       (idu_bpu_update_bus      ),  // O,`OPEN132_IDU_BPU_UPDATE_BUS_WIDTH
    .idu_ifu_return_bus       (idu_ifu_return_bus      )   // O,ret value from regfile[31]

    ,
    .clk_fpr                  (clk_fpr                 ),  // fpu regfiles clk
    .lsu_idu_mdu_busy         (lsu_idu_mdu_busy        ),  // from mem
    .fpu_idu_exception_enable (fpu_idu_exception_enable),
    .dec_is_fpu               (dec_is_fpu              ),  // for fpu-cg
    .idu_fpu_inst_valid       (idu_fpu_inst_valid      ),
    .idu_lsu_fpu_clear_skip   (idu_lsu_fpu_clear_skip  ),
    .idu_fpu_inst_bus         (idu_fpu_inst_bus        ),
    .fpu_idu_result_bus       (fpu_idu_result_bus      ),
    // decode read FCRs
    .idu_fpu_fcsr_read_enable (idu_fpu_fcsr_read_enable),
    .fpu_idu_fcsr_read_data   (fpu_idu_fcsr_read_data  )
`ifdef GODSON_DEBUG
    ,
    .gs_core_exe_valid        (gs_core_exe_valid       ),
    .gs_core_exe_pc           (gs_core_exe_pc          ),
    .gs_core_exe_inst         (gs_core_exe_inst        ),
    .gs_core_gr_we            (gs_core_gr_we           ),
    .gs_core_gr_waddr         (gs_core_gr_waddr        ),
    .gs_core_gr_wdata         (gs_core_gr_wdata        ),
    .gs_core_gr_raddr0        (gs_core_gr_raddr0       ),
    .gs_core_gr_rdata0        (gs_core_gr_rdata0       ),
    .gs_core_gr_raddr1        (gs_core_gr_raddr1       ),
    .gs_core_gr_rdata1        (gs_core_gr_rdata1       )
`endif
);

// OPEN132 MDU(mul&div unit)
// serial_area: serial mul and div, all operations take 34 clocks.
// serial_smart: serial mul and div, all operations takei 0~34 clocks.
// quick : half_size mul and serial div
// the area ratio is about :
// quick : smart : area = 14 :7 : 5
// the coremark perfermance(only mul) ratio is about :
// quick : smart : area= 10 : 8 : 5
// the divider perfermance is about (I guess):
// (because divider in area-mdu takes 34 clocks for any divide operation )
// quick : smart : area= 2 : 2 : 1
exu_mdu_sel #(
    .MDU_TYPE (MDU_TYPE)
) x_exu_mdu_sel (
    .clk_g              (clk_g             ),
    .reset              (reset             ),
    .data_reset         (data_reset        ),
    .rtu_exu_ctrl_bus   (rtu_exu_ctrl_bus  ),
    .lsu_exu_ctrl_bus   (lsu_exu_ctrl_bus  ),
    .idu_exu_mdu_bus    (idu_exu_mdu_bus   ),
    .rtu_exu_app_bus    (rtu_exu_app_bus   ),
    .exu_idu_allowin    (exu_idu_allowin   ),
    .exu_lsu_ctrl_bus   (exu_lsu_ctrl_bus  ),
    .exu_rtu_result_bus (exu_rtu_result_bus)
);

lsu_stage #(
    .HAS_BTB       (HAS_BTB      ),
    .MDU_TYPE      (MDU_TYPE     ),
  // ICache
    .HAS_ICC       (HAS_ICC      ),  // 0 or 1
    .ICC_SET_ASSOC (ICC_SET_ASSOC),  // 1/2/4 way set associative
    .ICC_WAYSIZE   (ICC_WAYSIZE  ),  // 1/2/4/8/16 KB Size/way
    .HAS_DCC       (HAS_DCC      ),  // 0 or 1
    .DCC_SET_ASSOC (DCC_SET_ASSOC),  // 1/2/4 way set associative
    .DCC_WAYSIZE   (DCC_WAYSIZE  ),  // 1/2/4/8/16 KB Size/way
    .PERF_CNT_NUM  (PERF_CNT_NUM ),
    .MPU_NUM       (MPU_NUM      )
) x_lsu_stage (
    .clk_g                     (clk_g                    ),  // I,1
    .clk_ng                    (clk_ng                   ),  // I,1
    .clk_count                 (clk_count                ),  // I,1
    .clk_cr                    (clk_cr                   ),  // I,1
    .sync_hresetn              (sync_hresetn             ),  // I,1
    .sync_sresetn              (sync_sresetn             ),  // I,1
    .reset                     (reset                    ),  // I,1
    .data_reset                (data_reset               ),  // I,1
    .prid_revision             (prid_revision_lsu_stage  ),  // I,4
    .cpunum                    (cpunum                   ),  // I,10
    .boot_pc                   (boot_pc                  ),  // I,32

    .core_lsu_nmi              (core_lsu_nmi             ),  // I,1
    .ext_int                   (ext_int                  ),  // I,8

    .ex_cancel                 (ex_cancel                ),  // I,1
    .rtu_lsu_cancel_pc         (rtu_lsu_cancel_pc        ),  // I,32
    .rtu_lsu_commit            (rtu_lsu_commit           ),  // I,1
    .rtu_lsu_allowin           (rtu_lsu_allowin          ),  // I,1
    .idu_lsu_inst_valid        (idu_lsu_inst_valid       ),  // I,1
    .idu_lsu_inst_bus          (idu_lsu_inst_bus         ),  // I,`OPEN132_IDU_LSU_INST_BUS_WIDTH
    .idu_lsu_fpu_clear_skip    (idu_lsu_fpu_clear_skip   ),  // I,1
    .idu_lsu_follow_pc         (idu_lsu_follow_pc        ),  // I,32
    .idu_lsu_load_attr_bus     (idu_lsu_load_attr_bus    ),  // I,34
    .idu_lsu_store_data_bus    (idu_lsu_store_data_bus   ),  // I,35

    .exu_lsu_ctrl_bus          (exu_lsu_ctrl_bus         ),  // I,1

    .cache_lsu_resp_bus        (cache_lsu_resp_bus       ),  // I,`OPEN132_CACHE_LSU_RESP_BUS_WIDTH

    .lsu_cache_req_bus         (lsu_cache_req_bus        ),  // O,`OPEN132_LSU_CACHE_REQ_BUS_WIDTH
    .csr_cache_ctrl_bus        (csr_cache_ctrl_bus       ),  // O,`OPEN132_CSR_CACHE_CTRL_BUS_WIDTH
`ifdef CONFIG_MMU
    .csr_mmu_ctrl_bus          (csr_mmu_ctrl_bus         ),  // O,`OPEN132_CSR_MMU_CTRL_BUS_WIDTH
`endif
    .lsu_idu_allowin           (lsu_idu_allowin          ),  // O,1
    .lsu_rtu_inst_valid        (lsu_rtu_inst_valid       ),  // O,1
    .lsu_rtu_inst_bus          (lsu_rtu_inst_bus         ),  // O,`OPEN132_LSU_RTU_INST_BUS_WIDTH
    .lsu_idu_forward_valid     (lsu_idu_forward_valid    ),  // O,1
    .lsu_idu_forward_bus       (lsu_idu_forward_bus      ),  // O,`OPEN132_LSU_IDU_FORWARD_BUS_WIDTH
    .lsu_exu_ctrl_bus          (lsu_exu_ctrl_bus         ),  // O,3
    .csr_ifu_ctrl_bus          (csr_ifu_ctrl_bus         ),  // O,`OPEN132_CSR_IFU_CTRL_BUS_WIDTH
    .csr_idu_ctrl_bus          (csr_idu_ctrl_bus         ),  // O,`OPEN132_CSR_IDU_CTRL_BUS_WIDTH
    .csr_bpu_ctrl_bus          (csr_bpu_ctrl_bus         ),  // O,`OPEN132_LSU_RTU_INST_BUS_WIDTH
    .lsu_core_ctrl_bus         (lsu_core_ctrl_bus        ),  // O,6
    // performance count
    .idu_csr_perf_bus          (idu_csr_perf_bus         ),  // I,`OPEN132_IDU_CSR_PERF_BUS_WIDTH
    .cache_csr_perf_bus        (cache_csr_perf_bus       ),  // I,`OPEN132_CACHE_CSR_PERF_BUS_WIDTH
    // ecc fatal
    .cache_lsu_ecc_fatal_bus   (cache_lsu_ecc_fatal_bus  ),
    .idu_lsu_app_bus           (idu_lsu_app_bus          ),  // I,`OPEN132_IDU_LSU_APP_BUS_WIDTH
    .lsu_rtu_app_bus           (lsu_rtu_app_bus          )   // O,`OPEN132_LSU_RTU_APP_BUS_WIDTH
`ifdef OPEN132_HAS_LJTAG
    ,
    .clk_dm                    (clk_dm                   ),
    .clk_slp_en                (clk_slp_en               ),  // I,1
    .asid                      (asid                     ),  // O,8, to tap
    .jtag_core_break           (jtag_core_break          ),  // I,1, from tap
    .lsu_clk_breakpoint_enable (lsu_clk_breakpoint_enable),  // O,1
    .lsu_jtag_debug_mode       (lsu_jtag_debug_mode      ),  // O,1
    .lsu_ifu_debug_map_valid   (lsu_ifu_debug_map_valid  ),  // O,1
    .lsu_idu_debug_bus         (lsu_idu_debug_bus        ),  // O,14
    .jtag_idu_ihb_req_bus      (jtag_idu_ihb_req_bus     ),  // O,81
    .idu_jtag_ihb_resp_bus     (idu_jtag_ihb_resp_bus    )   // I,32
`endif
    ,
    .fpu_lsu_bus               (fpu_lsu_bus              ),
    .lsu_fpu_bus               (lsu_fpu_bus              ),
    .lsu_idu_mdu_busy          (lsu_idu_mdu_busy         ),
    .ibus_win                  (ibus_win                 ),  // I, (1+32+32)*4
    .dbus_win                  (dbus_win                 )   // I, (1+32+32)*4
`ifdef GODSON_DEBUG
    ,
    .gs_core_csr0              (gs_core_csr0             ),
    .gs_core_csr1              (gs_core_csr1             ),
    .gs_core_csr4              (gs_core_csr4             ),
    .gs_core_csr5              (gs_core_csr5             ),
    .gs_core_csr6              (gs_core_csr6             ),
    .gs_core_csr7              (gs_core_csr7             )
`endif
);

rtu_stage x_rtu_stage (
    .clk_g                 (clk_g                ),  // I,1
    .reset                 (reset                ),  // I,1
    .data_reset            (data_reset           ),  // I,1

    .idu_lsu_follow_pc     (idu_lsu_follow_pc    ),  // I,32

    .lsu_rtu_inst_valid    (lsu_rtu_inst_valid   ),  // I,1
    .lsu_rtu_inst_bus      (lsu_rtu_inst_bus     ),  // I,`OPEN132_LSU_RTU_INST_BUS_WIDTH
    .exu_rtu_result_bus    (exu_rtu_result_bus   ),  // I,33

    .rtu_lsu_allowin       (rtu_lsu_allowin      ),  // O,1
    .rtu_exu_ctrl_bus      (rtu_exu_ctrl_bus     ),  // O,6
    .ex_cancel             (ex_cancel            ),  // O,1
    .rtu_lsu_cancel_pc     (rtu_lsu_cancel_pc    ),  // O,32
    .rtu_lsu_commit        (rtu_lsu_commit       ),  // O,1
    .rtu_ifu_redirect_bus  (rtu_ifu_redirect_bus ),  // O,33
    .rtu_idu_forward_valid (rtu_idu_forward_valid),  // O,1
    .rtu_idu_forward_bus   (rtu_idu_forward_bus  ),  // O,`OPEN132_RTU_IDU_FORWARD_BUS_WIDTH
    .rtu_clk_gpr_enable    (rtu_clk_gpr_enable   ),  // O,1
    .lsu_rtu_app_bus       (lsu_rtu_app_bus      ),  // I,`OPEN132_LSU_RTU_APP_BUS_WIDTH
    .rtu_exu_app_bus       (rtu_exu_app_bus      )   // O,`OPEN132_RTU_EXU_APP_BUS_WIDTH

`ifdef OPEN132_OUTPUT_WB_STATE
    ,
    .wb_pc                 (wb_pc                ),
    .wb_rf_dest            (wb_rf_dest           ),
    .wb_rf_wen             (wb_rf_wen            ),  // open132 regfile is word enable
    .wb_rf_value           (wb_rf_value          )
`endif
    ,
    .rtu_fpu_bus           (rtu_fpu_bus          )
);

//------------------------------------------------------------//
//                       Ahb Interface
//------------------------------------------------------------//
// End Ahb Interface

//------------------------------------------------------------//
//                       Axi Interface
//------------------------------------------------------------//
`ifdef OPEN132_INTERFACE_AXI
biu_axi_if #(
    .PERF_CNT_NUM  (PERF_CNT_NUM       ),
    .AXI_DATA_WD   (AXI_DATA_WD        ),  // 32/64/128
    .HAS_ICC       (HAS_ICC            ),
    .ICC_SET_ASSOC (ICC_SET_ASSOC      ),
    .ICC_WAYSIZE   (ICC_WAYSIZE        ),
    .ICC_ECC_BITS  (ICC_ECC_BITS_AXI_IF),
    .HAS_DCC       (HAS_DCC            ),
    .DCC_SET_ASSOC (DCC_SET_ASSOC      ),
    .DCC_WAYSIZE   (DCC_WAYSIZE        ),
    .DCC_ECC_BITS  (DCC_ECC_BITS_AXI_IF)
) x_biu_axi_if (
    .clk_g                   (clk_g                  ),  // I,1
    .clk_ng                  (clk_ng                 ),  // I,1
    .reset                   (reset                  ),  // I,1
    .data_reset              (data_reset             ),  // I,1

    .ctrl_nowrap             (ctrl_nowrap            ),  // I,1

    .ex_cancel               (ex_cancel              ),  // I,1
    .ifu_cache_req_bus       (ifu_cache_req_bus      ),  // I,`OPEN132_IFU_CACHE_REQ_BUS_WIDTH
    .lsu_cache_req_bus       (lsu_cache_req_bus      ),  // I,`OPEN132_LSU_CACHE_REQ_BUS_WIDTH
    .csr_cache_ctrl_bus      (csr_cache_ctrl_bus     ),  // I,`OPEN132_CSR_CACHE_CTRL_BUS_WIDTH
`ifdef CONFIG_MMU
    .csr_mmu_ctrl_bus        (csr_mmu_ctrl_bus       ),  // I,`OPEN132_CSR_MMU_CTRL_BUS_WIDTH
`endif

    // inst sram
    .inst_sram_en            (inst_sram_en           ),  // O,1
    .inst_sram_strb          (inst_sram_strb         ),  // O,4
    .inst_sram_wr            (inst_sram_wr           ),  // O,1
    .inst_sram_fetch         (inst_sram_fetch        ),  // O,1
    .inst_sram_addr          (inst_sram_addr         ),  // O,32
    .inst_sram_wdata         (inst_sram_wdata        ),  // O,32
    .inst_sram_rdata         (inst_sram_rdata        ),  // I,32

    // data sram
    .data_sram_en            (data_sram_en           ),  // O,1
    .data_sram_strb          (data_sram_strb         ),  // O,4
    .data_sram_wr            (data_sram_wr           ),  // O,1
    .data_sram_fetch         (data_sram_fetch        ),  // O,1
    .data_sram_addr          (data_sram_addr         ),  // O,32
    .data_sram_wdata         (data_sram_wdata        ),  // O,32
    .data_sram_rdata         (data_sram_rdata        ),  // I,32

`ifdef OPEN132_AXI_HANDSHAKE
    .inst_sram_ack           (inst_sram_ack          ),  // I, 1
    .inst_sram_rrdy          (inst_sram_rrdy         ),  // I, 1
    .inst_sram_resp          (inst_sram_resp         ),  // I, 1
    .data_sram_ack           (data_sram_ack          ),  // I, 1
    .data_sram_rrdy          (data_sram_rrdy         ),  // I, 1
    .data_sram_resp          (data_sram_resp         ),  // I, 1
`endif
    // sys axi
    // ar
    .arready                 (arready                ),  // I,1
    .arid                    (arid                   ),  // O,4
    .araddr                  (araddr                 ),  // O,32
    .arlen                   (arlen                  ),  // O,4
    .arsize                  (arsize                 ),  // O,3
    .arburst                 (arburst                ),  // O,2
    .arlock                  (arlock                 ),  // O,2
    .arcache                 (arcache                ),  // O,4
    .arprot                  (arprot                 ),  // O,3
    .arvalid                 (arvalid                ),  // O,1
    // r
    .rid                     (rid                    ),  // I,4
    .rdata                   (rdata                  ),  // I,AXI_DATA_WD
    .rresp                   (rresp                  ),  // I,2
    .rlast                   (rlast                  ),  // I,1
    .rvalid                  (rvalid                 ),  // I,1
    .rready                  (rready                 ),  // O,1
    // aw
    .awready                 (awready                ),  // I,1
    .awid                    (awid                   ),  // O,4
    .awaddr                  (awaddr                 ),  // O,32
    .awlen                   (awlen                  ),  // O,4
    .awsize                  (awsize                 ),  // O,3
    .awburst                 (awburst                ),  // O,2
    .awlock                  (awlock                 ),  // O,2
    .awcache                 (awcache                ),  // O,4
    .awprot                  (awprot                 ),  // O,3
    .awvalid                 (awvalid                ),  // O,1
    // w
    .wready                  (wready                 ),  // I,1
    .wid                     (wid                    ),  // O,4
    .wdata                   (wdata                  ),  // O,AXI_DATA_WD
    .wstrb                   (wstrb                  ),  // O,AXI_DATA_WD/8
    .wlast                   (wlast                  ),  // O,1
    .wvalid                  (wvalid                 ),  // O,1
    // b
    .bid                     (bid                    ),  // I,4
    .bresp                   (bresp                  ),  // I,2
    .bvalid                  (bvalid                 ),  // I,1
    .bready                  (bready                 ),  // O,1

    .cache_ifu_resp_bus      (cache_ifu_resp_bus     ),  // O,`OPEN132_CACHE_IFU_RESP_BUS_WIDTH
    .cache_lsu_resp_bus      (cache_lsu_resp_bus     ),  // O,`OPEN132_CACHE_LSU_RESP_BUS_WIDTH
    // performance count
    .cache_csr_perf_bus      (cache_csr_perf_bus     ),  // O,`OPEN132_CACHE_CSR_PERF_BUS_WIDTH

    .resetn_in_d2            (resetn_in_d2           ),
    .ram_init_cmplt          (ram_init_cmplt         ),
    // ecc fatal
    .cache_lsu_ecc_fatal_bus (cache_lsu_ecc_fatal_bus),

    // dcache ram
    .dcc_ram_tagv_req_bus    (dcc_ram_tagv_req_bus   ),
    .dcc_ram_data_req_bus    (dcc_ram_data_req_bus   ),
    .dcc_ram_lrud_req_bus    (dcc_ram_lrud_req_bus   ),  // write by bit
    .dcc_ram_tagv_resp_bus   (dcc_ram_tagv_resp_bus  ),
    .dcc_ram_data_resp_bus   (dcc_ram_data_resp_bus  ),
    .dcc_ram_lrud_resp_bus   (dcc_ram_lrud_resp_bus  ),
    // icache ram
    .icc_ram_tagv_req_bus    (icc_ram_tagv_req_bus   ),
    .icc_ram_data_req_bus    (icc_ram_data_req_bus   ),
    .icc_ram_lrud_req_bus    (icc_ram_lrud_req_bus   ),  // write by bit
    .icc_ram_tagv_resp_bus   (icc_ram_tagv_resp_bus  ),
    .icc_ram_data_resp_bus   (icc_ram_data_resp_bus  ),
    .icc_ram_lrud_resp_bus   (icc_ram_lrud_resp_bus  )

`ifdef OPEN132_HAS_LJTAG
    ,
    .biu_jtag_debug_req_bus  (biu_jtag_debug_req_bus ),  // O,56, to tap
    .jtag_biu_debug_resp_bus (jtag_biu_debug_resp_bus)   // I,33, from tap
`endif

    ,
    .ibus_win                (ibus_win               ),  // I, (1+32+32)*4
    .dbus_win                (dbus_win               )   // I, (1+32+32)*4
);
`endif
// End Axi Interface

//------------------------------------------------------------//
//                           LJTAG
//------------------------------------------------------------//
`ifdef OPEN132_HAS_LJTAG

assign trstn_e  =  test_mode ? trstn_sync : (cjtag_sel ? trstn_c : trstn_sync);
assign tms_e    =  cjtag_sel ? tms_c : jtag_tms;
assign tdi_e    =  cjtag_sel ? tdi_c : jtag_tdi;
openla132_std_cell_cmux2 x_open132_std_cell_cmux2_0 (
    .D0 (D0_cmux0),
    .D1 (D1_cmux0),
    .S0 (S0_cmux0),
    .Z  (Z_cmux0 )
);
openla132_std_cell_cmux2 x_open132_std_cell_cmux2_1 (
    .D0 (D0_cmux1),
    .D1 (D1_cmux1),
    .S0 (S0_cmux1),
    .Z  (Z_cmux1 )
);

ljtag_cjtag x_jtag_cjtag (
    .clk         (clk_cjtag        ),
    .reset_in    (reset_in_cjtag   ),
    .tckc        (tckc_cjtag       ),
    .tmsc_i      (tmsc_i_cjtag     ),
    .tmsc_o      (tmsc_o_cjtag     ),
    .tmsc_oe     (tmsc_oe_cjtag    ),
    .ljtag_trstn (ljtag_trstn_cjtag),
    .ljtag_tck   (ljtag_tck_cjtag  ),
    .ljtag_tms   (ljtag_tms_cjtag  ),
    .ljtag_tdi   (ljtag_tdi_cjtag  ),
    .ljtag_tdo   (ljtag_tdo_cjtag  )
);

ljtag_dm x_jtag_dm (
    .clk_ljt                 (clk_ljt_dm                ),
    .clk_ng                  (clk_ng_dm                 ),
    .reset                   (reset_dm                  ),
    .biu_jtag_debug_req_bus  (biu_jtag_debug_req_bus_dm ),
    .dm                      (dm_dm                     ),  // debug mode
    .pc                      (pc_dm                     ),
    .asid                    (asid_dm                   ),
    .ljtag_ce                (ljtag_ce_dm               ),
    .jtag_biu_debug_resp_bus (jtag_biu_debug_resp_bus_dm),
    .jtag_core_break         (jtag_core_break_dm        ),
    .ljtag_lock              (ljtag_lock_dm             ),
    .tck                     (tck_dm                    ),
    .trstn                   (trstn_dm                  ),
    .tms                     (tms_dm                    ),
    .tdi                     (tdi_dm                    ),
    .tdo                     (tdo_dm                    )
);

ljtag_core_rst x_ljtag_core_rst (
    .testmode  (testmode_jtag_rst ),
    .tck       (tck_jtag_rst      ),
    .trstn_in  (trstn_in_jtag_rst ),
    .trstn_out (trstn_out_jtag_rst)
);
`endif
// End LJTAG

//------------------------------------------------------------//
//                            BTB
//------------------------------------------------------------//
generate
    if (HAS_BTB) begin: gen_has_btb
        ifu_bpu x_ifu_bpu (
            .clk_g              (clk_g             ),
            .reset              (reset             ),
            .data_reset         (data_reset        ),
            .ifu_bpu_pc         (ifu_bpu_pc        ),
            .idu_bpu_update_bus (idu_bpu_update_bus),
            .csr_bpu_ctrl_bus   (csr_bpu_ctrl_bus  ),
            .bpu_ifu_pred_bus   (bpu_ifu_pred_bus  )
        );
    end
    else begin: gen_no_btb
        assign bpu_ifu_pred_bus =
            {`OPEN132_BPU_IFU_PRED_BUS_WIDTH{1'b0}};
    end
endgenerate
// End BTB
//------------------------------------------------------------//
//                            FPU
//------------------------------------------------------------//
// no_fpu
assign fpu_lsu_bus               =  {`OPEN132_FPU_LSU_BUS_WIDTH{1'b0}};
assign fpu_idu_result_bus        =  {`OPEN132_FPU_IDU_RESULT_BUS_WIDTH{1'b0}};
assign fpu_idu_exception_enable  =  1'b0;
assign fpu_idu_fcsr_read_data    =  32'd0;
assign fpu_is_valid              =  1'b0;
// End FPU
endmodule  // la132_core

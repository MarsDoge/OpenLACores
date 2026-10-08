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

`timescale 1ns / 1ps
`default_nettype none

module xlnx_cpu_axi_bd_adapt (
    input  wire           cpu_clk,
    input  wire           cpu_rst_b,
    input  wire [  7: 0]  bd_cpu_ext_interrupt,
    input  wire           cpu_bd_axi_awready,
    input  wire           cpu_bd_axi_wready,
    input  wire [  3: 0]  cpu_bd_axi_bid,
    input  wire [  1: 0]  cpu_bd_axi_bresp,
    input  wire           cpu_bd_axi_bvalid,
    input  wire           cpu_bd_axi_arready,
    input  wire [  3: 0]  cpu_bd_axi_rid,
    input  wire [ 31: 0]  cpu_bd_axi_rdata,
    input  wire [  1: 0]  cpu_bd_axi_rresp,
    input  wire           cpu_bd_axi_rlast,
    input  wire           cpu_bd_axi_rvalid,
    output wire [  3: 0]  cpu_bd_axi_awid,
    output wire [ 31: 0]  cpu_bd_axi_awaddr,
    output wire [  7: 0]  cpu_bd_axi_awlen,
    output wire [  2: 0]  cpu_bd_axi_awsize,
    output wire [  1: 0]  cpu_bd_axi_awburst,
    output wire           cpu_bd_axi_awlock,
    output wire [  3: 0]  cpu_bd_axi_awcache,
    output wire [  2: 0]  cpu_bd_axi_awprot,
    output wire [  3: 0]  cpu_bd_axi_awqos,
    output wire           cpu_bd_axi_awvalid,
    output wire [ 31: 0]  cpu_bd_axi_wdata,
    output wire [  3: 0]  cpu_bd_axi_wstrb,
    output wire           cpu_bd_axi_wlast,
    output wire           cpu_bd_axi_wvalid,
    output wire           cpu_bd_axi_bready,
    output wire [  3: 0]  cpu_bd_axi_arid,
    output wire [ 31: 0]  cpu_bd_axi_araddr,
    output wire [  7: 0]  cpu_bd_axi_arlen,
    output wire [  2: 0]  cpu_bd_axi_arsize,
    output wire [  1: 0]  cpu_bd_axi_arburst,
    output wire           cpu_bd_axi_arlock,
    output wire [  3: 0]  cpu_bd_axi_arcache,
    output wire [  2: 0]  cpu_bd_axi_arprot,
    output wire [  3: 0]  cpu_bd_axi_arqos,
    output wire           cpu_bd_axi_arvalid,
    output wire           cpu_bd_axi_rready
);

localparam [31:0] CORE_RESET_BASE = 32'h1c00_0000;

//============================================================//
//                     Wire Declarations
//============================================================//

wire          clk;
wire          hard_resetn;
wire          sleeping;
wire [  7: 0] ext_int;
wire [  9: 0] cpunum;
wire [ 31: 0] boot_pc;

wire [  3: 0] arid;
wire [ 31: 0] araddr;
wire [  3: 0] arlen;
wire [  2: 0] arsize;
wire [  1: 0] arburst;
wire [  1: 0] arlock;
wire [  3: 0] arcache;
wire [  2: 0] arprot;
wire          arvalid;
wire          arready;
wire [  3: 0] rid;
wire [ 31: 0] rdata;
wire [  1: 0] rresp;
wire          rlast;
wire          rvalid;
wire          rready;

wire [  3: 0] awid;
wire [ 31: 0] awaddr;
wire [  3: 0] awlen;
wire [  2: 0] awsize;
wire [  1: 0] awburst;
wire [  1: 0] awlock;
wire [  3: 0] awcache;
wire [  2: 0] awprot;
wire          awvalid;
wire          awready;
wire [  3: 0] wid;
wire [ 31: 0] wdata;
wire [  3: 0] wstrb;
wire          wlast;
wire          wvalid;
wire          wready;
wire [  3: 0] bid;
wire [  1: 0] bresp;
wire          bvalid;
wire          bready;

wire          inst_sram_en;
wire [  3: 0] inst_sram_strb;
wire          inst_sram_wr;
wire          inst_sram_fetch;
wire [ 31: 0] inst_sram_addr;
wire [ 31: 0] inst_sram_wdata;
wire [ 31: 0] inst_sram_rdata;
wire          data_sram_en;
wire [  3: 0] data_sram_strb;
wire          data_sram_wr;
wire          data_sram_fetch;
wire [ 31: 0] data_sram_addr;
wire [ 31: 0] data_sram_wdata;
wire [ 31: 0] data_sram_rdata;
wire          inst_sram_ack;
wire          inst_sram_rrdy;
wire          inst_sram_resp;
wire          data_sram_ack;
wire          data_sram_rrdy;
wire          data_sram_resp;

wire          ibus0_valid;
wire [ 31: 0] ibus0_base;
wire [ 31: 0] ibus0_mask;
wire          ibus1_valid;
wire [ 31: 0] ibus1_base;
wire [ 31: 0] ibus1_mask;
wire          ibus2_valid;
wire [ 31: 0] ibus2_base;
wire [ 31: 0] ibus2_mask;
wire          ibus3_valid;
wire [ 31: 0] ibus3_base;
wire [ 31: 0] ibus3_mask;
wire          dbus0_valid;
wire [ 31: 0] dbus0_base;
wire [ 31: 0] dbus0_mask;
wire          dbus1_valid;
wire [ 31: 0] dbus1_base;
wire [ 31: 0] dbus1_mask;
wire          dbus2_valid;
wire [ 31: 0] dbus2_base;
wire [ 31: 0] dbus2_mask;
wire          dbus3_valid;
wire [ 31: 0] dbus3_base;
wire [ 31: 0] dbus3_mask;

wire          cjtag_sel;
wire          cjtag_trstn;
wire          cjtag_clk;
wire          cjtag_tckc;
wire          cjtag_tmsc_i;
wire          cjtag_tmsc_o;
wire          cjtag_tmsc_oe;
wire          jtag_trstn;
wire          jtag_tck;
wire          jtag_tms;
wire          jtag_tdi;
wire          jtag_tdo;
wire          test_mode;
wire          unused_open132;

`ifdef GODSON_DEBUG
wire          gs_core_exe_valid;
wire [ 31: 0] gs_core_exe_pc;
wire [ 31: 0] gs_core_exe_inst;
wire          gs_core_gr_we;
wire [  4: 0] gs_core_gr_waddr;
wire [ 31: 0] gs_core_gr_wdata;
wire [  4: 0] gs_core_gr_raddr0;
wire [ 31: 0] gs_core_gr_rdata0;
wire [  4: 0] gs_core_gr_raddr1;
wire [ 31: 0] gs_core_gr_rdata1;
wire [ 31: 0] gs_core_csr0;
wire [ 31: 0] gs_core_csr1;
wire [ 31: 0] gs_core_csr4;
wire [ 31: 0] gs_core_csr5;
wire [ 31: 0] gs_core_csr6;
wire [ 31: 0] gs_core_csr7;
`endif

`ifdef FPGA_LA132_BOOT_ILA
(* mark_debug = "true", keep = "true" *) wire          la132_ila_cpu_reset;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_commit_valid;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_commit_pc;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_commit_inst;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_gr_we;
(* mark_debug = "true", keep = "true" *) wire [  4: 0] la132_ila_gr_waddr;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_gr_wdata;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_csr0;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_csr1;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_csr4;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_csr5;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_csr6;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_csr7;

(* mark_debug = "true", keep = "true" *) wire [  3: 0] la132_ila_axi_arid;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_axi_araddr;
(* mark_debug = "true", keep = "true" *) wire [  3: 0] la132_ila_axi_arlen;
(* mark_debug = "true", keep = "true" *) wire [  2: 0] la132_ila_axi_arsize;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_arvalid;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_arready;
(* mark_debug = "true", keep = "true" *) wire [  3: 0] la132_ila_axi_rid;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_axi_rdata;
(* mark_debug = "true", keep = "true" *) wire [  1: 0] la132_ila_axi_rresp;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_rlast;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_rvalid;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_rready;
(* mark_debug = "true", keep = "true" *) wire [  3: 0] la132_ila_axi_awid;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_axi_awaddr;
(* mark_debug = "true", keep = "true" *) wire [  3: 0] la132_ila_axi_awlen;
(* mark_debug = "true", keep = "true" *) wire [  2: 0] la132_ila_axi_awsize;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_awvalid;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_awready;
(* mark_debug = "true", keep = "true" *) wire [ 31: 0] la132_ila_axi_wdata;
(* mark_debug = "true", keep = "true" *) wire [  3: 0] la132_ila_axi_wstrb;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_wlast;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_wvalid;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_wready;
(* mark_debug = "true", keep = "true" *) wire [  3: 0] la132_ila_axi_bid;
(* mark_debug = "true", keep = "true" *) wire [  1: 0] la132_ila_axi_bresp;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_bvalid;
(* mark_debug = "true", keep = "true" *) wire          la132_ila_axi_bready;
`endif

//============================================================//
//                    Structural Integration
//============================================================//

openla132_ip_top x_open132_ip_top (
    .clk              (clk             ),
    .hard_resetn      (hard_resetn     ),
    .sleeping         (sleeping        ),
    .ext_int          (ext_int         ),
    .cpunum           (cpunum          ),
    .boot_pc          (boot_pc         ),
    .arid             (arid            ),
    .araddr           (araddr          ),
    .arlen            (arlen           ),
    .arsize           (arsize          ),
    .arburst          (arburst         ),
    .arlock           (arlock          ),
    .arcache          (arcache         ),
    .arprot           (arprot          ),
    .arvalid          (arvalid         ),
    .arready          (arready         ),
    .rid              (rid             ),
    .rdata            (rdata           ),
    .rresp            (rresp           ),
    .rlast            (rlast           ),
    .rvalid           (rvalid          ),
    .rready           (rready          ),
    .awid             (awid            ),
    .awaddr           (awaddr          ),
    .awlen            (awlen           ),
    .awsize           (awsize          ),
    .awburst          (awburst         ),
    .awlock           (awlock          ),
    .awcache          (awcache         ),
    .awprot           (awprot          ),
    .awvalid          (awvalid         ),
    .awready          (awready         ),
    .wid              (wid             ),
    .wdata            (wdata           ),
    .wstrb            (wstrb           ),
    .wlast            (wlast           ),
    .wvalid           (wvalid          ),
    .wready           (wready          ),
    .bid              (bid             ),
    .bresp            (bresp           ),
    .bvalid           (bvalid          ),
    .bready           (bready          ),
    .inst_sram_en     (inst_sram_en    ),
    .inst_sram_strb   (inst_sram_strb  ),
    .inst_sram_wr     (inst_sram_wr    ),
    .inst_sram_fetch  (inst_sram_fetch ),
    .inst_sram_addr   (inst_sram_addr  ),
    .inst_sram_wdata  (inst_sram_wdata ),
    .inst_sram_rdata  (inst_sram_rdata ),
    .data_sram_en     (data_sram_en    ),
    .data_sram_strb   (data_sram_strb  ),
    .data_sram_wr     (data_sram_wr    ),
    .data_sram_fetch  (data_sram_fetch ),
    .data_sram_addr   (data_sram_addr  ),
    .data_sram_wdata  (data_sram_wdata ),
    .data_sram_rdata  (data_sram_rdata ),
    .inst_sram_ack    (inst_sram_ack   ),
    .inst_sram_rrdy   (inst_sram_rrdy  ),
    .inst_sram_resp   (inst_sram_resp  ),
    .data_sram_ack    (data_sram_ack   ),
    .data_sram_rrdy   (data_sram_rrdy  ),
    .data_sram_resp   (data_sram_resp  ),
    .ibus0_valid      (ibus0_valid     ),
    .ibus0_base       (ibus0_base      ),
    .ibus0_mask       (ibus0_mask      ),
    .ibus1_valid      (ibus1_valid     ),
    .ibus1_base       (ibus1_base      ),
    .ibus1_mask       (ibus1_mask      ),
    .ibus2_valid      (ibus2_valid     ),
    .ibus2_base       (ibus2_base      ),
    .ibus2_mask       (ibus2_mask      ),
    .ibus3_valid      (ibus3_valid     ),
    .ibus3_base       (ibus3_base      ),
    .ibus3_mask       (ibus3_mask      ),
    .dbus0_valid      (dbus0_valid     ),
    .dbus0_base       (dbus0_base      ),
    .dbus0_mask       (dbus0_mask      ),
    .dbus1_valid      (dbus1_valid     ),
    .dbus1_base       (dbus1_base      ),
    .dbus1_mask       (dbus1_mask      ),
    .dbus2_valid      (dbus2_valid     ),
    .dbus2_base       (dbus2_base      ),
    .dbus2_mask       (dbus2_mask      ),
    .dbus3_valid      (dbus3_valid     ),
    .dbus3_base       (dbus3_base      ),
    .dbus3_mask       (dbus3_mask      ),
    .cjtag_sel        (cjtag_sel       ),
    .cjtag_trstn      (cjtag_trstn     ),
    .cjtag_clk        (cjtag_clk       ),
    .cjtag_tckc       (cjtag_tckc      ),
    .cjtag_tmsc_i     (cjtag_tmsc_i    ),
    .cjtag_tmsc_o     (cjtag_tmsc_o    ),
    .cjtag_tmsc_oe    (cjtag_tmsc_oe   ),
    .jtag_trstn       (jtag_trstn      ),
    .jtag_tck         (jtag_tck        ),
    .jtag_tms         (jtag_tms        ),
    .jtag_tdi         (jtag_tdi        ),
    .jtag_tdo         (jtag_tdo        ),
    .test_mode        (test_mode       )
`ifdef GODSON_DEBUG
    ,
    .gs_core_exe_valid(gs_core_exe_valid),
    .gs_core_exe_pc   (gs_core_exe_pc   ),
    .gs_core_exe_inst (gs_core_exe_inst ),
    .gs_core_gr_we    (gs_core_gr_we    ),
    .gs_core_gr_waddr (gs_core_gr_waddr ),
    .gs_core_gr_wdata (gs_core_gr_wdata ),
    .gs_core_gr_raddr0(gs_core_gr_raddr0),
    .gs_core_gr_rdata0(gs_core_gr_rdata0),
    .gs_core_gr_raddr1(gs_core_gr_raddr1),
    .gs_core_gr_rdata1(gs_core_gr_rdata1),
    .gs_core_csr0     (gs_core_csr0     ),
    .gs_core_csr1     (gs_core_csr1     ),
    .gs_core_csr4     (gs_core_csr4     ),
    .gs_core_csr5     (gs_core_csr5     ),
    .gs_core_csr6     (gs_core_csr6     ),
    .gs_core_csr7     (gs_core_csr7     )
`endif
);

//------------------------------------------------------------//
//                    Infrastructure Mapping
//------------------------------------------------------------//

assign clk         =  cpu_clk;
assign hard_resetn =  cpu_rst_b;
assign ext_int     =  bd_cpu_ext_interrupt;
assign cpunum      =  10'd0;
assign boot_pc     =  CORE_RESET_BASE;

`ifdef FPGA_LA132_BOOT_ILA
assign la132_ila_cpu_reset    =  !hard_resetn;
assign la132_ila_commit_valid =  gs_core_exe_valid;
assign la132_ila_commit_pc    =  gs_core_exe_pc;
assign la132_ila_commit_inst  =  gs_core_exe_inst;
assign la132_ila_gr_we        =  gs_core_gr_we;
assign la132_ila_gr_waddr     =  gs_core_gr_waddr;
assign la132_ila_gr_wdata     =  gs_core_gr_wdata;
assign la132_ila_csr0         =  gs_core_csr0;
assign la132_ila_csr1         =  gs_core_csr1;
assign la132_ila_csr4         =  gs_core_csr4;
assign la132_ila_csr5         =  gs_core_csr5;
assign la132_ila_csr6         =  gs_core_csr6;
assign la132_ila_csr7         =  gs_core_csr7;

assign la132_ila_axi_arid     =  arid;
assign la132_ila_axi_araddr   =  araddr;
assign la132_ila_axi_arlen    =  arlen;
assign la132_ila_axi_arsize   =  arsize;
assign la132_ila_axi_arvalid  =  arvalid;
assign la132_ila_axi_arready  =  arready;
assign la132_ila_axi_rid      =  rid;
assign la132_ila_axi_rdata    =  rdata;
assign la132_ila_axi_rresp    =  rresp;
assign la132_ila_axi_rlast    =  rlast;
assign la132_ila_axi_rvalid   =  rvalid;
assign la132_ila_axi_rready   =  rready;
assign la132_ila_axi_awid     =  awid;
assign la132_ila_axi_awaddr   =  awaddr;
assign la132_ila_axi_awlen    =  awlen;
assign la132_ila_axi_awsize   =  awsize;
assign la132_ila_axi_awvalid  =  awvalid;
assign la132_ila_axi_awready  =  awready;
assign la132_ila_axi_wdata    =  wdata;
assign la132_ila_axi_wstrb    =  wstrb;
assign la132_ila_axi_wlast    =  wlast;
assign la132_ila_axi_wvalid   =  wvalid;
assign la132_ila_axi_wready   =  wready;
assign la132_ila_axi_bid      =  bid;
assign la132_ila_axi_bresp    =  bresp;
assign la132_ila_axi_bvalid   =  bvalid;
assign la132_ila_axi_bready   =  bready;
`endif

//------------------------------------------------------------//
//                    CPU-to-BD AXI Requests
//------------------------------------------------------------//

assign cpu_bd_axi_awid    =  awid;
assign cpu_bd_axi_awaddr  =  awaddr;
assign cpu_bd_axi_awlen   =  {4'd0, awlen};
assign cpu_bd_axi_awsize  =  awsize;
assign cpu_bd_axi_awburst =  awburst;
assign cpu_bd_axi_awlock  =  awlock[0];
assign cpu_bd_axi_awcache =  awcache;
assign cpu_bd_axi_awprot  =  awprot;
assign cpu_bd_axi_awqos   =  4'd0;
assign cpu_bd_axi_awvalid =  awvalid;
assign cpu_bd_axi_wdata   =  wdata;
assign cpu_bd_axi_wstrb   =  wstrb;
assign cpu_bd_axi_wlast   =  wlast;
assign cpu_bd_axi_wvalid  =  wvalid;
assign cpu_bd_axi_bready  =  bready;
assign cpu_bd_axi_arid    =  arid;
assign cpu_bd_axi_araddr  =  araddr;
assign cpu_bd_axi_arlen   =  {4'd0, arlen};
assign cpu_bd_axi_arsize  =  arsize;
assign cpu_bd_axi_arburst =  arburst;
assign cpu_bd_axi_arlock  =  arlock[0];
assign cpu_bd_axi_arcache =  arcache;
assign cpu_bd_axi_arprot  =  arprot;
assign cpu_bd_axi_arqos   =  4'd0;
assign cpu_bd_axi_arvalid =  arvalid;
assign cpu_bd_axi_rready  =  rready;

//------------------------------------------------------------//
//                    BD-to-CPU AXI Responses
//------------------------------------------------------------//

assign awready =  cpu_bd_axi_awready;
assign wready  =  cpu_bd_axi_wready;
assign bid     =  cpu_bd_axi_bid;
assign bresp   =  cpu_bd_axi_bresp;
assign bvalid  =  cpu_bd_axi_bvalid;
assign arready =  cpu_bd_axi_arready;
assign rid     =  cpu_bd_axi_rid;
assign rdata   =  cpu_bd_axi_rdata;
assign rresp   =  cpu_bd_axi_rresp;
assign rlast   =  cpu_bd_axi_rlast;
assign rvalid  =  cpu_bd_axi_rvalid;

//------------------------------------------------------------//
//                         CPU Tie-Offs
//------------------------------------------------------------//

assign inst_sram_rdata =  32'd0;
assign data_sram_rdata =  32'd0;
assign inst_sram_ack   =  1'b0;
assign inst_sram_rrdy  =  1'b0;
assign inst_sram_resp  =  1'b0;
assign data_sram_ack   =  1'b0;
assign data_sram_rrdy  =  1'b0;
assign data_sram_resp  =  1'b0;

assign ibus0_valid =  1'b0;
assign ibus0_base  =  32'd0;
assign ibus0_mask  =  32'd0;
assign ibus1_valid =  1'b0;
assign ibus1_base  =  32'd0;
assign ibus1_mask  =  32'd0;
assign ibus2_valid =  1'b0;
assign ibus2_base  =  32'd0;
assign ibus2_mask  =  32'd0;
assign ibus3_valid =  1'b0;
assign ibus3_base  =  32'd0;
assign ibus3_mask  =  32'd0;
assign dbus0_valid =  1'b0;
assign dbus0_base  =  32'd0;
assign dbus0_mask  =  32'd0;
assign dbus1_valid =  1'b0;
assign dbus1_base  =  32'd0;
assign dbus1_mask  =  32'd0;
assign dbus2_valid =  1'b0;
assign dbus2_base  =  32'd0;
assign dbus2_mask  =  32'd0;
assign dbus3_valid =  1'b0;
assign dbus3_base  =  32'd0;
assign dbus3_mask  =  32'd0;

assign cjtag_sel    =  1'b0;
assign cjtag_trstn  =  cpu_rst_b;
assign cjtag_clk    =  cpu_clk;
assign cjtag_tckc   =  1'b0;
assign cjtag_tmsc_i =  1'b0;
assign jtag_trstn   =  cpu_rst_b;
assign jtag_tck     =  1'b0;
assign jtag_tms     =  1'b0;
assign jtag_tdi     =  1'b0;
assign test_mode    =  1'b0;

assign unused_open132 =  sleeping || (|wid)
                         || inst_sram_en || (|inst_sram_strb)
                         || inst_sram_wr || inst_sram_fetch
                         || (|inst_sram_addr) || (|inst_sram_wdata)
                         || data_sram_en || (|data_sram_strb)
                         || data_sram_wr || data_sram_fetch
                         || (|data_sram_addr) || (|data_sram_wdata)
                         || cjtag_tmsc_o || cjtag_tmsc_oe || jtag_tdo;

endmodule

`default_nettype wire

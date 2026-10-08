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

module openla132_ip_top (
    // ip global clock and reset except debug logic
    input  wire           clk,
    input  wire           hard_resetn,

    // miscellaneous signals
    output wire           sleeping,  // safe to cut clock or power off in sleeping mode

    // interrupt inputs
    input  wire [  7: 0]  ext_int,

    // cpu core number
    input  wire [  9: 0]  cpunum,
    input  wire [ 31: 0]  boot_pc,

    // sys axi
    // ar
    output wire [  3: 0]  arid,
    output wire [ 31: 0]  araddr,
    output wire [  3: 0]  arlen,
    output wire [  2: 0]  arsize,
    output wire [  1: 0]  arburst,
    output wire [  1: 0]  arlock,
    output wire [  3: 0]  arcache,
    output wire [  2: 0]  arprot,
    output wire           arvalid,
    input  wire           arready,
    // r
    input  wire [  3: 0]  rid,
    input  wire [ 31: 0]  rdata,
    input  wire [  1: 0]  rresp,
    input  wire           rlast,
    input  wire           rvalid,
    output wire           rready,
    // aw
    output wire [  3: 0]  awid,
    output wire [ 31: 0]  awaddr,
    output wire [  3: 0]  awlen,
    output wire [  2: 0]  awsize,
    output wire [  1: 0]  awburst,
    output wire [  1: 0]  awlock,
    output wire [  3: 0]  awcache,
    output wire [  2: 0]  awprot,
    output wire           awvalid,
    input  wire           awready,
    // w
    output wire [  3: 0]  wid,
    output wire [ 31: 0]  wdata,
    output wire [  3: 0]  wstrb,
    output wire           wlast,
    output wire           wvalid,
    input  wire           wready,
    // b
    input  wire [  3: 0]  bid,
    input  wire [  1: 0]  bresp,
    input  wire           bvalid,
    output wire           bready,
    // inst sram
    output wire           inst_sram_en,
    output wire [  3: 0]  inst_sram_strb,
    output wire           inst_sram_wr,
    output wire           inst_sram_fetch,
    output wire [ 31: 0]  inst_sram_addr,
    output wire [ 31: 0]  inst_sram_wdata,
    input  wire [ 31: 0]  inst_sram_rdata,
    // data sram
    output wire           data_sram_en,
    output wire [  3: 0]  data_sram_strb,
    output wire           data_sram_wr,
    output wire           data_sram_fetch,
    output wire [ 31: 0]  data_sram_addr,
    output wire [ 31: 0]  data_sram_wdata,
    input  wire [ 31: 0]  data_sram_rdata,

    input  wire           inst_sram_ack,
    input  wire           inst_sram_rrdy,
    input  wire           inst_sram_resp,
    input  wire           data_sram_ack,
    input  wire           data_sram_rrdy,
    input  wire           data_sram_resp,

    // i/d bus configuration
    input  wire           ibus0_valid,
    input  wire [ 31: 0]  ibus0_base,
    input  wire [ 31: 0]  ibus0_mask,
    input  wire           ibus1_valid,
    input  wire [ 31: 0]  ibus1_base,
    input  wire [ 31: 0]  ibus1_mask,
    input  wire           ibus2_valid,
    input  wire [ 31: 0]  ibus2_base,
    input  wire [ 31: 0]  ibus2_mask,
    input  wire           ibus3_valid,
    input  wire [ 31: 0]  ibus3_base,
    input  wire [ 31: 0]  ibus3_mask,
    input  wire           dbus0_valid,
    input  wire [ 31: 0]  dbus0_base,
    input  wire [ 31: 0]  dbus0_mask,
    input  wire           dbus1_valid,
    input  wire [ 31: 0]  dbus1_base,
    input  wire [ 31: 0]  dbus1_mask,
    input  wire           dbus2_valid,
    input  wire [ 31: 0]  dbus2_base,
    input  wire [ 31: 0]  dbus2_mask,
    input  wire           dbus3_valid,
    input  wire [ 31: 0]  dbus3_base,
    input  wire [ 31: 0]  dbus3_mask,

    input  wire           cjtag_sel,

    input  wire           cjtag_trstn,
    input  wire           cjtag_clk,
    input  wire           cjtag_tckc,
    input  wire           cjtag_tmsc_i,
    output wire           cjtag_tmsc_o,
    output wire           cjtag_tmsc_oe,

    input  wire           jtag_trstn,
    input  wire           jtag_tck,
    input  wire           jtag_tms,
    input  wire           jtag_tdi,
    output wire           jtag_tdo,

    input  wire           test_mode
`ifdef GODSON_DEBUG
    ,
    output wire           gs_core_exe_valid,
    output wire [ 31: 0]  gs_core_exe_pc,
    output wire [ 31: 0]  gs_core_exe_inst,
    output wire           gs_core_gr_we,
    output wire [  4: 0]  gs_core_gr_waddr,
    output wire [ 31: 0]  gs_core_gr_wdata,
    output wire [  4: 0]  gs_core_gr_raddr0,
    output wire [ 31: 0]  gs_core_gr_rdata0,
    output wire [  4: 0]  gs_core_gr_raddr1,
    output wire [ 31: 0]  gs_core_gr_rdata1,
    output wire [ 31: 0]  gs_core_csr0,
    output wire [ 31: 0]  gs_core_csr1,
    output wire [ 31: 0]  gs_core_csr4,
    output wire [ 31: 0]  gs_core_csr5,
    output wire [ 31: 0]  gs_core_csr6,
    output wire [ 31: 0]  gs_core_csr7
`endif
);

//============================================================//
//              Local Parameters and Wire Declarations
//============================================================//

`ifdef CONFIG_MMU
localparam HAS_ICC       = 1;
localparam ICC_SET_ASSOC = 4;
localparam ICC_WAYSIZE   = 4 * (2 ** 10);
localparam ICC_ECC_BITS  = 1;
localparam HAS_DCC       = 1;
localparam DCC_SET_ASSOC = 4;
localparam DCC_WAYSIZE   = 4 * (2 ** 10);
localparam DCC_ECC_BITS  = 1;
localparam MMU_MAX_CACHE_WAYSIZE = 4 * (2 ** 10);

generate
    if (((HAS_ICC != 0) && (ICC_WAYSIZE > MMU_MAX_CACHE_WAYSIZE)) ||
        ((HAS_DCC != 0) && (DCC_WAYSIZE > MMU_MAX_CACHE_WAYSIZE))) begin: gen_invalid_mmu_cache_waysize
        initial begin
            $fatal(1,
                   "CONFIG_MMU cache way size exceeds 4 KiB: ICC_WAYSIZE=%0d bytes, DCC_WAYSIZE=%0d bytes",
                   ICC_WAYSIZE, DCC_WAYSIZE);
        end
    end
endgenerate

wire [ `OPEN132_ICC_RAM_TAGV_REQ_BUS_WD-1: 0] icc_ram_tagv_req_bus;
wire [ `OPEN132_ICC_RAM_DATA_REQ_BUS_WD-1: 0] icc_ram_data_req_bus;
wire [ `OPEN132_ICC_RAM_LRUD_REQ_BUS_WD-1: 0] icc_ram_lrud_req_bus;
wire [`OPEN132_ICC_RAM_TAGV_RESP_BUS_WD-1: 0] icc_ram_tagv_resp_bus;
wire [`OPEN132_ICC_RAM_DATA_RESP_BUS_WD-1: 0] icc_ram_data_resp_bus;
wire [`OPEN132_ICC_RAM_LRUD_RESP_BUS_WD-1: 0] icc_ram_lrud_resp_bus;
wire [ `OPEN132_DCC_RAM_TAGV_REQ_BUS_WD-1: 0] dcc_ram_tagv_req_bus;
wire [ `OPEN132_DCC_RAM_DATA_REQ_BUS_WD-1: 0] dcc_ram_data_req_bus;
wire [ `OPEN132_DCC_RAM_LRUD_REQ_BUS_WD-1: 0] dcc_ram_lrud_req_bus;
wire [`OPEN132_DCC_RAM_TAGV_RESP_BUS_WD-1: 0] dcc_ram_tagv_resp_bus;
wire [`OPEN132_DCC_RAM_DATA_RESP_BUS_WD-1: 0] dcc_ram_data_resp_bus;
wire [`OPEN132_DCC_RAM_LRUD_RESP_BUS_WD-1: 0] dcc_ram_lrud_resp_bus;
`else
wire [1-1: 0] icc_ram_tagv_req_bus;
wire [1-1: 0] icc_ram_data_req_bus;
wire [1-1: 0] icc_ram_lrud_req_bus;
wire [1-1: 0] icc_ram_tagv_resp_bus;
wire [1-1: 0] icc_ram_data_resp_bus;
wire [1-1: 0] icc_ram_lrud_resp_bus;
wire [1-1: 0] dcc_ram_tagv_req_bus;
wire [1-1: 0] dcc_ram_data_req_bus;
wire [1-1: 0] dcc_ram_lrud_req_bus;
wire [1-1: 0] dcc_ram_tagv_resp_bus;
wire [1-1: 0] dcc_ram_data_resp_bus;
wire [1-1: 0] dcc_ram_lrud_resp_bus;
`endif

//============================================================//
//                    Structural Integration
//============================================================//

// Core Instance

`ifdef CONFIG_MMU
la132_core #(
    .HAS_ICC       (HAS_ICC      ),
    .ICC_SET_ASSOC (ICC_SET_ASSOC),
    .ICC_WAYSIZE   (ICC_WAYSIZE  ),
    .ICC_ECC_BITS  (ICC_ECC_BITS ),
    .HAS_DCC       (HAS_DCC      ),
    .DCC_SET_ASSOC (DCC_SET_ASSOC),
    .DCC_WAYSIZE   (DCC_WAYSIZE  ),
    .DCC_ECC_BITS  (DCC_ECC_BITS )
) x_la132_core (
`else
la132_core x_la132_core (
`endif
    .boot_pc               (boot_pc              ),
    // ip global clock and reset except debug logic
    .clk                   (clk                  ),  // I, 1
    .hard_resetn           (hard_resetn          ),  // I,1

    // miscellaneous signals
    .sleeping              (sleeping             ),  // O, 1

    // interrupt inputs
    .ext_int               (ext_int              ),  // I, 6

    // cpu core number
    .cpunum                (cpunum               ),

    // sys axi
    // ar
    .arready               (arready              ),  // I,1
    .arid                  (arid                 ),  // O,4
    .araddr                (araddr               ),  // O,32
    .arlen                 (arlen                ),  // O,4
    .arsize                (arsize               ),  // O,3
    .arburst               (arburst              ),  // O,2
    .arlock                (arlock               ),  // O,2
    .arcache               (arcache              ),  // O,4
    .arprot                (arprot               ),  // O,3
    .arvalid               (arvalid              ),  // O,1
    // r
    .rid                   (rid                  ),  // I,4
    .rdata                 (rdata                ),  // I,32
    .rresp                 (rresp                ),  // I,2
    .rlast                 (rlast                ),  // I,1
    .rvalid                (rvalid               ),  // I,1
    .rready                (rready               ),  // O,1
    // aw
    .awready               (awready              ),  // I,1
    .awid                  (awid                 ),  // O,4
    .awaddr                (awaddr               ),  // O,32
    .awlen                 (awlen                ),  // O,4
    .awsize                (awsize               ),  // O,3
    .awburst               (awburst              ),  // O,2
    .awlock                (awlock               ),  // O,2
    .awcache               (awcache              ),  // O,4
    .awprot                (awprot               ),  // O,3
    .awvalid               (awvalid              ),  // O,1
    // w
    .wready                (wready               ),  // I,1
    .wid                   (wid                  ),  // O,4
    .wdata                 (wdata                ),  // O,32
    .wstrb                 (wstrb                ),  // O,4
    .wlast                 (wlast                ),  // O,1
    .wvalid                (wvalid               ),  // O,1
    // b
    .bid                   (bid                  ),  // I,4
    .bresp                 (bresp                ),  // I,2
    .bvalid                (bvalid               ),  // I,1
    .bready                (bready               ),  // O,1

    // inst sram
    .inst_sram_en          (inst_sram_en         ),  // O,1
    .inst_sram_strb        (inst_sram_strb       ),  // O,4
    .inst_sram_wr          (inst_sram_wr         ),  // O,1
    .inst_sram_fetch       (inst_sram_fetch      ),  // O,1
    .inst_sram_addr        (inst_sram_addr       ),  // O,32
    .inst_sram_wdata       (inst_sram_wdata      ),  // O,32
    .inst_sram_rdata       (inst_sram_rdata      ),  // I,32
    // data sram
    .data_sram_en          (data_sram_en         ),  // O,1
    .data_sram_strb        (data_sram_strb       ),  // O,4
    .data_sram_wr          (data_sram_wr         ),  // O,1
    .data_sram_fetch       (data_sram_fetch      ),  // O,1
    .data_sram_addr        (data_sram_addr       ),  // O,32
    .data_sram_wdata       (data_sram_wdata      ),  // O,32
    .data_sram_rdata       (data_sram_rdata      ),  // I,32

    .inst_sram_ack         (inst_sram_ack        ),  // I, 1
    .inst_sram_rrdy        (inst_sram_rrdy       ),  // I, 1
    .inst_sram_resp        (inst_sram_resp       ),  // I, 1
    .data_sram_ack         (data_sram_ack        ),  // I, 1
    .data_sram_rrdy        (data_sram_rrdy       ),  // I, 1
    .data_sram_resp        (data_sram_resp       ),  // I, 1

    // JTAG signals
    .cjtag_sel             (cjtag_sel            ),  // I, 1
    .cjtag_trstn           (cjtag_trstn          ),  // I, 1
    .cjtag_clk             (cjtag_clk            ),  // I, 1
    .cjtag_tckc            (cjtag_tckc           ),  // I, 1
    .cjtag_tmsc_i          (cjtag_tmsc_i         ),  // I, 1
    .cjtag_tmsc_o          (cjtag_tmsc_o         ),  // O, 1
    .cjtag_tmsc_oe         (cjtag_tmsc_oe        ),  // O, 1
    .jtag_trstn            (jtag_trstn           ),  // I, 1
    .jtag_tck              (jtag_tck             ),  // I, 1
    .jtag_tms              (jtag_tms             ),  // I, 1
    .jtag_tdi              (jtag_tdi             ),  // I, 1
    .jtag_tdo              (jtag_tdo             ),  // O, 1

    // dcache ram
    .dcc_ram_tagv_req_bus  (dcc_ram_tagv_req_bus ),
    .dcc_ram_data_req_bus  (dcc_ram_data_req_bus ),
    .dcc_ram_lrud_req_bus  (dcc_ram_lrud_req_bus ),  // write by bit
    .dcc_ram_tagv_resp_bus (dcc_ram_tagv_resp_bus),
    .dcc_ram_data_resp_bus (dcc_ram_data_resp_bus),
    .dcc_ram_lrud_resp_bus (dcc_ram_lrud_resp_bus),
    // icache ram

    .icc_ram_tagv_req_bus  (icc_ram_tagv_req_bus ),
    .icc_ram_data_req_bus  (icc_ram_data_req_bus ),
    .icc_ram_lrud_req_bus  (icc_ram_lrud_req_bus ),  // write by bit
    .icc_ram_tagv_resp_bus (icc_ram_tagv_resp_bus),
    .icc_ram_data_resp_bus (icc_ram_data_resp_bus),
    .icc_ram_lrud_resp_bus (icc_ram_lrud_resp_bus),

    // i/d bus configuration
    .ibus0_valid           (ibus0_valid          ),  // I, 1
    .ibus0_base            (ibus0_base           ),  // I, 32
    .ibus0_mask            (ibus0_mask           ),  // I, 32
    .ibus1_valid           (ibus1_valid          ),  // I, 1
    .ibus1_base            (ibus1_base           ),  // I, 32
    .ibus1_mask            (ibus1_mask           ),  // I, 32
    .ibus2_valid           (ibus2_valid          ),  // I, 1
    .ibus2_base            (ibus2_base           ),  // I, 32
    .ibus2_mask            (ibus2_mask           ),  // I, 32
    .ibus3_valid           (ibus3_valid          ),  // I, 1
    .ibus3_base            (ibus3_base           ),  // I, 32
    .ibus3_mask            (ibus3_mask           ),  // I, 32
    .dbus0_valid           (dbus0_valid          ),  // I, 1
    .dbus0_base            (dbus0_base           ),  // I, 32
    .dbus0_mask            (dbus0_mask           ),  // I, 32
    .dbus1_valid           (dbus1_valid          ),  // I, 1
    .dbus1_base            (dbus1_base           ),  // I, 32
    .dbus1_mask            (dbus1_mask           ),  // I, 32
    .dbus2_valid           (dbus2_valid          ),  // I, 1
    .dbus2_base            (dbus2_base           ),  // I, 32
    .dbus2_mask            (dbus2_mask           ),  // I, 32
    .dbus3_valid           (dbus3_valid          ),  // I, 1
    .dbus3_base            (dbus3_base           ),  // I, 32
    .dbus3_mask            (dbus3_mask           ),  // I, 32

    // runnig mode
    .test_mode             (test_mode            )   // I, 1
`ifdef GODSON_DEBUG
    ,
    .gs_core_exe_valid     (gs_core_exe_valid    ),
    .gs_core_exe_pc        (gs_core_exe_pc       ),
    .gs_core_exe_inst      (gs_core_exe_inst     ),
    .gs_core_gr_we         (gs_core_gr_we        ),
    .gs_core_gr_waddr      (gs_core_gr_waddr     ),
    .gs_core_gr_wdata      (gs_core_gr_wdata     ),
    .gs_core_gr_raddr0     (gs_core_gr_raddr0    ),
    .gs_core_gr_rdata0     (gs_core_gr_rdata0    ),
    .gs_core_gr_raddr1     (gs_core_gr_raddr1    ),
    .gs_core_gr_rdata1     (gs_core_gr_rdata1    ),
    .gs_core_csr0          (gs_core_csr0         ),
    .gs_core_csr1          (gs_core_csr1         ),
    .gs_core_csr4          (gs_core_csr4         ),
    .gs_core_csr5          (gs_core_csr5         ),
    .gs_core_csr6          (gs_core_csr6         ),
    .gs_core_csr7          (gs_core_csr7         )
`endif
);

`ifdef CONFIG_MMU
// Small physical Cache arrays used by both CPU requests and the hardware PTW.
openla132_dcache_ram_arrays #(
    .HAS_DCC       (HAS_DCC      ),
    .DCC_SET_ASSOC (DCC_SET_ASSOC),
    .DCC_WAYSIZE   (DCC_WAYSIZE  ),
    .DCC_ECC_BITS  (DCC_ECC_BITS )
) x_open132_dcache_ram_arrays (
    .clk                    (clk                    ),
    .test_mode              (test_mode              ),
    .dcc_ram_tagv_req_bus   (dcc_ram_tagv_req_bus   ),
    .dcc_ram_data_req_bus   (dcc_ram_data_req_bus   ),
    .dcc_ram_lrud_req_bus   (dcc_ram_lrud_req_bus   ),
    .dcc_ram_tagv_resp_bus  (dcc_ram_tagv_resp_bus  ),
    .dcc_ram_data_resp_bus  (dcc_ram_data_resp_bus  ),
    .dcc_ram_lrud_resp_bus  (dcc_ram_lrud_resp_bus  )
);

openla132_icache_ram_arrays #(
    .HAS_ICC       (HAS_ICC      ),
    .ICC_SET_ASSOC (ICC_SET_ASSOC),
    .ICC_WAYSIZE   (ICC_WAYSIZE  ),
    .ICC_ECC_BITS  (ICC_ECC_BITS )
) x_open132_icache_ram_arrays (
    .clk                    (clk                    ),
    .test_mode              (test_mode              ),
    .icc_ram_tagv_req_bus   (icc_ram_tagv_req_bus   ),
    .icc_ram_data_req_bus   (icc_ram_data_req_bus   ),
    .icc_ram_lrud_req_bus   (icc_ram_lrud_req_bus   ),
    .icc_ram_tagv_resp_bus  (icc_ram_tagv_resp_bus  ),
    .icc_ram_data_resp_bus  (icc_ram_data_resp_bus  ),
    .icc_ram_lrud_resp_bus  (icc_ram_lrud_resp_bus  )
`else
// Inactive cache RAM response owner for the published no-cache configuration.
la132_cache_tieoff x_la132_cache_tieoff (
    .dcc_ram_tagv_resp_bus (dcc_ram_tagv_resp_bus),
    .dcc_ram_data_resp_bus (dcc_ram_data_resp_bus),
    .dcc_ram_lrud_resp_bus (dcc_ram_lrud_resp_bus),
    .icc_ram_tagv_resp_bus (icc_ram_tagv_resp_bus),
    .icc_ram_data_resp_bus (icc_ram_data_resp_bus),
    .icc_ram_lrud_resp_bus (icc_ram_lrud_resp_bus)
`endif
);

endmodule

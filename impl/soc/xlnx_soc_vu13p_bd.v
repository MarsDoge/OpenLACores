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

module xlnx_soc_vu13p_bd (
    input  wire           c0_sys_clk_p,
    input  wire           c0_sys_clk_n,
    input  wire           sys_rst_n,
    input  wire           uart_rx,
    output wire           uart_tx,
    output wire [  3: 0]  led,
    output wire [ 16: 0]  c0_ddr4_adr,
    output wire [  1: 0]  c0_ddr4_ba,
    output wire [  1: 0]  c0_ddr4_bg,
    output wire           c0_ddr4_act_n,
    output wire [  1: 0]  c0_ddr4_cke,
    output wire [  1: 0]  c0_ddr4_odt,
    output wire [  1: 0]  c0_ddr4_cs_n,
    output wire [  1: 0]  c0_ddr4_ck_t,
    output wire [  1: 0]  c0_ddr4_ck_c,
    output wire           c0_ddr4_reset_n,
    inout  wire [  7: 0]  c0_ddr4_dm_dbi_n,
    inout  wire [ 63: 0]  c0_ddr4_dq,
    inout  wire [  7: 0]  c0_ddr4_dqs_c,
    inout  wire [  7: 0]  c0_ddr4_dqs_t
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire          cpu_clk;
wire          cpu_rst_b;
wire [  7: 0] bd_cpu_ext_interrupt;
wire [  3: 0] cpu_bd_axi_awid;
wire [ 31: 0] cpu_bd_axi_awaddr;
wire [  7: 0] cpu_bd_axi_awlen;
wire [  2: 0] cpu_bd_axi_awsize;
wire [  1: 0] cpu_bd_axi_awburst;
wire          cpu_bd_axi_awlock;
wire [  3: 0] cpu_bd_axi_awcache;
wire [  2: 0] cpu_bd_axi_awprot;
wire [  3: 0] cpu_bd_axi_awqos;
wire          cpu_bd_axi_awvalid;
wire          cpu_bd_axi_awready;
wire [ 31: 0] cpu_bd_axi_wdata;
wire [  3: 0] cpu_bd_axi_wstrb;
wire          cpu_bd_axi_wlast;
wire          cpu_bd_axi_wvalid;
wire          cpu_bd_axi_wready;
wire [  3: 0] cpu_bd_axi_bid;
wire [  1: 0] cpu_bd_axi_bresp;
wire          cpu_bd_axi_bvalid;
wire          cpu_bd_axi_bready;
wire [  3: 0] cpu_bd_axi_arid;
wire [ 31: 0] cpu_bd_axi_araddr;
wire [  7: 0] cpu_bd_axi_arlen;
wire [  2: 0] cpu_bd_axi_arsize;
wire [  1: 0] cpu_bd_axi_arburst;
wire          cpu_bd_axi_arlock;
wire [  3: 0] cpu_bd_axi_arcache;
wire [  2: 0] cpu_bd_axi_arprot;
wire [  3: 0] cpu_bd_axi_arqos;
wire          cpu_bd_axi_arvalid;
wire          cpu_bd_axi_arready;
wire [  3: 0] cpu_bd_axi_rid;
wire [ 31: 0] cpu_bd_axi_rdata;
wire [  1: 0] cpu_bd_axi_rresp;
wire          cpu_bd_axi_rlast;
wire          cpu_bd_axi_rvalid;
wire          cpu_bd_axi_rready;

//============================================================//
//                    Structural Integration
//============================================================//

xlnx_cpu_axi_bd_adapt x_xlnx_cpu_axi_bd_adapt (
    .cpu_clk                  (cpu_clk                 ),
    .cpu_rst_b                (cpu_rst_b               ),
    .bd_cpu_ext_interrupt     (bd_cpu_ext_interrupt    ),
    .cpu_bd_axi_awready       (cpu_bd_axi_awready      ),
    .cpu_bd_axi_wready        (cpu_bd_axi_wready       ),
    .cpu_bd_axi_bid           (cpu_bd_axi_bid          ),
    .cpu_bd_axi_bresp         (cpu_bd_axi_bresp        ),
    .cpu_bd_axi_bvalid        (cpu_bd_axi_bvalid       ),
    .cpu_bd_axi_arready       (cpu_bd_axi_arready      ),
    .cpu_bd_axi_rid           (cpu_bd_axi_rid          ),
    .cpu_bd_axi_rdata         (cpu_bd_axi_rdata        ),
    .cpu_bd_axi_rresp         (cpu_bd_axi_rresp        ),
    .cpu_bd_axi_rlast         (cpu_bd_axi_rlast        ),
    .cpu_bd_axi_rvalid        (cpu_bd_axi_rvalid       ),
    .cpu_bd_axi_awid          (cpu_bd_axi_awid         ),
    .cpu_bd_axi_awaddr        (cpu_bd_axi_awaddr       ),
    .cpu_bd_axi_awlen         (cpu_bd_axi_awlen        ),
    .cpu_bd_axi_awsize        (cpu_bd_axi_awsize       ),
    .cpu_bd_axi_awburst       (cpu_bd_axi_awburst      ),
    .cpu_bd_axi_awlock        (cpu_bd_axi_awlock       ),
    .cpu_bd_axi_awcache       (cpu_bd_axi_awcache      ),
    .cpu_bd_axi_awprot        (cpu_bd_axi_awprot       ),
    .cpu_bd_axi_awqos         (cpu_bd_axi_awqos        ),
    .cpu_bd_axi_awvalid       (cpu_bd_axi_awvalid      ),
    .cpu_bd_axi_wdata         (cpu_bd_axi_wdata        ),
    .cpu_bd_axi_wstrb         (cpu_bd_axi_wstrb        ),
    .cpu_bd_axi_wlast         (cpu_bd_axi_wlast        ),
    .cpu_bd_axi_wvalid        (cpu_bd_axi_wvalid       ),
    .cpu_bd_axi_bready        (cpu_bd_axi_bready       ),
    .cpu_bd_axi_arid          (cpu_bd_axi_arid         ),
    .cpu_bd_axi_araddr        (cpu_bd_axi_araddr       ),
    .cpu_bd_axi_arlen         (cpu_bd_axi_arlen        ),
    .cpu_bd_axi_arsize        (cpu_bd_axi_arsize       ),
    .cpu_bd_axi_arburst       (cpu_bd_axi_arburst      ),
    .cpu_bd_axi_arlock        (cpu_bd_axi_arlock       ),
    .cpu_bd_axi_arcache       (cpu_bd_axi_arcache      ),
    .cpu_bd_axi_arprot        (cpu_bd_axi_arprot       ),
    .cpu_bd_axi_arqos         (cpu_bd_axi_arqos        ),
    .cpu_bd_axi_arvalid       (cpu_bd_axi_arvalid      ),
    .cpu_bd_axi_rready        (cpu_bd_axi_rready       )
);

xlnx_soc_peripherals_bd_wrapper x_xlnx_soc_peripherals_bd_wrapper (
    .cpu_clk              (cpu_clk             ),
    .cpu_rst_b            (cpu_rst_b           ),
    .sys_rst_n            (sys_rst_n           ),
    .bd_cpu_ext_interrupt (bd_cpu_ext_interrupt),
    .cpu_bd_axi_araddr    (cpu_bd_axi_araddr   ),
    .cpu_bd_axi_arburst   (cpu_bd_axi_arburst  ),
    .cpu_bd_axi_arcache   (cpu_bd_axi_arcache  ),
    .cpu_bd_axi_arid      (cpu_bd_axi_arid     ),
    .cpu_bd_axi_arlen     (cpu_bd_axi_arlen    ),
    .cpu_bd_axi_arlock    (cpu_bd_axi_arlock   ),
    .cpu_bd_axi_arprot    (cpu_bd_axi_arprot   ),
    .cpu_bd_axi_arqos     (cpu_bd_axi_arqos    ),
    .cpu_bd_axi_arready   (cpu_bd_axi_arready  ),
    .cpu_bd_axi_arsize    (cpu_bd_axi_arsize   ),
    .cpu_bd_axi_arvalid   (cpu_bd_axi_arvalid  ),
    .cpu_bd_axi_awaddr    (cpu_bd_axi_awaddr   ),
    .cpu_bd_axi_awburst   (cpu_bd_axi_awburst  ),
    .cpu_bd_axi_awcache   (cpu_bd_axi_awcache  ),
    .cpu_bd_axi_awid      (cpu_bd_axi_awid     ),
    .cpu_bd_axi_awlen     (cpu_bd_axi_awlen    ),
    .cpu_bd_axi_awlock    (cpu_bd_axi_awlock   ),
    .cpu_bd_axi_awprot    (cpu_bd_axi_awprot   ),
    .cpu_bd_axi_awqos     (cpu_bd_axi_awqos    ),
    .cpu_bd_axi_awready   (cpu_bd_axi_awready  ),
    .cpu_bd_axi_awsize    (cpu_bd_axi_awsize   ),
    .cpu_bd_axi_awvalid   (cpu_bd_axi_awvalid  ),
    .cpu_bd_axi_bid       (cpu_bd_axi_bid      ),
    .cpu_bd_axi_bready    (cpu_bd_axi_bready   ),
    .cpu_bd_axi_bresp     (cpu_bd_axi_bresp    ),
    .cpu_bd_axi_bvalid    (cpu_bd_axi_bvalid   ),
    .cpu_bd_axi_rdata     (cpu_bd_axi_rdata    ),
    .cpu_bd_axi_rid       (cpu_bd_axi_rid      ),
    .cpu_bd_axi_rlast     (cpu_bd_axi_rlast    ),
    .cpu_bd_axi_rready    (cpu_bd_axi_rready   ),
    .cpu_bd_axi_rresp     (cpu_bd_axi_rresp    ),
    .cpu_bd_axi_rvalid    (cpu_bd_axi_rvalid   ),
    .cpu_bd_axi_wdata     (cpu_bd_axi_wdata    ),
    .cpu_bd_axi_wlast     (cpu_bd_axi_wlast    ),
    .cpu_bd_axi_wready    (cpu_bd_axi_wready   ),
    .cpu_bd_axi_wstrb     (cpu_bd_axi_wstrb    ),
    .cpu_bd_axi_wvalid    (cpu_bd_axi_wvalid   ),

    .uart_rx              (uart_rx             ),
    .uart_tx              (uart_tx             ),
    .led                  (led                 ),
    .c0_sys_clk_clk_p     (c0_sys_clk_p        ),
    .c0_sys_clk_clk_n     (c0_sys_clk_n        ),
    .c0_ddr4_adr          (c0_ddr4_adr         ),
    .c0_ddr4_ba           (c0_ddr4_ba          ),
    .c0_ddr4_bg           (c0_ddr4_bg          ),
    .c0_ddr4_act_n        (c0_ddr4_act_n       ),
    .c0_ddr4_cke          (c0_ddr4_cke         ),
    .c0_ddr4_odt          (c0_ddr4_odt         ),
    .c0_ddr4_cs_n         (c0_ddr4_cs_n        ),
    .c0_ddr4_ck_t         (c0_ddr4_ck_t        ),
    .c0_ddr4_ck_c         (c0_ddr4_ck_c        ),
    .c0_ddr4_reset_n      (c0_ddr4_reset_n     ),
    .c0_ddr4_dm_n         (c0_ddr4_dm_dbi_n    ),
    .c0_ddr4_dq           (c0_ddr4_dq          ),
    .c0_ddr4_dqs_c        (c0_ddr4_dqs_c       ),
    .c0_ddr4_dqs_t        (c0_ddr4_dqs_t       )
);

endmodule

`default_nettype wire

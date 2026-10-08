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

`include "soc_config.vh"

module verilator_top (
    input  wire          clk,
    input  wire          resetn,
    input  wire [31:0]   boot_pc,
    input  wire [ 7:0]   ext_int,

    output wire          sram_device_valid,
    output wire          sram_device_write,
    output wire [ 3:0]   sram_device_strb,
    output wire [31:0]   sram_device_addr,
    output wire [31:0]   sram_device_wdata,
    input  wire          sram_device_hit,
    input  wire          sram_device_ack,
    input  wire          sram_device_rrdy,
    input  wire [31:0]   sram_device_rdata,
    input  wire          sram_device_resp,

    output wire [ 3:0]   arid,
    output wire [31:0]   araddr,
    output wire [ 3:0]   arlen,
    output wire [ 2:0]   arsize,
    output wire [ 1:0]   arburst,
    output wire          arvalid,
    input  wire          arready,

    input  wire [ 3:0]   rid,
    input  wire [31:0]   rdata,
    input  wire [ 1:0]   rresp,
    input  wire          rlast,
    input  wire          rvalid,
    output wire          rready,

    output wire [ 3:0]   awid,
    output wire [31:0]   awaddr,
    output wire [ 3:0]   awlen,
    output wire [ 2:0]   awsize,
    output wire [ 1:0]   awburst,
    output wire          awvalid,
    input  wire          awready,

    output wire [ 3:0]   wid,
    output wire [31:0]   wdata,
    output wire [ 3:0]   wstrb,
    output wire          wlast,
    output wire          wvalid,
    input  wire          wready,

    input  wire [ 3:0]   bid,
    input  wire [ 1:0]   bresp,
    input  wire          bvalid,
    output wire          bready,

    output wire          commit_valid,
    output wire [31:0]   commit_pc,
    output wire          commit_wen,
    output wire [ 4:0]   commit_wdest,
    output wire [31:0]   commit_wdata,
    output wire          commit_cancel,
    output wire [31:0]   commit_mem_addr,
    output wire [63:0]   inst_sram_accesses,
    output wire [63:0]   data_sram_accesses,
    output wire          interrupt_taken,
    output wire [31:0]   interrupt_entry,
    output wire          ex_taken,
    output wire [31:0]   ex_entry,
    output wire          lsu_mem_valid,
    output wire          lsu_mem_load,
    output wire          lsu_mem_store,
    output wire [31:0]   csr_crmd,
    output wire [31:0]   csr_prmd,
    output wire [31:0]   csr_ecfg,
    output wire [31:0]   csr_estat,
    output wire [31:0]   csr_era,
    output wire [31:0]   csr_badv,
    output wire [31:0]   csr_eentry,
    output wire [31:0]   csr_tval
);

wire          sleeping;
wire [ 1:0]   arlock;
wire [ 3:0]   arcache;
wire [ 2:0]   arprot;
wire [ 1:0]   awlock;
wire [ 3:0]   awcache;
wire [ 2:0]   awprot;
wire          inst_sram_en;
wire [ 3:0]   inst_sram_strb;
wire          inst_sram_wr;
wire          inst_sram_fetch;
wire [31:0]   inst_sram_addr;
wire [31:0]   inst_sram_wdata;
wire [31:0]   inst_sram_rdata;
wire          inst_sram_ack;
wire          inst_sram_rrdy;
wire          data_sram_en;
wire [ 3:0]   data_sram_strb;
wire          data_sram_wr;
wire          data_sram_fetch;
wire [31:0]   data_sram_addr;
wire [31:0]   data_sram_wdata;
wire [31:0]   data_sram_rdata;
wire          data_sram_ack;
wire          data_sram_rrdy;
wire          data_sram_resp;
wire          cjtag_tmsc_o;
wire          cjtag_tmsc_oe;
wire          jtag_tdo;
wire          unused_outputs;
reg           interrupt_taken_r;
reg  [31:0]   interrupt_entry_r;

`ifdef OPEN132_VERILATOR_SRAM
localparam       IBUS0_VALID = 1'b1;
localparam [31:0] IBUS0_BASE = `OPEN132_LOCAL_SRAM_BASE;
localparam [31:0] IBUS0_MASK = `OPEN132_LOCAL_SRAM_MASK;
localparam       DBUS0_VALID = 1'b1;
localparam [31:0] DBUS0_BASE = `OPEN132_LOCAL_DSRAM_BASE;
localparam [31:0] DBUS0_MASK = `OPEN132_LOCAL_SRAM_MASK;
localparam       DBUS1_VALID = 1'b1;
localparam [31:0] DBUS1_BASE = `OPEN132_CONSOLE_MMIO_ADDR;
localparam [31:0] DBUS1_MASK = 32'hffff_ffff;
localparam       DBUS2_VALID = 1'b1;
localparam [31:0] DBUS2_BASE = `OPEN132_RT_DSRAM_BASE;
localparam [31:0] DBUS2_MASK = `OPEN132_LOCAL_SRAM_MASK;
localparam       DBUS3_VALID = 1'b1;
localparam [31:0] DBUS3_BASE = `OPEN132_RT_MMIO_BASE;
localparam [31:0] DBUS3_MASK = `OPEN132_RT_MMIO_MASK;
`else
localparam       IBUS0_VALID = 1'b0;
localparam [31:0] IBUS0_BASE = 32'd0;
localparam [31:0] IBUS0_MASK = 32'd0;
localparam       DBUS0_VALID = 1'b0;
localparam [31:0] DBUS0_BASE = 32'd0;
localparam [31:0] DBUS0_MASK = 32'd0;
localparam       DBUS1_VALID = 1'b0;
localparam [31:0] DBUS1_BASE = 32'd0;
localparam [31:0] DBUS1_MASK = 32'd0;
localparam       DBUS2_VALID = 1'b0;
localparam [31:0] DBUS2_BASE = 32'd0;
localparam [31:0] DBUS2_MASK = 32'd0;
localparam       DBUS3_VALID = 1'b0;
localparam [31:0] DBUS3_BASE = 32'd0;
localparam [31:0] DBUS3_MASK = 32'd0;
`endif

openla132_ip_top x_open132_ip_top (
    .clk                  (clk                 ),
    .hard_resetn          (resetn              ),
    .sleeping             (sleeping            ),
    .ext_int              (ext_int             ),
    .cpunum               (10'd0               ),
    .boot_pc              (boot_pc             ),

    .arid                 (arid                ),
    .araddr               (araddr              ),
    .arlen                (arlen               ),
    .arsize               (arsize              ),
    .arburst              (arburst             ),
    .arlock               (arlock              ),
    .arcache              (arcache             ),
    .arprot               (arprot              ),
    .arvalid              (arvalid             ),
    .arready              (arready             ),
    .rid                  (rid                 ),
    .rdata                (rdata               ),
    .rresp                (rresp               ),
    .rlast                (rlast               ),
    .rvalid               (rvalid              ),
    .rready               (rready              ),

    .awid                 (awid                ),
    .awaddr               (awaddr              ),
    .awlen                (awlen               ),
    .awsize               (awsize              ),
    .awburst              (awburst             ),
    .awlock               (awlock              ),
    .awcache              (awcache             ),
    .awprot               (awprot              ),
    .awvalid              (awvalid             ),
    .awready              (awready             ),
    .wid                  (wid                 ),
    .wdata                (wdata               ),
    .wstrb                (wstrb               ),
    .wlast                (wlast               ),
    .wvalid               (wvalid              ),
    .wready               (wready              ),
    .bid                  (bid                 ),
    .bresp                (bresp               ),
    .bvalid               (bvalid              ),
    .bready               (bready              ),

    .inst_sram_en         (inst_sram_en        ),
    .inst_sram_strb       (inst_sram_strb      ),
    .inst_sram_wr         (inst_sram_wr        ),
    .inst_sram_fetch      (inst_sram_fetch     ),
    .inst_sram_addr       (inst_sram_addr      ),
    .inst_sram_wdata      (inst_sram_wdata     ),
    .inst_sram_rdata      (inst_sram_rdata     ),

    .data_sram_en         (data_sram_en        ),
    .data_sram_strb       (data_sram_strb      ),
    .data_sram_wr         (data_sram_wr        ),
    .data_sram_fetch      (data_sram_fetch     ),
    .data_sram_addr       (data_sram_addr      ),
    .data_sram_wdata      (data_sram_wdata     ),
    .data_sram_rdata      (data_sram_rdata     ),

    .inst_sram_ack        (inst_sram_ack       ),
    .inst_sram_rrdy       (inst_sram_rrdy      ),
    .inst_sram_resp       (1'b0                ),
    .data_sram_ack        (data_sram_ack       ),
    .data_sram_rrdy       (data_sram_rrdy      ),
    .data_sram_resp       (data_sram_resp      ),

    .ibus0_valid          (IBUS0_VALID          ),
    .ibus0_base           (IBUS0_BASE           ),
    .ibus0_mask           (IBUS0_MASK           ),
    .ibus1_valid          (1'b0                ),
    .ibus1_base           (32'd0               ),
    .ibus1_mask           (32'd0               ),
    .ibus2_valid          (1'b0                ),
    .ibus2_base           (32'd0               ),
    .ibus2_mask           (32'd0               ),
    .ibus3_valid          (1'b0                ),
    .ibus3_base           (32'd0               ),
    .ibus3_mask           (32'd0               ),
    .dbus0_valid          (DBUS0_VALID          ),
    .dbus0_base           (DBUS0_BASE           ),
    .dbus0_mask           (DBUS0_MASK           ),
    .dbus1_valid          (DBUS1_VALID          ),
    .dbus1_base           (DBUS1_BASE           ),
    .dbus1_mask           (DBUS1_MASK           ),
    .dbus2_valid          (DBUS2_VALID          ),
    .dbus2_base           (DBUS2_BASE           ),
    .dbus2_mask           (DBUS2_MASK           ),
    .dbus3_valid          (DBUS3_VALID          ),
    .dbus3_base           (DBUS3_BASE           ),
    .dbus3_mask           (DBUS3_MASK           ),

    .cjtag_sel            (1'b0                ),
    .cjtag_trstn          (resetn              ),
    .cjtag_clk            (clk                 ),
    .cjtag_tckc           (1'b0                ),
    .cjtag_tmsc_i         (1'b0                ),
    .cjtag_tmsc_o         (cjtag_tmsc_o        ),
    .cjtag_tmsc_oe        (cjtag_tmsc_oe       ),
    .jtag_trstn           (resetn              ),
    .jtag_tck             (1'b0                ),
    .jtag_tms             (1'b0                ),
    .jtag_tdi             (1'b0                ),
    .jtag_tdo             (jtag_tdo            ),
    .test_mode            (1'b0                )
);

assign sram_device_valid = data_sram_en;
assign sram_device_write = data_sram_wr;
assign sram_device_strb  = data_sram_strb;
assign sram_device_addr  = data_sram_addr;
assign sram_device_wdata = data_sram_wdata;

`ifdef OPEN132_VERILATOR_SRAM
// Instruction and data arrays are initialized independently from the ELF
// physical load segments supplied by the simulator.
openla132_spram_bytemask_init #(
    .Words      (4194304),
    .DataMemory (0)
) u_inst_sram (
    .clk   (clk),
    .rdata (inst_sram_rdata),
    .en    (inst_sram_en),
    .wr    (inst_sram_wr),
    .strb  (inst_sram_strb),
    .addr  (inst_sram_addr[23:2]),
    .wdata (inst_sram_wdata),
    .ack   (inst_sram_ack),
    .rrdy  (inst_sram_rrdy)
);

wire        data_ram_en;
wire [31:0] data_ram_rdata;
wire        data_ram_ack;
wire        data_ram_rrdy;
reg  [31:0] data_device_rdata;
reg         data_device_rrdy;
reg         data_device_resp;
reg  [63:0] inst_sram_accesses_r;
reg  [63:0] data_sram_accesses_r;

assign data_ram_en     = data_sram_en && !sram_device_hit;
assign data_sram_rdata = data_device_rrdy ? data_device_rdata : data_ram_rdata;
assign data_sram_ack   = sram_device_hit ? sram_device_ack   : data_ram_ack;
assign data_sram_rrdy  = data_device_rrdy || data_ram_rrdy;
assign data_sram_resp  = data_device_rrdy ? data_device_resp : 1'b0;

openla132_spram_bytemask_init #(
    .Words      (4194304),
    .DataMemory (1)
) u_data_sram (
    .clk   (clk),
    .rdata (data_ram_rdata),
    .en    (data_ram_en),
    .wr    (data_sram_wr),
    .strb  (data_sram_strb),
    .addr  (data_sram_addr[23:2]),
    .wdata (data_sram_wdata),
    .ack   (data_ram_ack),
    .rrdy  (data_ram_rrdy)
);

// Match the synchronous response timing of the RTL SRAM.  Peripheral decode
// and register behavior remain in the C++ device model.
always @(posedge clk) begin
    if (!resetn) begin
        data_device_rdata <= 32'd0;
        data_device_rrdy  <= 1'b0;
        data_device_resp  <= 1'b0;
    end else begin
        data_device_rrdy <= sram_device_rrdy;
        if (sram_device_rrdy) begin
            data_device_rdata <= sram_device_rdata;
            data_device_resp  <= sram_device_resp;
        end
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        inst_sram_accesses_r <= 64'd0;
        data_sram_accesses_r <= 64'd0;
    end else begin
        if (inst_sram_en && inst_sram_ack) begin
            inst_sram_accesses_r <= inst_sram_accesses_r + 1'b1;
        end
        if (data_sram_en && data_sram_ack) begin
            data_sram_accesses_r <= data_sram_accesses_r + 1'b1;
        end
    end
end

assign inst_sram_accesses = inst_sram_accesses_r;
assign data_sram_accesses = data_sram_accesses_r;

// Any request on AXI is a routing failure in local-SRAM mode.
always @(posedge clk) begin
    if (resetn && (arvalid || awvalid || wvalid)) begin
        $fatal(1, "AXI request in SRAM-only mode: ar=%0b araddr=%08x aw=%0b awaddr=%08x w=%0b",
               arvalid, araddr, awvalid, awaddr, wvalid);
    end
end
`else
assign inst_sram_rdata = 32'd0;
assign inst_sram_ack   = 1'b0;
assign inst_sram_rrdy  = 1'b0;
assign data_sram_rdata = 32'd0;
assign data_sram_ack   = 1'b0;
assign data_sram_rrdy  = 1'b0;
assign data_sram_resp  = 1'b0;
assign inst_sram_accesses = 64'd0;
assign data_sram_accesses = 64'd0;
`endif

assign commit_valid  = x_open132_ip_top.x_la132_core.rtu_lsu_commit;
assign commit_pc     = x_open132_ip_top.x_la132_core.wb_pc;
assign commit_wen    = x_open132_ip_top.x_la132_core.wb_rf_wen;
assign commit_wdest  = x_open132_ip_top.x_la132_core.wb_rf_dest;
assign commit_wdata  = x_open132_ip_top.x_la132_core.wb_rf_value;
assign commit_cancel = x_open132_ip_top.x_la132_core.ex_cancel;
assign commit_mem_addr = x_open132_ip_top.x_la132_core.x_lsu_stage.memld_st_vaddr;
assign lsu_mem_valid = x_open132_ip_top.x_la132_core.x_lsu_stage.valid_go_wb;
assign lsu_mem_load  = x_open132_ip_top.x_la132_core.x_lsu_stage.mem_is_ld_valid;
assign lsu_mem_store = x_open132_ip_top.x_la132_core.x_lsu_stage.mem_is_st_valid;
assign interrupt_taken = interrupt_taken_r;
assign interrupt_entry = interrupt_entry_r;
assign ex_taken = x_open132_ip_top.x_la132_core.x_lsu_stage.mem_ex
               && x_open132_ip_top.x_la132_core.rtu_lsu_allowin
               && !x_open132_ip_top.x_la132_core.ex_cancel;
assign ex_entry = x_open132_ip_top.x_la132_core.x_lsu_stage.ex_entry_expt;
assign csr_crmd   = x_open132_ip_top.x_la132_core.x_lsu_stage.x_csr_regs.csr_csr0;
assign csr_prmd   = x_open132_ip_top.x_la132_core.x_lsu_stage.x_csr_regs.csr_csr1;
assign csr_ecfg   = x_open132_ip_top.x_la132_core.x_lsu_stage.x_csr_regs.csr_csr4;
assign csr_estat  = x_open132_ip_top.x_la132_core.x_lsu_stage.x_csr_regs.csr_csr5;
assign csr_era    = x_open132_ip_top.x_la132_core.x_lsu_stage.x_csr_regs.csr_csr6;
assign csr_badv   = x_open132_ip_top.x_la132_core.x_lsu_stage.x_csr_regs.csr_csr7;
assign csr_eentry = x_open132_ip_top.x_la132_core.x_lsu_stage.x_csr_regs.csr_csrc;
assign csr_tval   = x_open132_ip_top.x_la132_core.x_lsu_stage.x_csr_regs.csr_csr42;

always @(posedge clk) begin
    if (!resetn) begin
        interrupt_taken_r <= 1'b0;
        interrupt_entry_r <= 32'd0;
    end else begin
        interrupt_taken_r <= x_open132_ip_top.x_la132_core.x_lsu_stage.mark_int;
        if (x_open132_ip_top.x_la132_core.x_lsu_stage.mark_int) begin
            interrupt_entry_r <= x_open132_ip_top.x_la132_core.x_lsu_stage.ex_entry_expt;
        end
    end
end

endmodule

// SPDX-License-Identifier: MulanPSL-2.0
module cpucfg_boot_tb;
reg clk=0;
always #5 clk=~clk;
reg resetn=0;
wire en;
wire [31:0] addr;
reg rrdy=0;
reg [31:0] rdata=0;
openla132_ip_top dut (
.clk(clk),
.hard_resetn(resetn),
.ext_int(8'd0),
.cpunum(10'd0),
.boot_pc(32'h1c000000),
.arready(1'd0),
.rid(4'd0),
.rdata(32'd0),
.rresp(2'd0),
.rlast(1'd0),
.rvalid(1'd0),
.awready(1'd0),
.wready(1'd0),
.bid(4'd0),
.bresp(2'd0),
.bvalid(1'd0),
.inst_sram_rdata(rdata),
.data_sram_rdata(32'd0),
.inst_sram_ack(1'b1),
.inst_sram_rrdy(rrdy),
.inst_sram_resp(1'd0),
.data_sram_ack(1'd0),
.data_sram_rrdy(1'd0),
.data_sram_resp(1'd0),
.ibus0_valid(1'b1),
.ibus0_base(32'h1c000000),
.ibus0_mask(32'hffff0000),
.ibus1_valid(1'd0),
.ibus1_base(32'd0),
.ibus1_mask(32'd0),
.ibus2_valid(1'd0),
.ibus2_base(32'd0),
.ibus2_mask(32'd0),
.ibus3_valid(1'd0),
.ibus3_base(32'd0),
.ibus3_mask(32'd0),
.dbus0_valid(1'd0),
.dbus0_base(32'd0),
.dbus0_mask(32'd0),
.dbus1_valid(1'd0),
.dbus1_base(32'd0),
.dbus1_mask(32'd0),
.dbus2_valid(1'd0),
.dbus2_base(32'd0),
.dbus2_mask(32'd0),
.dbus3_valid(1'd0),
.dbus3_base(32'd0),
.dbus3_mask(32'd0),
.cjtag_sel(1'd0),
.cjtag_trstn(resetn),
.cjtag_clk(clk),
.cjtag_tckc(clk),
.cjtag_tmsc_i(1'd0),
.jtag_trstn(resetn),
.jtag_tck(clk),
.jtag_tms(1'b1),
.jtag_tdi(1'd0),
.test_mode(1'd0),
.inst_sram_en(en),
.inst_sram_addr(addr));
always @(posedge clk) begin
 rrdy <= resetn && en;
 if(en) begin
 case(addr)
 32'h1c000000: rdata <= 32'h00006c0e; // cpucfg r14,r0
 32'h1c000004: rdata <= 32'h0380040c; // ori r12,r0,1
 32'h1c000008: rdata <= 32'h00006d8f; // cpucfg r15,r12
 32'h1c00000c: rdata <= 32'h0380800c; // ori r12,r0,0x20
 32'h1c000010: rdata <= 32'h00006d90; // cpucfg r16,r12
 32'h1c000014: rdata <= 32'h1400008c; // lu12i.w r12,4
 32'h1c000018: rdata <= 32'h00006d8d; // cpucfg r13,r12
 32'h1c00001c: rdata <= 32'h0380058c; // ori r12,r12,1
 32'h1c000020: rdata <= 32'h00006d91; // cpucfg r17,r12
 32'h1c000024: rdata <= 32'h1500000c; // lu12i.w r12,0x80000
 32'h1c000028: rdata <= 32'h00006d92; // cpucfg r18,r12
 default: rdata <= 32'h50000000; // b .
 endcase
 end
 if(resetn && dut.x_la132_core.wb_rf_wen) begin
 $display("pc=%08h r%0d=%08h",dut.x_la132_core.wb_pc,dut.x_la132_core.wb_rf_dest,dut.x_la132_core.wb_rf_value);
 case (dut.x_la132_core.wb_rf_dest)
 14,15: if (dut.x_la132_core.wb_rf_value === 0 ||
            (^dut.x_la132_core.wb_rf_value) === 1'bx)
            $fatal(1,"Defined CPUCFG index must return known nonzero data");
 13,16,17,18: begin
   if (dut.x_la132_core.wb_rf_value !== 0)
       $fatal(1,"Undefined CPUCFG index must return zero");
   if (dut.x_la132_core.wb_rf_dest == 18) begin
       $display("PASS: full-core CPUCFG boot regression");
       $finish;
   end
 end
 endcase
 end
end
initial begin
 repeat(20) @(negedge clk);
 resetn=1;
 repeat(1000) @(negedge clk);
 $fatal(1,"timeout");
end
endmodule

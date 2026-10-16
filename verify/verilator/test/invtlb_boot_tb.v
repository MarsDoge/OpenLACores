// SPDX-License-Identifier: MulanPSL-2.0
module invtlb_boot_tb;
integer invalid_op=7;
reg saw_era=0;
reg clk=0;
always #5 clk=~clk;
reg resetn=0;
wire en;
wire arvalid, rready;
wire [31:0] araddr;
wire [3:0] arid;
reg [3:0] rid=0;
reg rvalid=0;
reg [31:0] axi_rdata=0;
wire [31:0] addr;
reg rrdy=0;
reg [31:0] rdata=0;
openla132_ip_top dut (
.clk(clk),
.hard_resetn(resetn),
.ext_int(8'd0),
.cpunum(10'd0),
.boot_pc(32'h1c000000),
.arready(!rvalid),
.rid(rid),
.rdata(axi_rdata),
.rresp(2'd0),
.rlast(1'b1),
.rvalid(rvalid),
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
.arvalid(arvalid), .araddr(araddr), .arid(arid), .rready(rready),
.inst_sram_en(en),
.inst_sram_addr(addr));
always @(posedge clk) begin
 if(rvalid && rready) rvalid <= 0;
 if(resetn && arvalid && !rvalid) begin
 rvalid<=1; rid<=arid;
 case(araddr)
 32'h1c000000: axi_rdata <= 32'h1438002c; // lu12i.w r12,0x1c001
 32'h1c000004: axi_rdata <= 32'h0380018c; // ori r12,r12,0
 32'h1c000008: axi_rdata <= 32'h0400302c; // csrwr r12,0xc
 32'h1c00000c: axi_rdata <= 32'h06498000; // invtlb 0,r0,r0
 32'h1c000010: axi_rdata <= 32'h06498006; // invtlb 6,r0,r0
 32'h1c000014: axi_rdata <= (32'h06498000 | invalid_op); // invtlb 7,r0,r0
 32'h1c000018: axi_rdata <= 32'h0280040d; // addi.w r13,r0,1
 32'h1c001000: axi_rdata <= 32'h0400180f; // csrrd r15,0x6
 32'h1c001004: axi_rdata <= 32'h0400140e; // csrrd r14,0x5
 default: axi_rdata <= 32'h50000000; // b .
 endcase
 end
 rrdy <= resetn && en;
 if(en) begin
 case(addr)
 32'h1c000000: rdata <= 32'h1438002c; // lu12i.w r12,0x1c001
 32'h1c000004: rdata <= 32'h0380018c; // ori r12,r12,0
 32'h1c000008: rdata <= 32'h0400302c; // csrwr r12,0xc
 32'h1c00000c: rdata <= 32'h06498000; // invtlb 0,r0,r0
 32'h1c000010: rdata <= 32'h06498006; // invtlb 6,r0,r0
 32'h1c000014: rdata <= (32'h06498000 | invalid_op); // invtlb 7,r0,r0
 32'h1c000018: rdata <= 32'h0280040d; // addi.w r13,r0,1
 32'h1c001000: rdata <= 32'h0400180f; // csrrd r15,0x6
 32'h1c001004: rdata <= 32'h0400140e; // csrrd r14,0x5
 default: rdata <= 32'h50000000; // b .
 endcase
 end
 if(resetn && dut.x_la132_core.wb_rf_wen) begin
 $display("pc=%08h r%0d=%08h",dut.x_la132_core.wb_pc,dut.x_la132_core.wb_rf_dest,dut.x_la132_core.wb_rf_value);
 case (dut.x_la132_core.wb_rf_dest)
 13: $fatal(1,"Reserved INVTLB op %0d executed without INE",invalid_op);
 15: begin
 saw_era=1;
 if(dut.x_la132_core.wb_rf_value !== 32'h1c000014)
       $fatal(1,"Exception at wrong instruction");
 end
 14: begin
   if(!saw_era) $fatal(1,"ERA was not checked");
   if(dut.x_la132_core.wb_rf_value[21:16] !== 6'h0d)
       $fatal(1,"Expected INE exception");
   $display("PASS: INVTLB op %0d raises INE; op 0 and 6 execute",invalid_op);
   $finish;
 end
 endcase
 end
end
initial begin
 if($value$plusargs("invalid_op=%d",invalid_op)) begin end
 if(invalid_op<7 || invalid_op>31) $fatal(1,"invalid test op");
 repeat(20) @(negedge clk);
 resetn=1;
 repeat(10000) @(negedge clk);
 $fatal(1,"timeout");
end
endmodule

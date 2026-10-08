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

module openla132_spram_bytemask_init #(
    parameter integer Words = 1024,
    parameter integer DataMemory = 0
) (
    input  wire                       clk,
    input  wire                       en,
    input  wire                       wr,
    input  wire [                3:0] strb,
    input  wire [$clog2(Words)-1:0]   addr,
    input  wire [               31:0] wdata,
    output wire [               31:0] rdata,
    output wire                       ack,
    output wire                       rrdy
);

reg [31:0] mem [0:Words-1];
reg [31:0] rdata_r;
reg        rrdy_r;
string     init_file;
integer    has_init_file;

initial begin
    rdata_r = 32'd0;
    rrdy_r  = 1'b0;
    if (DataMemory != 0) begin
        has_init_file = $value$plusargs("OPEN132_DSRAM_INIT=%s", init_file);
    end else begin
        has_init_file = $value$plusargs("OPEN132_ISRAM_INIT=%s", init_file);
    end
    if (!has_init_file) begin
        has_init_file = $value$plusargs("OPEN132_SRAM_INIT=%s", init_file);
    end
    if (has_init_file) begin
        $readmemh(init_file, mem);
    end
end

always @(posedge clk) begin
    rrdy_r <= en && !wr;
    if (en && !wr) begin
        rdata_r <= mem[addr];
    end
    if (en && wr) begin
        if (strb[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
        if (strb[1]) mem[addr][15: 8] <= wdata[15: 8];
        if (strb[2]) mem[addr][23:16] <= wdata[23:16];
        if (strb[3]) mem[addr][31:24] <= wdata[31:24];
    end
end

assign rdata = rdata_r;
assign ack   = en;
assign rrdy  = rrdy_r;

endmodule

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

module biu_nocache #(
    parameter AXI_DATA = 32  // 32/64/128
) (
    input  wire                    is_icache,
    // clk and reset
    input  wire                    clk,
    input  wire                    clk_ng,
    input  wire                    reset,
    input  wire                    data_reset,

    input  wire                    ex_cancel,

    // ifc <--> cache
    input  wire                    req_rd_wr,  // request is read or write
    input  wire                    req_rd,  // request is read
    input  wire                    req_exc,  // request exclusive access
    input  wire                    cached,  // request is cached
    input  wire [           1: 0]  size,  // request size
    input  wire [          31: 0]  paddr,  // request paddr
    input  wire [          31: 0]  wdata,  // request write data
    output wire                    cd_ar_addr_ok,  // request to ar for cacheld
    output wire                    md_ar_addr_ok,  // request to ar for memld
    output wire                    aw_addr_ok,  // request to aw
    output wire                    dbgm_addr_ok,  // request to dbgm
    output wire [          31: 0]  rdata,  // read data
    output wire                    rdata_valid,  // rdata is valid
    output wire                    rdata_exok,  // rdata is exokay
    output wire                    rdata_err,  // rdata is error

    output wire                    rd_in_sysbus,  // read access is doing
    output wire                    wr_in_sysbus,  // write access is doing
    output wire                    axi_null,  // no incomplete access/miss/writeback in cache

    input  wire                    req2dbgm,
    output wire                    dbgm_req_valid,
    output wire                    dbgm_req_wr,
    output wire [          31: 0]  dbgm_req_addr,
    output wire [           1: 0]  dbgm_req_size,
    output wire [          31: 0]  dbgm_req_wdata,
    input  wire                    dbgm_resp_valid,  // for read, also need back resp_valid
    input  wire [          31: 0]  dbgm_resp_data,

    // cache <--> axi
    output wire                    dcc_ar_stall_icc,  // dcc-ar stall icc-ar
    output wire                    axi_arvalid,  // read request
    input  wire                    axi_arready,  // read request received
    output wire                    axi_arburst,  // read burst
    output wire                    axi_arexc,  // read exclusive
    output wire                    axi_arcache,  // read cached
    output wire [           2: 0]  axi_arsize,  // read size
    output wire [          31: 0]  axi_araddr,  // read addr
    input  wire                    axi_rvalid,  // read response valid
    input  wire [  AXI_DATA-1: 0]  axi_rdata,  // read data
    input  wire [           1: 0]  axi_rresp,  // read response

    output wire [           2: 0]  axi_aw_wid,  // write id for awid/wid
    output wire                    axi_awvalid,  // write request
    input  wire                    axi_awready,  // write request received
    output wire                    axi_awburst,  // write burst
    output wire                    axi_awexc,  // write exclusive
    output wire                    axi_awcache,  // write cached
    output wire [           2: 0]  axi_awsize,  // write size
    output wire [          31: 0]  axi_awaddr,  // write addr
    output wire                    axi_wvalid,  // write data request
    input  wire                    axi_wready,  // write data received
    output wire [AXI_DATA/8-1: 0]  axi_wstrb,  // write strobe
    output wire [  AXI_DATA-1: 0]  axi_wdata,  // write data
    output wire                    axi_wlast,  // write last
    input  wire                    axi_bvalid,  // write response valid
    input  wire [           2: 0]  axi_bid,  // bid[2:0]

    input  wire                    cd_hit_wr,  // axi-read address hit wr, for cahceld
    input  wire                    md_hit_wr  // axi-read address hit wr, for memld
);

// AXI
localparam AXI_STRB   = AXI_DATA / 8;
localparam AXI_DIV_32 = AXI_DATA / 32;

//============================================================//
//                     Regs Declarations
//============================================================//

reg [  1: 0] axi_rd_wait;

// FIFO with 2 depth
reg [  1: 0] axi_rd_sel0;
reg [  1: 0] axi_rd_sel1;
reg          axi_rd_mask;

// for axi
reg          awvalid_r;
reg          wvalid_r;

// for dbgm
reg          dvalid_r;
reg          dbgm_wr_r;
reg          dbgm_mask;  // cancel because of exception

// for axi/dbgm
reg                 ad_busy;
reg                 exc_r;    // exclusive
reg                 cache_r;
reg [         1: 0] size_r;
reg [        31: 0] addr_r;
reg [AXI_STRB-1: 0] wstrb_r;
reg [AXI_DATA-1: 0] wdata_r;

//============================================================//
//                     Wire Declarations
//============================================================//

wire          nc_clk_ng;
wire [  2: 0] nc_axi_bid;

wire          req_wr;

wire          dbgm_stall_axi;  // dbgm-access stall axi access
wire          wr_stall_cd;     // write to Address A, and cacheld also to Address A
wire          wr_stall_md;     // write to Address A, and memld   also to Address A

wire          axi_rd_null;
wire          axi_rd_full;
wire          axi_ar_ok;
wire          axi_r_ok;
wire          axi_rd_wnull;
wire          axi_rd_canc;

wire          axi_oth_stall_rd;
wire          axi_wr_stall_rd;

// for fetch, cd_axi_araddr_ok is same as md_axi_araddr_ok
wire          cd_axi_araddr_ok;  // for cacheld
wire          md_axi_araddr_ok;  // for memld

wire [  3: 0] strb;

wire [AXI_STRB-1: 0] wstrb_axi;
wire [AXI_DATA-1: 0] wdata_axi;

wire          axi_aw_ok;
wire          axi_w_ok;
wire          dbgm_ok;
wire          ad_ok;

wire          axi_wr_go;
wire          dbgm_go;
wire          dbgm_canc;
wire          req_ad;
wire          req_ad_go;

wire [ 31: 0] axi_rdata32;

//============================================================//
//                    Module Implementation
//============================================================//

assign nc_clk_ng   =  clk_ng;
assign nc_axi_bid  =  axi_bid;

assign req_wr  =  req_rd_wr && !req_rd;
//------------------------------------------------------------//
//                          Axi Read
//------------------------------------------------------------//

assign axi_rd_null   =  axi_rd_wait == 2'd0;
assign axi_rd_full   =  axi_rd_wait[1];
assign axi_ar_ok     =  axi_arvalid && axi_arready;
assign axi_r_ok      =  axi_rvalid;
assign axi_rd_wnull  =  axi_r_ok && axi_rd_wait[0];
assign axi_rd_canc   =  !axi_rd_null && ex_cancel;

always @ ( posedge clk )
begin
    axi_rd_wait <= reset ? 2'd0 :
    axi_ar_ok && !axi_r_ok ? axi_rd_wait + 1'b1 : axi_r_ok && !axi_ar_ok ? axi_rd_wait - 1'b1 : axi_rd_wait;
    axi_rd_mask <= reset ? 1'b0 : axi_rd_wnull ? 1'b0 :  // is prior to axi_rd_canc
    axi_rd_canc ? 1'b1 : axi_rd_mask;
    // sel0
    if(data_reset) begin
        axi_rd_sel0 <= 2'd0;
    end
    else if(axi_ar_ok) begin  // ar_ok is set, must axi_rd_wait<=2'd1
        if(axi_r_ok || !axi_rd_wait[0]) begin  // r_ok and ar_ok are set together, must axi_rd_wait==2'd1
            axi_rd_sel0 <= paddr[3:2];
        end
    end
    else if(axi_r_ok) begin  // axi_rd_wait==2'd1 or 2'd2, if ==2'd1, no update sel0
        axi_rd_sel0 <= axi_rd_sel1;
    end

    // sel1
    if(data_reset) begin
        axi_rd_sel1 <= 2'd0;
    end
    else if(axi_ar_ok) begin  // ar_ok is set, must axi_rd_wait<=2'd1
        if(!axi_r_ok && axi_rd_wait[0]) begin
            axi_rd_sel1 <= paddr[3:2];
        end
    end
end

// if req2dbgm or dbgm is doing or axi_read has >=2 outstanding
// can't send axi_arvalid
assign dcc_ar_stall_icc  =  req_rd && !req2dbgm && !is_icache;

assign axi_oth_stall_rd  =  dbgm_stall_axi || axi_rd_full || axi_rd_mask;
assign axi_wr_stall_rd   =  wr_stall_cd || wr_stall_md;
// for icache, must axi_wr_stall_rd==0

assign axi_arvalid  =  req_rd && !req2dbgm && !ex_cancel && !axi_oth_stall_rd && !axi_wr_stall_rd;
assign axi_arburst  =  1'b0;
assign axi_arexc    =  req_exc;
assign axi_arcache  =  cached;
assign axi_arsize   =  {1'b0, size};
assign axi_araddr   =  paddr;

assign cd_axi_araddr_ok  =  axi_arready && !axi_oth_stall_rd && !wr_stall_cd;
assign md_axi_araddr_ok  =  axi_arready && !axi_oth_stall_rd && !wr_stall_md;

// End Axi Read

//------------------------------------------------------------//
//                         Axi Write
//------------------------------------------------------------//
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
assign strb[3]        =  (paddr[1:0] == 2'b11) | size[1] | (size[0] & paddr[1]);
assign strb[2]        =  (paddr[1:0] == 2'b10) | size[1];
assign strb[1]        =  (paddr[1:0] == 2'b01) | size[1] | (size[0] & ~paddr[1]);
assign strb[0]        =  (paddr[1:0] == 2'b00);
assign wdata_axi      =  {AXI_DIV_32{wdata}};
generate
    case (AXI_DATA)
        32: begin: gen_axi_wstrb_32
            assign wstrb_axi = strb;
        end
        64: begin: gen_axi_wstrb_64
            assign wstrb_axi = paddr[2] ? {strb, 4'd0} : {4'd0, strb};
        end
        128: begin: gen_axi_wstrb_128
            assign wstrb_axi = {16{paddr[3:2] == 2'd0}} & {12'd0, strb} |
                               {16{paddr[3:2] == 2'd1}} & {8'd0, strb, 4'd0} |
                               {16{paddr[3:2] == 2'd2}} & {4'd0, strb, 8'd0} |
                               {16{paddr[3:2] == 2'd3}} & {strb, 12'd0};
        end
    endcase
endgenerate

assign axi_aw_ok  =  axi_awvalid && axi_awready;
assign axi_w_ok   =  axi_wvalid && axi_wready;
assign dbgm_ok    =  dbgm_req_valid && dbgm_resp_valid;
assign ad_ok      =  dbgm_req_valid ? dbgm_resp_valid : axi_bvalid;

assign axi_wr_go  =  req_wr && !req2dbgm && aw_addr_ok;
assign dbgm_go    =  req_rd_wr && req2dbgm && dbgm_addr_ok && (req_wr || !ex_cancel);
assign dbgm_canc  =  ex_cancel && dvalid_r  /*&&!dbgm_wr_r*/;
assign req_ad     =  axi_wr_go || dbgm_go;
assign req_ad_go  =  req_rd_wr && !ad_busy;
always @ ( posedge clk )
begin
    // for axi
    awvalid_r <= reset ? 1'b0 : axi_wr_go ? 1'b1 : axi_aw_ok ? 1'b0 : awvalid_r;
    wvalid_r  <= reset ? 1'd0 : axi_wr_go ? 1'b1 : axi_w_ok ? 1'b0 : wvalid_r;
    // for dbgm
    dvalid_r  <= reset ? 1'd0 : dbgm_go ? 1'b1 : dbgm_ok ? 1'b0 : dvalid_r;
    dbgm_wr_r <= reset ? 1'd0 : dbgm_go ? req_wr : dbgm_wr_r;
    dbgm_mask <= reset ? 1'd0 : dbgm_ok ? 1'b0 :  // is prior to dbgm_canc
    dbgm_canc ? 1'b1 : dbgm_mask;
    // for axi/dbgm
    ad_busy <= reset ? 1'd0 : ad_ok ? 1'b0 : req_ad ? 1'b1 : ad_busy;
    exc_r   <= reset ? 1'd0 : req_ad_go ? req_exc : exc_r;
    cache_r <= reset ? 1'd0 : req_ad_go ? cached : cache_r;
    size_r  <= reset ? 2'd0 : req_ad_go ? size : size_r;
    addr_r  <= reset ? 32'd0 : req_ad_go ? paddr : addr_r;
    wstrb_r <= reset ? {AXI_STRB{1'b0}} : req_ad_go ? wstrb_axi : wstrb_r;
    wdata_r <= reset ? {AXI_DATA{1'b0}} : req_ad_go ? wdata_axi : wdata_r;
end
assign axi_aw_wid   =  3'd0;
assign axi_awvalid  =  awvalid_r;
assign axi_awburst  =  1'b0;
assign axi_awexc    =  exc_r;
assign axi_awcache  =  cache_r;
assign axi_awsize   =  {1'b0, size_r};
assign axi_awaddr   =  addr_r;
assign axi_wvalid   =  wvalid_r;
assign axi_wstrb    =  wstrb_r;
assign axi_wdata    =  wdata_r;
assign axi_wlast    =  1'b1;
// End Axi Write

//------------------------------------------------------------//
//                      Access To Ljtag
//------------------------------------------------------------//
assign dbgm_req_valid  =  dvalid_r;
assign dbgm_req_wr     =  dbgm_wr_r;
assign dbgm_req_addr   =  addr_r;
assign dbgm_req_size   =  size_r;
assign dbgm_req_wdata  =  wdata_r[31:0];
// stall
assign dbgm_stall_axi  =  dvalid_r;
assign wr_stall_cd     =  ad_busy && cd_hit_wr;  // for cahceld
assign wr_stall_md     =  ad_busy && md_hit_wr;  // for memld
// End Access To Ljtag

//------------------------------------------------------------//
//                      Reponse To Core
//------------------------------------------------------------//
generate
    case (AXI_DATA)
        32: begin: gen_axi_rdata_32
            assign axi_rdata32 = axi_rdata;
        end
        64: begin: gen_axi_rdata_64
            assign axi_rdata32 = axi_rd_sel0[0] ? axi_rdata[63:32] : axi_rdata[31:0];
        end
        128: begin: gen_axi_rdata_128
            assign axi_rdata32 = {32{axi_rd_sel0 == 2'd0}} & axi_rdata[31 : 0] |
                                 {32{axi_rd_sel0 == 2'd1}} & axi_rdata[63 : 32] |
                                 {32{axi_rd_sel0 == 2'd2}} & axi_rdata[95 : 64] |
                                 {32{axi_rd_sel0 == 2'd3}} & axi_rdata[127:96];
        end
    endcase
endgenerate

// back to request
// for fetch, cd_ar_addr_ok is same as md_ar_addr_ok
assign cd_ar_addr_ok  =  cd_axi_araddr_ok;  // for cacheld
assign md_ar_addr_ok  =  md_axi_araddr_ok;  // for memld
assign aw_addr_ok     =  !ad_busy;
assign dbgm_addr_ok   =  !ad_busy && axi_rd_null;
assign rdata          =  dvalid_r ? dbgm_resp_data : axi_rdata32;
assign rdata_valid    =  dbgm_ok && !dbgm_wr_r && !dbgm_mask || axi_r_ok && !axi_rd_mask;
assign rdata_exok     =  axi_rvalid && axi_rresp[0];
assign rdata_err      =  axi_rvalid && axi_rresp[1];

assign rd_in_sysbus  =  !axi_rd_null || dvalid_r && !dbgm_wr_r;
assign wr_in_sysbus  =  ad_busy && !dvalid_r || dvalid_r && dbgm_wr_r;
assign axi_null      =  axi_rd_null && !ad_busy;
// End Reponse To Core

`ifdef OPEN132_ASSERT
// req
assert property (@(posedge clk) axi_r_ok && dbgm_ok |-> (1'b1 == 1'b0))
else begin
    $display("axi_r_ok and dbgm_ok Assert Error!!!");
    #2 $finish;
end
`endif
endmodule

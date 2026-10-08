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

`ifdef OPEN132_HAS_LJTAG
module ljtag_ihb #(
    parameter IHB_NUM = 1  // 1~15
) (
    input  wire           clk_g,
    input  wire           clk_dm,
    input  wire           sync_hresetn,
    input  wire           data_reset,
    input  wire [ 80: 0]  jtag_idu_ihb_req_bus,
    input  wire           debug_mode,
    input  wire [ 31: 0]  pc_m,
    input  wire [  7: 0]  asid,
    input  wire           ibs_can_set,

    output wire [ 31: 0]  idu_jtag_ihb_resp_bus,
    output wire           ihb_te_be,
    output wire           ihb_signal,
    output wire           ihb_debug
);

genvar i, j;

wire [1:0]  csr_lisa_plv;
wire        csr_watch_en;
wire [11:0] csr_off;
wire        csr_req_valid;
wire        csr_req_wr;
wire [31:0] csr_req_wdata;
wire [31:0] csr_wrmask;

assign {csr_lisa_plv,
        csr_watch_en,
        csr_off,
        csr_req_valid,
        csr_req_wr,
        csr_req_wdata,
        csr_wrmask} = jtag_idu_ihb_req_bus;

wire [31:0] csr_rdata;
assign idu_jtag_ihb_resp_bus = csr_rdata;

wire               off_ibs;
wire               off_ibn;
wire               off_addr;
wire               off_mask;
wire               off_ibasid;
wire               off_cfg;
wire [IHB_NUM-1:0] off_n;
wire [IHB_NUM-1:0] ihb_rw_allow;

assign off_ibs    = csr_req_valid && csr_off[6:0] == 7'h1;
assign off_ibn    = csr_req_valid && csr_off[6:0] == 7'h0;
assign off_addr   = csr_req_valid && csr_off[6:3] != 4'b0 && csr_off[2:0] == 3'h0;
assign off_mask   = csr_req_valid && csr_off[6:3] != 4'b0 && csr_off[2:0] == 3'h1;
assign off_ibasid = csr_req_valid && csr_off[6:3] != 4'b0 && csr_off[2:0] == 3'h3;
assign off_cfg    = csr_req_valid && csr_off[6:3] != 4'b0 && csr_off[2:0] == 3'h2;

generate
    for (i = 0; i < IHB_NUM; i = i + 1) begin: gen_off_n
        assign off_n[i] = csr_req_valid &&
                          csr_off[6:3] == (i[3:0] + 4'h2) &&
                          ihb_rw_allow[i];
    end
endgenerate

reg  [IHB_NUM-1:0] ibs_bs_n;
reg  [31:0] addr_n [IHB_NUM-1:0];
reg  [31:0] mask_n [IHB_NUM-1:0];
reg  [7:0] ibasid_n [IHB_NUM-1:0];
reg  [IHB_NUM-1:0] cfg_useasid_n;
reg  [IHB_NUM-1:0] cfg_iam_n;
reg  [IHB_NUM-1:0] cfg_status_n;
reg  [3:0] lisa_cfg_plv [IHB_NUM-1:0];
reg  [IHB_NUM-1:0] lisa_dsonly;

wire [IHB_NUM-1:0] cfg_watchen;
assign ihb_te_be    = |cfg_watchen;
assign ihb_rw_allow = {IHB_NUM{debug_mode}} | ~cfg_status_n;

wire [31:0] csr_ibs_rout;
wire [31:0] csr_ibn_rout;
wire [31:0] csr_addr_rout;
wire [31:0] csr_mask_rout;
wire [31:0] csr_ibasid_rout;
wire [31:0] csr_cfg_rout;
wire [31:0] ibs_bcn32;
wire [13:0] ibs_bs14;
wire [15:0] bs_n_tmp;

assign ibs_bcn32 = IHB_NUM;
assign bs_n_tmp  = {{(16-IHB_NUM){1'b0}}, ibs_bs_n};
assign ibs_bs14  = bs_n_tmp[13:0];

`GEN_2D_SEL_1D(IHB_NUM,32,addr_n,addr_n_T,off_n,csr_addr_rout)
`GEN_2D_SEL_1D(IHB_NUM,32,mask_n,mask_n_T,off_n,csr_mask_rout)

wire [7:0] csr_ibasid_only;
`GEN_2D_SEL_1D(IHB_NUM,8,ibasid_n,ibasid_n_T,off_n,csr_ibasid_only)

assign csr_ibs_rout = {18'd0, ibs_bs14};
assign csr_ibn_rout = {26'b0, ibs_bcn32[5:0]};
assign csr_ibasid_rout = {24'd0, csr_ibasid_only};

wire [3:0] csr_cfg_plv_only;
`GEN_2D_SEL_1D(IHB_NUM,4,lisa_cfg_plv,lisa_cfg_plv_T,off_n,csr_cfg_plv_only)

wire csr_cfg_status;
wire csr_cfg_useasid;
wire csr_cfg_iam;

assign csr_cfg_status  = |(cfg_status_n  & off_n);
assign csr_cfg_useasid = |(cfg_useasid_n & off_n);
assign csr_cfg_iam     = |(cfg_iam_n     & off_n);
assign csr_cfg_rout    = {15'd0,
                          csr_cfg_iam,
                          8'd0,
                          csr_cfg_useasid,
                          2'd0,
                          csr_cfg_plv_only,
                          csr_cfg_status};

assign csr_rdata = {32{off_ibs}}    & csr_ibs_rout |
                   {32{off_ibn}}    & csr_ibn_rout |
                   {32{off_addr}}   & csr_addr_rout |
                   {32{off_mask}}   & csr_mask_rout |
                   {32{off_ibasid}} & csr_ibasid_rout |
                   {32{off_cfg}}    & csr_cfg_rout;

wire [IHB_NUM-1:0] hit;
wire [IHB_NUM-1:0] hit_ex;
wire [IHB_NUM-1:0] hit_ex_debug;
wire [IHB_NUM-1:0] hit_trigger;

generate
    for (i = 0; i < IHB_NUM; i = i + 1) begin: gen_ihb_hit
        assign hit[i] = (!cfg_useasid_n[i] || asid == ibasid_n[i]) &&
                        (((~mask_n[i] & (pc_m ^ addr_n[i])) == 32'd0) ^
                         cfg_iam_n[i]);
    end
endgenerate

assign hit_ex       = hit & cfg_watchen;
assign hit_ex_debug = hit_ex & cfg_status_n;
assign hit_trigger  = hit_ex;
assign ihb_signal   = (|hit_ex) && !debug_mode;
assign ihb_debug    = |hit_ex_debug;

wire [3:0] la_plv;
assign la_plv[3]   = csr_lisa_plv == 2'h3;
assign la_plv[2:1] = 2'b0;
assign la_plv[0]   = csr_lisa_plv == 2'h0;

generate
    for (i = 0; i < IHB_NUM; i = i + 1) begin: lisa_cfg_be
        assign cfg_watchen[i] = (|(la_plv & lisa_cfg_plv[i])) &&
                                (cfg_status_n[i] || csr_watch_en);
    end
endgenerate

wire        ihb_wen;
wire [31:0] ihb_wdata;
assign ihb_wen   = csr_req_wr;
assign ihb_wdata = csr_req_wdata;

generate
    for (i = 0; i < IHB_NUM; i = i + 1) begin: gen_ihb
        always @(posedge clk_g) begin
            if (data_reset) begin
                ibs_bs_n[i] <= 1'b0;
            end
            else if (ihb_wen && off_ibs && ihb_wdata[i] && csr_wrmask[i]) begin
                ibs_bs_n[i] <= 1'b0;
            end
            else if (ibs_can_set && hit_trigger[i]) begin
                ibs_bs_n[i] <= 1'b1;
            end
        end

        always @(posedge clk_dm) begin
            if (data_reset) begin
                addr_n[i] <= 32'd0;
            end
            else if (ihb_wen && off_addr && off_n[i]) begin
                addr_n[i] <= csr_wrmask & ihb_wdata |
                             ~csr_wrmask & addr_n[i];
            end
        end

        always @(posedge clk_dm) begin
            if (data_reset) begin
                mask_n[i] <= 32'd0;
            end
            else if (ihb_wen && off_mask && off_n[i]) begin
                mask_n[i] <= csr_wrmask & ihb_wdata |
                             ~csr_wrmask & mask_n[i];
            end
        end

        always @(posedge clk_dm) begin
            if (data_reset) begin
                ibasid_n[i] <= 8'd0;
            end
            else if (ihb_wen && off_ibasid && off_n[i]) begin
                ibasid_n[i] <= csr_wrmask[7:0] & ihb_wdata[7:0] |
                               ~csr_wrmask[7:0] & ibasid_n[i];
            end
        end

        always @(posedge clk_dm) begin
            if (data_reset) begin
                cfg_useasid_n[i] <= 1'b0;
                cfg_iam_n[i]     <= 1'b0;
            end
            else if (ihb_wen && off_cfg && off_n[i]) begin
                cfg_useasid_n[i] <= csr_wrmask[7] & ihb_wdata[7] |
                                    ~csr_wrmask[7] & cfg_useasid_n[i];
                cfg_iam_n[i] <= csr_wrmask[16] & ihb_wdata[16] |
                                ~csr_wrmask[16] & cfg_iam_n[i];
            end

            if (!sync_hresetn) begin
                cfg_status_n[i] <= 1'b0;
                lisa_cfg_plv[i] <= 4'd0;
            end
            else if (ihb_wen && off_cfg && off_n[i]) begin
                lisa_cfg_plv[i] <= csr_wrmask[4:1] & ihb_wdata[4:1] |
                                   ~csr_wrmask[4:1] & lisa_cfg_plv[i];
                if (debug_mode) begin
                    cfg_status_n[i] <= csr_wrmask[0] & ihb_wdata[0] |
                                       ~csr_wrmask[0] & cfg_status_n[i];
                end
            end
        end
    end
endgenerate

endmodule
`endif

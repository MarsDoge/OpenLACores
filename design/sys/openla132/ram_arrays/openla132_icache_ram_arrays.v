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

`define RAM_TAGV_WAY 1  //1/2/4 way to one ram
`define RAM_DATA_WAY 1  //1/2/4 way to one ram

module openla132_icache_ram_arrays #(
    parameter HAS_ICC       = 0,              //0 or 1
    parameter ICC_SET_ASSOC = 2,              //1/2/4 way set associative
    parameter ICC_WAYSIZE   = 4 * (2 ** 10),  //1/2/4/8/16 KB Size/way
    parameter ICC_ECC_BITS  = 1               //1/7/8/9 bits, for no ecc, 32+7, 64+8, 128+9
) (
    input  wire                                           clk,
    input  wire                                           test_mode,
    input  wire [ `OPEN132_ICC_RAM_TAGV_REQ_BUS_WD-1: 0]  icc_ram_tagv_req_bus,
    input  wire [ `OPEN132_ICC_RAM_DATA_REQ_BUS_WD-1: 0]  icc_ram_data_req_bus,
    input  wire [ `OPEN132_ICC_RAM_LRUD_REQ_BUS_WD-1: 0]  icc_ram_lrud_req_bus,  //write by bit
    output wire [`OPEN132_ICC_RAM_TAGV_RESP_BUS_WD-1: 0]  icc_ram_tagv_resp_bus,
    output wire [`OPEN132_ICC_RAM_DATA_RESP_BUS_WD-1: 0]  icc_ram_data_resp_bus,
    output wire [`OPEN132_ICC_RAM_LRUD_RESP_BUS_WD-1: 0]  icc_ram_lrud_resp_bus
);

localparam SET_ASSOC  = `OPEN132_ICC_SET_ASSOC;
localparam WAYSIZE    = `OPEN132_ICC_WAYSIZE;

// Cache geometry
localparam INDEX_BITS  = $clog2(WAYSIZE) - 5;
localparam TAG_BITS    = 32 - INDEX_BITS - 5;
localparam TAGV_BITS   = TAG_BITS + 1 + (SET_ASSOC + 2) / 4;  //1 bit lock only for 2/4 ways
localparam RAM_TAGV_WD = TAGV_BITS * SET_ASSOC;

// DATA
localparam DATA_BANK_STRB = 4 * SET_ASSOC;
localparam BANK_WD        = 32 * SET_ASSOC;

// LRUD
localparam LRU_BITS    = SET_ASSOC * SET_ASSOC / 2 - SET_ASSOC / 2;  //4-ways:6bit; 2-ways:1bit; 1-way:0bit
localparam LRUD_RAM_WD = LRU_BITS + SET_ASSOC;  //dirty; 1 bit per way

// ECC
localparam ECC_BITS = `OPEN132_ICC_ECC_BITS;

// ECC
// ECC_BITS    ECC_WAY    ECC_SET   ECC_BANK_BITS
//   0          1         assoc           0
//   7          1         assoc         7*assoc
//   8          2        assoc/2        8 or 16
//   9          4        assoc/4          9
localparam TAGV_ECC_WAY  = ECC_BITS < 7 ? `RAM_TAGV_WAY : 2 ** (ECC_BITS - 7);
localparam TAGV_ECC_SET  = SET_ASSOC / TAGV_ECC_WAY;

localparam DATA_ECC_WAY  = ECC_BITS < 7 ? `RAM_DATA_WAY : 2 ** (ECC_BITS - 7);
localparam DATA_ECC_SET  = SET_ASSOC / DATA_ECC_WAY;

localparam ECC_BANK_BITS = (DATA_ECC_SET * ECC_BITS);  //TAGV DATA has same ECC_BANK_BITS

localparam RAM_TAGV_WD_ECC = (ECC_BITS < 7) ? RAM_TAGV_WD : RAM_TAGV_WD + ECC_BANK_BITS;
localparam BANK_WD_ECC     = (ECC_BITS < 7) ? BANK_WD : BANK_WD + ECC_BANK_BITS;

localparam TAGV_WEN = ECC_BITS < 7 ? SET_ASSOC     : TAGV_ECC_SET;
localparam BANK_WEN = ECC_BITS < 7 ? SET_ASSOC * 4 : DATA_ECC_SET;

localparam ONE_BANK_REQ_BUS_WD = SET_ASSOC + BANK_WEN + INDEX_BITS + BANK_WD_ECC;

// Primitive RAM
localparam TAGV_ECCSET_BITS = TAGV_BITS * TAGV_ECC_WAY;
localparam DATA_ECCSET_BITS = 32 * DATA_ECC_WAY;
localparam PM_TAGV_BITS     = (ECC_BITS < 7) ? TAGV_ECCSET_BITS : (TAGV_ECCSET_BITS + ECC_BITS);
localparam PM_DATA_BITS     = (ECC_BITS < 7) ? DATA_ECCSET_BITS : (DATA_ECCSET_BITS + ECC_BITS);
localparam PM_DATA_WEN      = (ECC_BITS < 7) ? 4 * DATA_ECC_WAY : 1;

genvar i;
genvar j;
genvar k;
genvar l;
genvar m;

//============================================================//
//                     Wire Declarations
//============================================================//

// Constant bank index signals
wire [  2: 0] num [7:0];

// Tag and valid RAM signals
wire [       SET_ASSOC-1: 0] ram_tagv_en;
wire [        TAGV_WEN-1: 0] ram_tagv_wen;
wire [      INDEX_BITS-1: 0] ram_tagv_addr;
wire [     RAM_TAGV_WD-1: 0] ram_tagv_wdata;
wire [     RAM_TAGV_WD-1: 0] ram_tagv_rdata;
wire [TAGV_ECCSET_BITS-1: 0] ram_tagv_wdata_eccset [TAGV_ECC_SET-1:0];
wire [TAGV_ECCSET_BITS-1: 0] ram_tagv_rdata_eccset [TAGV_ECC_SET-1:0];
wire [   ECC_BANK_BITS-1: 0] ram_tagv_wecc;
wire [   ECC_BANK_BITS-1: 0] ram_tagv_recc;  //all ways
wire [        ECC_BITS-1: 0] ram_tagv_wecc_eccset  [TAGV_ECC_SET-1:0];
wire [        ECC_BITS-1: 0] ram_tagv_recc_eccset  [TAGV_ECC_SET-1:0];  //all ways
wire [ RAM_TAGV_WD_ECC-1: 0] ram_tagv_wall;  //data+ecc
wire [ RAM_TAGV_WD_ECC-1: 0] ram_tagv_rall;
wire [    TAGV_ECC_SET-1: 0] pm_ram_tv_en;
wire [    TAGV_ECC_SET-1: 0] pm_ram_tv_wen;
wire [    PM_TAGV_BITS-1: 0] pm_ram_tv_wall        [TAGV_ECC_SET-1:0];
wire [    PM_TAGV_BITS-1: 0] pm_ram_tv_rall        [TAGV_ECC_SET-1:0];
wire [        ECC_BITS-1: 0] pm_ram_tv_old_ecc     [TAGV_ECC_SET-1:0];
wire [        ECC_BITS-1: 0] pm_ram_tv_new_ecc     [TAGV_ECC_SET-1:0];
wire                         tag_clk;

// Data RAM signals
wire [       SET_ASSOC-1: 0] ram_data_en           [7:0];
wire [        BANK_WEN-1: 0] ram_data_wen          [7:0];
wire [      INDEX_BITS-1: 0] ram_data_addr         [7:0];
wire [         BANK_WD-1: 0] ram_data_wdata        [7:0];
wire [         BANK_WD-1: 0] ram_data_rdata        [7:0];
wire [DATA_ECCSET_BITS-1: 0] ram_data_wdata_eccset [7:0][DATA_ECC_SET-1:0];
wire [DATA_ECCSET_BITS-1: 0] ram_data_rdata_eccset [7:0][DATA_ECC_SET-1:0];
wire [   ECC_BANK_BITS-1: 0] ram_data_wecc         [7:0];
wire [   ECC_BANK_BITS-1: 0] ram_data_recc         [7:0];
wire [        ECC_BITS-1: 0] ram_data_wecc_eccset  [7:0][DATA_ECC_SET-1:0];
wire [        ECC_BITS-1: 0] ram_data_recc_eccset  [7:0][DATA_ECC_SET-1:0];
wire [     BANK_WD_ECC-1: 0] ram_data_wall         [7:0];
wire [     BANK_WD_ECC-1: 0] ram_data_rall         [7:0];
wire [    DATA_ECC_SET-1: 0] pm_ram_d_en           [7:0];
wire [     PM_DATA_WEN-1: 0] pm_ram_d_wen          [7:0][DATA_ECC_SET-1:0];
wire [      INDEX_BITS-1: 0] pm_ram_d_addr         [7:0];
wire [    PM_DATA_BITS-1: 0] pm_ram_d_wall         [7:0][DATA_ECC_SET-1:0];
wire [    PM_DATA_BITS-1: 0] pm_ram_d_rall         [7:0][DATA_ECC_SET-1:0];
wire [        ECC_BITS-1: 0] pm_ram_d_old_ecc      [7:0][DATA_ECC_SET-1:0];
wire [        ECC_BITS-1: 0] pm_ram_d_new_ecc      [7:0][DATA_ECC_SET-1:0];
wire [                 7: 0] data_clk;

// LRU and dirty RAM signals
wire                    ram_lrud_en;
wire [LRUD_RAM_WD-1: 0] ram_lrud_wen;
wire [ INDEX_BITS-1: 0] ram_lrud_addr;
wire [LRUD_RAM_WD-1: 0] ram_lrud_wdata;
wire [LRUD_RAM_WD-1: 0] ram_lrud_rdata;
wire                    lrud_clk;

//============================================================//
//                    Module Implementation
//============================================================//

//------------------------------------------------------------//
//                    Constant Bank Indexes
//------------------------------------------------------------//

assign num[0]  =  3'd0;
assign num[1]  =  3'd1;
assign num[2]  =  3'd2;
assign num[3]  =  3'd3;
assign num[4]  =  3'd4;
assign num[5]  =  3'd5;
assign num[6]  =  3'd6;
assign num[7]  =  3'd7;
//------------------------------------------------------------//
//                  Tag and Valid RAM Array
//------------------------------------------------------------//

// ram0: way0/way1
// Data packing
`GEN_1D_TO_2D(TAGV_ECC_SET, TAGV_ECCSET_BITS, ram_tagv_wdata, ram_tagv_wdata_eccset)
`GEN_2D_TO_1D(TAGV_ECC_SET, TAGV_ECCSET_BITS, ram_tagv_rdata_eccset, ram_tagv_rdata)
// ECC packing
`GEN_1D_TO_2D(TAGV_ECC_SET, ECC_BITS, ram_tagv_wecc, ram_tagv_wecc_eccset)
`GEN_2D_TO_1D(TAGV_ECC_SET, ECC_BITS, ram_tagv_recc_eccset, ram_tagv_recc)

// Data and ECC packing
generate
if(ECC_BITS >= 7) begin : gen_tagv_ram_has_ecc
    assign ram_tagv_rall                    =  {ram_tagv_rdata, ram_tagv_recc};
    assign {ram_tagv_wdata, ram_tagv_wecc}  =  ram_tagv_wall;
end
else begin : gen_tagv_ram_no_ecc
    assign ram_tagv_rall   =  {ram_tagv_rdata};
    assign ram_tagv_wdata  =  ram_tagv_wall;
    assign ram_tagv_wecc   =  {ECC_BANK_BITS{1'b0}};
end
endgenerate

// RAM bus mapping
assign icc_ram_tagv_resp_bus                                      =  ram_tagv_rall;
assign {ram_tagv_en, ram_tagv_wen, ram_tagv_addr, ram_tagv_wall}  =  icc_ram_tagv_req_bus;

// ECC grouping
// ram: (24+24)*2^8
`GEN_COMPRESS_OR(TAGV_ECC_SET, TAGV_ECC_WAY, ram_tagv_en, pm_ram_tv_en)
`GEN_COMPRESS_OR(TAGV_ECC_SET, (TAGV_WEN / TAGV_ECC_SET), ram_tagv_wen, pm_ram_tv_wen)

openla132_cg_cell_wrap x_open132_cg_cell_wrap_tag (
    .clock_in  (clk          ),
    .enable    (|pm_ram_tv_en),
    .scan_en   (test_mode    ),
    .clock_out (tag_clk      )
);

generate
for (i = 0; i < TAGV_ECC_SET; i = i + 1) begin : gen_tagv_ram
    if(ECC_BITS >= 7) begin : gen_tagv_wdata_has_ecc
        assign pm_ram_tv_wall[i]                                    =  {ram_tagv_wdata_eccset[i], ram_tagv_wecc_eccset[i]};
        assign {ram_tagv_rdata_eccset[i], ram_tagv_recc_eccset[i]}  =  pm_ram_tv_rall[i];
    end
    else begin : gen_tagv_wdata_no_ecc
        assign pm_ram_tv_wall[i]           =  {ram_tagv_wdata_eccset[i]};
        assign {ram_tagv_rdata_eccset[i]}  =  pm_ram_tv_rall[i];
    end
    openla132_tag_ram #(
        .ADDR_WD (INDEX_BITS  ),
        .DATA_WD (PM_TAGV_BITS),
        .WEN_WD  (1           )
    ) x_open132_tag_ram (
        .clk   (tag_clk          ),
        .en    (pm_ram_tv_en[i]  ),
        .wen   (pm_ram_tv_wen[i] ),
        .addr  (ram_tagv_addr    ),  //
        .wdata (pm_ram_tv_wall[i]),
        .rdata (pm_ram_tv_rall[i])
    );
end
endgenerate
//------------------------------------------------------------//
//                       Data RAM Array
//------------------------------------------------------------//

// Data packing
`GEN_2D_TO_3D(8, DATA_ECC_SET, DATA_ECCSET_BITS, ram_data_wdata, ram_data_wdata_eccset)
`GEN_3D_TO_2D(8, DATA_ECC_SET, DATA_ECCSET_BITS, ram_data_rdata_eccset, ram_data_rdata)

// ECC packing
`GEN_2D_TO_3D(8, DATA_ECC_SET, ECC_BITS, ram_data_wecc, ram_data_wecc_eccset)
`GEN_3D_TO_2D(8, DATA_ECC_SET, ECC_BITS, ram_data_recc_eccset, ram_data_recc)

// Data and ECC packing
generate
for (i = 0; i < 8; i = i + 1) begin : gen_data_ram_data_ecc_all
    if(ECC_BITS >= 7) begin : gen_data_ecc_all_has_ecc
        assign ram_data_rall[i]                       =  {ram_data_rdata[i], ram_data_recc[i]};
        assign {ram_data_wdata[i], ram_data_wecc[i]}  =  ram_data_wall[i];
    end
    else begin : gen_data_ecc_all_no_ecc
        assign ram_data_rall[i]   =  {ram_data_rdata[i]};
        assign ram_data_wdata[i]  =  ram_data_wall[i];
        assign ram_data_wecc[i]   =  {ECC_BANK_BITS{1'b0}};
    end
end
endgenerate

// RAM bus mapping
`GEN_2D_TO_1D(8, BANK_WD_ECC, ram_data_rall, icc_ram_data_resp_bus)
generate
for (j = 0; j < 8; j = j + 1) begin
    assign {ram_data_en[j], ram_data_wen[j], ram_data_addr[j], ram_data_wall[j]}  =  icc_ram_data_req_bus[ONE_BANK_REQ_BUS_WD*j+:ONE_BANK_REQ_BUS_WD];
end
endgenerate

// 2-ways, 16KB/way
// 8 bank:
// for one bank, 2 rams:
// ram0: way0/way1
// ram1: way2/way3
// one ram: 64*2^8
generate
for (k = 0; k < 8; k = k + 1) begin : data_bank
    assign pm_ram_d_addr[k]  =  ram_data_addr[k];
    for (i = 0; i < DATA_ECC_SET; i = i + 1) begin
        assign pm_ram_d_en[k][i]   =  |ram_data_en[k][i*DATA_ECC_WAY+:DATA_ECC_WAY];
        assign pm_ram_d_wen[k][i]  =  ram_data_wen[k][i*PM_DATA_WEN+:PM_DATA_WEN];  //
        if(ECC_BITS >= 7) begin : gen_data_ram_wall_has_ecc
            assign pm_ram_d_wall[k][i]                                        =  {ram_data_wdata_eccset[k][i], ram_data_wecc_eccset[k][i]};
            assign {ram_data_rdata_eccset[k][i], ram_data_recc_eccset[k][i]}  =  pm_ram_d_rall[k][i];
        end
        else begin : gen_data_ram_wall_no_ecc
            assign pm_ram_d_wall[k][i]            =  ram_data_wdata_eccset[k][i];
            assign {ram_data_rdata_eccset[k][i]}  =  pm_ram_d_rall[k][i];
        end
    end
    openla132_cg_cell_wrap x_open132_cg_cell_wrap_data (
        .clock_in  (clk            ),
        .enable    (|pm_ram_d_en[k]),
        .scan_en   (test_mode      ),
        .clock_out (data_clk[k]    )
    );


end
endgenerate

// Primitive data RAMs

generate
for (l = 0; l < 8; l = l + 1) begin : primitive_ram_data_bank
    for (m = 0; m < DATA_ECC_SET; m = m + 1) begin : icache_ram_data_bank
        openla132_data_ram #(
            .ADDR_WD (INDEX_BITS  ),
            .DATA_WD (PM_DATA_BITS),
            .WEN_WD  (PM_DATA_WEN )
        ) x_open132_data_ram (
            .clk   (data_clk[l]        ),
            .en    (pm_ram_d_en[l][m]  ),
            .wen   (pm_ram_d_wen[l][m] ),
            .addr  (pm_ram_d_addr[l]   ),
            .wdata (pm_ram_d_wall[l][m]),
            .rdata (pm_ram_d_rall[l][m])
        );
    end
end
endgenerate
//------------------------------------------------------------//
//                    LRU and Dirty RAM Array
//------------------------------------------------------------//

// RAM bus mapping
assign icc_ram_lrud_resp_bus                                       =  ram_lrud_rdata;
assign {ram_lrud_en, ram_lrud_wen, ram_lrud_addr, ram_lrud_wdata}  =  icc_ram_lrud_req_bus;

openla132_cg_cell_wrap x_open132_cg_cell_wrap_lrud (
    .clock_in  (clk         ),
    .enable    (|ram_lrud_en),
    .scan_en   (test_mode   ),
    .clock_out (lrud_clk    )
);


openla132_lrud_ram #(
    .ADDR_WD (INDEX_BITS ),
    .DATA_WD (LRUD_RAM_WD),
    .WEN_WD  (LRUD_RAM_WD)
) x_open132_lrud_ram (
    .clk   (lrud_clk      ),
    .en    (ram_lrud_en   ),
    .wen   (ram_lrud_wen  ),
    .addr  (ram_lrud_addr ),  //
    .wdata (ram_lrud_wdata),
    .rdata (ram_lrud_rdata)
);
endmodule  // openla132_icache_ram_arrays

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

module exu_qmul (
    input  wire           clk,
    input  wire           reset,
    input  wire           data_reset,
    input  wire           de_cancel,
    input  wire           mem_cancel,

    input  wire           de_validout,
    input  wire [  8: 0]  de_pp_neg,
    input  wire [  8: 0]  de_pp_e,
    input  wire [  8: 0]  de_sel_m,
    input  wire [  8: 0]  de_sel_2m,
    input  wire           de_half_size,
    input  wire [ 32: 0]  mem_opa_33b,
    output wire           mem_full_1st,  // feedback to boothenc @de stage
    output wire           mem_opa_msb,

    input  wire           rtu_lsu_allowin,
    output wire           mem_valid,
    output wire           mem_complete,
    output wire           mem_half,
    output wire           mem_full_2nd,

    input  wire [ 36: 0]  wb_acc_res_52_16,
    output wire           mem_full_1st_out,
    output wire [ 51: 0]  mem_wallace_s,
    output wire [ 51: 0]  mem_wallace_c
);

localparam SM_IDLE  = 2'b00;
localparam SM_HALF  = 2'b01;
localparam SM_FULL1 = 2'b10;
localparam SM_FULL2 = 2'b11;

//============================================================//
//                     Regs Declarations
//============================================================//

reg [  1: 0] mem_sm;

reg [  8: 0] mem_pp_neg;
reg [  8: 0] mem_pp_e;
reg [  8: 0] mem_sel_m;
reg [  8: 0] mem_sel_2m;

//============================================================//
//                     Wire Declarations
//============================================================//

wire [ 32: 0] opa_wallace;
wire [  8: 0] pp_neg_wallace;
wire [  8: 0] pp_e_wallace;
wire [  8: 0] sel_m_wallace;
wire [  8: 0] sel_2m_wallace;
wire          full_2nd_wallace;
wire [ 36: 0] acc_res_52_16_wallace;
wire [ 51: 0] wallace_s_wallace;
wire [ 51: 0] wallace_c_wallace;

//============================================================//
//                    Module Implementation
//============================================================//

// synopsys sync_set_reset "reset"

// FSM
// Instance Boundary Alias Mapping
// x_exu_wallace9_2

assign opa_wallace            =  mem_opa_33b;
assign pp_neg_wallace         =  mem_pp_neg;
assign pp_e_wallace           =  mem_pp_e;
assign sel_m_wallace          =  mem_sel_m;
assign sel_2m_wallace         =  mem_sel_2m;
assign full_2nd_wallace       =  mem_full_2nd;
assign acc_res_52_16_wallace  =  wb_acc_res_52_16;
assign mem_wallace_s          =  wallace_s_wallace;
assign mem_wallace_c          =  wallace_c_wallace;

always @ ( posedge clk )
begin
    if(reset || mem_cancel) begin
        mem_sm <= SM_IDLE;
    end
    else if(de_validout) begin
        mem_sm <= de_cancel ? SM_IDLE : de_half_size ? SM_HALF : SM_FULL1;
    end
    else if(mem_sm != SM_IDLE && rtu_lsu_allowin) begin
        mem_sm <= (mem_sm == SM_HALF || mem_sm == SM_FULL2) ? SM_IDLE : SM_FULL2;
    end
end

assign mem_valid     =  mem_sm != SM_IDLE;
assign mem_half      =  mem_sm == SM_HALF;
assign mem_full_1st  =  mem_sm == SM_FULL1;
assign mem_full_2nd  =  mem_sm == SM_FULL2;
assign mem_complete  =  mem_half || mem_full_2nd;

always @ ( posedge clk )
begin
    if(data_reset) begin
        mem_pp_neg <= 9'd0;
        mem_pp_e   <= 9'd0;
        mem_sel_m  <= 9'd0;
        mem_sel_2m <= 9'd0;
    end
    else if(de_validout || mem_full_1st_out) begin
        mem_pp_neg <= de_pp_neg;
        mem_pp_e   <= de_pp_e;
        mem_sel_m  <= de_sel_m;
        mem_sel_2m <= de_sel_2m;
    end
end

assign mem_opa_msb  =  mem_opa_33b[32];

exu_wallace9_2 x_exu_wallace9_2 (
    .opa           (opa_wallace          ),  // I
    .pp_neg        (pp_neg_wallace       ),  // I
    .pp_e          (pp_e_wallace         ),  // I
    .sel_m         (sel_m_wallace        ),  // I
    .sel_2m        (sel_2m_wallace       ),  // I
    .full_2nd      (full_2nd_wallace     ),  // I
    .acc_res_52_16 (acc_res_52_16_wallace),  // I
    .wallace_s     (wallace_s_wallace    ),  // O
    .wallace_c     (wallace_c_wallace    )   // O
);

assign mem_full_1st_out  =  mem_full_1st && rtu_lsu_allowin;

endmodule  // exu_qmul

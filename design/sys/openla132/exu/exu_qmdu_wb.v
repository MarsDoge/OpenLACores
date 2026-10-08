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

module exu_qmdu_wb
(
    input         clk,
    input         data_reset,

    input         rtu_lsu_allowin,
    input         mem_validout,
    input         mem_divide_op,
    input         mem_mul_half,
    input         mem_mul_full_2nd,
    input         mem_mul_full_1st_out,
    input  [51:0] mem_res_0,
    input  [51:0] mem_res_1,
    input         mem_div_quot_neg,
    input         mem_div_rem_neg,
    input         sel_hl,

    input         wb_dest_gpr,
    output [36:0] wb_acc_res_52_16,
    output [31:0] exu_rtu_value ,
    input  [`OPEN132_WB2MDU_APP_BUS-1:0] rtu_exu_app_bus
);

reg         wb_divide_op;
reg         wb_mul_half;
reg         wb_mul_full_2nd;
reg  [51:0] wb_res_0;
reg  [51:0] wb_res_1;
reg         wb_div_quot_neg;
reg         wb_div_rem_neg;

wire [63:0] acc_a;
wire [63:0] acc_b;
wire [63:0] acc_c;
wire [63:0] sum;
wire [63:0] carry;
wire [63:0] acc_res;

always @(posedge clk)
begin
    if (data_reset)
    begin
        wb_divide_op    <= 1'd0;
        wb_mul_half     <= 1'd0;
        wb_mul_full_2nd <= 1'd0;
        wb_res_0        <= 52'd0;
        wb_res_1        <= 52'd0;
        wb_div_quot_neg <= 1'd0;
        wb_div_rem_neg  <= 1'd0;
    end
    else if (mem_validout || mem_mul_full_1st_out)
    begin
        wb_divide_op    <= mem_divide_op;
        wb_mul_half     <= mem_mul_half;
        wb_mul_full_2nd <= mem_mul_full_2nd;
        wb_res_0        <= mem_res_0;
        wb_res_1        <= mem_res_1;
        wb_div_quot_neg <= mem_div_quot_neg;
        wb_div_rem_neg  <= mem_div_rem_neg;
    end
end

reg [15:0] wb_acc_res_15_0;
always @(posedge clk)
begin
    if (rtu_lsu_allowin)
    begin
        if(mem_mul_full_2nd)
        begin
            wb_acc_res_15_0 <= acc_res[15:0];
        end
    end
end

assign acc_a = wb_mul_full_2nd              ? {wb_res_0[47:0], wb_acc_res_15_0}
                                            : {{12{wb_mul_half}}, wb_res_0[51:0]};
assign acc_b = wb_mul_full_2nd|wb_divide_op ? {wb_res_1[46:0],1'b0,15'b0,1'b0}
                                            : {11'b0,     wb_res_1[51:0],1'b0};
assign acc_c = {64{wb_divide_op}} & {31'b0, wb_div_rem_neg, 31'b0, wb_div_quot_neg};

generate
  genvar i;
  for (i=0; i<64; i=i+1)
  begin : gen_for_acc
    exu_csa3_2 csa
        (
        .in ({acc_c[i], acc_b[i], acc_a[i]} ), //I
        .s  (sum[i]                         ), //O
        .c  (carry[i]                       )  //O
        );
  end
endgenerate

exu_simd_add64 inst_simd_add64
        (
        .a       (sum[63:0]         ), //I
        .b       ({carry[62:0],1'b0}), //I
        .width_w (wb_divide_op      ), //I
        .sum     (acc_res           )  //O
        );

assign wb_acc_res_52_16 = acc_res[52:16];

assign exu_rtu_value = sel_hl            ? acc_res[63:32] :
                                          acc_res[31: 0] ;

//--------------------{app-specific}end--------------------------//

`ifndef OPEN132_APP_SPEC
wire [`OPEN132_WB2MDU_APP_BUS-1:0] wb2mdu_app_bus_nc;
assign wb2mdu_app_bus_nc = rtu_exu_app_bus;
wire   wb_dest_gpr_nc    = wb_dest_gpr;
`endif
//--------------------{app-specific}end--------------------------//
endmodule //exu_qmdu_wb

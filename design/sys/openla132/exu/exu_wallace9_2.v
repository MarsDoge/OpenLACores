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

module exu_wallace9_2
(
    input  [32:0] opa,
    input  [ 8:0] pp_neg,
    input  [ 8:0] pp_e,
    input  [ 8:0] sel_m,
    input  [ 8:0] sel_2m,
    input         full_2nd,
    input  [36:0] acc_res_52_16,
    output [51:0] wallace_s,
    output [51:0] wallace_c
);

wire [33:0] pp_m[8:0];
wire [36:0] pp0;
wire [35:0] pp7;
wire [35:0] pp8;

wire [51:0] add_pp_row[8:0];
wire [ 8:0] add_pp_col[51:0];

generate
  genvar i;
  for (i=0; i<=8; i=i+1)
  begin : gen_for_select_pp
    exu_booth_pp_sel inst(.opa(opa),.pp_neg(pp_neg[i]),.sel_m(sel_m[i]),.sel_2m(sel_2m[i]),.pp_m(pp_m[i]));
  end
endgenerate

assign pp0 = full_2nd ? acc_res_52_16 : {pp_e[0], ~pp_e[0], ~pp_e[0], pp_m[0]};
assign pp7 = {~full_2nd,           pp_e[7], pp_m[7]};
assign pp8 = {~full_2nd, ~full_2nd&pp_e[8], pp_m[8]};

assign add_pp_row[0] = {15'b0, pp0                                           };
assign add_pp_row[1] = {14'b0, 1'b1, pp_e[1], pp_m[1], 1'b0, pp_neg[0]       };
assign add_pp_row[2] = {12'b0, 1'b1, pp_e[2], pp_m[2], 1'b0, pp_neg[1],  2'b0};
assign add_pp_row[3] = {10'b0, 1'b1, pp_e[3], pp_m[3], 1'b0, pp_neg[2],  4'b0};
assign add_pp_row[4] = { 8'b0, 1'b1, pp_e[4], pp_m[4], 1'b0, pp_neg[3],  6'b0};
assign add_pp_row[5] = { 6'b0, 1'b1, pp_e[5], pp_m[5], 1'b0, pp_neg[4],  8'b0};
assign add_pp_row[6] = { 4'b0, 1'b1, pp_e[6], pp_m[6], 1'b0, pp_neg[5], 10'b0};
assign add_pp_row[7] = { 2'b0, pp7,                    1'b0, pp_neg[6], 12'b0};
assign add_pp_row[8] = {       pp8,                    1'b0, pp_neg[7], 14'b0};


// partial product transpose
generate
  genvar row, col;
  for (row=0; row<=8; row=row+1)
  begin : gen_for_pp_transpose_row
    for (col=0; col<=51; col=col+1)
    begin : gen_for_pp_transpose_col
        assign add_pp_col[col][row] = add_pp_row[row][col];
    end
  end
endgenerate


wire [5:0] cin [52:0];
wire [5:0] cout[51:0];

wire [51:0] wallace_c_tmp;
assign cin[0] = 6'b0;
generate
  genvar k;
  for (k=0; k<=51; k=k+1)
  begin : gen_for_wallace_tree
    exu_csa9_2 inst(.in(add_pp_col[k]),.ci(cin[k]),.s(wallace_s[k]),.c(wallace_c_tmp[k]),.co(cout[k]));
    assign cin[k+1] = cout[k];
  end
endgenerate
assign wallace_c[50:0] = wallace_c_tmp[50:0];
assign wallace_c[51]   = wallace_c_tmp[51] | cout[51][5];//the last cout maybe in cou[51][5] or c_tmp[51];

endmodule //exu_wallace9_2

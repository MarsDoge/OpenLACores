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

module exu_booth_enc19
(
    input  [18:0] opb,
    input         opa_neg,
    output [ 8:0] pp_neg,
    output [ 8:0] pp_e,
    output [ 8:0] sel_m,
    output [ 8:0] sel_2m
);
// We signed/unsigned extend multiplicand to 33 bits, and only consider signed
// mulitply later. But for the last pass of wallace tree compressor(i.e. first
// pass for half size and second pass for full size), we should change partial
// product -0 to +0, because -0 needs to add an extra 1. When we doing sum of
// {HI,LO}+PP_S+PP_C at WB stage, there is no place to insert this extra 1. So
// the booth encoder looks a little different than the classical one.

// for all partial product, -0 is treated as +0
generate
  genvar i;
  for (i=0; i<=8; i=i+1) begin : gen_for_boothenc_16b
    exu_booth_enc3 inst(.opb(opb[2*i+2:2*i]),.opa_neg(opa_neg),.pp_neg(pp_neg[i]),.pp_e(pp_e[i]),.sel_m(sel_m[i]),.sel_2m(sel_2m[i]));
  end
endgenerate

endmodule //exu_booth_enc19

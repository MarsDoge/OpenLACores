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

module lsu_find1_8 #(
    parameter INV = 1'b0  // inversion. 0: find one; 1: find zero
) (
    input  wire [  7: 0]  a,
    output wire [  7: 0]  dec,
    output wire [  3: 0]  enc
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire [  7: 0] a_;

//    x1 x0
// y3 7 | 3
// y2 6 | 2
// y1 5 | 1
// y0 4 | 0
wire          x1;
wire          x0;

wire [  1: 0] sx_o;
wire          sx;

wire [  1: 0] x1_sy;
wire [  1: 0] x0_sy;
wire [  1: 0] sy;

wire [  3: 0] x1_y;
wire [  3: 0] x0_y;

//============================================================//
//                    Module Implementation
//============================================================//

assign a_  =  INV ? ~a : a;

assign x1  =  a_[7] | a_[6] | a_[5] | a_[4];
assign x0  =  a_[3] | a_[2] | a_[1] | a_[0];

assign sx    =  x1;
assign sx_o  =  {x1, !x1 && x0};

assign x1_sy  =  {a_[7] || a_[6], a_[7] || !a_[6] && a_[5]};
assign x0_sy  =  {a_[3] || a_[2], a_[3] || !a_[2] && a_[1]};
assign sy     =  x1 ? x1_sy : x0_sy;

assign x1_y  =  {a_[7], !a_[7] && a_[6], !a_[7] && !a_[6] && a_[5], !a_[7] && !a_[6] && !a_[5] && a_[4]};
assign x0_y  =  {a_[3], !a_[3] && a_[2], !a_[3] && !a_[2] && a_[1], !a_[3] && !a_[2] && !a_[1] && a_[0]};

assign dec  =  {{4{sx_o[1]}}, {4{sx_o[0]}}} & {x1_y, x0_y};
assign enc  =  {~(x1 | x0), sx, sy};
endmodule  // lsu_find1_8

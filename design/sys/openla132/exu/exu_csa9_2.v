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

module exu_csa9_2 (
    input  wire [  8: 0]  in,
    input  wire [  5: 0]  ci,
    output wire           s,
    output wire           c,
    output wire [  5: 0]  co
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire [  7: 0] in_csa8;
wire [  4: 0] ci_csa8;
wire          s_csa8;
wire          c_csa8;
wire [  4: 0] co_csa8;
wire [  2: 0] in_csa3_lane;
wire          s_csa3_lane;
wire          c_csa3_lane;

// input delay of in[0] input delay can be longer than in[1]~in[8]
// input delay of in[7] and in[8] can be a little longer than in[1]~in[6]
wire          s0;

//============================================================//
//                    Module Implementation
//============================================================//

// Instance Boundary Alias Mapping
// x_exu_csa8_2

assign in_csa8  =  in[8:1];
assign ci_csa8  =  ci[5:1];
assign s0       =  s_csa8;
assign co[0]    =  c_csa8;
assign co[5:1]  =  co_csa8;
// x_exu_csa3_2
assign in_csa3_lane  =  {in[0], s0, ci[0]};
assign s             =  s_csa3_lane;
assign c             =  c_csa3_lane;

exu_csa8_2 x_exu_csa8_2 (
    .in (in_csa8),
    .ci (ci_csa8),
    .s  (s_csa8 ),
    .c  (c_csa8 ),
    .co (co_csa8)
);

exu_csa3_2 x_exu_csa3_2 (
    .in (in_csa3_lane),
    .s  (s_csa3_lane ),
    .c  (c_csa3_lane )
);

endmodule  // exu_csa9_2

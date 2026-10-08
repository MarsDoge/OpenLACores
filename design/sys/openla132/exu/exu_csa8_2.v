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

module exu_csa8_2 (
    input  wire [  7: 0]  in,
    input  wire [  4: 0]  ci,
    output wire           s,
    output wire           c,
    output wire [  4: 0]  co
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire [  2: 0] in_csa3_lane0;
wire          s_csa3_lane0;
wire          c_csa3_lane0;
wire [  2: 0] in_csa3_lane1;
wire          s_csa3_lane1;
wire          c_csa3_lane1;
wire [  2: 0] in_csa3_lane2;
wire          s_csa3_lane2;
wire          c_csa3_lane2;
wire [  2: 0] in_csa3_lane3;
wire          s_csa3_lane3;
wire          c_csa3_lane3;
wire [  2: 0] in_csa3_lane4;
wire          s_csa3_lane4;
wire          c_csa3_lane4;
wire [  2: 0] in_csa3_lane5;
wire          s_csa3_lane5;
wire          c_csa3_lane5;

// input delay of in[6] and in[7] can be a little longer than in[0]~in[5]
wire [  1: 0] s0;
wire [  1: 0] s1;
wire          s2;

//============================================================//
//                    Module Implementation
//============================================================//

// Instance Boundary Alias Mapping
// x_exu_csa3_2_0

assign in_csa3_lane0  =  {in[2], in[1], in[0]};
assign s0[0]          =  s_csa3_lane0;
assign co[0]          =  c_csa3_lane0;
// x_exu_csa3_2_1
assign in_csa3_lane1  =  {in[5], in[4], in[3]};
assign s0[1]          =  s_csa3_lane1;
assign co[1]          =  c_csa3_lane1;
// x_exu_csa3_2_2
assign in_csa3_lane2  =  {in[7], in[6], ci[0]};
assign s1[0]          =  s_csa3_lane2;
assign co[2]          =  c_csa3_lane2;
// x_exu_csa3_2_3
assign in_csa3_lane3  =  {ci[1], s0[1], s0[0]};
assign s1[1]          =  s_csa3_lane3;
assign co[3]          =  c_csa3_lane3;
// x_exu_csa3_2_4
assign in_csa3_lane4  =  {ci[2], s1[1], s1[0]};
assign s2             =  s_csa3_lane4;
assign co[4]          =  c_csa3_lane4;
// x_exu_csa3_2_5
assign in_csa3_lane5  =  {ci[4], ci[3], s2};
assign s              =  s_csa3_lane5;
assign c              =  c_csa3_lane5;

exu_csa3_2 x_exu_csa3_2_0 (
    .in (in_csa3_lane0),
    .s  (s_csa3_lane0 ),
    .c  (c_csa3_lane0 )
);
exu_csa3_2 x_exu_csa3_2_1 (
    .in (in_csa3_lane1),
    .s  (s_csa3_lane1 ),
    .c  (c_csa3_lane1 )
);

exu_csa3_2 x_exu_csa3_2_2 (
    .in (in_csa3_lane2),
    .s  (s_csa3_lane2 ),
    .c  (c_csa3_lane2 )
);
exu_csa3_2 x_exu_csa3_2_3 (
    .in (in_csa3_lane3),
    .s  (s_csa3_lane3 ),
    .c  (c_csa3_lane3 )
);

exu_csa3_2 x_exu_csa3_2_4 (
    .in (in_csa3_lane4),
    .s  (s_csa3_lane4 ),
    .c  (c_csa3_lane4 )
);

exu_csa3_2 x_exu_csa3_2_5 (
    .in (in_csa3_lane5),
    .s  (s_csa3_lane5 ),
    .c  (c_csa3_lane5 )
);

endmodule  // exu_csa8_2

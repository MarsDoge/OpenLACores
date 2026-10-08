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

module exu_add8_tree (
    input  wire [  7: 0]  p,
    input  wire [  7: 0]  g,
    output wire [  7: 0]  g_out,
    output wire [  7: 0]  p_out
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire [  7: 0] g_1st;
wire [  7: 0] p_1st;
wire [  7: 0] g_2nd;
wire [  7: 0] p_2nd;

//============================================================//
//                    Module Implementation
//============================================================//

assign g_1st  =  {
                   g[7] | p[7] & g[6], g[6], g[5] | p[5] & g[4], g[4], g[3] | p[3] & g[2], g[2], g[1] | p[1] & g[0], g[0]
                 };
assign p_1st  =  {p[7] & p[6], p[6], p[5] & p[4], p[4], p[3] & p[2], p[2], p[1] & p[0], p[0]};

assign g_2nd  =  {
                   g_1st[7] | p_1st[7] & g_1st[5],
                   g_1st[6] | p_1st[6] & g_1st[5],
                   g_1st[5],
                   g_1st[4],
                   g_1st[3] | p_1st[3] & g_1st[1],
                   g_1st[2] | p_1st[2] & g_1st[1],
                   g_1st[1],
                   g_1st[0]
                 };
assign p_2nd  =  {
                   p_1st[7] & p_1st[5],
                   p_1st[6] & p_1st[5],
                   p_1st[5],
                   p_1st[4],
                   p_1st[3] & p_1st[1],
                   p_1st[2] & p_1st[1],
                   p_1st[1],
                   p_1st[0]
                 };

assign g_out  =  {
                   g_2nd[7] | p_2nd[7] & g_2nd[3],
                   g_2nd[6] | p_2nd[6] & g_2nd[3],
                   g_2nd[5] | p_2nd[5] & g_2nd[3],
                   g_2nd[4] | p_2nd[4] & g_2nd[3],
                   g_2nd[3:0]
                 };
assign p_out  =  {p_2nd[7] & p_2nd[3], p_2nd[6] & p_2nd[3], p_2nd[5] & p_2nd[3], p_2nd[4] & p_2nd[3], p_2nd[3:0]};

endmodule  // exu_add8_tree

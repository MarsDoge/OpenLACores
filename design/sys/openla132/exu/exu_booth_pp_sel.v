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

module exu_booth_pp_sel (
    input  wire [ 32: 0]  opa,
    input  wire           pp_neg,
    input  wire           sel_m,
    input  wire           sel_2m,
    output wire [ 33: 0]  pp_m
);

//============================================================//
//                    Module Implementation
//============================================================//

assign pp_m  =  ({34{pp_neg}}) ^ (({34{sel_m}} & {opa[32], opa[32:0]}) | ({34{sel_2m}} & {opa[32:0], 1'b0}));

endmodule  // exu_booth_pp_sel

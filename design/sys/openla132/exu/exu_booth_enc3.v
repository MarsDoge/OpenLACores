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

module exu_booth_enc3 (
    input  wire [  2: 0]  opb,
    input  wire           opa_neg,
    output wire           pp_neg,
    output wire           pp_e,
    output wire           sel_m,
    output wire           sel_2m
);

//============================================================//
//                     Wire Declarations
//============================================================//

// opb==3'b111 is treated as 3'b000
wire          opb_2;

//============================================================//
//                    Module Implementation
//============================================================//

assign opb_2  =  opb[2];

assign pp_neg  =  opb_2 && (!(opb[1] && opb[0]));
assign sel_m   =  opb[1] ^ opb[0];
assign sel_2m  =  (opb[2] ^ opb[1]) & (opb[2] ^ opb[0]);
assign pp_e    =  (opa_neg == opb_2) || (opb == 3'b111) || (opb == 3'b0);

endmodule  // exu_booth_enc3

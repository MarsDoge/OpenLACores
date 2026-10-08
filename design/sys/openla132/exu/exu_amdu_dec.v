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

module exu_amdu_dec (
    input  wire           dec_signmdu,
    input  wire           dec_divide,

    input  wire [ 31: 0]  dec_opa,
    input  wire [ 31: 0]  dec_opb,

    output wire [ 31: 0]  de_opa_abs,  // abs value for DIV and MUL
    output wire [ 31: 0]  de_opb_abs,  // mul:abs(multiplicant); div:~abs(divisor)+1
    output wire           de_res_h_neg,
    output wire           de_res_l_neg
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire          de_opa_neg;
wire          de_opb_neg_real;
wire          de_opb_div_neg;

//============================================================//
//                    Module Implementation
//============================================================//

assign de_opb_neg_real  =  (dec_opb[31] & dec_signmdu);
assign de_opa_neg       =  (dec_opa[31] & dec_signmdu);
assign de_opb_div_neg   =  de_opb_neg_real ^ dec_divide;  // div:~abs(divisor)+1

assign de_opa_abs  =  ({32{de_opa_neg}} ^ dec_opa) + de_opa_neg;
assign de_opb_abs  =  ({32{de_opb_div_neg}} ^ dec_opb) + de_opb_div_neg;

assign de_res_h_neg  =  dec_divide ? de_opa_neg : de_res_l_neg;
assign de_res_l_neg  =  de_opa_neg ^ de_opb_neg_real;
endmodule  // exu_amdu_dec

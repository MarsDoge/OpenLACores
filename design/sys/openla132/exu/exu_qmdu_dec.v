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

module exu_qmdu_dec (
    input  wire [ 31: 0]  dec_opa,
    input  wire [ 31: 0]  dec_opb,
    input  wire           dec_multiply,
    input  wire           dec_divide,
    input  wire           dec_signmdu,

    input  wire           mem_mul_full_1st,
    input  wire           mem_mul_opa_msb,
    input  wire           mem_opb_neg,
    input  wire [ 31: 0]  mem_opb,

    output wire           de_multiply,
    output wire           de_divide,
    output wire [ 32: 0]  de_opa_ext_abs,  // abs value for DIV, 33b ext value for MUL
    output wire [ 31: 0]  de_opb,
    output wire [  8: 0]  de_mul_pp_neg,
    output wire [  8: 0]  de_mul_pp_e,
    output wire [  8: 0]  de_mul_sel_m,
    output wire [  8: 0]  de_mul_sel_2m,
    output wire           de_mul_half_size,
    output wire           de_opb_neg,
    output wire           de_div_quot_neg,
    output wire           de_div_rem_neg
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire [ 18: 0] opb_booth_enc19;
wire          opa_neg_booth_enc19;
wire [  8: 0] pp_neg_booth_enc19;
wire [  8: 0] pp_e_booth_enc19;
wire [  8: 0] sel_m_booth_enc19;
wire [  8: 0] sel_2m_booth_enc19;

wire [ 32: 0] de_opa_33b;
wire          de_opa_neg;

wire [ 18: 0] booth_opb;
wire          booth_opa_neg;

//============================================================//
//                    Module Implementation
//============================================================//

// Instance Boundary Alias Mapping
// x_exu_booth_enc19

assign opb_booth_enc19      =  booth_opb;
assign opa_neg_booth_enc19  =  booth_opa_neg;
assign de_mul_pp_neg        =  pp_neg_booth_enc19;
assign de_mul_pp_e          =  pp_e_booth_enc19;
assign de_mul_sel_m         =  sel_m_booth_enc19;
assign de_mul_sel_2m        =  sel_2m_booth_enc19;

assign de_multiply  =  dec_multiply;
assign de_divide    =  dec_divide;

assign de_opa_33b      =  {(dec_signmdu & dec_opa[31]), dec_opa[31:0]};
assign de_opa_ext_abs  =  (dec_divide && dec_signmdu && dec_opa[31]) ? (~de_opa_33b + 1'b1) : de_opa_33b;
assign de_opb          =  dec_opb;
assign de_opa_neg      =  (|dec_opa[31:0]) & de_opa_33b[32];

assign de_mul_half_size  =  ((dec_opb[31:16] == 16'h0000) && !dec_signmdu) ||
                              ((dec_opb[31:15] == 17'h1ffff) && dec_signmdu) ||
                              ((dec_opb[31:15] == 17'h00000) && dec_signmdu);  // multiple is 32*16

assign booth_opb      =  mem_mul_full_1st ? {{2{mem_opb_neg}}, mem_opb[31:15]} : {de_opb[17:0], 1'b0};
assign booth_opa_neg  =  mem_mul_full_1st ? mem_mul_opa_msb : de_opa_neg;

exu_booth_enc19 x_exu_booth_enc19 (
    .opb     (opb_booth_enc19    ),  // I
    .opa_neg (opa_neg_booth_enc19),  // I
    .pp_neg  (pp_neg_booth_enc19 ),  // O
    .pp_e    (pp_e_booth_enc19   ),  // O
    .sel_m   (sel_m_booth_enc19  ),  // O
    .sel_2m  (sel_2m_booth_enc19 )   // O
);

assign de_opb_neg       =  dec_signmdu & dec_opb[31];
assign de_div_quot_neg  =  dec_signmdu & (dec_opa[31] ^ dec_opb[31]);
assign de_div_rem_neg   =  dec_signmdu & dec_opa[31];

endmodule  // exu_qmdu_dec

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

module lsu_ecc_comp #(
    parameter ECC_BITS = 8
) (
    input  wire [         8: 0]  ecc_in,
    output wire [ECC_BITS-1: 0]  ecc_out
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire [  8: 0] ecc_out_full;

//============================================================//
//                    Module Implementation
//============================================================//

assign ecc_out_full[8:1]  =  ecc_in[8:1];
assign ecc_out_full[0]    =  ECC_BITS == 7 ? ecc_in[0] ^ ecc_in[7] ^ ecc_in[8] :
                               ECC_BITS == 8 ? ecc_in[0] ^ ecc_in[8] : ECC_BITS == 9 ? ecc_in[0] : 1'b0;
assign ecc_out            =  ecc_out_full[ECC_BITS-1:0];

endmodule

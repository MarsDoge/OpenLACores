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

module lsu_ecc_set #(
    parameter ECC_WAY       = 2    , //1/2/4 way to one ecc_set
    parameter ECC_DATA      = 32*2 , //for 4 ways
    parameter ECC_BITS      = 8      //1/7/8/9 bits
)(
    input  [ECC_DATA -1:0] data_in   ,  //one bank's one ecc set
    input  [ECC_BITS -1:0] old_ecc,

    output [ECC_BITS -1:0] gen_ecc,
    output [ECC_BITS -1:0] ecc_syndrome
);
//ecc use 32+9
wire [9 *ECC_WAY -1:0] data_ecc; //one way data_in's ecc
genvar i,j;

lsu_ecc_gen_sets #(
    .ECC_BITS (ECC_BITS),
    .SET_ASSOC(ECC_WAY ) //only need one ecc set
) open132_data_ecc_gen(
    .data_in (data_in    ),
    .ecc_out (data_ecc)
);
//9bits ecc for per set_assoc
wire [8:0] ecc_perway[ECC_WAY -1:0];
`GEN_1D_TO_2D(ECC_WAY, 9, data_ecc, ecc_perway)
//9bits ecc for per ecc_set
wire [8:0] ecc_perset[0:0]; // ECC_WAY --> one ecc
`GEN_ECC_COMPRESS_X(ECC_WAY, 1, ECC_WAY, ecc_perway,ecc_perway_T, ecc_perset)

//ecc for per ecc_set
wire [ECC_BITS -1:0] new_ecc_perset[0:0];
`GEN_ECC_COMPRESS_Y(1, ECC_BITS, ecc_perset, new_ecc_perset)

//ecc err check
generate if(ECC_BITS>=7)
begin: gen_cache_has_ecc
    assign gen_ecc      = new_ecc_perset[0];
    assign ecc_syndrome = new_ecc_perset[0] ^ old_ecc;
end
else
begin: gen_cache_has_ecc
    assign gen_ecc      = {ECC_BITS{1'b0}};
    assign ecc_syndrome = {ECC_BITS{1'b0}};
end
endgenerate
endmodule

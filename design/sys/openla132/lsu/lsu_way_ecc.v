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

module lsu_way_ecc #(
    parameter SET_ASSOC     = 4 , //1/2/4 way set associative
    parameter ECC_WAY       = 2 , //1/2/4 way to one ecc_set
    parameter ECC_BITS      = 8   //1/7/8/9 bits
)(
    input  [32*ECC_WAY*7 -1:0] way_rdata       ,  //7 banks
    input  [ECC_BITS*7   -1:0] way_old_ecc     ,  //7 banks

    output [ECC_BITS*7   -1:0] way_gen_ecc     ,  //all banks in one way
    output [ECC_BITS*7   -1:0] way_ecc_syndrome   //all banks in one way
);
localparam ECC_DATA = 32*ECC_WAY;
wire [ECC_DATA  -1:0] rdata_perbank[6:0];
wire [ECC_BITS  -1:0] recc_perbank [6:0];
wire [ECC_BITS  -1:0] gen_ecc      [6:0];
wire [ECC_BITS  -1:0] ecc_syndrome [6:0];

genvar i;

`GEN_1D_TO_2D(7, ECC_DATA, way_rdata   , rdata_perbank)
`GEN_1D_TO_2D(7, ECC_BITS, way_old_ecc , recc_perbank )
generate for(i=0; i<7; i=i+1)
begin: gen_ecc_for_onebank
    lsu_ecc_set #(
        .ECC_WAY  (ECC_WAY  ),
        .ECC_DATA (ECC_DATA ),
        .ECC_BITS (ECC_BITS )
    )open132_bank_one_eccset (
        .data_in   (rdata_perbank[i] ),  //one bank's one ecc set
        .old_ecc     (recc_perbank [i] ),

        .gen_ecc     (gen_ecc      [i] ),
        .ecc_syndrome(ecc_syndrome [i] )
    );
end
endgenerate

`GEN_2D_TO_1D(7, ECC_BITS, gen_ecc     , way_gen_ecc     )
`GEN_2D_TO_1D(7, ECC_BITS, ecc_syndrome, way_ecc_syndrome)
endmodule

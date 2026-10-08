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

module lsu_bank_ecc #(
    parameter SET_ASSOC     = 4         , //1/2/4 way set associative
    parameter DATA_BITS     = 23        , //for tagv,  waysize 1K
    parameter ECC_BITS      = 8         , //1/7/8/9 bits
    parameter ECC_SET       = 2         , //for 4 ways, use 64+8
    parameter ECC_WAY       = 2         , //for 4 ways, use 64+8
    parameter ECC_BANK_BITS = 8*2         //for 4 ways, use 64+8
)(
    input  [DATA_BITS*SET_ASSOC -1:0] bank_rdata      ,
    input  [ECC_BANK_BITS       -1:0] bank_recc       ,  //all ways
    input  [ECC_SET             -1:0] mq_refill_eccset,

    output                            tc_err          ,  //there are errors in any way
    output [ECC_BANK_BITS       -1:0] tc_ecc_syndrome ,  //all eccset
    output [ECC_BANK_BITS       -1:0] mq_gen_ecc_all  ,  //all eccset
    output [ECC_BITS            -1:0] mq_gen_ecc_one  ,  //one eccset
    output [ECC_BITS            -1:0] mq_ecc_syndrome    //one eccset
);
//ecc use 32+9
wire [33           -1:0] bank_way [SET_ASSOC -1:0];
wire [32*SET_ASSOC -1:0] bank    ;
wire [9 *SET_ASSOC -1:0] bank_ecc;
genvar i,j;
generate
    for(i=0; i<SET_ASSOC; i=i+1)
    begin:gen_bank_32bits
        assign bank_way [i]    = {{(33-DATA_BITS){1'b0}},bank_rdata[DATA_BITS*i +: DATA_BITS]};
        assign bank[32*i +:32] = bank_way[i][31:0];
    end
endgenerate

lsu_ecc_gen_sets #(
    .ECC_BITS (ECC_BITS  ),
    .SET_ASSOC(SET_ASSOC ) //1/2/4
) open132_bank_ecc_gen(
    .data_in (bank    ),
    .ecc_out (bank_ecc)
);
//9bits ecc for per set_assoc
wire [8:0] ecc_perway[SET_ASSOC -1:0];
`GEN_1D_TO_2D(SET_ASSOC, 9, bank_ecc, ecc_perway)

//9bits ecc for per ecc_set
wire [8:0] ecc_perset[ECC_SET   -1:0];
`GEN_ECC_COMPRESS_X(SET_ASSOC,ECC_SET,ECC_WAY,ecc_perway,ecc_perway_T,ecc_perset)

//ecc for per ecc_set
wire [ECC_BITS -1:0] new_ecc_perset[ECC_SET -1:0];
`GEN_ECC_COMPRESS_Y(ECC_SET,ECC_BITS,ecc_perset,new_ecc_perset)

//per ecc_set old_ecc
wire [ECC_BITS -1:0] old_ecc[ECC_SET -1:0];
`GEN_1D_TO_2D(ECC_SET, ECC_BITS, bank_recc, old_ecc)

//ecc err check
wire [ECC_BITS -1:0] ecc_syndrome[ECC_SET -1:0];
wire [ECC_SET  -1:0] ecc_err_set;
generate for(i=0; i<ECC_SET; i=i+1)
begin: gen_ecc_syndrome
    assign ecc_syndrome[i] = (new_ecc_perset[i] ^ old_ecc[i]);
    assign ecc_err_set [i] = |ecc_syndrome[i];
end
endgenerate

//out
wire                            tc_err_t       ;
wire [ECC_BANK_BITS       -1:0] tc_ecc_syndrome_t;
wire [ECC_BANK_BITS       -1:0] mq_gen_ecc_all_t ;
wire [ECC_BITS            -1:0] mq_gen_ecc_one_t ;
wire [ECC_BITS            -1:0] mq_ecc_syndrome_t;
assign tc_err_t       = |ecc_err_set;
`GEN_2D_TO_1D (ECC_SET, ECC_BITS, ecc_syndrome  , tc_ecc_syndrome_t)
`GEN_2D_SEL_1D(ECC_SET, ECC_BITS, ecc_syndrome,ecc_syndrome_T, mq_refill_eccset, mq_ecc_syndrome_t)

`GEN_2D_TO_1D (ECC_SET, ECC_BITS, new_ecc_perset, mq_gen_ecc_all_t)

wire [3         :0] mq_gen_ecc_sel4 = 4'd1;
wire [ECC_SET -1:0] mq_gen_ecc_sel  = mq_gen_ecc_sel4[ECC_SET -1:0];
`GEN_2D_SEL_1D(ECC_SET, ECC_BITS, new_ecc_perset,new_ecc_perset_T, mq_gen_ecc_sel, mq_gen_ecc_one_t)
generate if(ECC_BITS>=7)
begin: Cache_has_ecc
    assign tc_err          = tc_err_t          ;
    assign tc_ecc_syndrome = tc_ecc_syndrome_t ;
    assign mq_gen_ecc_all  = mq_gen_ecc_all_t  ;
    assign mq_gen_ecc_one  = mq_gen_ecc_one_t  ;
    assign mq_ecc_syndrome = mq_ecc_syndrome_t ;
end
else
begin: Cache_no_ecc
    assign tc_err          = 1'b0                 ;  //there are errors in any way
    assign tc_ecc_syndrome = {ECC_BANK_BITS{1'b0}};  //all eccset
    assign mq_gen_ecc_all  = {ECC_BANK_BITS{1'b0}};  //all eccset
    assign mq_gen_ecc_one  = {ECC_BITS     {1'b0}};  //one eccset
    assign mq_ecc_syndrome = {ECC_BITS     {1'b0}};  //one eccset
end
endgenerate
endmodule

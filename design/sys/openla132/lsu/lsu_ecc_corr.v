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
`include "openla132_ecc_define.h"

module lsu_ecc_corr #(
    parameter ECC_BITS     = 8   , //1/7/8/9
    parameter ECC_WAY      = 2   ,
    parameter DATA_BITS    = 32    //bits for one set data

)(
    input  [ECC_BITS          -1:0] ecc_syndrome,
    output [DATA_BITS*ECC_WAY -1:0] xor_word,
    output [ECC_BITS          -1:0] xor_ecc,
    output                          data_1bit_err,//err in this word
    output                          ecc_1bit_err ,
    output                          fatal         //err in all ecc_word
);
genvar i,j;
wire [9 :0] syndrome10;
wire [8 :0] syndrome;
assign syndrome10 = {{(10-ECC_BITS){1'b0}},ecc_syndrome};
assign syndrome   = syndrome10[8:0];
// mask
wire [31:0] mask32   [8 :0];
wire [31:0] mask64   [8 :0];
wire [31:0] mask96   [8 :0];
wire [31:0] mask128  [8 :0];
wire [8 :0] mask32_t [31:0];
wire [8 :0] mask64_t [31:0];
wire [8 :0] mask96_t [31:0];
wire [8 :0] mask128_t[31:0];
assign mask32 [0] = `OPEN132_ECC_MASK0;
assign mask32 [1] = `OPEN132_ECC_MASK1;
assign mask32 [2] = `OPEN132_ECC_MASK2;
assign mask32 [3] = `OPEN132_ECC_MASK3;
assign mask32 [4] = `OPEN132_ECC_MASK4;
assign mask32 [5] = `OPEN132_ECC_MASK5;
assign mask32 [6] = `OPEN132_ECC_MASK6;
assign mask32 [7] = `OPEN132_ECC_MASK7;
assign mask32 [8] = `OPEN132_ECC_MASK8;

assign mask64 [0] =~mask32[0];
assign mask64 [1] = mask32[1];
assign mask64 [2] = mask32[2];
assign mask64 [3] = mask32[3];
assign mask64 [4] = mask32[4];
assign mask64 [5] = mask32[5];
assign mask64 [6] = mask32[6];
assign mask64 [7] =~mask32[7];
assign mask64 [8] = mask32[8];

assign mask96 [0] =~mask32[0];
assign mask96 [1] = mask32[1];
assign mask96 [2] = mask32[2];
assign mask96 [3] = mask32[3];
assign mask96 [4] = mask32[4];
assign mask96 [5] = mask32[5];
assign mask96 [6] = mask32[6];
assign mask96 [7] = mask32[7];
assign mask96 [8] =~mask32[8];

assign mask128[0] = mask32[0];
assign mask128[1] = mask32[1];
assign mask128[2] = mask32[2];
assign mask128[3] = mask32[3];
assign mask128[4] = mask32[4];
assign mask128[5] = mask32[5];
assign mask128[6] = mask32[6];
assign mask128[7] =~mask32[7];
assign mask128[8] =~mask32[8];
`GEN_2D_T(9, 32, mask32 , mask32_t )
`GEN_2D_T(9, 32, mask64 , mask64_t )
`GEN_2D_T(9, 32, mask96 , mask96_t )
`GEN_2D_T(9, 32, mask128, mask128_t)

//compare syndrome;
wire [31:0] syndrome_cmp_mask32 ;
wire [31:0] syndrome_cmp_mask64 ;
wire [31:0] syndrome_cmp_mask96 ;
wire [31:0] syndrome_cmp_mask128;
wire  syndrome_data_1bit_err;
generate for (i=0; i<32; i=i+1)
begin: gen_syndrome_perbit
    assign syndrome_cmp_mask32 [i] = syndrome== mask32_t [i];
    assign syndrome_cmp_mask64 [i] = syndrome== mask64_t [i];
    assign syndrome_cmp_mask96 [i] = syndrome== mask96_t [i];
    assign syndrome_cmp_mask128[i] = syndrome== mask128_t[i];
end
endgenerate
assign syndrome_data_1bit_err = |syndrome_cmp_mask32 || |syndrome_cmp_mask64  ||
                                |syndrome_cmp_mask96 || |syndrome_cmp_mask128 ;
//xor_word
wire [127 :0] syndrome_cmp_mask;
assign syndrome_cmp_mask = {syndrome_cmp_mask128,syndrome_cmp_mask96,
                            syndrome_cmp_mask64 ,syndrome_cmp_mask32};
//1bit ecc checkbit err
wire [8 :0] eccmask [8 :0];
assign eccmask[0] = 9'h001;
assign eccmask[1] = 9'h002;
assign eccmask[2] = 9'h004;
assign eccmask[3] = 9'h008;
assign eccmask[4] = 9'h010;
assign eccmask[5] = 9'h020;
assign eccmask[6] = 9'h040;
assign eccmask[7] = 9'h080;
assign eccmask[8] = 9'h100;
wire [8 :0] syndrome_cmp_eccmask;
generate for(i=0; i<9; i=i+1)
begin: gen_syndrome_cmp_eccmask_perbit
    assign syndrome_cmp_eccmask[i] =  syndrome==eccmask[i];
end
endgenerate

wire syndrome_ecc_1bit_err;
assign syndrome_ecc_1bit_err =  |syndrome_cmp_eccmask;

//xor_ecc
//if no error or 2bits error, xor_ecc is syndrome,
//so can set ecc==gen_ecc(bad_data)
wire [8 :0] xor_ecc9;
assign xor_ecc9 = syndrome_cmp_eccmask;

//fatal: 2bit err
wire syndrome_all_1bit_err;
wire syndrome_fatal;
assign syndrome_all_1bit_err = syndrome_data_1bit_err || syndrome_ecc_1bit_err;
assign syndrome_fatal        = |syndrome && !syndrome_all_1bit_err;

wire [DATA_BITS*ECC_WAY -1:0] xor_word_t;
generate for(i=0; i<ECC_WAY; i=i+1)
begin: gen_eccset_xor_word
    assign xor_word_t[DATA_BITS*i +: DATA_BITS] = syndrome_cmp_mask[32*i +: DATA_BITS];
end
endgenerate
//output
generate if(ECC_BITS>=7)
begin: gen_cache_has_ecc
    assign xor_word      = xor_word_t;
    assign xor_ecc       = syndrome_all_1bit_err ? xor_ecc9  [ECC_BITS  -1:0] :
                                                   ecc_syndrome ;
    assign data_1bit_err = syndrome_data_1bit_err;
    assign ecc_1bit_err  = syndrome_ecc_1bit_err;
    assign fatal         = syndrome_fatal;
end
else
begin: gen_cache_no_ecc
    assign xor_word      = {(DATA_BITS*ECC_WAY){1'b0}};
    assign xor_ecc       = {ECC_BITS{1'b0}};
    assign data_1bit_err = 1'b0;
    assign ecc_1bit_err  = 1'b0;
    assign fatal         = 1'b0;
end
endgenerate
endmodule

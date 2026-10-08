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

module lsu_ecc_corr_sets #(
    parameter SET_ASSOC     = 4   , //1/2/4
    parameter ECC_BITS      = 8   , //1/7/8/9
    parameter ECC_SET       = 2   ,
    parameter ECC_WAY       = 2   ,
    parameter DATA_BITS     = 32  , //bits for one set data
    parameter ECC_BANK_BITS = 8*2

)(
    input  [ECC_BANK_BITS        -1:0] ecc_syndrome,
    output [DATA_BITS*SET_ASSOC  -1:0] xor_word,
    output [ECC_BANK_BITS        -1:0] xor_ecc,
    output                             data_1bit_err,
    output                             ecc_1bit_err,
    output                             syndrome_err, //1 or 2 bits error
    output [ECC_SET              -1:0] fatal
);
genvar i,j;
wire [9 :0] syndrome10_perset[ECC_SET -1:0];
wire [8 :0] syndrome_perset[ECC_SET -1:0];
generate for (i=0; i<ECC_SET; i=i+1)
begin: gen_syndrome_perset
    assign syndrome10_perset[i] = {{(10-ECC_BITS){1'b0}},ecc_syndrome[ECC_BITS*i +: ECC_BITS]};
    assign syndrome_perset  [i] = syndrome10_perset[i][8:0];
end
endgenerate
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
wire [31:0] syndrome_cmp_mask32 [ECC_SET -1:0];
wire [31:0] syndrome_cmp_mask64 [ECC_SET -1:0];
wire [31:0] syndrome_cmp_mask96 [ECC_SET -1:0];
wire [31:0] syndrome_cmp_mask128[ECC_SET -1:0];
wire [ECC_SET -1:0] syndrome_data_1bit_err;
generate for (i=0; i<ECC_SET; i=i+1)
begin: gen_syndrome_data_1bit_err_perset
    for (j=0; j<32; j=j+1)
    begin: gen_syndrome_perset_perbit
        assign syndrome_cmp_mask32 [i][j] = syndrome_perset[i]== mask32_t [j];
        assign syndrome_cmp_mask64 [i][j] = syndrome_perset[i]== mask64_t [j];
        assign syndrome_cmp_mask96 [i][j] = syndrome_perset[i]== mask96_t [j];
        assign syndrome_cmp_mask128[i][j] = syndrome_perset[i]== mask128_t[j];
    end
    assign syndrome_data_1bit_err [i] = |syndrome_cmp_mask32[i] || |syndrome_cmp_mask64 [i] ||
                                        |syndrome_cmp_mask96[i] || |syndrome_cmp_mask128[i] ;
end
endgenerate
//xor_word
wire [127         :0] syndrome_cmp_mask [ECC_SET   -1:0];
wire [31          :0] xor_word32        [SET_ASSOC -1:0];
wire [DATA_BITS -1:0] xor_word_perset   [SET_ASSOC -1:0];
generate for (i=0; i<ECC_SET; i=i+1)
begin: gen_syndrome_data_128
    assign syndrome_cmp_mask[i] = {syndrome_cmp_mask128[i],syndrome_cmp_mask96[i],
                                   syndrome_cmp_mask64 [i],syndrome_cmp_mask32[i]};
end
endgenerate
generate for (i=0; i<SET_ASSOC; i=i+1)
begin: gen_xor_word32
    assign xor_word32     [i] = syndrome_cmp_mask[i/ECC_WAY][(i-(i/ECC_WAY)*ECC_WAY)*32 +: 32];
    assign xor_word_perset[i] = xor_word32[i][DATA_BITS -1:0];
end
endgenerate

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
wire [8 :0] syndrome_cmp_eccmask[ECC_SET -1:0];
generate for (i=0; i<ECC_SET; i=i+1)
begin: gen_syndrome_cmp_eccmask_perset
    for(j=0; j<9; j=j+1)
    begin: gen_syndrome_cmp_eccmask_perset_perbit
        assign syndrome_cmp_eccmask[i][j] =  syndrome_perset[i]==eccmask[j];
    end
end
endgenerate

wire [ECC_SET -1:0] syndrome_ecc_1bit_err;
generate for (i=0; i<ECC_SET; i=i+1)
begin: gen_syndrome_ecc_1bit_err_perset
    assign syndrome_ecc_1bit_err [i] =  |syndrome_cmp_eccmask[i];
end
endgenerate

//xor_ecc
//if no error or 2bits error, xor_ecc is syndrome,
//so can set ecc==gen_ecc(bad_data)
wire [ECC_SET  -1:0] syndrome_all_1bit_err;
wire [8          :0] xor_ecc9       [ECC_SET -1:0];
wire [ECC_BITS -1:0] xor_ecc_eccset [ECC_SET -1:0];
generate for (i=0; i<ECC_SET; i=i+1)
begin: gen_xor_ecc9
    assign xor_ecc9      [i] = syndrome_cmp_eccmask[i];
    assign xor_ecc_eccset[i] = syndrome_all_1bit_err[i] ? xor_ecc9       [i][ECC_BITS -1:0] :
                                                          syndrome_perset[i][ECC_BITS -1:0];
end
endgenerate

//fatal: 2bit err
wire [ECC_SET   -1:0] syndrome_err_perset;
wire [ECC_SET   -1:0] syndrome_fatal_perset;
generate for (i=0; i<ECC_SET; i=i+1)
begin: gen_syndrome_fatal
    assign syndrome_all_1bit_err[i] = syndrome_data_1bit_err[i] || syndrome_ecc_1bit_err[i];
    assign syndrome_err_perset[i]   = |syndrome_perset[i];
    assign syndrome_fatal_perset[i] = syndrome_err_perset[i] && !syndrome_all_1bit_err[i];
end
endgenerate

wire [DATA_BITS*SET_ASSOC  -1:0] xor_word_t;
wire [ECC_BANK_BITS        -1:0] xor_ecc_t;
`GEN_2D_TO_1D (SET_ASSOC, DATA_BITS, xor_word_perset, xor_word_t)
`GEN_2D_TO_1D (ECC_SET  , ECC_BITS , xor_ecc_eccset , xor_ecc_t)

//output
generate if(ECC_BITS>=7)
begin: gen_cache_has_ecc
    assign xor_word      = xor_word_t;
    assign xor_ecc       = xor_ecc_t ;
    assign data_1bit_err = |syndrome_data_1bit_err;
    assign ecc_1bit_err  = |syndrome_ecc_1bit_err;
    assign syndrome_err  = |syndrome_err_perset;
    assign fatal         =  syndrome_fatal_perset;
end
else
begin: gen_cache_no_ecc
    assign xor_word      = {(DATA_BITS*SET_ASSOC){1'b0}};
    assign xor_ecc       = {ECC_BANK_BITS        {1'b0}};
    assign data_1bit_err = 1'b0;
    assign ecc_1bit_err  = 1'b0;
    assign syndrome_err  = 1'b0;
    assign fatal         = {ECC_SET{1'b0}};
end
endgenerate
endmodule

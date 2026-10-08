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

module lsu_ecc_gen_sets #(
    parameter ECC_BITS  = 4, //0/7/8/9
    parameter SET_ASSOC = 4  //1/2/4
)(
    input  [32*SET_ASSOC -1:0] data_in,
    output [9 *SET_ASSOC -1:0] ecc_out
);
wire [31:0] mask[8:0];
assign mask[0] = `OPEN132_ECC_MASK0;
assign mask[1] = `OPEN132_ECC_MASK1;
assign mask[2] = `OPEN132_ECC_MASK2;
assign mask[3] = `OPEN132_ECC_MASK3;
assign mask[4] = `OPEN132_ECC_MASK4;
assign mask[5] = `OPEN132_ECC_MASK5;
assign mask[6] = `OPEN132_ECC_MASK6;
assign mask[7] = `OPEN132_ECC_MASK7;
assign mask[8] = `OPEN132_ECC_MASK8;

wire [31:0] mask0_perset[3:0];
wire [31:0] mask1_perset[3:0];
wire [31:0] mask2_perset[3:0];
wire [31:0] mask3_perset[3:0];
wire [31:0] mask4_perset[3:0];
wire [31:0] mask5_perset[3:0];
wire [31:0] mask6_perset[3:0];
wire [31:0] mask7_perset[3:0];
wire [31:0] mask8_perset[3:0];
assign mask0_perset[0] = mask[0];
assign mask1_perset[0] = mask[1];
assign mask2_perset[0] = mask[2];
assign mask3_perset[0] = mask[3];
assign mask4_perset[0] = mask[4];
assign mask5_perset[0] = mask[5];
assign mask6_perset[0] = mask[6];
assign mask7_perset[0] = mask[7];
assign mask8_perset[0] = mask[8];

assign mask0_perset[1] =~mask[0];
assign mask1_perset[1] = mask[1];
assign mask2_perset[1] = mask[2];
assign mask3_perset[1] = mask[3];
assign mask4_perset[1] = mask[4];
assign mask5_perset[1] = mask[5];
assign mask6_perset[1] = mask[6];
assign mask7_perset[1] =~mask[7];
assign mask8_perset[1] = mask[8];

assign mask0_perset[2] =~mask[0];
assign mask1_perset[2] = mask[1];
assign mask2_perset[2] = mask[2];
assign mask3_perset[2] = mask[3];
assign mask4_perset[2] = mask[4];
assign mask5_perset[2] = mask[5];
assign mask6_perset[2] = mask[6];
assign mask7_perset[2] = mask[7];
assign mask8_perset[2] =~mask[8];

assign mask0_perset[3] = mask[0];
assign mask1_perset[3] = mask[1];
assign mask2_perset[3] = mask[2];
assign mask3_perset[3] = mask[3];
assign mask4_perset[3] = mask[4];
assign mask5_perset[3] = mask[5];
assign mask6_perset[3] = mask[6];
assign mask7_perset[3] =~mask[7];
assign mask8_perset[3] =~mask[8];

wire [31:0] data_perset[SET_ASSOC:0];
wire [8 :0] ecc_perset [SET_ASSOC:0];
genvar i;
generate for(i=0; i<SET_ASSOC; i=i+1)
begin: gen_ecc_for_perset
    assign ecc_perset[i][0] = (^(data_perset[i] & mask0_perset[i]));
    assign ecc_perset[i][1] = (^(data_perset[i] & mask1_perset[i]));
    assign ecc_perset[i][2] = (^(data_perset[i] & mask2_perset[i]));
    assign ecc_perset[i][3] = (^(data_perset[i] & mask3_perset[i]));
    assign ecc_perset[i][4] = (^(data_perset[i] & mask4_perset[i]));
    assign ecc_perset[i][5] = (^(data_perset[i] & mask5_perset[i]));
    assign ecc_perset[i][6] = (^(data_perset[i] & mask6_perset[i]));
    assign ecc_perset[i][7] = (^(data_perset[i] & mask7_perset[i]));
    assign ecc_perset[i][8] = (^(data_perset[i] & mask8_perset[i]));
end
endgenerate

wire [9 *SET_ASSOC -1:0] ecc_out_tmp;
`GEN_1D_TO_2D(SET_ASSOC, 32, data_in   ,data_perset)
`GEN_2D_TO_1D(SET_ASSOC, 9 , ecc_perset,ecc_out_tmp)
generate if(ECC_BITS>=7)
begin: gen_cache_has_ecc
    assign ecc_out = ecc_out_tmp;
end
else
begin: gen_cache_no_ecc
    assign ecc_out = {(9 *SET_ASSOC){1'b0}};
end
endgenerate
endmodule

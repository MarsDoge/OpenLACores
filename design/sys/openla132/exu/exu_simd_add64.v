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

module exu_simd_add64
(
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire        width_w,
    output wire [63:0] sum
);

wire [ 7:0] cin_b   = 8'b0;
wire [ 3:0] cin_h   = 4'b0;
wire [ 1:0] cin_w   = 2'b0;
wire        cin_d   = 1'b0;
wire        width_b = 1'b0;
wire        width_h = 1'b0;
wire        width_d = ~width_w;

wire [63:0] p;
wire [63:0] g;
wire [63:0] g_0l;   // g_0l[7:0] is the final g_7_0
wire [63:0] p_0l;

wire [ 7:0] g_1l_15_8;  // final_g_15_8
wire [ 7:0] g_1l_31_24;
wire [ 7:0] g_1l_47_40;
wire [ 7:0] g_1l_63_56;
wire [ 7:0] p_1l_15_8;
wire [ 7:0] p_1l_31_24;
wire [ 7:0] p_1l_47_40;
wire [ 7:0] p_1l_63_56;

wire [15:0] g_2l_31_16; // final_g_31_16
wire [15:0] g_2l_63_48;
wire [15:0] p_2l_31_16;
wire [15:0] p_2l_63_48;

wire [31:0] g_3l_63_32; // final_g_63_32
wire [31:0] p_3l_63_32;

wire        g_0l_7_0_h;
wire        g_0l_23_16_h;
wire        g_0l_39_32_h;
wire        g_0l_55_48_h;
wire        g_1l_15_8_h;
wire        g_1l_47_40_h;
wire        g_2l_31_16_h;
wire        p_0l_7_0_h;
wire        p_0l_23_16_h;
wire        p_0l_39_32_h;
wire        p_0l_55_48_h;
wire        p_1l_15_8_h;
wire        p_1l_47_40_h;
wire        p_2l_31_16_h;

wire [63:0] a_xor_b;
wire [63:0] c;
wire [63:0] cin;

assign p[63:0] = a[63:0] | b[63:0];
assign g[63:0] = a[63:0] & b[63:0];

genvar i;
generate
    for (i = 0; i < 8; i = i + 1)
    begin: gen_8_bits_trees
        exu_add8_tree inst_tree_8bit
            (
            .p     (p[8*i+7:8*i]    ),
            .g     (g[8*i+7:8*i]    ),
            .g_out (g_0l[8*i+7:8*i] ),
            .p_out (p_0l[8*i+7:8*i] )
            );
     end
endgenerate

assign g_0l_7_0_h   = g_0l[ 7] & ~width_b;
assign g_0l_23_16_h = g_0l[23] & ~width_b;
assign g_0l_39_32_h = g_0l[39] & ~width_b;
assign g_0l_55_48_h = g_0l[55] & ~width_b;

assign g_1l_15_8_h  = g_1l_15_8 [7] & ~width_b & ~width_h;
assign g_1l_47_40_h = g_1l_47_40[7] & ~width_b & ~width_h;

assign g_2l_31_16_h = g_2l_31_16[15] & width_d;

assign p_0l_7_0_h   = p_0l[ 7] | width_b;
assign p_0l_23_16_h = p_0l[23] | width_b;
assign p_0l_39_32_h = p_0l[39] | width_b;
assign p_0l_55_48_h = p_0l[55] | width_b;

assign p_1l_15_8_h  = p_1l_15_8 [7] | width_b | width_h;
assign p_1l_47_40_h = p_1l_47_40[7] | width_b | width_h;

assign p_2l_31_16_h = p_2l_31_16[15] | ~width_d;

assign g_1l_15_8  = g_0l[15: 8] | p_0l[15: 8] & {8{g_0l_7_0_h}};
assign g_1l_31_24 = g_0l[31:24] | p_0l[31:24] & {8{g_0l_23_16_h}};
assign g_1l_47_40 = g_0l[47:40] | p_0l[47:40] & {8{g_0l_39_32_h}};
assign g_1l_63_56 = g_0l[63:56] | p_0l[63:56] & {8{g_0l_55_48_h}};

assign p_1l_15_8  = p_0l[15: 8] & {8{p_0l_7_0_h}};
assign p_1l_31_24 = p_0l[31:24] & {8{p_0l_23_16_h}};
assign p_1l_47_40 = p_0l[47:40] & {8{p_0l_39_32_h}};
assign p_1l_63_56 = p_0l[63:56] & {8{p_0l_55_48_h}};

assign g_2l_31_16[15: 8] = g_1l_31_24   | p_1l_31_24  & {8{g_1l_15_8_h}};
assign g_2l_31_16[ 7: 7] = g_0l_23_16_h | p_0l[23]    &    g_1l_15_8_h  ;
assign g_2l_31_16[ 6: 0] = g_0l[22:16]  | p_0l[22:16] & {7{g_1l_15_8_h}};

assign p_2l_31_16[15: 8] = p_1l_31_24   & {8{p_1l_15_8_h}};
assign p_2l_31_16[ 7: 7] = p_0l_23_16_h &    p_1l_15_8_h  ;
assign p_2l_31_16[ 6: 0] = p_0l[22:16]  & {7{p_1l_15_8_h}};

assign g_2l_63_48[15: 8] = g_1l_63_56   | p_1l_63_56  & {8{g_1l_47_40_h}};
assign g_2l_63_48[ 7: 7] = g_0l_55_48_h | p_0l[55]    &    g_1l_47_40_h  ;
assign g_2l_63_48[ 6: 0] = g_0l[54:48]  | p_0l[54:48] & {7{g_1l_47_40_h}};

assign p_2l_63_48[15: 8] = p_1l_63_56   & {8{p_1l_47_40_h}};
assign p_2l_63_48[ 7: 7] = p_0l_55_48_h &    p_1l_47_40_h  ;
assign p_2l_63_48[ 6: 0] = p_0l[54:48]  & {7{p_1l_47_40_h}};

assign g_3l_63_32[31:16] = g_2l_63_48      | p_2l_63_48       & {16{g_2l_31_16_h}};
assign g_3l_63_32[15:15] = g_1l_47_40_h    | p_1l_47_40 [7  ] &     g_2l_31_16_h  ;
assign g_3l_63_32[14: 8] = g_1l_47_40[6:0] | p_1l_47_40 [6:0] & { 7{g_2l_31_16_h}};
assign g_3l_63_32[ 7: 7] = g_0l_39_32_h    | p_0l[39]         &     g_2l_31_16_h  ;
assign g_3l_63_32[ 6: 0] = g_0l[38:32]     | p_0l[38:32]      & { 7{g_2l_31_16_h}};

assign p_3l_63_32[31:16] = p_2l_63_48      & {16{p_2l_31_16_h}};
assign p_3l_63_32[15:15] = p_1l_47_40_h    &     p_2l_31_16_h  ;
assign p_3l_63_32[14: 8] = p_1l_47_40[6:0] & { 7{p_2l_31_16_h}};
assign p_3l_63_32[ 7: 7] = p_0l_39_32_h    &     p_2l_31_16_h  ;
assign p_3l_63_32[ 6: 0] = p_0l[38:32]     & { 7{p_2l_31_16_h}};

assign cin = {64{width_b}} & {{8{cin_b[7]}},{8{cin_b[6]}},{8{cin_b[5]}},{8{cin_b[4]}},
                              {8{cin_b[3]}},{8{cin_b[2]}},{8{cin_b[1]}},{8{cin_b[0]}}}
           | {64{width_h}} & {{16{cin_h[3]}},{16{cin_h[2]}},{16{cin_h[1]}},{16{cin_h[0]}}}
           | {64{width_w}} & {{32{cin_w[1]}},{32{cin_w[0]}}}
           | {64{width_d}} & {64{cin_d}};


assign c   = {g_3l_63_32       | p_3l_63_32       & {cin[63],cin[63:33]},
              g_2l_31_16_h     | p_2l_31_16_h     & cin[32],
              g_2l_31_16[14:0] | p_2l_31_16[14:0] & cin[31:17],
              g_1l_15_8_h      | p_1l_15_8_h      & cin[16],
              g_1l_15_8[6:0]   | p_1l_15_8[6:0]   & cin[15:9],
              g_0l_7_0_h       | p_0l_7_0_h       & cin[8],
              g_0l[6:0]        | p_0l[6:0]        & cin[7:1]};

assign a_xor_b = (~g) & p;

assign sum = a_xor_b ^ {c[62:0],cin[0]};

endmodule //exu_simd_add64

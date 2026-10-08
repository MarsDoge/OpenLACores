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

module dsu_gpr(
    input clock,
    input data_reset,

    input  [ 4:0] raddr0    ,  //[2:0] is e_ry
    output [31:0] rvalue0   ,
    input  [ 4:0] raddr1_0  ,  //[2:0] is e_rz
    output [31:0] rvalue1   ,  //rt_value, rz_value, r32_value
    input  [ 4:0] raddr1_1  ,  //lisa read rd
    input         raddr1_s  ,  //lisa choose rd
    input         wen0      ,
    input  [4 :0] waddr0    ,
    input  [31:0] wvalue0   ,
    output [31:0] ra_value

);
reg  [31:0] heap[31:1];

//Write
genvar i;
generate for (i=1; i<32; i=i+1)
begin : reg_write_loop
    always @(posedge clock)
    begin
        if (data_reset)
        begin
            heap[i] <= 32'd0;
        end
        else if ((waddr0==i[4:0])&&wen0)
        begin
            heap[i] <= wvalue0;
        end
    end
end
endgenerate

//Read rvalue0.
wire [31:0] rvalue0_0_7;
wire [31:0] rvalue0_8_15;
wire [31:0] rvalue0_16_23;
wire [31:0] rvalue0_24_31;
assign rvalue0_0_7   = {32{raddr0[2:0]==3'd1}} & heap[ 1] |
                       {32{raddr0[2:0]==3'd2}} & heap[ 2] |
                       {32{raddr0[2:0]==3'd3}} & heap[ 3] |
                       {32{raddr0[2:0]==3'd4}} & heap[ 4] |
                       {32{raddr0[2:0]==3'd5}} & heap[ 5] |
                       {32{raddr0[2:0]==3'd6}} & heap[ 6] |
                       {32{raddr0[2:0]==3'd7}} & heap[ 7] ;
assign rvalue0_8_15  = {32{raddr0[2:0]==3'd0}} & heap[ 8] |
                       {32{raddr0[2:0]==3'd1}} & heap[ 9] |
                       {32{raddr0[2:0]==3'd2}} & heap[10] |
                       {32{raddr0[2:0]==3'd3}} & heap[11] |
                       {32{raddr0[2:0]==3'd4}} & heap[12] |
                       {32{raddr0[2:0]==3'd5}} & heap[13] |
                       {32{raddr0[2:0]==3'd6}} & heap[14] |
                       {32{raddr0[2:0]==3'd7}} & heap[15] ;
assign rvalue0_16_23 = {32{raddr0[2:0]==3'd0}} & heap[16] |
                       {32{raddr0[2:0]==3'd1}} & heap[17] |
                       {32{raddr0[2:0]==3'd2}} & heap[18] |
                       {32{raddr0[2:0]==3'd3}} & heap[19] |
                       {32{raddr0[2:0]==3'd4}} & heap[20] |
                       {32{raddr0[2:0]==3'd5}} & heap[21] |
                       {32{raddr0[2:0]==3'd6}} & heap[22] |
                       {32{raddr0[2:0]==3'd7}} & heap[23] ;
assign rvalue0_24_31 = {32{raddr0[2:0]==3'd0}} & heap[24] |
                       {32{raddr0[2:0]==3'd1}} & heap[25] |
                       {32{raddr0[2:0]==3'd2}} & heap[26] |
                       {32{raddr0[2:0]==3'd3}} & heap[27] |
                       {32{raddr0[2:0]==3'd4}} & heap[28] |
                       {32{raddr0[2:0]==3'd5}} & heap[29] |
                       {32{raddr0[2:0]==3'd6}} & heap[30] |
                       {32{raddr0[2:0]==3'd7}} & heap[31] ;
assign rvalue0       = {32{raddr0[4:3]==2'd0}} & rvalue0_0_7  |
                       {32{raddr0[4:3]==2'd1}} & rvalue0_8_15 |
                       {32{raddr0[4:3]==2'd2}} & rvalue0_16_23|
                       {32{raddr0[4:3]==2'd3}} & rvalue0_24_31;
//Read rvalue1.
wire [4:0] true_raddr1 = raddr1_s ? raddr1_1 : raddr1_0;
assign rvalue1 = true_raddr1==5'd0 ? 32'd0 : heap[true_raddr1];
assign ra_value = heap[1];

endmodule //dsu_gpr

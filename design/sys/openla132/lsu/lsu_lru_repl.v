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

module lsu_lru_repl
#(
    parameter LRU_BITS= 6,
    parameter WAY_N   = 4
)(
    //update lru: hit pr refill
    input  [WAY_N   -1:0] new_way,
    input  [WAY_N   -1:0] way_lock,
    input                 new_wen,
    input                 new_clr,//clr clear lru and lock
    output [LRU_BITS-1:0] new_lru,
    output [LRU_BITS-1:0] new_lru_bitmask,

    //select way to repalce
    input  [LRU_BITS-1:0] repl_lru,
    output [WAY_N   -1:0] repl_way
);
wire [LRU_BITS -1:0] lru_wdata_tmp;
wire [LRU_BITS -1:0] lru_wen_tmp;
wire [LRU_BITS -1:0] lru_lock_mask_tmp;
wire [LRU_BITS -1:0] lru_lock_mask; //1 means can't update
assign new_lru         = lru_wdata_tmp ^{LRU_BITS{new_clr}};
assign new_lru_bitmask = lru_wen_tmp & ~lru_lock_mask & {LRU_BITS{new_wen}};
generate if (WAY_N==4)
begin: gen_lru_4way
    // way| 0  1   2   3
    // ___|______________
    //  0 | -  5   4   3
    //  1 | ~5  -  2   1
    //  2 | ~4 ~2  -   0
    //  3 | ~3 ~1  ~0  -
    //way ->lru
    assign lru_wdata_tmp     = {{3{new_way [0]}},{2{new_way[1]}},new_way[2]};
    assign lru_wen_tmp       =  {6{new_way [0]}} & 6'b111000 |
                                {6{new_way [1]}} & 6'b100110 |
                                {6{new_way [2]}} & 6'b010101 |
                                {6{new_way [3]}} & 6'b001011 ;
    assign lru_lock_mask_tmp =  {6{way_lock[0]}} & 6'b111000 |
                                {6{way_lock[1]}} & 6'b100110 |
                                {6{way_lock[2]}} & 6'b010101 |
                                {6{way_lock[3]}} & 6'b001011 ;
    //all ways are locked means no way locked.
    //clear lru also no care lock
    assign lru_lock_mask     = ((&way_lock)||new_clr) ? 6'b000000 : lru_lock_mask_tmp;
    //lru ->way :select oldest way
    assign repl_way[0] = !repl_lru[5] && !repl_lru[4] && !repl_lru[3];
    assign repl_way[1] =  repl_lru[5] && !repl_lru[2] && !repl_lru[1];
    assign repl_way[2] =  repl_lru[4] &&  repl_lru[2] && !repl_lru[0];
    //assign repl_way[3] =  repl_lru[3] &&  repl_lru[1] &&  repl_lru[0];
    assign repl_way[3] = !(repl_way[0]||repl_way[1]||repl_way[2]);
end
else
begin: gen_lru_2way
    // way| 0  1
    // ___|______
    //  0 | -  0
    //  1 | ~0  -
    //way ->lru
    assign lru_wdata_tmp     =  new_way[0];
    assign lru_wen_tmp       = |new_way;
    assign lru_lock_mask_tmp = |way_lock;
    //all ways are locked means no way locked.
    //clear lru also no care lock
    assign lru_lock_mask     = ((&way_lock)||new_clr) ? 1'b0 : lru_lock_mask_tmp;
    //lru ->way :select oldest way
    assign repl_way[0]     = !repl_lru[0];
    assign repl_way[1]     =  repl_lru[0];
end
endgenerate
endmodule

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

module ifu_plru2
#(
    parameter LRU_DEPTH= 6
)(
    input                           clk,
    input                           reset,
    input                           hit_update_lru,
    input  [LRU_DEPTH         -1:0] hit_update_pos,
    input                           lru_next,
    output [LRU_DEPTH         -1:0] new_pos
);

localparam LENGTH    = 2**(LRU_DEPTH) - 1;
localparam MAX_WIDTH = 2**(LRU_DEPTH-1);

reg  [LENGTH -1:0] lru_nodes;
wire               lru_nodes_wen;
wire [LENGTH -1:0] lru_update_mask;
wire [LENGTH -1:0] lru_update_data;

always @(posedge clk)
begin
    if (reset)
    begin
        lru_nodes  <= {LENGTH{1'b0}};
    end
    else if (lru_nodes_wen)
    begin
        lru_nodes <= lru_nodes&~lru_update_mask|lru_update_data&lru_update_mask;
    end
end

//wen
wire [LRU_DEPTH-1:0] lru_update_pos;
assign lru_update_pos = lru_next ? new_pos : hit_update_pos;
assign lru_nodes_wen  = hit_update_lru || lru_next;

assign lru_update_mask[0] = 1'b1;
assign lru_update_data[0] = ~lru_update_pos[LRU_DEPTH-1];
genvar i,j;
generate for (i=1;i<LRU_DEPTH;i=i+1)begin
    for (j=0;j<(2**i);j=j+1)begin
        assign lru_update_mask[(2**i)-1+j] = lru_update_pos[LRU_DEPTH-1:LRU_DEPTH-i] == j;
        assign lru_update_data[(2**i)-1+j] = ~lru_update_pos[LRU_DEPTH-i-1];
    end
end
endgenerate

//read
wire [LENGTH -1:0] lru_read_mask;
wire [LENGTH -1:0] lru_pos = lru_read_mask& lru_nodes;
wire [LENGTH -1:0] lru_neg = lru_read_mask&~lru_nodes;
assign lru_read_mask[0] = 1'b1;
assign new_pos[LRU_DEPTH-1] = lru_read_mask[0]&lru_nodes[0];
generate for (i=1;i<LRU_DEPTH;i=i+1)begin
    for (j=0;j<(2**i);j=j+1)begin
        assign lru_read_mask[(2**i)-1+j] = j%2 ? lru_pos[(2**(i-1))-1+j/2] : lru_neg[(2**(i-1))-1+j/2];
    end
    assign new_pos[LRU_DEPTH-1-i] = |(lru_read_mask[(2**(i+1))-2:(2**i)-1]&lru_nodes[(2**(i+1))-2:(2**i)-1]);
end
endgenerate
endmodule

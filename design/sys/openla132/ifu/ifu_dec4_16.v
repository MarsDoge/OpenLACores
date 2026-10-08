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

module ifu_dec4_16 #
(
    parameter M = 16
)
(
    input  wire [$clog2(M)-1:0] decode_index,
    output wire [        M-1:0] decode_onehot
);

genvar i;
generate
    for (i = 0; i < M; i = i + 1)
    begin : gen_dec_n_m
        assign decode_onehot[i] = (decode_index == i[$clog2(M)-1:0]);
    end
endgenerate
endmodule

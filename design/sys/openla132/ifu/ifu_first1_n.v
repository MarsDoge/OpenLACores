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

module ifu_first1_n #
(
    parameter N = 16
)
(
    input  wire [N-1:0] first_one_input,
    output wire [N-1:0] first_one_output,
    output wire         first_one_has
);
assign first_one_output[0] = first_one_input[0];
genvar i;
generate
    for (i = 1; i < N; i = i + 1)
    begin : gen_first_one_n
        assign first_one_output[i] = first_one_input[i] & (~|first_one_input[i-1:0]);
    end
endgenerate

assign first_one_has = |first_one_input[N-1:0];
endmodule

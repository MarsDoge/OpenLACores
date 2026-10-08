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

module ifu_enc_n_m #
(
    parameter N = 4
)
(
    input  wire [        N-1:0] encode_onehot,
    output wire [$clog2(N)-1:0] encode_value
);

reg [$clog2(N)-1:0] enc_res;

integer i;
always @(*)
begin
    enc_res = {$clog2(N){1'b0}};
    for (i = 0; i < N; i = i + 1)
    begin
        if (encode_onehot[i]) enc_res = enc_res | i[$clog2(N)-1:0];
    end
end

assign encode_value = enc_res;

endmodule //ifu_enc_n_m

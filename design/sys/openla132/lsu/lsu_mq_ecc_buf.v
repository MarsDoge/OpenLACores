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

module lsu_mq_ecc_buf #(
    parameter ECC_BITS = 8
)(
    input                     has_ecc        ,
    input                     clk            ,
    input                     data_reset     ,
    input                     mq_ecc_in_valid,
    input  [ECC_BITS   -1:0]  mq_tagv_syndrome_in,
    input  [ECC_BITS*8 -1:0]  mq_data_syndrome_in,

    output [ECC_BITS   -1:0]  mq_tagv_syndrome_q,
    output [ECC_BITS*8 -1:0]  mq_data_syndrome_q
);
localparam ECC_BITS_X8 = ECC_BITS*8;

reg [ECC_BITS   -1:0]  mq_tagv_syndrome_r;
reg [ECC_BITS*8 -1:0]  mq_data_syndrome_r;
always @(posedge clk)
begin
    if(data_reset)
    begin
        mq_tagv_syndrome_r <= {ECC_BITS   {1'b0}};
        mq_data_syndrome_r <= {ECC_BITS_X8{1'b0}};
    end
    else if (mq_ecc_in_valid)
    begin
        mq_tagv_syndrome_r <= mq_tagv_syndrome_in;
        mq_data_syndrome_r <= mq_data_syndrome_in;
    end
end

assign mq_tagv_syndrome_q = mq_tagv_syndrome_r & {ECC_BITS   {has_ecc}};
assign mq_data_syndrome_q = mq_data_syndrome_r & {ECC_BITS_X8{has_ecc}};
endmodule

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

module lsu_mq_axi_buf #(
    parameter DATA_WD = 32   //32/64/128
)(
    input                       clk,
    input                       reset,
    input                       data_reset,
    input                       hit_mq_wen,
    input      [DATA_WD/8 -1:0] hit_mq_strb,
    input      [DATA_WD   -1:0] hit_mq_wdata,
    input                       upd_valid,  //axi back / shift for wdata
    input      [DATA_WD   -1:0] upd_data,

    input                       valid_clr,
    input                       valid_set,

    output reg [DATA_WD   -1:0] buf_data_axi,
    output reg                  buf_valid_axi
);
always @(posedge clk)
begin
    if (reset || valid_clr)
    begin
        buf_valid_axi <= 1'b0;
    end
    else if (valid_set)
    begin
        buf_valid_axi <= 1'b1;
    end
end
genvar i;
generate
    for (i=0; i<DATA_WD/8; i=i+1)
    begin:gen_mq_buf_data_axi_8bit
        always @(posedge clk)
        begin
            if (data_reset)
            begin
                buf_data_axi[8*i+7:8*i] <= 8'd0;
            end
            else if (hit_mq_wen && hit_mq_strb[i])
            begin
                buf_data_axi[8*i+7:8*i] <= hit_mq_wdata[8*i+7:8*i];
            end
            else if (upd_valid)
            begin
                buf_data_axi[8*i+7:8*i] <= upd_data[8*i+7:8*i];
            end
        end
    end
endgenerate
endmodule

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

module lsu_mq_axi_bufs #(
    parameter DATA_WD = 32
) (
    input  wire                   clk,
    input  wire                   reset,
    input  wire                   data_reset,
    input  wire [          7: 0]  hit_mq_wen,
    input  wire [DATA_WD/8-1: 0]  hit_mq_strb,
    input  wire [  DATA_WD-1: 0]  hit_mq_wdata,
    input  wire [          7: 0]  upd_valid,
    input  wire [8*DATA_WD-1: 0]  upd_data,
    input  wire [          7: 0]  valid_clr,
    input  wire [          7: 0]  valid_set,
    output wire [8*DATA_WD-1: 0]  buf_data,
    output wire [          7: 0]  buf_valid
);

genvar i;
generate
    for (i = 0; i < 8; i = i + 1) begin: gen_mq_axi_buf
        lsu_mq_axi_buf #(
            .DATA_WD (DATA_WD)
        ) x_lsu_mq_axi_buf (
            .clk           (clk),
            .reset         (reset),
            .data_reset    (data_reset),
            .hit_mq_wen    (hit_mq_wen[i]),
            .hit_mq_strb   (hit_mq_strb),
            .hit_mq_wdata  (hit_mq_wdata),
            .upd_valid     (upd_valid[i]),
            .upd_data      (upd_data[DATA_WD*i +: DATA_WD]),
            .valid_clr     (valid_clr[i]),
            .valid_set     (valid_set[i]),
            .buf_data_axi  (buf_data[DATA_WD*i +: DATA_WD]),
            .buf_valid_axi (buf_valid[i])
        );
    end
endgenerate

endmodule

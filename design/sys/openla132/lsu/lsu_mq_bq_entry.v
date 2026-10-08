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

module lsu_mq_bq_entry (
    input  wire           clk,
    input  wire           reset,
    input  wire           entry_active,
    input  wire           in_en,
    input  wire           enter_selected,
    input  wire [ 14: 0]  in_addr_fold,
    input  wire           axi_b_ok,
    input  wire           axi_id_match,

    output reg            entry_valid,
    output reg  [ 14: 0]  entry_addr
);

//============================================================//
//                    Module Implementation
//============================================================//

always @ ( posedge clk )
begin
    if(entry_active) begin
        if(reset) begin
            entry_valid <= 1'b0;
        end
        else if(in_en || axi_b_ok) begin
            if(in_en && enter_selected) begin
                entry_addr <= in_addr_fold;
            end

            if(in_en && enter_selected) begin
                entry_valid <= 1'b1;
            end
            else if(axi_b_ok && axi_id_match) begin
                entry_valid <= 1'b0;
            end
        end
    end
end

endmodule

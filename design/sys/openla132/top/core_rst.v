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

module core_rst (
    input  wire           clk,
    input  wire           resetn_in_d2,
    input  wire           ram_init_cmplt,
    output reg            reset
);

//============================================================//
//                    Module Implementation
//============================================================//

always @ ( posedge clk )
begin
    if(!resetn_in_d2) begin
        reset <= 1'b1;
    end
    else if(ram_init_cmplt) begin
        reset <= 1'b0;
    end
end
endmodule

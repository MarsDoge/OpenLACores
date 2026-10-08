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

module ljtag_core_rst (
    input  wire           tck,
    input  wire           trstn_in,
    output wire           trstn_out,
    input  wire           testmode
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg          rff;
reg          rff1;

//============================================================//
//                    Module Implementation
//============================================================//

always @ ( posedge tck or negedge trstn_in )
begin
    if(!trstn_in) begin
        {rff1, rff} <= 2'b0;
    end
    else begin
        {rff1, rff} <= {rff, 1'b1};
    end
end

assign trstn_out  =  testmode ? trstn_in : rff1;

endmodule

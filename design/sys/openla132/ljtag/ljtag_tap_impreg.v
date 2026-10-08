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

`ifdef OPEN132_HAS_LJTAG

module ljtag_tap_impreg (
    input  wire           tck_in,
    input  wire           trst_in,
    input  wire           enable,
    input  wire           cap,
    input  wire           shift,
    input  wire           si,
    output wire           so
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg [ 31: 0] sr;

//============================================================//
//                     Wire Declarations
//============================================================//

wire [ 31: 0] imp_init;

//============================================================//
//                    Module Implementation
//============================================================//

assign imp_init  =  32'h60400000;

assign so  =  sr[0];

`ifdef OPEN132_LJTAG_SYNC_RESET
always @ ( posedge tck_in )
`else
always @ ( posedge tck_in or negedge trst_in )
`endif
begin
    if(!trst_in) begin
        sr <= imp_init;
    end
    else if(cap && enable) begin
        sr <= imp_init;
    end
    else if(shift && enable) begin
        sr <= {si, sr[32 - 1 : 1]};
    end
end

endmodule

`endif  // OPEN132_HAS_LJTAG

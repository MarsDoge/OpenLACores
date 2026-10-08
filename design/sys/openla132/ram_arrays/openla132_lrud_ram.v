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

module openla132_lrud_ram #(
    parameter ADDR_WD = 1,
    parameter DATA_WD = 1,
    parameter WEN_WD  = 1
) (
    input  wire                 clk,
    input  wire                 en,
    input  wire [ WEN_WD-1: 0]  wen,
    input  wire [ADDR_WD-1: 0]  addr,
    input  wire [DATA_WD-1: 0]  wdata,
    output wire [DATA_WD-1: 0]  rdata
);

//============================================================//
//                    Module Implementation
//============================================================//

openla132_spram_bitmask #(
    .Words (2**ADDR_WD),
    .Bits  (DATA_WD   )
) x_open132_spram_bitmask (
    .Q   (rdata  ),
    .CLK (clk    ),
    .CEN (~en    ),
    .LS  (1'b0   ),
    .WEN (~(|wen)),
    .M   (~wen   ),
    .A   (addr   ),
    .D   (wdata  )
);

endmodule  // openla132_lrud_ram

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

module mmu_vaddr_cfgseg #(
    parameter CFGSEG_NUM = 3
) (
    input  wire [          31: 0]  vaddr,
    output wire [CFGSEG_NUM-1: 0]  cfgseg
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire [  7: 0] lisa_seg;

//============================================================//
//                    Module Implementation
//============================================================//

assign lisa_seg  =  {
                      vaddr[31:29] == 3'h7,
                      vaddr[31:29] == 3'h6,
                      vaddr[31:29] == 3'h5,
                      vaddr[31:29] == 3'h4,
                      vaddr[31:29] == 3'h3,
                      vaddr[31:29] == 3'h2,
                      vaddr[31:29] == 3'h1,
                      vaddr[31:29] == 3'h0
                    };
assign cfgseg    =  lisa_seg;

endmodule

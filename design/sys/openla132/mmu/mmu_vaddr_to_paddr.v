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

module mmu_vaddr_to_paddr (
    input  wire           lisa_da,  // da-mode, paddr=vaddr
    input  wire [ 23: 0]  lisa_segpa,  // for lisa, pa of seg7-seg0

    input  wire [  2: 0]  vaddr_h3,

    output wire [  2: 0]  paddr_h3
);

//============================================================//
//                     Wire Declarations
//============================================================//

// lisa segMT
wire [  2: 0] lisa_paddr_h3;

//============================================================//
//                    Module Implementation
//============================================================//

assign lisa_paddr_h3  =  {3{vaddr_h3 == 3'h7}} & lisa_segpa[23:21] | {3{vaddr_h3 == 3'h6}} & lisa_segpa[20:18] |
                           {3{vaddr_h3 == 3'h5}} & lisa_segpa[17:15] | {3{vaddr_h3 == 3'h4}} & lisa_segpa[14:12] |
                           {3{vaddr_h3 == 3'h3}} & lisa_segpa[11:9] | {3{vaddr_h3 == 3'h2}} & lisa_segpa[8 : 6] |
                           {3{vaddr_h3 == 3'h1}} & lisa_segpa[5 : 3] | {3{vaddr_h3 == 3'h0}} & lisa_segpa[2 : 0];

assign paddr_h3  =  lisa_da ? vaddr_h3 : lisa_paddr_h3;
endmodule

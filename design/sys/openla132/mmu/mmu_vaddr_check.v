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

module mmu_vaddr_check (
    input  wire           lisa_da,  // da-mode, paddr=vaddr
    input  wire [  1: 0]  lisa_dacm,
    input  wire [  7: 0]  lisa_segplv,  // 1: can access by PLV3; 0: only access by PLV0
    input  wire [  7: 0]  lisa_segca_dev,  // 1: device-attribute

    input  wire [ 31: 0]  vaddr,

    input  wire           dbgm,
    input  wire           user_mode,

    output wire           addr_mem,
    output wire           ade_priv
);

//============================================================//
//                     Wire Declarations
//============================================================//

// lisa seg7~0;
wire [  7: 0] lisa_seg;

// if in da-mode, not cached will set deviceseg.
wire          lisa_deviceseg;
wire          deviceseg;

// software should set da-mode when PLV!=0, but if set, won't signal ADE.
wire          lisa_ade_priv;

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
//------------------------------------------------------------//
//                  Memory Device Attribute
//------------------------------------------------------------//
assign lisa_deviceseg  =  lisa_da ? lisa_dacm != 2'b01 : |(lisa_seg & lisa_segca_dev);
assign deviceseg       =  lisa_deviceseg;
assign addr_mem        =  !(deviceseg || dbgm);
// End Memory Device Attribute

//------------------------------------------------------------//
//                         Privilege
//------------------------------------------------------------//
assign lisa_ade_priv  =  lisa_da ? 1'b0 : user_mode && !(|(lisa_seg & lisa_segplv));
assign ade_priv       =  lisa_ade_priv;
// End Privilege
endmodule

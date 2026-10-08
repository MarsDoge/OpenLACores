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

`ifndef OPEN132_CONFIG_H
`define OPEN132_CONFIG_H
//-------- ip configuration --------

//cfg-----------------------------------1-------------------------------------//
//-----data reset:
//-----Usually, data path needn't be reseted.
//-----Open this macro define, if you want to reset all data path.
`define _OPEN132_DATA_PATH_RESET

//cfg-----------------------------------2-------------------------------------//
//-----low power:
//-----if define OPEN132_LOW_POWER, many combinational logic will be mask, so
//-----can reduce power, but timing is worse.
`define OPEN132_LOW_POWER

`ifdef CONFIG_MMU
`define OPEN132_COUNT64
`endif

//cfg-----------------------------------5-------------------------------------//
`define OPEN132_HAS_LJTAG

//1. at most time, ljtag use async-reset,
//2. if need, can config ljtag with sync-reset, but break also use async-reset.
`define _OPEN132_LJTAG_SYNC_RESET

//cfg-----------------------------------6-------------------------------------//
//-----OPEN132_INTERFACE
`define OPEN132_INTERFACE_AXI
`define OPEN132_AXI_HANDSHAKE  //i/d_sram handshake for axi configuration

`define OPEN132_N_AXI_WID  4 //depth of wait B queue

//cfg----------------------------------7-------------------------------------//
//-----output wb-stage state
`define _OPEN132_OUTPUT_WB_STATE

//cfg----------------------------------9-------------------------------------//
//-----DFT: unsupported
//`define OPEN132_INCLUDE_DFT
`endif // OPEN132_CONFIG_H

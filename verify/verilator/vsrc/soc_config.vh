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


`ifndef OPEN132_VERILATOR_SOC_CONFIG_VH
`define OPEN132_VERILATOR_SOC_CONFIG_VH

// Local SRAM windows used by the standalone verification workloads.
`define OPEN132_LOCAL_SRAM_BASE     32'h1c00_0000
`define OPEN132_LOCAL_SRAM_MASK     32'hff80_0000
`define OPEN132_LOCAL_DSRAM_BASE    32'h1c80_0000
`define OPEN132_CONSOLE_MMIO_ADDR   32'h9fe0_0000
`define OPEN132_RT_DSRAM_BASE       32'h1500_0000
`define OPEN132_RT_MMIO_BASE        32'hbfe0_0000
`define OPEN132_RT_MMIO_MASK        32'hfff0_0000

`endif

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

module mmu_vaddr_sel_bus (
    input  wire [           31: 0]  vaddr,
    input  wire [(1+32+32)*4-1: 0]  ibus_win,
    input  wire [(1+32+32)*4-1: 0]  dbus_win,

    output wire                     ibus_hit,
    output wire                     dbus_hit,
    output wire                     sysbus_hit
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire          ibus0_valid;
wire          ibus1_valid;
wire          ibus2_valid;
wire          ibus3_valid;
wire [ 31: 0] ibus0_base;
wire [ 31: 0] ibus1_base;
wire [ 31: 0] ibus2_base;
wire [ 31: 0] ibus3_base;
wire [ 31: 0] ibus0_mask;
wire [ 31: 0] ibus1_mask;
wire [ 31: 0] ibus2_mask;
wire [ 31: 0] ibus3_mask;
wire          dbus0_valid;
wire          dbus1_valid;
wire          dbus2_valid;
wire          dbus3_valid;
wire [ 31: 0] dbus0_base;
wire [ 31: 0] dbus1_base;
wire [ 31: 0] dbus2_base;
wire [ 31: 0] dbus3_base;
wire [ 31: 0] dbus0_mask;
wire [ 31: 0] dbus1_mask;
wire [ 31: 0] dbus2_mask;
wire [ 31: 0] dbus3_mask;

//============================================================//
//                    Module Implementation
//============================================================//

assign {ibus0_valid,  // 1
        ibus0_base,  // 32
        ibus0_mask,  // 32
        ibus1_valid,  // 1
        ibus1_base,  // 32
        ibus1_mask,  // 32
        ibus2_valid,  // 1
        ibus2_base,  // 32
        ibus2_mask,  // 32
        ibus3_valid,  // 1
        ibus3_base,  // 32
        ibus3_mask  // 32
        }  =  ibus_win;
assign {dbus0_valid,  // 1
        dbus0_base,  // 32
        dbus0_mask,  // 32
        dbus1_valid,  // 1
        dbus1_base,  // 32
        dbus1_mask,  // 32
        dbus2_valid,  // 1
        dbus2_base,  // 32
        dbus2_mask,  // 32
        dbus3_valid,  // 1
        dbus3_base,  // 32
        dbus3_mask  // 32
        }  =  dbus_win;
assign ibus_hit  =  ((vaddr & ibus0_mask) == ibus0_base) && ibus0_valid ||
                      ((vaddr & ibus1_mask) == ibus1_base) && ibus1_valid || ((vaddr & ibus2_mask) == ibus2_base) && ibus2_valid ||
                      ((vaddr & ibus3_mask) == ibus3_base) && ibus3_valid;
assign dbus_hit  =  ((vaddr & dbus0_mask) == dbus0_base) && dbus0_valid ||
                      ((vaddr & dbus1_mask) == dbus1_base) && dbus1_valid || ((vaddr & dbus2_mask) == dbus2_base) && dbus2_valid ||
                      ((vaddr & dbus3_mask) == dbus3_base) && dbus3_valid;

assign sysbus_hit  =  ~ibus_hit & ~dbus_hit;

endmodule

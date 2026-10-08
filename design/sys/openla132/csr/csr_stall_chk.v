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

module csr_stall_chk (
    input  wire           inst_csr_write,
    input  wire [ 13: 0]  csr_num,

    output wire           ctrl_stallf
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire          lisa_stallf;  // PLV

//============================================================//
//                    Module Implementation
//============================================================//

assign lisa_stallf  =  ((csr_num == 14'h0)
                       || (csr_num == 14'h2)  // UnitEn
                       || (csr_num == 14'h3)  // func-cfg
                       || (csr_num == 14'h4)  // ex-cfg
                       || (csr_num == 14'h18)  // asid
`ifdef CONFIG_MMU
                       || (csr_num == 14'h19)  // pgdl
                       || (csr_num == 14'h1a)  // pgdh
                       || (csr_num == 14'h1c)  // pwctl0
                       || (csr_num == 14'h1d)  // pwctl1
`endif
                       || (csr_num == 14'h44)  // timercfg
                       || (csr_num == 14'h80)  // gsconfig
                       || (csr_num == 14'haf)  // userdef
                       || (csr_num == 14'hff)  // elusion
                       || (csr_num[13:5] == 9'h00c)  // 0x180~19f, 0x00_0001_100x_xxxx, mpu, segpa/ca
                       || (csr_num[13:8] == 6'h05)  // 0x5xx    , 0x00_0101_xxxx_xxxx, debug
                         ) && inst_csr_write;

assign ctrl_stallf  =  lisa_stallf;
endmodule  // csr_stall_chk

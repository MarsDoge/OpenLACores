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


module openla132_std_cell_cmux2 (
    input  wire           D0,
    input  wire           D1,
    input  wire           S0,
    output wire           Z
);

//============================================================//
//                    Module Implementation
//============================================================//

/***************************************************************
 * Notes:
 *   The following codes only for simulation and FPGA implementation.
 *   if you customize chips, Please add code here.
 *
 ***************************************************************/

assign Z  =  S0 ? D1 : D0;

endmodule  // openla132_std_cell_cmux2

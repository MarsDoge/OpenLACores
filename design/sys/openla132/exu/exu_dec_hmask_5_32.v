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

module exu_dec_hmask_5_32 (
    input  wire [  4: 0]  in,
    output wire [ 31: 0]  out
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire [  7: 0] low;

//============================================================//
//                    Module Implementation
//============================================================//

assign low[7]  =  1'b1;  //-000,001,010,011,100,101,110,111-/
assign low[6]  =  ~in[2] | (~in[1] | ~in[0]);  //-000,001,010,011,100,101,110-/
assign low[5]  =  ~in[2] | ~in[1];  //-000,001,010,011,100,101-/
assign low[4]  =  ~in[2] | (~in[1] & ~in[0]);  //-000,001,010,011,100-/
assign low[3]  =  ~in[2];  //-000,001,010,011-/
assign low[2]  =  ~in[2] & (~in[1] | ~in[0]);  //-000,001,010-/
assign low[1]  =  ~in[2] & ~in[1];  //-000,001-/
assign low[0]  =  ~in[2] & (~in[1] & ~in[0]);  //-000-/

assign out[31]  =  1'b1;  // 1'b1
assign out[30]  =  ~in[4] | (~in[3] | low[6]);
assign out[29]  =  ~in[4] | (~in[3] | low[5]);
assign out[28]  =  ~in[4] | (~in[3] | low[4]);
assign out[27]  =  ~in[4] | (~in[3] | low[3]);
assign out[26]  =  ~in[4] | (~in[3] | low[2]);
assign out[25]  =  ~in[4] | (~in[3] | low[1]);
assign out[24]  =  ~in[4] | (~in[3] | low[0]);
assign out[23]  =  ~in[4] | ~in[3];  // !in[4] || !in[3]
assign out[22]  =  ~in[4] | (~in[3] & low[6]);
assign out[21]  =  ~in[4] | (~in[3] & low[5]);
assign out[20]  =  ~in[4] | (~in[3] & low[4]);
assign out[19]  =  ~in[4] | (~in[3] & low[3]);
assign out[18]  =  ~in[4] | (~in[3] & low[2]);
assign out[17]  =  ~in[4] | (~in[3] & low[1]);
assign out[16]  =  ~in[4] | (~in[3] & low[0]);
assign out[15]  =  ~in[4];  // !in[4]
assign out[14]  =  ~in[4] & (~in[3] | low[6]);
assign out[13]  =  ~in[4] & (~in[3] | low[5]);
assign out[12]  =  ~in[4] & (~in[3] | low[4]);
assign out[11]  =  ~in[4] & (~in[3] | low[3]);
assign out[10]  =  ~in[4] & (~in[3] | low[2]);
assign out[9]   =  ~in[4] & (~in[3] | low[1]);
assign out[8]   =  ~in[4] & (~in[3] | low[0]);
assign out[7]   =  ~in[4] & ~in[3];  // !in[4] & !in[3]
assign out[6]   =  ~in[4] & (~in[3] & low[6]);
assign out[5]   =  ~in[4] & (~in[3] & low[5]);
assign out[4]   =  ~in[4] & (~in[3] & low[4]);
assign out[3]   =  ~in[4] & (~in[3] & low[3]);
assign out[2]   =  ~in[4] & (~in[3] & low[2]);
assign out[1]   =  ~in[4] & (~in[3] & low[1]);
assign out[0]   =  ~in[4] & (~in[3] & low[0]);
endmodule  // exu_dec_hmask_5_32

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

module rtu_expt_entry (
    input  wire [  2: 0]  lisa_vs,
    input  wire [  6: 0]  lisa_vscode,
    input  wire [ 19: 0]  merrentry,

    input  wire [ 19: 0]  eentry,

    input  wire           ex_debug,
    input  wire           ex_general_in_debug_mode,
    input  wire           ex_srnmi,

    output wire [ 31: 0]  ex_entry
);

//============================================================//
//                     Wire Declarations
//============================================================//

wire [ 31: 0] debug_entry;      // entry for debug_ex or ex in debug_mode
wire [ 31: 0] srnmi_entry;      // entry for softreset or nmi
wire [ 31: 0] general_entry;    // entry for general ex
wire [ 31: 0] lisa_norm_entry;

// lisa normal ex
wire [ 15: 0] lisa_norm_off;

//============================================================//
//                    Module Implementation
//============================================================//

// debug

assign debug_entry  =  32'hdb00_0000;
// mc: NMI, CachErr
assign srnmi_entry  =  {merrentry, 12'd0};
// normal ex
assign general_entry  =  lisa_norm_entry;

assign lisa_norm_entry  =  {eentry, 12'd0} | {16'd0, lisa_norm_off};
assign lisa_norm_off    =  {16{lisa_vs == 3'd0}} & 16'd0 | {16{lisa_vs == 3'd1}} & {6'd0, lisa_vscode, 3'd0} |
                             {16{lisa_vs == 3'd2}} & {5'd0, lisa_vscode, 4'd0} | {16{lisa_vs == 3'd3}} & {4'd0, lisa_vscode, 5'd0} |
                             {16{lisa_vs == 3'd4}} & {3'd0, lisa_vscode, 6'd0} | {16{lisa_vs == 3'd5}} & {2'd0, lisa_vscode, 7'd0} |
                             {16{lisa_vs == 3'd6}} & {1'd0, lisa_vscode, 8'd0} | {16{lisa_vs == 3'd7}} & {lisa_vscode, 9'd0};

// fial ex_entry
assign ex_entry  =  ex_debug || ex_general_in_debug_mode ? debug_entry :
                      ex_srnmi ? srnmi_entry : general_entry;  // for ex_general
endmodule

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

module exu_amdu_pipe (
    input  wire           clk,
    input  wire           reset,
    input  wire           data_reset,
    // de
    input  wire           idu_exu_valid,
    input  wire           de_multiply,
    input  wire           de_divide,
    input  wire           de_togpr,
    input  wire           de_selhl,
    input  wire           de_flag,
    // mem
    output wire           mem_begin,
    output wire           mem_do_div,
    input  wire           mem_complete,

    // mdu and iu
    input  wire [  2: 0]  lsu_exu_ctrl_bus,
    input  wire [  5: 0]  rtu_exu_ctrl_bus,
    output wire           exu_idu_allowin,
    output wire           mdu_is_run,
    output wire           exu_rtu_valid,
    output wire           wb_selhl
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg          mem_valid;

reg          mem_divide;
reg          mem_togpr;
reg          mem_selhl;

// order flag
reg          mem_flag;
reg          mem_oldest;

//============================================================//
//                     Wire Declarations
//============================================================//

// lsu_exu_ctrl_bus
wire          iu_mem_valid;
wire          iu_mem_flag;
wire          iu_mem_wait_mdu;

// rtu_exu_ctrl_bus
wire          iu_wb_valid;
wire          iu_wb_validout;
wire          iu_wb_mul;
wire          iu_wb_flag;
wire          iu_wb_allowin;
wire          exbus_ex;

wire          de_cancel;
wire          de_validout;

wire          mem_cancel;
wire          lsu_idu_allowin;
wire          mem_cango;

wire          commit_en;
wire          iu_inst_complete;
wire          mdu_inst_complete;
wire          iu_inst_commit;
wire          mdu_inst_commit;

// NOTE: exbus_ex=1 is possible only when iu_wb_valid=1
wire          mem_newer_iuwb;

// iuwb no inst, iumem oldest than mdu_mem
wire          mem_newer_iumem;

//============================================================//
//                    Module Implementation
//============================================================//

assign {iu_mem_valid, iu_mem_flag, iu_mem_wait_mdu}  =  lsu_exu_ctrl_bus;

assign {iu_wb_valid, iu_wb_validout, iu_wb_mul, iu_wb_flag, iu_wb_allowin, exbus_ex}  =  rtu_exu_ctrl_bus;

assign mem_newer_iuwb   =  mem_valid && (iu_wb_valid && !(iu_wb_flag == mem_flag || mem_oldest) || mem_togpr);
assign mem_newer_iumem  =  mem_valid && (iu_mem_valid && !(iu_mem_flag == mem_flag || mem_oldest) && !iu_wb_valid);
assign mem_cancel       =  exbus_ex && mem_newer_iuwb;

assign de_cancel    =  exbus_ex;
assign de_validout  =  idu_exu_valid && lsu_idu_allowin;

// order flag
always @ ( posedge clk )
begin
    if(data_reset) begin
        mem_flag <= 1'b0;
    end
    else if(de_validout) begin
        mem_flag <= de_flag;
    end

    if(data_reset) begin
        mem_oldest <= 1'b0;
    end
    else if(de_validout) begin
        mem_oldest <= 1'b0;
    end
    else if(iu_wb_validout && !mem_newer_iuwb) begin
        mem_oldest <= 1'b1;
    end
end

always @ ( posedge clk )
begin
    if(reset || mem_cancel) begin
        mem_valid <= 1'b0;
    end
    else if(lsu_idu_allowin) begin
        mem_valid <= idu_exu_valid && !de_cancel;
    end

    if(data_reset) begin
        mem_divide <= 1'b0;
        mem_togpr  <= 1'b0;
        mem_selhl  <= 1'b0;
    end
    else if(de_validout) begin
        mem_divide <= de_divide;
        mem_togpr  <= de_togpr;
        mem_selhl  <= de_selhl;
    end
end

assign lsu_idu_allowin  =  !mem_valid || mem_cango;
assign mem_cango        =  commit_en;

assign commit_en          =  (iu_inst_commit || mdu_inst_commit) && !mem_cancel;
assign iu_inst_complete   =  mem_valid && mem_complete && mem_togpr;
assign mdu_inst_complete  =  mem_valid && mem_complete && !mem_togpr;
assign iu_inst_commit     =  iu_inst_complete && (iu_wb_mul && iu_wb_valid || iu_mem_wait_mdu);
assign mdu_inst_commit    =  mdu_inst_complete && !(mem_newer_iuwb || mem_newer_iumem);
assign mem_begin          =  de_validout && (de_divide || de_multiply);
assign mem_do_div         =  mem_divide;

assign exu_idu_allowin  =  lsu_idu_allowin;
assign mdu_is_run       =  mem_valid;
assign exu_rtu_valid    =  iu_inst_complete && !mem_cancel;
assign wb_selhl         =  mem_selhl;
endmodule  // exu_amdu_pipe

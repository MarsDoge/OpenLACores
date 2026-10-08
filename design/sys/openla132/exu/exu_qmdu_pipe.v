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

module exu_qmdu_pipe (
    input  wire           clk,
    input  wire           reset,
    input  wire           data_reset,

    input  wire           dec_togpr,
    input  wire           dec_selhl,
    input  wire           dec_flag,
    input  wire           idu_exu_valid,
    output wire           exu_idu_allowin,
    output wire           de_validout,
    output wire           de_cancel,

    input  wire [  2: 0]  lsu_exu_ctrl_bus,
    input  wire           mem_mul_complete,
    input  wire           mem_div_complete,
    output wire           mem_validout,
    output wire           mem_cancel,

    input  wire [  5: 0]  rtu_exu_ctrl_bus,
    output wire           rtu_lsu_allowin,
    output wire           wb_dest_gpr,
    output wire           mdu_is_run,
    output wire           exu_rtu_valid,
    output wire           sel_hl
);

//============================================================//
//                     Regs Declarations
//============================================================//

reg          mem_valid;
reg          mem_togpr;
reg          mem_selhl;

reg          wb_valid;
reg          wb_togpr;
reg          wb_selhl;

// order flag
reg          mem_flag;
reg          mem_oldest;  // mdu mem instruction is older than main-pipeline
reg          wb_flag;
reg          wb_oldest;   // mdu wb instruction is older than main-pipeline

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

wire          lsu_idu_allowin;
wire          mem_cango;
wire          mem_complete;

wire          wb_cancel;

wire          commit_en;
wire          iu_inst_commit;
wire          mdu_inst_commit;

// NOTE: exbus_ex=1 is possible only when iu_wb_valid=1
wire          wb_newer_iuwb;
wire          mem_newer_iuwb;

// iuwb no inst, iumem oldest than mdu_wb
wire          wb_newer_iumem;

// order flag
wire          next_mem_oldest;

//============================================================//
//                    Module Implementation
//============================================================//

assign {iu_mem_valid, iu_mem_flag, iu_mem_wait_mdu}  =  lsu_exu_ctrl_bus;

assign {iu_wb_valid, iu_wb_validout, iu_wb_mul, iu_wb_flag, iu_wb_allowin, exbus_ex}  =  rtu_exu_ctrl_bus;

assign wb_newer_iuwb   =  wb_valid && (iu_wb_valid && !(iu_wb_flag == wb_flag || wb_oldest) || wb_togpr);
assign mem_newer_iuwb  =  mem_valid && (iu_wb_valid && !(iu_wb_flag == mem_flag || mem_oldest) || mem_togpr);
assign wb_newer_iumem  =  wb_valid && (iu_mem_valid && !(iu_mem_flag == wb_flag || wb_oldest) && !iu_wb_valid);
assign mem_cancel      =  exbus_ex && (mem_newer_iuwb || wb_newer_iuwb);
assign wb_cancel       =  exbus_ex && wb_newer_iuwb;

assign de_cancel    =  exbus_ex;
assign de_validout  =  idu_exu_valid && lsu_idu_allowin;

assign next_mem_oldest  =  mem_valid && iu_wb_validout && !mem_newer_iuwb;
always @ ( posedge clk )
begin
    if(data_reset) begin
        mem_flag <= 1'b0;
    end
    else if(de_validout) begin
        mem_flag <= dec_flag;
    end

    if(data_reset) begin
        mem_oldest <= 1'b0;
    end
    else if(de_validout) begin
        mem_oldest <= 1'b0;
    end
    else if(next_mem_oldest) begin
        mem_oldest <= 1'b1;
    end

    if(data_reset) begin
        wb_flag <= 1'b0;
    end
    else if(mem_validout) begin  // include rtu_lsu_allowin
        wb_flag <= mem_flag;
    end

    if(data_reset) begin
        wb_oldest <= 1'b0;
    end
    else if(mem_validout) begin  // include rtu_lsu_allowin
        wb_oldest <= mem_oldest || next_mem_oldest;
    end
    else if(iu_wb_validout && !wb_newer_iuwb) begin
        wb_oldest <= 1'b1;
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
        mem_togpr <= 1'b0;
        mem_selhl <= 1'b0;
    end
    else if(lsu_idu_allowin && idu_exu_valid) begin
        mem_togpr <= dec_togpr;
        mem_selhl <= dec_selhl;
    end
end

assign lsu_idu_allowin  =  !mem_valid || mem_cango;
assign mem_validout     =  mem_valid && mem_cango;
assign mem_cango        =  mem_complete && rtu_lsu_allowin;
assign mem_complete     =  mem_mul_complete || mem_div_complete;

always @ ( posedge clk )
begin
    if(reset || wb_cancel) begin
        wb_valid <= 1'b0;
    end
    else if(rtu_lsu_allowin) begin
        wb_valid <= mem_valid && mem_complete && !mem_cancel;
    end

    if(data_reset) begin
        wb_togpr <= 1'b0;
        wb_selhl <= 1'b0;
    end
    else if(mem_validout) begin  // include rtu_lsu_allowin
        wb_togpr <= mem_togpr;
        wb_selhl <= mem_selhl;
    end
end

assign rtu_lsu_allowin  =  ~wb_valid || commit_en;
assign commit_en        =  (iu_inst_commit || mdu_inst_commit) && !wb_cancel;
assign iu_inst_commit   =  wb_valid && wb_togpr && iu_wb_mul && iu_wb_valid;
assign mdu_inst_commit  =  wb_valid && !wb_togpr && !(wb_newer_iuwb || wb_newer_iumem);

assign exu_idu_allowin  =  lsu_idu_allowin;
assign wb_dest_gpr      =  wb_togpr;
assign mdu_is_run       =  mem_valid || wb_valid;
assign exu_rtu_valid    =  wb_valid && wb_togpr && !wb_cancel;
assign sel_hl           =  wb_selhl;
endmodule  // exu_qmdu_pipe
